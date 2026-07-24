package com.example.flutter_receipt_scanner_android

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.util.Log

/** Orchestrates processing of one scanned camera page into a [ReceiptImageWire]. */
object ResultBuilder {
    private const val LOG_TAG = "ReceiptScanner.Gallery"

    /**
     * Pipeline (mirrors the RN camera path): decode → OCR (+ rotation detect) →
     * optional CW pixel rotation + re-OCR on the rotated frame → EXIF
     * read/synthesis → JPEG encode → `writeExifToFile` (last, so a re-compress
     * can't strip it).
     */
    fun processCameraPage(
        context: Context,
        uri: Uri,
        options: ScanOptionsWire,
        ocr: OcrProcessor,
    ): ReceiptImageWire? {
        val decoded = ImageProcessor.decodeOriented(context, uri) ?: return null
        val run = runOcrAndAutoRotate(decoded, options, ocr)
        val bitmap = run.bitmap

        val includeExif = options.includeExif ?: true
        val exif = ImageProcessor.readExif(context, uri, includeExif, synthesizeDeviceInfo = true)
        val file = ImageProcessor.encodeJpeg(context, bitmap, options.quality ?: 0.82) ?: return null
        exif?.writeTo(file)

        return ReceiptImageWire(
            uri = "file://${file.absolutePath}",
            width = bitmap.width.toLong(),
            height = bitmap.height.toLong(),
            fileName = file.name,
            mimeType = "image/jpeg",
            fileSize = file.length(),
            imageOrigin = ImageOriginWire.CAMERA,
            ocrText = run.ocrText,
            ocrQuality = qualityWire(run),
            exif = exif?.wire,
            ocrLines = run.ocrLines,
        )
    }

    /**
     * Pipeline for one confirmed gallery crop (mirrors [processCameraPage]):
     * perspective correct → OCR (+ rotation detect) → optional CW pixel rotation
     * + re-OCR on the rotated frame → JPEG encode → `writeTo` (last). [uri] is the
     * `file://` cache copy of the picked bytes and [corners] are its full-resolution
     * quad. Returns `null` on a soft failure (decode/encode);
     * [OutOfMemoryError] propagates so the caller can reject with `PROCESSING_FAILED`.
     */
    fun processGalleryImage(
        context: Context,
        uri: Uri,
        corners: FloatArray,
        options: ScanOptionsWire,
        ocr: OcrProcessor,
    ): ReceiptImageWire? {
        val includeExif = options.includeExif ?: true
        val includeGps = options.includeGpsExif ?: false
        val includeRaw = options.includeRawExif ?: false

        val gallery =
            try {
                ImageProcessor.processGallery(context, uri, corners, includeExif, includeGps, includeRaw)
            } catch (e: Exception) {
                Log.w(LOG_TAG, "processGallery failed for uri=$uri", e)
                return null
            }
        val imageOrigin = ImageProcessor.inferOrigin(context, uri, gallery.exif)

        val run = runOcrAndAutoRotate(gallery.bitmap, options, ocr)
        val bitmap = run.bitmap

        val file =
            ImageProcessor.encodeJpeg(context, bitmap, options.quality ?: 0.82) ?: run {
                bitmap.recycle()
                return null
            }
        // Write EXIF last so the JPEG encode above cannot strip it.
        gallery.exif?.writeTo(file)
        val width = bitmap.width.toLong()
        val height = bitmap.height.toLong()
        bitmap.recycle()

        return ReceiptImageWire(
            uri = "file://${file.absolutePath}",
            width = width,
            height = height,
            fileName = file.name,
            mimeType = "image/jpeg",
            fileSize = file.length(),
            imageOrigin = imageOrigin,
            ocrText = run.ocrText,
            ocrQuality = qualityWire(run),
            exif = gallery.exif?.wire,
            ocrLines = run.ocrLines,
        )
    }

    /** The output of [runOcrAndAutoRotate]: the (possibly rotated) bitmap plus OCR payload. */
    private data class OcrRun(
        val bitmap: Bitmap,
        val ocrText: String?,
        val confidence: Double?,
        val ocrLines: List<OcrLineWire>?,
    )

    /**
     * Recognize, bake any detected rotation into the pixels, then recognize again
     * on the rotated bitmap. The second pass is what keeps `ocrText`'s line order
     * (and the geometry boxes) matching the image that ships: ML Kit orders lines
     * by their position in the frame it was handed, so text recognized before the
     * rotation reads in the pre-rotation order — on a receipt turned 180° that is
     * bottom-to-top.
     *
     * An empty re-read counts as a failed one: reaching the re-read means the
     * first pass found enough text to detect a rotation, so "no lines now" says
     * the second pass didn't work, not that the receipt is blank. In that case
     * keep the first result and remap its boxes via [OcrGeometry.rotateClockwise]
     * instead — losing the corrected line order is cheaper than losing the text.
     *
     * Recycles the pre-rotation bitmap when it rotates; the returned bitmap is the
     * caller's to encode (and recycle, on the gallery path).
     */
    private fun runOcrAndAutoRotate(
        bitmap: Bitmap,
        options: ScanOptionsWire,
        ocr: OcrProcessor,
    ): OcrRun {
        val runOcr = options.ocr ?: true
        if (!runOcr) return OcrRun(bitmap, null, null, null)

        val autoRotate = options.autoRotate ?: true
        val ocrGeometry = options.ocrGeometry ?: false
        val sourceWidth = bitmap.width
        val sourceHeight = bitmap.height

        val detected = ocr.recognizeWithRotationDetection(bitmap, autoRotate)
        var outBitmap = bitmap
        var result = detected
        var remapDegrees = 0
        var frameWidth = sourceWidth
        var frameHeight = sourceHeight

        if (autoRotate && detected.rotationDegrees != 0) {
            val rotated = ImageProcessor.rotate(bitmap, detected.rotationDegrees)
            if (rotated !== bitmap) bitmap.recycle()
            outBitmap = rotated
            frameWidth = rotated.width
            frameHeight = rotated.height

            val refreshed =
                try {
                    ocr.recognizeInFinalFrame(rotated)
                } catch (e: Exception) {
                    Log.w(LOG_TAG, "Re-OCR after auto-rotate failed", e)
                    null
                }
            if (refreshed != null && refreshed.lineCount > 0) {
                // Fresh boxes were measured on the output frame — no remap owed.
                result = refreshed
                remapDegrees = 0
            } else {
                // Keep the pre-rotation result; its boxes still owe the rotation.
                result = detected
                remapDegrees = detected.rotationDegrees
            }
        }

        val ocrLines =
            if (ocrGeometry) {
                result.lines.mapNotNull { line ->
                    val turned = OcrGeometry.rotateClockwise(line.box, sourceWidth, sourceHeight, remapDegrees)
                    OcrGeometry.clamp(turned, frameWidth, frameHeight)?.let { lineToWire(line, it) }
                }
            } else {
                null
            }

        return OcrRun(outBitmap, result.text, result.confidence, ocrLines)
    }

    private fun lineToWire(
        line: OcrProcessor.Line,
        box: OcrGeometry.Box,
    ): OcrLineWire =
        OcrLineWire(
            text = line.text,
            x = box.x.toLong(),
            y = box.y.toLong(),
            width = box.width.toLong(),
            height = box.height.toLong(),
            confidence = line.confidence,
        )

    /** Builds the reporting-only `ocrQuality` wire, or null when OCR produced no text. */
    private fun qualityWire(run: OcrRun): OcrQualityWire? =
        if (run.ocrText == null) {
            null
        } else {
            OcrQualityWire(textLength = null, lineCount = null, confidence = run.confidence)
        }
}

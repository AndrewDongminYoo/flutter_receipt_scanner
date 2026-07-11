package com.example.flutter_receipt_scanner_android

import android.content.Context
import android.net.Uri
import android.util.Log

/** Orchestrates processing of one scanned camera page into a [ReceiptImageWire]. */
object ResultBuilder {
    private const val LOG_TAG = "ReceiptScanner.Gallery"

    /**
     * Pipeline (mirrors the RN camera path): decode → OCR (+ rotation detect) →
     * optional CW pixel rotation → EXIF read/synthesis → JPEG encode →
     * `writeExifToFile` (last, so a re-compress can't strip it).
     */
    fun processCameraPage(
        context: Context,
        uri: Uri,
        options: ScanOptionsWire,
        ocr: OcrProcessor,
    ): ReceiptImageWire? {
        var bitmap = ImageProcessor.decodeOriented(context, uri) ?: return null

        val runOcr = options.ocr ?: true
        val autoRotate = options.autoRotate ?: true
        var ocrText: String? = null
        var confidence: Double? = null
        if (runOcr) {
            val outcome = ocr.recognize(bitmap, autoRotate)
            ocrText = outcome.text
            confidence = outcome.confidence
            if (autoRotate && outcome.rotationDegrees != 0) {
                bitmap = ImageProcessor.rotate(bitmap, outcome.rotationDegrees)
            }
        }

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
            ocrText = ocrText,
            ocrQuality =
                if (ocrText == null) {
                    null
                } else {
                    OcrQualityWire(textLength = null, lineCount = null, confidence = confidence)
                },
            exif = exif?.wire,
        )
    }

    /**
     * Pipeline for one confirmed gallery crop (mirrors [processCameraPage]): perspective
     * correct → OCR (+ rotation detect) → optional CW pixel rotation → JPEG encode →
     * `writeTo` (last). [uri] is the `file://` cache copy of the picked bytes and [corners]
     * are its full-resolution quad. Returns `null` on a soft failure (decode/encode);
     * [OutOfMemoryError] propagates so the caller can reject with `out_of_memory`.
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
        var bitmap = gallery.bitmap
        val imageOrigin = ImageProcessor.inferOrigin(context, uri, gallery.exif)

        val runOcr = options.ocr ?: true
        val autoRotate = options.autoRotate ?: true
        var ocrText: String? = null
        var confidence: Double? = null
        if (runOcr) {
            val outcome = ocr.recognize(bitmap, autoRotate)
            ocrText = outcome.text
            confidence = outcome.confidence
            if (autoRotate && outcome.rotationDegrees != 0) {
                val rotated = ImageProcessor.rotate(bitmap, outcome.rotationDegrees)
                if (rotated !== bitmap) bitmap.recycle()
                bitmap = rotated
            }
        }

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
            ocrText = ocrText,
            ocrQuality =
                if (ocrText == null) {
                    null
                } else {
                    OcrQualityWire(textLength = null, lineCount = null, confidence = confidence)
                },
            exif = gallery.exif?.wire,
        )
    }
}

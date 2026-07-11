package com.example.flutter_receipt_scanner_android

import android.content.Context
import android.net.Uri

/** Orchestrates processing of one scanned camera page into a [ReceiptImageWire]. */
object ResultBuilder {
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
}

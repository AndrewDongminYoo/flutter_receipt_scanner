package com.example.flutter_receipt_scanner_android

import android.graphics.Bitmap
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

/** Result of an OCR pass, including the detected upright rotation. */
data class OcrOutcome(
    val text: String?,
    val confidence: Double?,
    /**
     * Detected upright rotation in degrees using the Android CW convention (see
     * the native port map §6.2 / §6.3). 0 when no rotation is warranted.
     */
    val rotationDegrees: Int,
)

/**
 * Korean/English on-device OCR with single-pass, aspect-mismatch rotation
 * detection.
 *
 * Faithful port of the RN `OcrProcessor`: the Korean recognizer is rotation
 * invariant (validated on `text-recognition-korean` 16.0.0, pinned 16.0.1), so
 * a single measurement suffices — multi-pass probing (as on iOS) is useless
 * here. `close()` the shared client once per scan.
 */
class OcrProcessor {
    private val recognizer: TextRecognizer =
        TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())

    private companion object {
        const val MISMATCH_MIN_LINES = 5
        const val MIN_LINES_TO_JUDGE = 3
        const val ROTATED_DEFAULT_DEGREES = 270
    }

    /** Recognizes text and, when [autoRotate] is on, detects the upright rotation. */
    fun recognize(
        bitmap: Bitmap,
        autoRotate: Boolean,
    ): OcrOutcome {
        val pass = measure(bitmap)
        if (!autoRotate || pass.lineCount < MIN_LINES_TO_JUDGE) {
            return OcrOutcome(pass.text, pass.confidence, 0)
        }
        if (pass.lineCount < MISMATCH_MIN_LINES) {
            return OcrOutcome(pass.text, pass.confidence, 0)
        }

        val imageIsLandscape = bitmap.width.toDouble() / bitmap.height > 1
        val lineIsVertical = pass.lineAspect < 0.7
        // A portrait receipt held sideways: image is landscape but glyph lines
        // run vertically. Ambiguous aspect bands stay upright.
        val degrees = if (imageIsLandscape && lineIsVertical) ROTATED_DEFAULT_DEGREES else 0
        return OcrOutcome(pass.text, pass.confidence, degrees)
    }

    fun close() = recognizer.close()

    private data class Measurement(
        val text: String?,
        val confidence: Double?,
        val lineCount: Int,
        val lineAspect: Double,
    )

    private fun measure(bitmap: Bitmap): Measurement {
        val image = InputImage.fromBitmap(bitmap, 0)
        val result = Tasks.await(recognizer.process(image))
        val lines = result.textBlocks.flatMap { it.lines }
        if (lines.isEmpty()) return Measurement(null, null, 0, 1.0)

        var confSum = 0.0
        var confCount = 0
        val aspects = mutableListOf<Double>()
        for (line in lines) {
            val c = line.confidence
            if (!c.isNaN()) {
                confSum += c
                confCount++
            }
            val box = line.boundingBox
            if (box != null && box.height() > 0) {
                aspects.add(box.width().toDouble() / box.height())
            }
        }
        val text = result.text.ifEmpty { null }
        val confidence = if (confCount == 0) null else confSum / confCount
        return Measurement(text, confidence, lines.size, trimmedMean(aspects))
    }

    /** Trimmed mean (10% each end when >= 5 samples) of per-line aspect ratios. */
    private fun trimmedMean(values: List<Double>): Double {
        if (values.isEmpty()) return 1.0
        val sorted = values.sorted()
        val trim = if (sorted.size >= 5) (sorted.size * 0.1).toInt() else 0
        val kept = sorted.subList(trim, sorted.size - trim)
        return kept.average()
    }
}

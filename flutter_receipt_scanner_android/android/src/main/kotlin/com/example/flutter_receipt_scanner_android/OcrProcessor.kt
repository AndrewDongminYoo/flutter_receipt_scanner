package com.example.flutter_receipt_scanner_android

import android.graphics.Bitmap
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

/** Result of an OCR pass, including the detected upright rotation and per-line geometry. */
data class OcrOutcome(
    val text: String?,
    val confidence: Double?,
    /**
     * Detected upright rotation in degrees using the Android CW convention (see
     * the native port map §6). 0 when no rotation is warranted.
     */
    val rotationDegrees: Int,
    /** Number of recognized lines — feeds the Dart OCR-floor gate and the re-read check. */
    val lineCount: Int,
    /**
     * Per-line geometry in the coordinates of the image handed to
     * [OcrProcessor.recognizeWithRotationDetection] — i.e. *before* any pixel
     * auto-rotate. Callers that rotate the pixels afterwards must remap via
     * [OcrGeometry.rotateClockwise] (or re-measure with [recognizeInFinalFrame]).
     */
    val lines: List<OcrProcessor.Line>,
)

/**
 * Korean/English on-device OCR with text-angle rotation detection.
 *
 * Faithful port of the RN `OcrProcessor` (v2.0): rotation is decided primarily
 * by ML Kit's per-line `getAngle`, which carries *direction* and so separates
 * 90 from 270 and detects a plain 180 flip. The older image-vs-line aspect
 * mismatch stays as a fallback for samples too small or too split to judge.
 *
 * The Korean recognizer covers Latin too (pinned `text-recognition-korean`
 * 16.0.1). `close()` the shared client once per scan. Every method blocks on
 * [Tasks.await] and must be called from a background thread.
 */
class OcrProcessor {
    private val recognizer: TextRecognizer =
        TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())

    private companion object {
        const val MISMATCH_MIN_LINES = 5
        const val MIN_LINES_TO_JUDGE = 3
        const val ROTATED_DEFAULT_DEGREES = 270

        /** Below this trimmed line-aspect the glyph lines run vertically. */
        const val LINE_VERTICAL_THRESHOLD = 0.7
    }

    /**
     * One recognized line with the box it occupies, in the coordinates of the
     * image handed to [recognizeWithRotationDetection] — the frame *before* any
     * auto-rotate. Callers that rotate the pixels afterwards remap via
     * [OcrGeometry.rotateClockwise].
     */
    data class Line(
        val text: String,
        val box: OcrGeometry.Box,
        val confidence: Double?,
    )

    /**
     * Recognizes [bitmap] and, when [autoRotate] is on, detects the upright
     * rotation. The returned [OcrOutcome.lines] sit in [bitmap]'s frame; when a
     * non-zero rotation is returned the caller is expected to bake it into the
     * pixels and then either re-measure with [recognizeInFinalFrame] or remap.
     */
    fun recognizeWithRotationDetection(
        bitmap: Bitmap,
        autoRotate: Boolean,
    ): OcrOutcome {
        val m = measure(bitmap)
        if (!autoRotate || m.lineCount < MIN_LINES_TO_JUDGE) {
            return OcrOutcome(m.text, m.confidence, 0, m.lineCount, m.lines)
        }

        // Fallback signal: image-vs-line aspect direction. A landscape image
        // whose glyph lines run vertically is a portrait receipt held sideways.
        // Computed up front because the angle path uses it as a sanity check.
        val imageIsLandscape = bitmap.width.toDouble() / bitmap.height > 1
        val lineIsVertical = m.lineAspect < LINE_VERTICAL_THRESHOLD
        val hasEnoughLinesForAspect = m.lineCount >= MISMATCH_MIN_LINES
        val aspectSuggestsRotation = imageIsLandscape && lineIsVertical && hasEnoughLinesForAspect

        // Primary signal: the text angle itself carries direction, so it separates
        // 90 from 270 and catches a 180 flip — cases lineAspect cannot reach. A
        // confirmed 0 counts as an answer, except when lineAspect independently
        // says the content is sideways (a possible reading-frame mismatch); defer
        // to the fallback there rather than newly refusing a rotation.
        val textAngle = OcrGeometry.dominantQuarterTurn(m.angles)
        val angleContradictsAspect = textAngle == 0 && aspectSuggestsRotation
        if (textAngle != null && !angleContradictsAspect) {
            val correction = OcrGeometry.correctionForTextAngle(textAngle)
            return OcrOutcome(m.text, m.confidence, correction, m.lineCount, m.lines)
        }

        // Fallback needs enough lines for the aspect mean to be reliable.
        if (!hasEnoughLinesForAspect) {
            return OcrOutcome(m.text, m.confidence, 0, m.lineCount, m.lines)
        }
        val degrees = if (imageIsLandscape && lineIsVertical) ROTATED_DEFAULT_DEGREES else 0
        return OcrOutcome(m.text, m.confidence, degrees, m.lineCount, m.lines)
    }

    /**
     * Plain recognition with **no** rotation detection, for the caller that has
     * already baked a rotation into [bitmap]'s pixels and needs the text order
     * and the boxes to belong to the frame it actually ships. The image is
     * upright by now, so re-detecting would be wasted work and a needless chance
     * to act on a spurious reading.
     */
    fun recognizeInFinalFrame(bitmap: Bitmap): OcrOutcome {
        val m = measure(bitmap)
        return OcrOutcome(m.text, m.confidence, 0, m.lineCount, m.lines)
    }

    fun close() = recognizer.close()

    private data class Measurement(
        val text: String?,
        val confidence: Double?,
        val lineCount: Int,
        val lineAspect: Double,
        val lines: List<Line>,
        /** Per-line clockwise text angles, straight from ML Kit. May contain NaN. */
        val angles: List<Float>,
    )

    private fun measure(bitmap: Bitmap): Measurement {
        val image = InputImage.fromBitmap(bitmap, 0)
        val result = Tasks.await(recognizer.process(image))
        val allLines = result.textBlocks.flatMap { it.lines }
        if (allLines.isEmpty()) return Measurement(null, null, 0, 1.0, emptyList(), emptyList())

        var confSum = 0.0
        var confCount = 0
        val aspects = mutableListOf<Double>()
        val lines = mutableListOf<Line>()
        val angles = mutableListOf<Float>()
        for (line in allLines) {
            val c = line.confidence
            if (!c.isNaN()) {
                confSum += c
                confCount++
            }
            val box = line.boundingBox
            if (box != null && box.height() > 0) {
                aspects.add(box.width().toDouble() / box.height())
            }

            // Per-line angle + geometry skip blank text: an angle keeps its line
            // even without a box (it still counts toward the mode), but geometry
            // needs a positive-area box. Mirrors RN `anglesOf` / `linesOf`.
            if (line.text.isNotBlank()) {
                angles.add(line.angle)
                if (box != null) {
                    val w = box.width()
                    val h = box.height()
                    if (w > 0 && h > 0) {
                        lines.add(
                            Line(
                                text = line.text,
                                box = OcrGeometry.Box(box.left, box.top, w, h),
                                confidence = if (c.isNaN()) null else c.toDouble(),
                            ),
                        )
                    }
                }
            }
        }
        val text = result.text.ifEmpty { null }
        val confidence = if (confCount == 0) null else confSum / confCount
        return Measurement(text, confidence, allLines.size, trimmedMean(aspects), lines, angles)
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

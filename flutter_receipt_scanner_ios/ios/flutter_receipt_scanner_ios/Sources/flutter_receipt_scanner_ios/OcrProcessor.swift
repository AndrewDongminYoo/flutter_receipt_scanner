import CoreGraphics
import Foundation
import Vision

/// Result of an OCR pass over a single image.
struct OcrOutcome {
    let text: String?
    let confidence: Double?
    /// Detected upright rotation, in degrees, using the iOS CCW convention (see
    /// the native port map §6). 0 when no rotation is warranted. The caller bakes
    /// it into the output pixels via `ImageProcessor.rotated(_:byDegreesCCW:)`.
    let rotationDegrees: Int
    /// Number of recognized lines in the chosen pass.
    let lineCount: Int
    /// Per-line geometry in top-left pixels of `passSize` — the frame the chosen
    /// pass ran on, i.e. the *rotated* frame whenever `rotationDegrees` is
    /// non-zero, so it already matches the image the caller ships.
    let lines: [OcrLineBox]
    /// Pixel size of the frame `lines` sit in.
    let passSize: CGSize
    /// The already-rotated bitmap the chosen pass measured on, when
    /// `rotationDegrees` is non-zero. Callers must encode THIS frame instead of
    /// rotating again: it saves a full-size redraw and guarantees the shipped
    /// pixels and the measured boxes share one frame.
    let rotatedFrame: CGImage?
}

/// Korean/English on-device OCR with text-angle rotation detection.
///
/// Faithful port of the RN `RNOcrProcessor` (v2.0): the primary rotation signal
/// is the text angle read off each Vision observation's quad, which carries
/// direction and so separates 90 from 270 and catches a plain 180 flip. The
/// older count-based multi-pass probe stays as the fallback. When a rotation is
/// chosen the image is actually rotated and re-recognized, so `lines` and the
/// text order belong to the frame that ships. `usesLanguageCorrection` is off
/// (receipt prices/codes are not dictionary words).
enum OcrProcessor {
    /// Default minimum text height as a fraction of image height (1/32).
    static let defaultMinTextHeight: Float = 1.0 / 32.0

    private static let minLinesToJudgeOrientation = 3
    private static let uprightLineCount = 8
    private static let rotateCommitRatio = 1.3

    /// Recognizes text and, when `autoRotate` is on, detects the upright rotation.
    static func recognize(
        _ cg: CGImage,
        minimumTextHeight: Float,
        autoRotate: Bool
    ) -> OcrOutcome {
        let effectiveHeight = minimumTextHeight > 0 ? minimumTextHeight : defaultMinTextHeight
        let size0 = CGSize(width: cg.width, height: cg.height)
        let pass0 = recognizeText(cg, orientation: 0, level: .accurate, minHeight: effectiveHeight, pixelSize: size0)

        // Skeleton: "0° accepted". Every early return ships pass0's upright boxes.
        let upright = OcrOutcome(
            text: pass0.text, confidence: pass0.confidence, rotationDegrees: 0,
            lineCount: pass0.count, lines: pass0.lines, passSize: size0, rotatedFrame: nil
        )
        guard autoRotate, pass0.count >= minLinesToJudgeOrientation else { return upright }

        // Primary signal: the angle of the text itself. Read off the observation
        // quad, it carries direction the line *count* cannot — which is precisely
        // why a 180°-flipped receipt (plenty of lines, every one upside down) was
        // never detected. Runs ahead of the count fast paths for that reason.
        let textAngle = OcrGeometry.dominantQuarterTurn(fromAngles: pass0.angles)
        if textAngle != OcrGeometry.quarterTurnUnknown {
            let correction = OcrGeometry.correctionForTextAngle(textAngle)
            // Only act on a quarter turn, never a confirmed 0: the probe loop is
            // still live on iOS versions where Vision is not rotation-robust, so
            // letting a 0 short-circuit it would regress them if the angle turns
            // out to be reported in Vision's own reading frame.
            if correction != 0 {
                // `correction` is clockwise (canonical); rotate the pixels the
                // complementary CCW amount and re-recognize on that frame.
                return measureRotated(
                    cg, ccwDegrees: (360 - correction) % 360, minHeight: effectiveHeight,
                    fallback: pass0, fallbackSize: size0
                )
            }
        }

        // Fast paths: a clearly-upright page needs no probing.
        let aspect = Double(cg.width) / Double(max(cg.height, 1))
        let isLandscape = aspect > 1
        if !isLandscape, pass0.count >= uprightLineCount { return upright }
        if isLandscape, pass0.count >= uprightLineCount, aspect <= 1.5 { return upright }

        // Fallback: count-based multi-pass probe.
        let probes = isLandscape ? [90, 180, 270] : [180]
        var bestDegrees = 0
        var bestCount = pass0.count
        for degrees in probes {
            let probe = recognizeText(
                cg, orientation: degrees, level: .fast, minHeight: effectiveHeight, pixelSize: size0
            )
            if probe.count > bestCount {
                bestCount = probe.count
                bestDegrees = degrees
            }
        }
        // Bias against rotating: a false rotation is worse than a missed one.
        guard bestDegrees != 0, Double(bestCount) >= Double(pass0.count) * rotateCommitRatio else {
            return upright
        }
        return measureRotated(
            cg, ccwDegrees: bestDegrees, minHeight: effectiveHeight, fallback: pass0, fallbackSize: size0
        )
    }

    /// Rotates `cg` by `ccwDegrees` and re-recognizes on that frame, so the text
    /// order and boxes belong to the image that ships. The rotation is always
    /// committed (RN parity — see the port map §6): an empty re-read indicts the
    /// re-read, not the receipt, because reaching here means `fallback` (pass0)
    /// found enough text to detect the rotation. In that case the pre-rotation
    /// text ships and its boxes are remapped into the rotated frame — the same
    /// fallback Android's `runOcrAndAutoRotate` uses.
    private static func measureRotated(
        _ cg: CGImage, ccwDegrees: Int, minHeight: Float, fallback: Pass, fallbackSize: CGSize
    ) -> OcrOutcome {
        let rotated = ImageProcessor.rotated(cg, byDegreesCCW: ccwDegrees)
        let size = CGSize(width: rotated.width, height: rotated.height)
        let pass = recognizeText(rotated, orientation: 0, level: .accurate, minHeight: minHeight, pixelSize: size)
        if pass.text != nil {
            return OcrOutcome(
                text: pass.text, confidence: pass.confidence, rotationDegrees: ccwDegrees,
                lineCount: pass.count, lines: pass.lines, passSize: size, rotatedFrame: rotated
            )
        }
        // The frame is rotated CCW, so boxes move the complementary CW amount.
        let remapped = OcrGeometry.linesByRotating(
            fallback.lines, frameSize: fallbackSize,
            clockwiseDegrees: (360 - ccwDegrees) % 360, outputSize: size
        )
        return OcrOutcome(
            text: fallback.text, confidence: fallback.confidence, rotationDegrees: ccwDegrees,
            lineCount: fallback.count, lines: remapped, passSize: size, rotatedFrame: rotated
        )
    }

    private struct Pass {
        let text: String?
        let confidence: Double?
        let count: Int
        let lines: [OcrLineBox]
        /// Per-observation clockwise text angles — the iOS counterpart of ML Kit's
        /// `Text.Line.getAngle`, read off each observation quad.
        let angles: [CGFloat]
    }

    private static func recognizeText(
        _ cg: CGImage,
        orientation degrees: Int,
        level: VNRequestTextRecognitionLevel,
        minHeight: Float,
        pixelSize: CGSize
    ) -> Pass {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = minHeight

        let handler = VNImageRequestHandler(cgImage: cg, orientation: cgOrientation(for: degrees), options: [:])
        try? handler.perform([request])
        guard let observations = request.results, !observations.isEmpty else {
            return Pass(text: nil, confidence: nil, count: 0, lines: [], angles: [])
        }

        var lineStrings: [String] = []
        var lines: [OcrLineBox] = []
        var angles: [CGFloat] = []
        var confSum: Float = 0
        var confCount = 0
        for obs in observations {
            guard let top = obs.topCandidates(1).first else { continue }
            let trimmed = top.string.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            lineStrings.append(top.string)
            confSum += top.confidence
            confCount += 1
            angles.append(
                OcrGeometry.clockwiseAngle(fromTopLeft: obs.topLeft, topRight: obs.topRight, pixelSize: pixelSize)
            )
            let box = OcrGeometry.rect(fromNormalizedBox: obs.boundingBox, pixelSize: pixelSize)
            if box.width > 0, box.height > 0 {
                lines.append(OcrLineBox(text: top.string, box: box, confidence: Double(top.confidence)))
            }
        }
        let text = lineStrings.isEmpty ? nil : lineStrings.joined(separator: "\n")
        let confidence = confCount == 0 ? nil : Double(confSum / Float(confCount))
        return Pass(text: text, confidence: confidence, count: lineStrings.count, lines: lines, angles: angles)
    }

    /// Maps a CCW rotation in degrees to the `CGImagePropertyOrientation` that
    /// makes Vision read the image as if rotated by that amount.
    private static func cgOrientation(for degrees: Int) -> CGImagePropertyOrientation {
        switch ((degrees % 360) + 360) % 360 {
        case 90: return .left
        case 180: return .down
        case 270: return .right
        default: return .up
        }
    }

    /// Places `outcome`'s per-line boxes in the `outputSize` frame and maps them
    /// to the wire type, or nil when geometry wasn't requested. The boxes already
    /// sit in the chosen pass's (rotated) frame, so this only rescales onto the
    /// encoded output size and clamps — see `OcrGeometry.linesByRotating`.
    static func ocrLinesWire(_ outcome: OcrOutcome, outputSize: CGSize, enabled: Bool) -> [OcrLineWire]? {
        guard enabled else { return nil }
        return OcrGeometry.linesByRotating(
            outcome.lines, frameSize: outcome.passSize, clockwiseDegrees: 0, outputSize: outputSize
        ).compactMap { line in
            // Round the edges and derive the extents from them, so x + width can
            // never overshoot the clamped frame; slivers that round to zero area
            // drop instead of shipping the degenerate boxes the wire doc forbids.
            let x = Int64(line.box.minX.rounded())
            let y = Int64(line.box.minY.rounded())
            let width = Int64(line.box.maxX.rounded()) - x
            let height = Int64(line.box.maxY.rounded()) - y
            guard width > 0, height > 0 else { return nil }
            return OcrLineWire(
                text: line.text, x: x, y: y, width: width, height: height, confidence: line.confidence
            )
        }
    }
}

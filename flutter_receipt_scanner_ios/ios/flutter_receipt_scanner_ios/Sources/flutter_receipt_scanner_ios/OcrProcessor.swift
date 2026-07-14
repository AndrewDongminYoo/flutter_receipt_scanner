import CoreGraphics
import Foundation
import Vision

/// Result of an OCR pass over a single image.
struct OcrOutcome {
    let text: String?
    let confidence: Double?
    /// Detected upright rotation, in degrees, using the iOS CCW convention
    /// (see the native port map §6.1 / §6.3). 0 when no rotation is warranted.
    let rotationDegrees: Int
}

/// Korean/English on-device OCR with orientation detection.
///
/// Faithful port of the RN `RNOcrProcessor` behavior: `usesLanguageCorrection`
/// is off (receipt prices/codes are not dictionary words), `minimumTextHeight`
/// is honored (iOS-only), and rotation is chosen by a count-based multi-pass
/// heuristic — NOT the confidence formula in the (drifted) design doc.
enum OcrProcessor {
    /// Default minimum text height as a fraction of image height (1/32).
    static let defaultMinTextHeight: Float = 1.0 / 32.0

    private static let minLinesToJudgeOrientation = 3
    private static let uprightLineCount = 8
    private static let rotateCommitRatio = 1.3

    /// Recognizes text and, when `autoRotate` is on, detects the upright rotation.
    ///
    /// When `autoRotate` is false the text is still recognized (and 180° reads are
    /// corrected implicitly by the recognizer) but `rotationDegrees` is 0.
    static func recognize(
        _ cg: CGImage,
        minimumTextHeight: Float,
        autoRotate: Bool
    ) -> OcrOutcome {
        let effectiveHeight = minimumTextHeight > 0 ? minimumTextHeight : defaultMinTextHeight

        let pass0 = recognizeText(cg, orientation: 0, level: .accurate, minHeight: effectiveHeight)
        guard autoRotate, pass0.count >= minLinesToJudgeOrientation else {
            return OcrOutcome(text: pass0.text, confidence: pass0.confidence, rotationDegrees: 0)
        }

        let aspect = Double(cg.width) / Double(max(cg.height, 1))
        let isLandscape = aspect > 1
        // Fast paths: a clearly-upright page needs no probing.
        if !isLandscape, pass0.count >= uprightLineCount {
            return OcrOutcome(text: pass0.text, confidence: pass0.confidence, rotationDegrees: 0)
        }
        if isLandscape, pass0.count >= uprightLineCount, aspect <= 1.5 {
            return OcrOutcome(text: pass0.text, confidence: pass0.confidence, rotationDegrees: 0)
        }

        let probes = isLandscape ? [90, 180, 270] : [180]
        var bestDegrees = 0
        var bestCount = pass0.count
        var bestProbeText: String?
        for degrees in probes {
            let probe = recognizeText(cg, orientation: degrees, level: .fast, minHeight: effectiveHeight)
            if probe.count > bestCount {
                bestCount = probe.count
                bestDegrees = degrees
                bestProbeText = probe.text
            }
        }

        // Bias against rotating: a false rotation is worse than a missed one.
        guard bestDegrees != 0, Double(bestCount) >= Double(pass0.count) * rotateCommitRatio else {
            return OcrOutcome(text: pass0.text, confidence: pass0.confidence, rotationDegrees: 0)
        }

        let finalPass = recognizeText(cg, orientation: bestDegrees, level: .accurate, minHeight: effectiveHeight)
        // On final-pass failure fall back to the winning probe's text (matches the
        // committed rotation), not the 0° pass0 text; pass0 is the last resort.
        let text = finalPass.text ?? bestProbeText ?? pass0.text
        return OcrOutcome(text: text, confidence: finalPass.confidence, rotationDegrees: bestDegrees)
    }

    private struct Pass {
        let text: String?
        let confidence: Double?
        let count: Int
    }

    private static func recognizeText(
        _ cg: CGImage,
        orientation degrees: Int,
        level: VNRequestTextRecognitionLevel,
        minHeight: Float
    ) -> Pass {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = minHeight

        let handler = VNImageRequestHandler(cgImage: cg, orientation: cgOrientation(for: degrees), options: [:])
        try? handler.perform([request])
        guard let observations = request.results, !observations.isEmpty else {
            return Pass(text: nil, confidence: nil, count: 0)
        }

        var lines: [String] = []
        var confSum: Float = 0
        var confCount = 0
        for obs in observations {
            guard let top = obs.topCandidates(1).first else { continue }
            let trimmed = top.string.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            lines.append(top.string)
            confSum += top.confidence
            confCount += 1
        }
        let text = lines.isEmpty ? nil : lines.joined(separator: "\n")
        let confidence = confCount == 0 ? nil : Double(confSum / Float(confCount))
        return Pass(text: text, confidence: confidence, count: lines.count)
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
}

import CoreGraphics
import Foundation

/// One recognized line: its text, its box in top-left-origin pixels, and ML
/// Kit/Vision's per-line confidence when finite.
struct OcrLineBox {
    let text: String
    var box: CGRect
    let confidence: Double?
}

/// Places OCR line boxes in the frame the output image actually ships in, and
/// turns per-line text angles into the rotation that puts them upright.
/// Mirrors the Kotlin `OcrGeometry`; see the native port map §6. The angle
/// formulas are the shared cross-platform contract — a sign slip here silently
/// swaps 90 and 270.
enum OcrGeometry {
    /// Returned by `dominantQuarterTurn` when the sample is too small or split.
    static let quarterTurnUnknown = -1

    /// Minimum lines carrying a finite angle before the mode is trusted. PROVISIONAL.
    static let angleMinLines = 5

    /// Fraction of lines the winning quarter turn must hold. PROVISIONAL.
    static let angleMajority = 0.7

    /// Converts one Vision bounding box — normalized `[0, 1]`, bottom-left origin
    /// — into top-left-origin pixels of a `pixelSize` frame.
    static func rect(fromNormalizedBox box: CGRect, pixelSize: CGSize) -> CGRect {
        CGRect(
            x: box.minX * pixelSize.width,
            y: (1.0 - box.maxY) * pixelSize.height,
            width: box.width * pixelSize.width,
            height: box.height * pixelSize.height
        )
    }

    /// Rotates `rect` clockwise by `degrees` (0 / 90 / 180 / 270) inside a
    /// `frameSize` frame and returns it in the rotated frame's coordinates.
    /// Width and height swap for 90 / 270. Clockwise is the Android
    /// `Matrix.postRotate` convention this package canonicalized on.
    static func rect(byRotating rect: CGRect, frameSize: CGSize, clockwiseDegrees degrees: Int) -> CGRect {
        let frameW = frameSize.width, frameH = frameSize.height
        let x = rect.origin.x, y = rect.origin.y, w = rect.size.width, h = rect.size.height
        switch ((degrees % 360) + 360) % 360 {
        case 90: return CGRect(x: frameH - y - h, y: x, width: h, height: w)
        case 180: return CGRect(x: frameW - x - w, y: frameH - y - h, width: w, height: h)
        case 270: return CGRect(x: y, y: frameW - x - w, width: h, height: w)
        default: return rect
        }
    }

    /// Places every line's box in the output image's coordinate space: rotates
    /// by `degrees`, rescales onto `outputSize`, clamps, and drops lines whose
    /// box clamps to nothing. The rescale keeps the emitted coordinates inside
    /// the output frame even if Vision measured on a frame of a slightly
    /// different size; it is a no-op in the expected case where they agree.
    static func linesByRotating(
        _ lines: [OcrLineBox],
        frameSize: CGSize,
        clockwiseDegrees degrees: Int,
        outputSize: CGSize
    ) -> [OcrLineBox] {
        let turn = ((degrees % 360) + 360) % 360
        let swapsAxes = (turn == 90 || turn == 270)
        let turnedFrame = CGSize(
            width: swapsAxes ? frameSize.height : frameSize.width,
            height: swapsAxes ? frameSize.width : frameSize.height
        )
        guard turnedFrame.width > 0, turnedFrame.height > 0 else { return [] }
        let scaleX = outputSize.width / turnedFrame.width
        let scaleY = outputSize.height / turnedFrame.height
        let bounds = CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height)

        var placed: [OcrLineBox] = []
        placed.reserveCapacity(lines.count)
        for line in lines {
            let turned = rect(byRotating: line.box, frameSize: frameSize, clockwiseDegrees: turn)
            let scaled = CGRect(
                x: turned.origin.x * scaleX, y: turned.origin.y * scaleY,
                width: turned.size.width * scaleX, height: turned.size.height * scaleY
            )
            let clamped = scaled.intersection(bounds)
            if clamped.isNull || clamped.isEmpty { continue }
            var out = line
            out.box = clamped
            placed.append(out)
        }
        return placed
    }

    // MARK: - Text angle rotation detection

    /// Clockwise angle in degrees of the text running from `topLeft` to
    /// `topRight`. Both points come from `VNRectangleObservation`: normalized,
    /// **bottom-left** origin. Negating the y component moves to the top-left
    /// origin the rest of this package uses, which is what turns Vision's
    /// convention into the clockwise one Android's `Text.Line.getAngle` reports.
    static func clockwiseAngle(fromTopLeft topLeft: CGPoint, topRight: CGPoint) -> CGFloat {
        let dx = topRight.x - topLeft.x
        let dy = topRight.y - topLeft.y
        return CGFloat(atan2(Double(-dy), Double(dx)) * 180.0 / .pi)
    }

    /// Rounds a clockwise text angle to the nearest quarter turn, normalized into
    /// `[0, 360)`. Uses `floor(x + 0.5)`, deliberately not `rounded()` /
    /// `lround` (ties away from zero): Kotlin's `roundToInt` rounds ties toward
    /// positive infinity, and the two platforms must land -45 / -135 in the same
    /// bin.
    static func quantizeQuarterTurn(_ degrees: CGFloat) -> Int {
        let quarters = Int((Double(degrees) / 90.0 + 0.5).rounded(.down))
        return ((quarters * 90) % 360 + 360) % 360
    }

    /// The clockwise rotation that puts text sitting at `quarterTurn` back upright.
    static func correctionForTextAngle(_ quarterTurn: Int) -> Int {
        (360 - (((quarterTurn % 360) + 360) % 360)) % 360
    }

    /// Counts of finite angles per quarter-turn bin, indexed `turn / 90`.
    /// Non-finite entries are dropped, so the sum is the usable sample size.
    static func quarterTurnHistogram(fromAngles angles: [CGFloat]) -> [Int] {
        var bins = [0, 0, 0, 0]
        for angle in angles where angle.isFinite {
            bins[quantizeQuarterTurn(angle) / 90] += 1
        }
        return bins
    }

    /// Dominant quarter turn across per-line text angles, or `quarterTurnUnknown`
    /// when the sample is too small or too split. Angles are binned before
    /// counting rather than averaged: a linear mean of -179 and +179 is 0, the
    /// opposite of the truth.
    static func dominantQuarterTurn(fromAngles angles: [CGFloat]) -> Int {
        let bins = quarterTurnHistogram(fromAngles: angles)
        let total = bins.reduce(0, +)
        if total < angleMinLines { return quarterTurnUnknown }
        var best = 0
        for i in 1 ..< bins.count where bins[i] > bins[best] {
            best = i
        }
        if Double(bins[best]) / Double(total) < angleMajority { return quarterTurnUnknown }
        return best * 90
    }
}

import CoreImage
import Foundation
import UIKit
import Vision

/// Document-quad detection, the distortion backstop, and perspective correction
/// for the gallery crop flow.
///
/// Faithful port of RN `RNGalleryPickerDelegate.detectCornersForImage:`,
/// `RNQuadGeometry`, and `RNImageProcessor.perspectiveCorrectedCGImage:`.
///
/// Corners are always in CIImage coordinate space (origin bottom-left, Y up),
/// ordered `[topLeft, topRight, bottomRight, bottomLeft]`.
enum QuadDetector {
    /// A detected quad below this confidence is discarded (editor falls back to
    /// its 10% inset default). Only gates the document-segmentation candidate —
    /// the rectangle detector enforces its own 0.5 floor. VNDetectDocumentSegmentationRequest
    /// can return a near-zero-confidence quad on hard inputs (e.g. the thin gap
    /// above a receipt embedded in a screenshot, observed ≈ 0.004).
    /// PROVISIONAL — see docs/specs threshold-calibration notes.
    static let detectionMinConfidence: Float = 0.1

    /// Opposite-edge length ratio above which a quad is treated as distorted.
    /// Kept identical to Android (`QuadGeometry`) — PROVISIONAL.
    private static let maxEdgeRatio: CGFloat = 2.2

    // MARK: - Detection

    /// Detects a document quad in `image`. Returns corners in CIImage space and
    /// the detection confidence (0 when nothing usable was found or the quad was
    /// discarded as distorted).
    static func detectCorners(in image: UIImage) -> (corners: [CGPoint]?, confidence: Float) {
        guard let cgImage = image.cgImage else { return (nil, 0) }

        let docRequest = VNDetectDocumentSegmentationRequest()
        let rectRequest = VNDetectRectanglesRequest()
        rectRequest.minimumConfidence = 0.5
        rectRequest.maximumObservations = 1
        // More permissive for perspective-distorted receipts (default is 30°).
        rectRequest.quadratureTolerance = 45

        // Pass the CGImage + explicit orientation so Vision processes pixels in the
        // same oriented space as image.size. initWithCIImage: ignores the embedded
        // orientation transform and returns landscape coords for portrait images,
        // which would mismatch the seeded corners in the crop editor (ADR-004 D3).
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgOrientation(from: image.imageOrientation),
            options: [:]
        )
        try? handler.perform([docRequest, rectRequest])

        let width = image.size.width
        let height = image.size.height

        // Preferred: document segmentation. Fallback: generic rectangle detector.
        // detectionMinConfidence gates only the doc-seg candidate (it exposes no
        // minimumConfidence knob); a non-nil rectObs is always above its own floor.
        let docObs = docRequest.results?.first as? VNRectangleObservation
        let rectObs = rectRequest.results?.first as? VNRectangleObservation

        var obs: VNRectangleObservation?
        var confidence: Float = 0
        if let docObs, docObs.confidence >= detectionMinConfidence {
            obs = docObs
            confidence = docObs.confidence
        }
        if obs == nil, let rectObs {
            obs = rectObs
            confidence = rectObs.confidence
        }

        guard let observation = obs else { return (nil, 0) }

        let detected = [
            CGPoint(x: observation.topLeft.x * width, y: observation.topLeft.y * height),
            CGPoint(x: observation.topRight.x * width, y: observation.topRight.y * height),
            CGPoint(x: observation.bottomRight.x * width, y: observation.bottomRight.y * height),
            CGPoint(x: observation.bottomLeft.x * width, y: observation.bottomLeft.y * height),
        ]

        // Distorted/degenerate quad → discard so the editor uses its inset default.
        // Report 0 confidence to honor the "0 on failure" contract.
        if isDistorted(detected) {
            return (nil, 0)
        }
        return (detected, confidence)
    }

    // MARK: - Distortion backstop

    /// True if `corners` is not a usable convex, roughly-rectangular quad.
    /// Port of `RNQuadGeometry.isDistorted:`.
    static func isDistorted(_ corners: [CGPoint]) -> Bool {
        guard corners.count == 4 else { return true }
        let tl = corners[0], tr = corners[1], br = corners[2], bl = corners[3]

        let topW = distance(tl, tr)
        let botW = distance(bl, br)
        let leftH = distance(tl, bl)
        let rightH = distance(tr, br)

        // All-zero edges (coincident corners) are degenerate. Everything else is
        // covered by the convexity + opposite-edge-ratio checks (a zero-length edge
        // makes its opposite-pair ratio diverge past maxEdgeRatio). A standalone
        // shortest/longest-edge gate was intentionally dropped (it flagged
        // legitimate high-aspect-ratio receipts).
        let maxE = max(max(topW, botW), max(leftH, rightH))
        if maxE <= 0 { return true }
        if !isConvex(tl: tl, tr: tr, br: br, bl: bl) { return true }

        let wRatio = max(topW, botW) / max(min(topW, botW), .leastNonzeroMagnitude)
        let hRatio = max(leftH, rightH) / max(min(leftH, rightH), .leastNonzeroMagnitude)
        return wRatio > maxEdgeRatio || hRatio > maxEdgeRatio
    }

    private static func isConvex(tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint) -> Bool {
        let p = [tl, tr, br, bl]
        var sign = 0
        for i in 0 ..< 4 {
            let a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            let s = cross > 0 ? 1 : (cross < 0 ? -1 : 0)
            if s == 0 { return false } // colinear / coincident → degenerate
            if sign == 0 {
                sign = s
            } else if s != sign {
                return false
            }
        }
        return true
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Perspective correction

    /// Perspective-corrects `image` to the quad `corners` (CIImage space) and
    /// returns an upright CGImage. Distorted quads fall back to an axis-aligned
    /// bounding-box crop (no warp). Port of
    /// `RNImageProcessor.perspectiveCorrectedCGImage:corners:` (ADR-004 D4).
    static func perspectiveCorrected(_ image: UIImage, corners: [CGPoint]) -> CGImage? {
        guard corners.count == 4, let cgImage = image.cgImage else { return nil }
        let tl = corners[0], tr = corners[1], br = corners[2], bl = corners[3]

        // Bake orientation into the CIImage first so the filter sees logically
        // oriented pixels (initWithImage: would leave a lazy transform the filter
        // may ignore → axes-swap). Defensively translate the extent to (0,0).
        var ciInput = CIImage(cgImage: cgImage)
            .oriented(cgOrientation(from: image.imageOrientation))
        let extent = ciInput.extent
        if extent.origin.x != 0 || extent.origin.y != 0 {
            ciInput = ciInput.transformed(
                by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y)
            )
        }

        // Fresh CIContext per call — CIContext is not thread-safe and maxPages > 1
        // can drive concurrent callers.
        if isDistorted(corners) {
            let minX = min(min(tl.x, tr.x), min(br.x, bl.x))
            let maxX = max(max(tl.x, tr.x), max(br.x, bl.x))
            let minY = min(min(tl.y, tr.y), min(br.y, bl.y))
            let maxY = max(max(tl.y, tr.y), max(br.y, bl.y))
            let bbox = ciInput.extent.intersection(
                CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            )
            if bbox.isNull || bbox.width < 1 || bbox.height < 1 { return nil }
            let cropped = ciInput.cropped(to: bbox).transformed(
                by: CGAffineTransform(translationX: -bbox.origin.x, y: -bbox.origin.y)
            )
            return CIContext().createCGImage(cropped, from: cropped.extent)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciInput, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: tl.x, y: tl.y), forKey: "inputTopLeft")
        filter.setValue(CIVector(x: tr.x, y: tr.y), forKey: "inputTopRight")
        filter.setValue(CIVector(x: br.x, y: br.y), forKey: "inputBottomRight")
        filter.setValue(CIVector(x: bl.x, y: bl.y), forKey: "inputBottomLeft")
        guard let output = filter.outputImage else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }

    // MARK: - Helpers

    static func cgOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

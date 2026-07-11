import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Orientation normalization, CCW rotation, JPEG recompression, EXIF synthesis,
/// and the temp-file lifecycle for the camera path.
///
/// Faithful port of the RN `RNImageProcessor` behavior: output pixels are always
/// oriented Up (`exif.orientation == 1`), JPEG is written via `CGImageDestination`
/// (never `UIImageJPEGRepresentation`, which strips EXIF), and camera captures —
/// whose source EXIF the document scanner drops — get synthesized device info.
enum ImageProcessor {
    private static let filePrefix = "receipt_"

    private static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    /// Deletes the previous scan session's `receipt_*.jpg` files. Called at the
    /// start of each scan so output URIs are stable only until the next scan.
    static func deletePreviousSessionFiles() {
        let dir = cachesDirectory
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )) ?? []
        for url in entries where url.lastPathComponent.hasPrefix(filePrefix) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Redraws `image` upright when its orientation is not already `.up`, so the
    /// encoded pixels need no orientation transform.
    static func normalized(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up { return image.cgImage }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let redrawn = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
        return redrawn.cgImage
    }

    /// Rotates `cg` counter-clockwise by 90/180/270 degrees (iOS convention).
    static func rotated(_ cg: CGImage, byDegreesCCW degrees: Int) -> CGImage {
        let normalized = ((degrees % 360) + 360) % 360
        if normalized == 0 { return cg }
        let swaps = normalized == 90 || normalized == 270
        let outW = swaps ? cg.height : cg.width
        let outH = swaps ? cg.width : cg.height
        guard let ctx = CGContext(
            data: nil,
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cg.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return cg }

        ctx.translateBy(x: CGFloat(outW) / 2, y: CGFloat(outH) / 2)
        ctx.rotate(by: CGFloat(normalized) * .pi / 180) // CCW (positive) in CG's flipped space
        ctx.draw(
            cg,
            in: CGRect(
                x: -CGFloat(cg.width) / 2,
                y: -CGFloat(cg.height) / 2,
                width: CGFloat(cg.width),
                height: CGFloat(cg.height)
            )
        )
        return ctx.makeImage() ?? cg
    }

    /// Synthesized device EXIF for a camera capture, as both the Pigeon wire object
    /// and the ImageIO property dict written into the output file.
    static func deviceExif() -> (wire: ReceiptExifWire, fileProps: [CFString: Any]) {
        let now = timestamp()
        let model = UIDevice.current.model
        let wire = ReceiptExifWire(
            orientation: 1,
            make: "Apple",
            model: model,
            dateTimeOriginal: now
        )
        let fileProps: [CFString: Any] = [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: model,
                kCGImagePropertyTIFFOrientation: 1,
            ],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: now,
            ],
        ]
        return (wire, fileProps)
    }

    /// Encodes `cg` to a JPEG cache file at `quality`, writing `exifProps` (when
    /// provided) into the file. Always stamps orientation Up.
    static func encodeJpeg(
        _ cg: CGImage,
        quality: CGFloat,
        exifProps: [CFString: Any]?
    ) -> (url: URL, fileName: String, fileSize: Int)? {
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let uuid = UUID().uuidString.prefix(8)
        let fileName = "\(filePrefix)\(millis)_\(uuid).jpg"
        let url = cachesDirectory.appendingPathComponent(fileName)

        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }

        var props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyOrientation: CGImagePropertyOrientation.up.rawValue,
        ]
        if let exifProps {
            props.merge(exifProps) { _, new in new }
        }
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? Int) ?? 0
        return (url, fileName, fileSize)
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

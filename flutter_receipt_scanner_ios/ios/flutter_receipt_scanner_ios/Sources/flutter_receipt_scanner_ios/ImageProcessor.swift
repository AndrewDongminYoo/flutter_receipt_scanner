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

// MARK: - Real-source EXIF (gallery path)

/// Reads the real source EXIF for gallery imports. The camera path synthesizes
/// device info (`deviceExif()`); the gallery path forwards the source's own
/// metadata. Faithful port of RN `RNImageProcessor.buildExifDict:` / `flattenRaw:`
/// plus the file-props forwarding in `processImage:`.
extension ImageProcessor {
    /// Reads `source`'s properties and returns both the Pigeon white-list wire
    /// object and the ImageIO property dict to write into the output file.
    ///
    /// `fileProps` forwards the raw EXIF/TIFF/GPS dictionaries (TIFF orientation
    /// forced to Up, GPS only when `includeGpsExif`); `encodeJpeg` merges them.
    /// Returns nil when the source exposes no readable properties.
    static func buildExif(
        from source: CGImageSource,
        includeGpsExif: Bool,
        includeRawExif: Bool
    ) -> (wire: ReceiptExifWire, fileProps: [CFString: Any])? {
        guard let sourceProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any] else { return nil }

        let exifDict = sourceProps[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiffDict = sourceProps[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let gpsDict = sourceProps[kCGImagePropertyGPSDictionary] as? [CFString: Any]

        // ── File props: forward the raw dicts (orientation stripped to Up). ──
        var fileProps: [CFString: Any] = [:]
        if let exifDict { fileProps[kCGImagePropertyExifDictionary] = exifDict }
        if var tiffDict {
            tiffDict[kCGImagePropertyTIFFOrientation] = CGImagePropertyOrientation.up.rawValue
            fileProps[kCGImagePropertyTIFFDictionary] = tiffDict
        }
        if includeGpsExif, let gpsDict {
            fileProps[kCGImagePropertyGPSDictionary] = gpsDict
        }

        // ── Wire white-list. ──
        var wire = ReceiptExifWire()
        // Output pixels are always orientation-normalized; report 1 (Up). The
        // original value survives only in raw.Orientation (when includeRawExif).
        wire.orientation = Int64(CGImagePropertyOrientation.up.rawValue)

        wire.dateTimeOriginal = exifDict?[kCGImagePropertyExifDateTimeOriginal] as? String
        wire.dateTimeDigitized = exifDict?[kCGImagePropertyExifDateTimeDigitized] as? String
        wire.dateTime = tiffDict?[kCGImagePropertyTIFFDateTime] as? String
        wire.make = tiffDict?[kCGImagePropertyTIFFMake] as? String
        wire.model = tiffDict?[kCGImagePropertyTIFFModel] as? String
        wire.software = tiffDict?[kCGImagePropertyTIFFSoftware] as? String

        wire.exposureTime = asDouble(exifDict?[kCGImagePropertyExifExposureTime])
        wire.fNumber = asDouble(exifDict?[kCGImagePropertyExifFNumber])
        wire.focalLength = asDouble(exifDict?[kCGImagePropertyExifFocalLength])
        wire.flash = asInt64(exifDict?[kCGImagePropertyExifFlash])
        wire.whiteBalance = asInt64(exifDict?[kCGImagePropertyExifWhiteBalance])
        wire.exposureMode = asInt64(exifDict?[kCGImagePropertyExifExposureMode])
        wire.exposureProgram = asInt64(exifDict?[kCGImagePropertyExifExposureProgram])
        wire.meteringMode = asInt64(exifDict?[kCGImagePropertyExifMeteringMode])
        wire.colorSpace = asInt64(exifDict?[kCGImagePropertyExifColorSpace])
        wire.lightSource = asInt64(exifDict?[kCGImagePropertyExifLightSource])

        // ISOSpeedRatings is an array on iOS (e.g. [50]); take the first element.
        let isoRaw = exifDict?[kCGImagePropertyExifISOSpeedRatings]
        if let isoArray = isoRaw as? [Any], let first = isoArray.first {
            wire.iso = asDouble(first)
        } else {
            wire.iso = asDouble(isoRaw)
        }

        // ExifVersion is either a String ("0220") or an array of digits.
        let versionRaw = exifDict?[kCGImagePropertyExifVersion]
        if let versionString = versionRaw as? String {
            wire.exifVersion = versionString
        } else if let versionParts = versionRaw as? [Any] {
            let joined = versionParts.map { "\($0)" }.joined()
            wire.exifVersion = joined.isEmpty ? nil : joined
        }

        if includeGpsExif, let gpsDict {
            wire.gps = buildGps(from: gpsDict)
        }

        if includeRawExif {
            let raw = flattenRaw(sourceProps, includeGps: includeGpsExif)
            wire.raw = raw.isEmpty ? nil : raw
        }

        return (wire, fileProps)
    }

    private static func buildGps(from gpsDict: [CFString: Any]) -> GpsDataWire? {
        guard let lat = asDouble(gpsDict[kCGImagePropertyGPSLatitude]),
              let lon = asDouble(gpsDict[kCGImagePropertyGPSLongitude])
        else { return nil }

        let latRef = gpsDict[kCGImagePropertyGPSLatitudeRef] as? String
        let lonRef = gpsDict[kCGImagePropertyGPSLongitudeRef] as? String

        var gps = GpsDataWire(
            latitude: lat * (latRef == "S" ? -1 : 1),
            longitude: lon * (lonRef == "W" ? -1 : 1)
        )
        if let altitude = asDouble(gpsDict[kCGImagePropertyGPSAltitude]) {
            let altRef = asInt64(gpsDict[kCGImagePropertyGPSAltitudeRef])
            gps.altitude = altRef == 1 ? -altitude : altitude
        }
        gps.timestamp = gpsDict[kCGImagePropertyGPSTimeStamp] as? String
        gps.speed = asDouble(gpsDict[kCGImagePropertyGPSSpeed])
        gps.heading = asDouble(gpsDict[kCGImagePropertyGPSImgDirection])
            ?? asDouble(gpsDict[kCGImagePropertyGPSDestBearing])
        return gps
    }

    /// Flat raw-EXIF map keyed by standard tag names. Skips binary/dict values and
    /// a deny-set; GPS keys are prefixed with "GPS" and excluded unless `includeGps`.
    private static func flattenRaw(
        _ sourceProps: [CFString: Any],
        includeGps: Bool
    ) -> [String: Any?] {
        let deny: Set = [
            "MakerNote",
            "UserComment",
            "ComponentsConfiguration",
            "FileSource",
            "SceneType",
            "InteroperabilityIndex",
        ]

        var raw: [String: Any?] = [:]
        func add(_ dict: [CFString: Any]?, prefix: String?) {
            guard let dict else { return }
            for (cfKey, value) in dict {
                let key = cfKey as String
                if deny.contains(key) { continue }
                // Skip values the codec can't marshal cleanly.
                if value is Data { continue }
                if value is [AnyHashable: Any] { continue }
                if !(value is String || value is NSNumber || value is [Any]) { continue }
                let outKey = (prefix != nil && !key.hasPrefix(prefix!))
                    ? prefix! + key
                    : key
                raw[outKey] = value
            }
        }
        add(sourceProps[kCGImagePropertyTIFFDictionary] as? [CFString: Any], prefix: nil)
        add(sourceProps[kCGImagePropertyExifDictionary] as? [CFString: Any], prefix: nil)
        if includeGps {
            add(sourceProps[kCGImagePropertyGPSDictionary] as? [CFString: Any], prefix: "GPS")
        }
        return raw
    }

    private static func asDouble(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private static func asInt64(_ value: Any?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }
}

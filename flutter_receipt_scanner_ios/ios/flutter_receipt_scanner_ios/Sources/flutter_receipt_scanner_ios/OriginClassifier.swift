import Foundation
import ImageIO
import Photos
import PhotosUI

/// Classifies a gallery photo's `imageOrigin` (native port map §7.1).
///
/// Priority: PHAsset screenshot subtype → extracted EXIF → raw source props →
/// `.unknown`. Faithful port of the origin helpers in RN `RNGalleryPickerDelegate`.
enum OriginClassifier {
    /// Definitive origin from the Photos library, when library access populated
    /// the picker's `assetIdentifier`. Returns `.screenshot` for screenshots,
    /// otherwise nil (Photos has no "download" subtype — EXIF heuristics run later).
    static func earlyOrigin(
        for result: PHPickerResult,
        hasLibraryAccess: Bool
    ) -> ImageOriginWire? {
        guard hasLibraryAccess, let identifier = result.assetIdentifier else { return nil }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            return .screenshot
        }
        return nil
    }

    /// Classifies origin from three EXIF indicators.
    /// - `dateTimeOriginal` present → camera (shutter timestamp, strongest signal).
    /// - `make` && `model` (no timestamp) → camera (device IDs, still camera-like).
    /// - neither `make` nor `model` → download (no camera metadata at all).
    /// - one of make/model but not the other → nil (ambiguous).
    static func originFromExifFields(
        make: String?,
        model: String?,
        dateTimeOriginal: String?
    ) -> ImageOriginWire? {
        if dateTimeOriginal != nil { return .camera }
        if make != nil, model != nil { return .camera }
        if make == nil, model == nil { return .download }
        return nil
    }

    /// Origin from an already-extracted EXIF wire (avoids re-reading the source).
    static func origin(fromExif exif: ReceiptExifWire?) -> ImageOriginWire? {
        guard let exif else { return nil }
        return originFromExifFields(
            make: exif.make,
            model: exif.model,
            dateTimeOriginal: exif.dateTimeOriginal
        )
    }

    /// Fallback used when `includeExif: false` left no extracted EXIF. Reads the
    /// source properties directly so origin detection is independent of the option.
    static func origin(fromSource source: CGImageSource) -> ImageOriginWire? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        return originFromExifFields(
            make: tiff?[kCGImagePropertyTIFFMake] as? String,
            model: tiff?[kCGImagePropertyTIFFModel] as? String,
            dateTimeOriginal: exif?[kCGImagePropertyExifDateTimeOriginal] as? String
        )
    }
}

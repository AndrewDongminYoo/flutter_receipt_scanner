import CoreGraphics
import Foundation
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Gallery scan flow: PHPicker → per-photo quad detect → optional crop editor →
/// perspective-correct → OCR/encode/EXIF/origin. Faithful port of RN
/// `RNGalleryPickerDelegate`.
///
/// Photos are processed **one at a time** (`queuedItems` + `queueIndex` +
/// `processNextQueuedItem`). A parallel for-loop of `present(_:)` calls would be
/// silently rejected by UIKit for all but the first editor, and the rejected
/// editors' completion blocks would never fire → the scan hangs forever.
///
/// The delegate must be retained by the caller (`ReceiptScannerApiImpl`) for the
/// whole flow — PHPickerViewController holds its delegate weakly. The internal
/// dispatch blocks capture `self` strongly on purpose so it survives the async
/// round-trips even after the caller releases its strong reference on completion.
final class GalleryPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    /// Above this detection confidence, `cropAutoConfirm` skips the editor.
    private static let cropAutoConfirmMinConfidence: Float = 0.85

    private let options: ScanOptionsWire
    private weak var presentingVC: UIViewController?
    private let hasLibraryAccess: Bool
    private let completion: (Result<ScanResultWire, Error>) -> Void

    private var results: [ReceiptImageWire] = []
    private var queuedItems: [PHPickerResult] = []
    private var queueIndex = 0

    init(
        options: ScanOptionsWire,
        presentingViewController: UIViewController,
        hasLibraryAccess: Bool,
        completion: @escaping (Result<ScanResultWire, Error>) -> Void
    ) {
        self.options = options
        presentingVC = presentingViewController
        self.hasLibraryAccess = hasLibraryAccess
        self.completion = completion
    }

    // MARK: - Resolved options

    private var maxPages: Int {
        max(1, Int(options.maxPages ?? 1))
    }

    private var runOcr: Bool {
        options.ocr ?? true
    }

    private var autoRotate: Bool {
        options.autoRotate ?? true
    }

    private var quality: CGFloat {
        CGFloat(options.quality ?? 0.82)
    }

    private var includeExif: Bool {
        options.includeExif ?? true
    }

    private var includeGpsExif: Bool {
        options.includeGpsExif ?? false
    }

    private var includeRawExif: Bool {
        options.includeRawExif ?? false
    }

    private var cropAutoConfirm: Bool {
        options.cropAutoConfirm ?? false
    }

    private var minimumTextHeight: Float {
        Float(options.minimumTextHeight ?? 0)
    }

    // MARK: - PHPickerViewControllerDelegate

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        if results.isEmpty {
            picker.dismiss(animated: true) {
                self.completion(.success(Self.cancelled()))
            }
            return
        }
        picker.dismiss(animated: true) {
            ImageProcessor.deletePreviousSessionFiles()
            // Serial queue — concurrent present(_:) on the same presenter is
            // silently rejected by UIKit (see the type doc / ADR-004 anti-pattern).
            self.queuedItems = results
            self.queueIndex = 0
            self.processNextQueuedItem()
        }
    }

    // MARK: - Serial per-photo pipeline

    private func processNextQueuedItem() {
        if queueIndex >= queuedItems.count {
            if results.isEmpty {
                completion(.success(Self.cancelled()))
            } else {
                completion(.success(ScanResultWire(status: .success, images: results, rejectedImages: [])))
            }
            return
        }

        let item = queuedItems[queueIndex]
        queueIndex += 1

        // PHAsset fetch is synchronous for local identifiers — safe on main.
        let earlyOrigin = OriginClassifier.earlyOrigin(for: item, hasLibraryAccess: hasLibraryAccess)

        item.itemProvider.loadDataRepresentation(
            forTypeIdentifier: UTType.image.identifier
        ) { data, error in
            guard let data, error == nil else {
                self.didFinishOneItem(nil)
                return
            }
            // CGImageSource is ARC-managed in Swift; no manual holder needed.
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = UIImage(data: data)
            else {
                self.didFinishOneItem(nil)
                return
            }
            self.detectAndCrop(image: image, source: source, earlyOrigin: earlyOrigin)
        }
    }

    /// Runs Vision detection (on the loadDataRepresentation background queue). Auto-
    /// confirms when enabled and confident enough, otherwise presents the editor.
    private func detectAndCrop(
        image: UIImage,
        source: CGImageSource,
        earlyOrigin: ImageOriginWire?
    ) {
        let (corners, confidence) = QuadDetector.detectCorners(in: image)

        if cropAutoConfirm, let corners, confidence >= Self.cropAutoConfirmMinConfidence {
            applyCropAndFinish(image: image, corners: corners, source: source, earlyOrigin: earlyOrigin)
            return
        }

        DispatchQueue.main.async {
            guard let presentingVC = self.presentingVC else {
                self.didFinishOneItem(nil)
                return
            }
            let editor = CropEditorViewController(image: image, corners: corners) { cropped in
                // Called from the editor's background render.
                guard let cropped else {
                    self.didFinishOneItem(nil)
                    return
                }
                self.processAndFinish(cropped: cropped, source: source, earlyOrigin: earlyOrigin)
            }
            editor.modalPresentationStyle = .fullScreen
            presentingVC.present(editor, animated: true)
        }
    }

    /// Auto-confirm path: perspective-correct with the detected corners directly.
    /// Must run on a background thread.
    private func applyCropAndFinish(
        image: UIImage,
        corners: [CGPoint],
        source: CGImageSource,
        earlyOrigin: ImageOriginWire?
    ) {
        guard let cropped = QuadDetector.perspectiveCorrected(image, corners: corners) else {
            didFinishOneItem(nil)
            return
        }
        processAndFinish(cropped: cropped, source: source, earlyOrigin: earlyOrigin)
    }

    /// Encodes, optionally OCRs (before encode, so rotation can bake into pixels),
    /// reads the real source EXIF, classifies origin, and appends one result.
    /// Must run on a background thread.
    private func processAndFinish(
        cropped: CGImage,
        source: CGImageSource,
        earlyOrigin: ImageOriginWire?
    ) {
        var ocrText: String?
        var confidence: Double?
        var rotationDegrees = 0
        if runOcr {
            let outcome = OcrProcessor.recognize(
                cropped, minimumTextHeight: minimumTextHeight, autoRotate: autoRotate
            )
            ocrText = outcome.text
            confidence = outcome.confidence
            rotationDegrees = outcome.rotationDegrees
        }

        var encodeCG = cropped
        if autoRotate, rotationDegrees != 0 {
            encodeCG = ImageProcessor.rotated(cropped, byDegreesCCW: rotationDegrees)
        }

        // Gallery imports forward the real source EXIF (unlike the camera path,
        // which synthesizes device info).
        let exif = includeExif
            ? ImageProcessor.buildExif(
                from: source, includeGpsExif: includeGpsExif, includeRawExif: includeRawExif
            )
            : nil

        guard let encoded = ImageProcessor.encodeJpeg(
            encodeCG, quality: quality, exifProps: exif?.fileProps
        ) else {
            didFinishOneItem(nil)
            return
        }

        // Priority: PHAsset subtype → extracted EXIF → raw source props → unknown.
        // The source read is gated on exif being nil so we don't decode twice.
        let imageOrigin = earlyOrigin
            ?? OriginClassifier.origin(fromExif: exif?.wire)
            ?? (exif == nil ? OriginClassifier.origin(fromSource: source) : nil)
            ?? .unknown

        let hasText = !(ocrText?.isEmpty ?? true)
        let result = ReceiptImageWire(
            uri: encoded.url.absoluteString,
            width: Int64(encodeCG.width),
            height: Int64(encodeCG.height),
            fileName: encoded.fileName,
            mimeType: "image/jpeg",
            fileSize: Int64(encoded.fileSize),
            imageOrigin: imageOrigin,
            ocrText: hasText ? ocrText : nil,
            ocrQuality: hasText
                ? OcrQualityWire(textLength: nil, lineCount: nil, confidence: confidence)
                : nil,
            exif: exif?.wire
        )
        didFinishOneItem(result)
    }

    /// Called once per queued photo. `nil` means the photo was skipped (load
    /// failure or the user cancelled its editor) — continue the batch.
    private func didFinishOneItem(_ imageResult: ReceiptImageWire?) {
        DispatchQueue.main.async {
            if let imageResult { self.results.append(imageResult) }
            self.processNextQueuedItem()
        }
    }

    private static func cancelled() -> ScanResultWire {
        ScanResultWire(status: .cancelled, images: [], rejectedImages: [])
    }
}

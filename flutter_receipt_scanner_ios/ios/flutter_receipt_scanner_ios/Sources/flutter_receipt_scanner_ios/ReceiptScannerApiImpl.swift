import Flutter
import PhotosUI
import UIKit
import VisionKit

/// iOS implementation of the generated `ReceiptScannerApi`.
///
/// Camera path (`source == .camera`): VisionKit document scanner → orientation
/// normalize → OCR (+ rotation detect) → optional pixel rotation → JPEG encode
/// with synthesized device EXIF.
///
/// Gallery path (`source == .gallery`): PHPicker → per-photo quad detect →
/// custom crop editor (or auto-confirm) → perspective-correct → OCR → JPEG encode
/// with the real source EXIF. Delegated to `GalleryPickerDelegate` (held strongly
/// for the whole flow).
final class ReceiptScannerApiImpl: NSObject, ReceiptScannerApi,
    VNDocumentCameraViewControllerDelegate
{
    /// Upper bound on pages / multi-select count, matching Android.
    private static let maxPagesCeiling = 10

    private var completion: ((Result<ScanResultWire, Error>) -> Void)?
    private var options: ScanOptionsWire?
    /// Retained for the whole gallery flow — PHPickerViewController holds its
    /// delegate weakly. Cleared in `finish`.
    private var galleryDelegate: GalleryPickerDelegate?

    private let workQueue = DispatchQueue(label: "com.flutterreceiptscanner.work", qos: .userInitiated)

    func scan(
        options: ScanOptionsWire,
        completion: @escaping (Result<ScanResultWire, Error>) -> Void
    ) {
        guard self.completion == nil else {
            completion(.failure(PigeonError(
                code: "SCAN_IN_PROGRESS",
                message: "A scan is already in progress.",
                details: nil
            )))
            return
        }
        switch options.source ?? .camera {
        case .camera:
            startCamera(options: options, completion: completion)
        case .gallery:
            startGallery(options: options, completion: completion)
        }
    }

    // MARK: - Camera path

    private func startCamera(
        options: ScanOptionsWire,
        completion: @escaping (Result<ScanResultWire, Error>) -> Void
    ) {
        guard VNDocumentCameraViewController.isSupported else {
            completion(.failure(PigeonError(
                code: "NOT_SUPPORTED",
                message: "Document scanning is not supported on this device.",
                details: nil
            )))
            return
        }
        self.completion = completion
        self.options = options
        DispatchQueue.main.async {
            guard let presenter = Self.topViewController() else {
                self.finish(.failure(PigeonError(
                    code: "NO_ACTIVITY",
                    message: "No view controller is available to present the scanner.",
                    details: nil
                )))
                return
            }
            let scanner = VNDocumentCameraViewController()
            scanner.delegate = self
            presenter.present(scanner, animated: true)
        }
    }

    // MARK: - Gallery path

    private func startGallery(
        options: ScanOptionsWire,
        completion: @escaping (Result<ScanResultWire, Error>) -> Void
    ) {
        self.completion = completion
        self.options = options
        DispatchQueue.main.async {
            guard let presenter = Self.topViewController() else {
                self.finish(.failure(PigeonError(
                    code: "NO_ACTIVITY",
                    message: "No view controller is available to present the picker.",
                    details: nil
                )))
                return
            }
            self.presentPicker(options: options, presenter: presenter)
        }
    }

    private func presentPicker(
        options: ScanOptionsWire,
        presenter: UIViewController
    ) {
        // PHPicker works without Photos authorization — never prompt. Origin is
        // classified from EXIF alone (no PHAsset lookup), so no library access is needed.
        var config = PHPickerConfiguration()
        config.filter = .images
        // selectionLimit 0 means unlimited in PHPicker — clamp to 1...maxPagesCeiling.
        config.selectionLimit = min(Self.maxPagesCeiling, max(1, Int(options.maxPages ?? 1)))

        let delegate = GalleryPickerDelegate(
            options: options,
            presentingViewController: presenter,
            completion: { [weak self] result in self?.finish(result) }
        )
        galleryDelegate = delegate

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = delegate
        presenter.present(picker, animated: true)
    }

    // MARK: - VNDocumentCameraViewControllerDelegate

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        controller.dismiss(animated: true)
        let opts = options ?? ScanOptionsWire()
        let pageCount = min(scan.pageCount, min(Self.maxPagesCeiling, max(1, Int(opts.maxPages ?? 1))))
        var pages: [UIImage] = []
        for index in 0 ..< pageCount {
            pages.append(scan.imageOfPage(at: index))
        }

        workQueue.async { [weak self] in
            ImageProcessor.deletePreviousSessionFiles()
            let images = pages.compactMap { Self.process($0, options: opts) }
            if images.isEmpty, pageCount > 0 {
                self?.finish(.failure(PigeonError(
                    code: "PROCESSING_FAILED",
                    message: "Failed to process the scanned pages.",
                    details: nil
                )))
                return
            }
            self?.finish(.success(ScanResultWire(status: .success, images: images, rejectedImages: [])))
        }
    }

    func documentCameraViewControllerDidCancel(
        _ controller: VNDocumentCameraViewController
    ) {
        controller.dismiss(animated: true)
        finish(.success(ScanResultWire(status: .cancelled, images: [], rejectedImages: [])))
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        controller.dismiss(animated: true)
        finish(.failure(PigeonError(
            code: "CAMERA_FAILED",
            message: error.localizedDescription,
            details: nil
        )))
    }

    // MARK: - Processing

    private static func process(_ image: UIImage, options: ScanOptionsWire) -> ReceiptImageWire? {
        guard var cg = ImageProcessor.normalized(image) else { return nil }

        let runOcr = options.ocr ?? true
        let autoRotate = options.autoRotate ?? true
        var ocrText: String?
        var confidence: Double?
        var ocrLines: [OcrLineWire]?
        if runOcr {
            let minHeight = Float(options.minimumTextHeight ?? 0)
            let outcome = OcrProcessor.recognize(cg, minimumTextHeight: minHeight, autoRotate: autoRotate)
            ocrText = outcome.text
            confidence = outcome.confidence
            if autoRotate, outcome.rotationDegrees != 0 {
                cg = ImageProcessor.rotated(cg, byDegreesCCW: outcome.rotationDegrees)
            }
            // `cg` is now the output frame; the outcome's boxes already sit in it.
            ocrLines = OcrProcessor.ocrLinesWire(
                outcome, outputSize: CGSize(width: cg.width, height: cg.height), enabled: options.ocrGeometry ?? false
            )
        }

        let includeExif = options.includeExif ?? true
        let exif = includeExif ? ImageProcessor.deviceExif() : nil
        guard let encoded = ImageProcessor.encodeJpeg(
            cg, quality: CGFloat(options.quality ?? 0.82), exifProps: exif?.fileProps
        ) else { return nil }

        return ReceiptImageWire(
            uri: encoded.url.absoluteString,
            width: Int64(cg.width),
            height: Int64(cg.height),
            fileName: encoded.fileName,
            mimeType: "image/jpeg",
            fileSize: Int64(encoded.fileSize),
            imageOrigin: .camera,
            ocrText: ocrText,
            ocrQuality: ocrText == nil ? nil : OcrQualityWire(
                textLength: nil, lineCount: nil, confidence: confidence
            ),
            exif: exif?.wire,
            ocrLines: ocrLines
        )
    }

    private func finish(_ result: Result<ScanResultWire, Error>) {
        let callback = completion
        completion = nil
        options = nil
        // Safe to release even mid-flight: an in-flight gallery block holds a
        // strong reference to the delegate until it returns.
        galleryDelegate = nil
        DispatchQueue.main.async { callback?(result) }
    }

    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

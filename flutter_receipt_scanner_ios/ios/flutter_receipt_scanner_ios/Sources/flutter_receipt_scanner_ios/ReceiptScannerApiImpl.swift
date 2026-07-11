import Flutter
import UIKit
import VisionKit

/// iOS implementation of the generated `ReceiptScannerApi`.
///
/// Camera path (`source == .camera`): VisionKit document scanner → orientation
/// normalize → OCR (+ rotation detect) → optional pixel rotation → JPEG encode
/// with synthesized device EXIF. Gallery path is not yet implemented.
final class ReceiptScannerApiImpl: NSObject, ReceiptScannerApi,
    VNDocumentCameraViewControllerDelegate
{
    private var completion: ((Result<ScanResultWire, Error>) -> Void)?
    private var options: ScanOptionsWire?

    private let workQueue = DispatchQueue(label: "com.flutterreceiptscanner.work", qos: .userInitiated)

    func scan(
        options: ScanOptionsWire,
        completion: @escaping (Result<ScanResultWire, Error>) -> Void
    ) {
        guard self.completion == nil else {
            completion(.failure(PigeonError(
                code: "scan_in_progress",
                message: "A scan is already in progress.",
                details: nil
            )))
            return
        }
        guard (options.source ?? .camera) == .camera else {
            completion(.failure(PigeonError(
                code: "unimplemented",
                message: "source: gallery is not implemented yet.",
                details: nil
            )))
            return
        }
        guard VNDocumentCameraViewController.isSupported else {
            completion(.failure(PigeonError(
                code: "unavailable",
                message: "Document scanning is not supported on this device.",
                details: nil
            )))
            return
        }
        self.completion = completion
        self.options = options
        DispatchQueue.main.async {
            let scanner = VNDocumentCameraViewController()
            scanner.delegate = self
            Self.topViewController()?.present(scanner, animated: true)
        }
    }

    // MARK: - VNDocumentCameraViewControllerDelegate

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        controller.dismiss(animated: true)
        let opts = options ?? ScanOptionsWire()
        let pageCount = min(scan.pageCount, max(1, Int(opts.maxPages ?? 1)))
        var pages: [UIImage] = []
        for index in 0 ..< pageCount {
            pages.append(scan.imageOfPage(at: index))
        }

        workQueue.async { [weak self] in
            ImageProcessor.deletePreviousSessionFiles()
            let images = pages.compactMap { Self.process($0, options: opts) }
            if images.isEmpty, pageCount > 0 {
                self?.finish(.failure(PigeonError(
                    code: "processing_failed",
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
            code: "scan_failed",
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
        if runOcr {
            let minHeight = Float(options.minimumTextHeight ?? 0)
            let outcome = OcrProcessor.recognize(cg, minimumTextHeight: minHeight, autoRotate: autoRotate)
            ocrText = outcome.text
            confidence = outcome.confidence
            if autoRotate, outcome.rotationDegrees != 0 {
                cg = ImageProcessor.rotated(cg, byDegreesCCW: outcome.rotationDegrees)
            }
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
            exif: exif?.wire
        )
    }

    private func finish(_ result: Result<ScanResultWire, Error>) {
        let callback = completion
        completion = nil
        options = nil
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

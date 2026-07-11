import Flutter
import ImageIO
import UIKit
import UniformTypeIdentifiers
import Vision
import VisionKit

/// Clean-room iOS implementation of the generated `ReceiptScannerApi`.
///
/// Skeleton milestone: only `source == .camera` is implemented. Every other
/// path returns a `PigeonError` with code `unimplemented`.
final class ReceiptScannerApiImpl: NSObject, ReceiptScannerApi,
    VNDocumentCameraViewControllerDelegate
{
    private var completion: ((Result<ScanResultWire, Error>) -> Void)?
    private var options: ScanOptionsWire?

    func scan(
        options: ScanOptionsWire,
        completion: @escaping (Result<ScanResultWire, Error>) -> Void
    ) {
        guard (options.source ?? .camera) == .camera else {
            completion(.failure(PigeonError(
                code: "unimplemented",
                message: "Only source: camera is implemented in the skeleton.",
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
        let maxPages = max(1, Int(opts.maxPages ?? 1))
        let pageCount = min(scan.pageCount, maxPages)

        var images: [ReceiptImageWire] = []
        for index in 0 ..< pageCount {
            let uiImage = scan.imageOfPage(at: index)
            if let image = Self.process(uiImage, options: opts) {
                images.append(image)
            }
        }
        finish(.success(ScanResultWire(status: .success, images: images, rejectedImages: [])))
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
        guard let cg = image.cgImage else { return nil }
        let quality = CGFloat(options.quality ?? 0.82)
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let fileName = "receipt_\(millis)_\(UUID().uuidString.prefix(6)).jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        // Always normalize output orientation to Up (1).
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyOrientation: CGImagePropertyOrientation.up.rawValue,
        ]
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? Int) ?? 0

        var ocrText: String?
        var confidence: Double?
        if options.ocr ?? true {
            let result = Self.recognizeText(cg)
            ocrText = result.text
            confidence = result.confidence
        }

        return ReceiptImageWire(
            uri: url.absoluteString,
            width: Int64(cg.width),
            height: Int64(cg.height),
            fileName: fileName,
            mimeType: "image/jpeg",
            fileSize: Int64(fileSize),
            imageOrigin: .camera,
            ocrText: ocrText,
            ocrQuality: ocrText == nil ? nil : OcrQualityWire(
                textLength: nil, lineCount: nil, confidence: confidence
            ),
            exif: nil
        )
    }

    private static func recognizeText(_ cg: CGImage) -> (text: String?, confidence: Double?) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let observations = request.results, !observations.isEmpty else {
            return (nil, nil)
        }
        var lines: [String] = []
        var confSum: Float = 0
        var confCount = 0
        for obs in observations {
            guard let top = obs.topCandidates(1).first else { continue }
            lines.append(top.string)
            confSum += top.confidence
            confCount += 1
        }
        let text = lines.isEmpty ? nil : lines.joined(separator: "\n")
        let confidence = confCount == 0 ? nil : Double(confSum / Float(confCount))
        return (text, confidence)
    }

    private func finish(_ result: Result<ScanResultWire, Error>) {
        let callback = completion
        completion = nil
        options = nil
        callback?(result)
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

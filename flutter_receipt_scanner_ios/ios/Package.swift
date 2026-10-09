// swift-tools-version: 5.9
import PackageDescription

/// Compile the production batch seam directly, without Flutter or a picker.
let package = Package(
    name: "NativeBatchTests",
    targets: [
        .target(
            name: "PageBatch",
            path: "flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios",
            exclude: [
                "CropEditorViewController.swift", "FlutterReceiptScannerPlugin.swift",
                "GalleryPickerDelegate.swift", "ImageProcessor.swift", "Messages.g.swift",
                "OcrGeometry.swift", "OcrProcessor.swift", "OriginClassifier.swift",
                "PrivacyInfo.xcprivacy", "QuadDetector.swift", "ReceiptScannerApiImpl.swift",
            ],
            sources: ["PageBatch.swift"]
        ),
        .testTarget(name: "PageBatchTests", dependencies: ["PageBatch"], path: "tests/Tests/PageBatchTests"),
    ]
)

# Changelog

## 0.3.0

### Changed

- Require `flutter_receipt_scanner_platform_interface` 0.3.0 for coordinated federated package compatibility.

## 0.2.0

### Added

- Return per-line OCR geometry in output-image pixel coordinates when `ocrGeometry` is enabled.

### Changed

- Use the permissionless photo picker for gallery scans.

### Fixed

- Keep the returned image, dimensions, and OCR line geometry aligned after automatic rotation.
- Declare UIKit in the CocoaPods specification.

## 0.1.0

Initial release.

### Added

- iOS implementation of `FlutterReceiptScannerPlatform`: VisionKit document scanner and PHPicker gallery source, with crop, orientation normalization, JPEG compression, EXIF extraction, and Vision on-device OCR.
- Minimum deployment target: iOS 16.0.

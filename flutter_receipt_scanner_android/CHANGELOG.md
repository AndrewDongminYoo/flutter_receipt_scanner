# Changelog

## 0.3.0

### Changed

- Require `flutter_receipt_scanner_platform_interface` 0.3.0 for coordinated federated package compatibility.

## 0.2.0

### Added

- Return per-line OCR geometry in output-image pixel coordinates when `ocrGeometry` is enabled.

### Fixed

- Apply OCR-detected rotation consistently to images and line geometry.
- Report unexpected scan and crop-editor failures instead of treating them as cancellations.
- Enforce scan and image-size limits while improving gallery cache cleanup and large-image failure handling.

## 0.1.0

Initial release.

### Added

- Android implementation of `FlutterReceiptScannerPlatform`: GMS document scanner and system photo picker source, with crop, orientation normalization, JPEG compression, EXIF extraction, and ML Kit on-device OCR.
- Minimum SDK: 24.

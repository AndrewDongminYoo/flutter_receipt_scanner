# Changelog

## 0.5.0

### Added

- **Multilingual OCR Support:** Added `ocrLanguages` to `ScanReceiptOptions` (default: `['ko-KR', 'en-US']`).
- Added `FlutterReceiptScanner.getOcrCapabilities()` to query script family installation status (Android) or active Vision framework support (iOS).
- Added `OcrLanguageException` (and native error codes `INVALID_OCR_LANGUAGE`, `OCR_LANGUAGE_NOT_SUPPORTED`, `OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED`, `OCR_MODEL_INSTALL_FAILED`) for capability rejection without charging a capture.
- Android: The scanner now dynamically downloads and manages ML Kit non-Latin language modules via Google Play Services.
- Added capabilities inspection UI and BCP 47 language input to the example app.

## 0.4.0

### Added

- Populate `discardedPageCount` when VisionKit returns more pages than `maxPages`; the first `maxPages` pages are still processed unchanged.

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

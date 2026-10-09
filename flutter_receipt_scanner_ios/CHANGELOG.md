# Changelog

## 0.5.0

### Added

- **Multilingual OCR Support:** Added `ocrLanguages` to `ScanReceiptOptions` (default: `['ko-KR', 'en-US']`).
- Added the app-facing top-level `getOcrCapabilities()` function, backed by `FlutterReceiptScannerIos.getOcrCapabilities()`, to query active Vision framework support.
- Native capability rejection surfaces as `PlatformException`; iOS reports `INVALID_OCR_LANGUAGE` and `OCR_LANGUAGE_NOT_SUPPORTED` before scanner UI opens.
  `OcrLanguageException` is an Android implementation type, not a public Dart exception.
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

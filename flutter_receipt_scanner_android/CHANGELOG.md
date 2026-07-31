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

- Populate `discardedPageCount` defensively (expected `0` — the GMS scanner enforces `setPageLimit` in its UI).

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

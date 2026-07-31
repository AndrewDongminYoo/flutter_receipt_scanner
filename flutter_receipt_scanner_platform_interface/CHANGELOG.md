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

- `ScanReceiptResult.discardedPageCount` (default `0`) and the optional `ScanResultWire.discardedPageCount` wire field for natively dropped scanner pages.

## 0.3.0

### Added

- `MergedOcrResult` and optional `ScanReceiptResult.mergedOcr` diagnostics.

## 0.2.0

### Added

- `ScanReceiptOptions.ocrGeometry` for requesting per-line OCR text-region boxes.
- `OcrLine` and `ReceiptImage.ocrLines` for OCR text, confidence, and output-image pixel geometry.

### Changed

- Document the native `maxPages` coercion range as 1 through 10.
- Clarify that screenshot origin detection is Android-only.

## 0.1.0

Initial release.

### Added

- Abstract `FlutterReceiptScannerPlatform` interface (extended, never implemented, by platform packages).
- Hand-written public models: `ScanReceiptOptions`, `ScanReceiptResult`, `ReceiptImage`, `OcrQuality`, `ReceiptExif`, `GpsData`, and the `ScanStatus` / `ScanSource` / `ImageOrigin` enums.
- Pigeon-generated wire contract (`messages.g.dart`) re-exported for the platform packages.

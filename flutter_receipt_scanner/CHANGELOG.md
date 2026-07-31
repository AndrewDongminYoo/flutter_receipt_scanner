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

- `ScanReceiptResult.discardedPageCount` surfaces scanner pages natively dropped beyond `maxPages` (iOS-only in practice — VisionKit cannot enforce a page limit in its UI).

### Changed

- `mergeOcrPages` never reports `MergedOcrResult.isComplete == true` when pages were natively discarded, even if every returned seam is proven.

## 0.3.0

### Added

- Opt-in multi-page OCR text merging through `scan(mergeOcrPages: true)`.
- Example controls and result diagnostics for trying multi-page OCR merging.
- `ScanReceiptResult.mergedOcr` diagnostics for merged text, page completeness, and unmatched page boundaries.
- Deterministic 11:1 long-receipt fixtures and a pinned public receipt dataset manifest for offline benchmarking.

## 0.2.0

### Added

- Re-export `OcrLine` so applications can consume per-line OCR geometry from scan results.

## 0.1.0

Initial release.

### Added

- `scan()` app-facing API that launches the native scan flow and returns a `ScanReceiptResult`.
- Dart-side OCR-floor acceptance gate (`ocr_floor.dart`) partitioning results into `images` and `rejectedImages`.
- Re-exports the public models and enums from the platform interface.

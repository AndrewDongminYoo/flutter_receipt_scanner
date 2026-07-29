# Changelog

## 0.2.0

### Added

- Re-export `OcrLine` so applications can consume per-line OCR geometry from scan results.

## 0.1.0

Initial release.

### Added

- `scan()` app-facing API that launches the native scan flow and returns a `ScanReceiptResult`.
- Dart-side OCR-floor acceptance gate (`ocr_floor.dart`) partitioning results into `images` and `rejectedImages`.
- Re-exports the public models and enums from the platform interface.

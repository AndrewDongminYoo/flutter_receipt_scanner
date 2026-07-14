# Changelog

## 0.1.0

Initial release.

### Added

- Abstract `FlutterReceiptScannerPlatform` interface (extended, never implemented, by platform packages).
- Hand-written public models: `ScanReceiptOptions`, `ScanReceiptResult`, `ReceiptImage`, `OcrQuality`, `ReceiptExif`, `GpsData`, and the `ScanStatus` / `ScanSource` / `ImageOrigin` enums.
- Pigeon-generated wire contract (`messages.g.dart`) re-exported for the platform packages.

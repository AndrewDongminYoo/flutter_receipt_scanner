# flutter_receipt_scanner

On-device receipt image acquisition, crop, orientation normalization, JPEG compression, EXIF extraction, and OCR (raw string) for Flutter, on iOS and Android.

This is a federated plugin.
The native layers own **image primitives only** — receipt domain parsing (store name, amount, date), upload transport, cloud OCR, and duplicate detection belong in the consuming app, not here.

## Status

Walking-skeleton milestone.
Only the iOS `source: "camera"` path is implemented end-to-end (VisionKit document scanner → JPEG → Vision OCR → typed result → Dart OCR-floor gate).
Every other path (Android, iOS gallery + crop editor, `autoRotate` pixel rotation) currently returns an `unimplemented` error.

## Packages

| Package | Responsibility |
| --- | --- |
| `flutter_receipt_scanner` | App-facing API: `scan()` and the Dart-side OCR-floor acceptance gate. |
| `flutter_receipt_scanner_platform_interface` | Abstract platform interface plus the Pigeon-generated message contract. |
| `flutter_receipt_scanner_ios` | iOS (VisionKit + Vision) implementation. |
| `flutter_receipt_scanner_android` | Android implementation (skeleton stub). |

## Usage

```dart
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';

final result = await scan(const ScanReceiptOptions(maxPages: 1));
switch (result.status) {
  case ScanStatus.success:
    for (final image in result.images) {
      print('${image.fileName}: ${image.ocrQuality?.textLength ?? 0} OCR chars');
    }
  case ScanStatus.cancelled:
    // The user dismissed the scanner.
  case ScanStatus.rejected:
    // Every capture fell below the OCR floor; see result.rejectedImages.
}
```

The output `file://` JPEG URIs are stable until the next `scan()` call and do not survive app restarts (the OS clears the cache directory).

## Host app permissions

- iOS `Info.plist`: `NSCameraUsageDescription` (camera scan). `NSPhotoLibraryUsageDescription` once the gallery path lands.
- Android: none for the skeleton milestone.

## Development

```bash
dart run pigeon --input pigeons/messages.dart   # regenerate the wire contract
melos run analyze                                # analyze all packages
melos run test --no-select                       # test all packages
```

Dart is formatted at 120 columns (`dart format --line-length 120`) and linted with `very_good_analysis`.
Kotlin, Swift, YAML, and Markdown are owned by trunk; Dart is intentionally left to `flutter`/`melos`.

## License

MIT — see [LICENSE](LICENSE).

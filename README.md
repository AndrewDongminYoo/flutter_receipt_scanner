# flutter_receipt_scanner

On-device receipt image acquisition, crop, orientation normalization, JPEG compression, EXIF extraction, and OCR (raw string) for Flutter, on iOS and Android.

This is a federated plugin.
The native layers own **image primitives only** — receipt domain parsing (store name, amount, date), upload transport, cloud OCR, and duplicate detection belong in the consuming app, not here.

## Status

Both platforms implement the full path end-to-end: camera (document scanner) and gallery + crop editor, with orientation normalization, `autoRotate` pixel rotation, JPEG compression, EXIF extraction, on-device OCR, and the Dart OCR-floor gate.

- iOS: VisionKit document scanner + PHPicker → Vision OCR.
- Android: GMS document scanner + system photo picker → ML Kit OCR.

## Packages

| Package                                      | Responsibility                                                          |
| -------------------------------------------- | ----------------------------------------------------------------------- |
| `flutter_receipt_scanner`                    | App-facing API: `scan()` and the Dart-side OCR-floor acceptance gate.   |
| `flutter_receipt_scanner_platform_interface` | Abstract platform interface plus the Pigeon-generated message contract. |
| `flutter_receipt_scanner_ios`                | iOS (VisionKit + Vision) implementation.                                |
| `flutter_receipt_scanner_android`            | Android (GMS document scanner + ML Kit) implementation.                 |

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

- iOS `Info.plist`: `NSCameraUsageDescription` (camera scan) and `NSPhotoLibraryUsageDescription` (gallery scan).
- Android: none — the GMS document scanner and the system photo picker run out-of-process and require no app-declared permission.

## Development

```bash
melos run generate   # regenerate the Pigeon wire contract from the root schema
melos run analyze    # analyze all packages
melos run test       # test all packages
```

The Pigeon schema is a single source of truth at the repo root (`pigeons/messages.dart`). `melos run generate` runs Pigeon once from the root, emitting the Dart client into `flutter_receipt_scanner_platform_interface` and the Swift/Kotlin hosts into their platform packages.

Dart is formatted at 120 columns (`dart format --line-length 120`) and linted with `very_good_analysis`.
Kotlin, Swift, YAML, and Markdown are owned by trunk; Dart is intentionally left to `flutter`/`melos`.

## License

BSD 3-Clause — see [LICENSE](LICENSE).

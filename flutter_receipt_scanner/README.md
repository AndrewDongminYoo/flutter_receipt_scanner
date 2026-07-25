# flutter_receipt_scanner

On-device receipt image acquisition, crop, orientation normalization, JPEG compression, EXIF extraction, and OCR (raw string) for Flutter, on iOS and Android.

This is a [federated plugin][federated].
The native layers own **image primitives only** — receipt domain parsing (store name, amount, date), upload transport, cloud OCR, and duplicate detection belong in the consuming app, not here.

- iOS: VisionKit document scanner + PHPicker → Vision OCR.
- Android: GMS document scanner + system photo picker → ML Kit OCR.

## Usage

```dart
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';

final result = await scan(options: const ScanReceiptOptions(maxPages: 1));
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

- iOS `Info.plist`: `NSCameraUsageDescription` (camera scan). No photo-library key is needed — the gallery flow uses the permissionless `PHPickerViewController`.
- Android: none — the GMS document scanner and the system photo picker run out-of-process and require no app-declared permission.

## Platform baselines

- iOS deployment target: 16.0.
- Android `minSdk`: 24.

See the [repository][repo] for the full documentation and design specs.

[federated]: https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins
[repo]: https://github.com/AndrewDongminYoo/flutter_receipt_scanner

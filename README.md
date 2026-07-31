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

## Long receipts (multi-page OCR merge)

Very long receipts should be captured as multiple overlapping camera pages, not one tall photo.
Enable the opt-in merge to get one ordered OCR string with proven page-seam duplicates removed:

```dart
final result = await scan(
  options: const ScanReceiptOptions(maxPages: 6),
  mergeOcrPages: true,
);

final merged = result.mergedOcr;
if (merged != null) {
  if (merged.isComplete) {
    print(merged.text); // One ordered OCR string, seam duplicates removed.
  } else {
    // Diagnostics: merged.unmatchedBoundaryIndexes, merged.rejectedPageIndexes.
  }
}
```

`mergeOcrPages: true` requires `ocr: true` (the default), `source: ScanSource.camera`, and `maxPages >= 2`; any other combination throws `ArgumentError` before the native scanner opens.

### Support contract

- The supported logical receipt content aspect ratio is `contentHeight / contentWidth <= 11.0`.
- The physical interpretation is a receipt up to 600 mm long on paper at least 57.0 mm wide (`600 / 57.0 = 10.53`).
- The reference capture layout is six portrait pages with approximately 20% vertical overlap between adjacent pages.
- The 11.0 limit is a tested capability claim, not a runtime physical-length measurement — a scan is never rejected because a physical size cannot be inferred from pixels.

### Capture guidance

Capture consecutive sections top-to-bottom in one camera session, overlapping each page with the previous one by roughly 20%.
The overlap is what lets the merger prove each adjacent seam and remove the duplicated lines exactly once.

Exact page division is not required — a seam is proven when the next capture re-shows the last few lines of the previous one (two or three receipt lines are usually enough); the ~20% figure is the tested reference layout with margin.
A gap between adjacent captures surfaces as an unmatched boundary, but a missed receipt top or bottom cannot be detected — start at the very first printed line and finish past the last one.

Set `maxPages` to the ceiling (10) when merging.
iOS cannot enforce a page limit in the VisionKit scanner UI, so pages captured beyond `maxPages` are discarded before processing without native recourse; `ScanReceiptResult.discardedPageCount` reports how many were dropped, and a positive count always makes the merged result incomplete.

Prefer the scanner's manual shutter while sectioning a long receipt — the automatic shutter can fire before a section is framed.
On iOS, use the Auto/Manual toggle inside the scanner UI; the package cannot switch it programmatically.
There is no capture-mode scan option on either platform: Android's `GmsDocumentScannerOptions` declares `CaptureMode` constants but its public builder has no capture-mode setter ([googlesamples/mlkit#846](https://github.com/googlesamples/mlkit/issues/846)), and those constants must never be passed to `setScannerMode`, whose integer namespace is unrelated.
Android's in-scanner capture behavior is pending physical-device verification.

### What the merge does and does not do

- The merge assembles **OCR text only**. No stitched bitmap, PDF, or tall composite image is returned; each page keeps its own JPEG in `result.images`.
- Gallery-selected images are not merged in version 1 — `mergeOcrPages` works with `ScanSource.camera` only.
- An unproven seam or an OCR-rejected page never throws after a completed scan.
  The result comes back with `isComplete == false`, the seam recorded in `unmatchedBoundaryIndexes` (index `i` is the seam between pages `i` and `i + 1`), the page recorded in `rejectedPageIndexes`, and all text preserved — the merger never deletes uncertain content to make a result look complete.

## Multilingual OCR

The scanner extracts text using the languages requested in `ScanReceiptOptions.ocrLanguages`.
By default, this is `['ko-KR', 'en-US']` (Korean and Latin text).

```dart
final result = await scan(
  options: const ScanReceiptOptions(
    ocrLanguages: ['ko-KR', 'en-US'], // BCP 47 language tags
  ),
);
```

### Checking Capabilities

You can query current OCR support without opening the scanner or downloading models:

```dart
final capabilities = await getOcrCapabilities();

if (capabilities is IosOcrCapabilities) {
  // Vision OCR exact supported languages
  print(capabilities.supportedLanguages);
} else if (capabilities is AndroidOcrCapabilities) {
  // ML Kit OCR script families and download states
  for (final model in capabilities.models) {
    print('${model.script} is ${model.status.name}');
  }
}
```

- **iOS:** The system language bundle handles OCR. If a requested language is not supported by the active Vision framework revision, it throws `PlatformException('OCR_LANGUAGE_NOT_SUPPORTED')`.
- **Android:** The Latin module (`text-recognition`) is bundled with the plugin, but non-Latin modules (`-korean`, `-japanese`, `-chinese`, `-devanagari`) are downloaded dynamically from Google Play Services. If a script family is not installed, the first `scan()` will trigger a download and may throw `PlatformException('OCR_MODEL_INSTALL_FAILED')` if offline. At most one non-Latin script can be requested at a time, or it throws `PlatformException('OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED')`.

_Note: The `11.0` aspect ratio and seam-matching metrics were calibrated exclusively on Korean+Latin text. Other scripts are natively supported but uncalibrated._

## Host app permissions

- iOS `Info.plist`: `NSCameraUsageDescription` (camera scan). No photo-library key is needed — the gallery flow uses the permissionless `PHPickerViewController`.
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

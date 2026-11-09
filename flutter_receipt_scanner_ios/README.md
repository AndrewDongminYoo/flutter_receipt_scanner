# flutter_receipt_scanner_ios

The iOS implementation of [`flutter_receipt_scanner`][1].

## Usage

This package is [endorsed][2], which means you can simply use `flutter_receipt_scanner` normally.
This package is automatically included in your app when you do, so you do not need to add it to your `pubspec.yaml`.

## Native geometry conformance

From the repository root, with Xcode and an already booted iOS simulator:

```bash
VERIFY_CORRUPTION=1 bash flutter_receipt_scanner_ios/ios/tests/run-geometry.sh
```

Set `SIMULATOR_UDID` to select a booted simulator; the runner never boots or shuts down devices.
An optional first argument selects an absolute corpus JSON path, so edited expectations can be tested without changing the vendored corpus.
The runner compiles production `OcrGeometry.swift` and `QuadDetector.swift` directly for the iOS simulator SDK, then uses `simctl spawn` to execute all 64 geometry cases from `flutter_receipt_scanner/test/fixtures/ocr-contracts/v1/contract.json`.
It requires no Flutter framework, package resolution, scanner UI, or OCR model.
The existing macOS `Package.swift` remains the separate `PageBatch` test host; it cannot compile the UIKit/Vision quad helper.

Discrete outputs and integer pixel boxes compare exactly; angle and quad inputs decode through binary32 (`Float`) before conversion to `CGFloat`.
Additional Vision normalized bottom-left box and non-square-frame angle checks use an absolute tolerance of `0.000001` pixels/degrees for conversion arithmetic.
Quad inputs reflect Y into bottom-left coordinates while preserving corner order.
Geometry helpers consume canonical clockwise degrees; production `OcrProcessor` converts that correction to complementary counterclockwise degrees for iOS pixel rotation, then converts back for fallback box placement.
The harness preserves those helper conventions and does not change native pixel rotation.

`VERIFY_CORRUPTION=1` also increments the `rotate-90` expected X coordinate in a temporary corpus and requires the same executable to reject it with a nonzero exit.
CI runs both the original corpus and this negative control in `.github/workflows/native-ios.yaml`.
That workflow also builds the example with `flutter build ios --simulator --debug --no-codesign` to verify plugin integration.

[1]: https://pub.dev/packages/flutter_receipt_scanner
[2]: https://flutter.dev/to/endorsed-federated-plugin

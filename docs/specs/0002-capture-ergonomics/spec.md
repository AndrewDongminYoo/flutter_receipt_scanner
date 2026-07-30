---
type: Spec
title: Long Receipt Capture Ergonomics
---

## Problem

The 2026-07-30 iOS physical acceptance run ([record](../../notes/2026-07-30-physical-acceptance-record.md)) exposed two capture-ergonomics failure modes in long-receipt scanning.

First, iOS silently discards scanner pages beyond `maxPages`.
VisionKit's document camera cannot enforce a page limit in its UI, so `ReceiptScannerApiImpl.swift` processes only the first `maxPages` pages and drops the rest without any signal.
In acceptance run 1 this produced a merged OCR result that reported no unmatched boundaries while the final three receipt lines were missing — a silently incomplete result presented as proven complete. [L2]

Second, automatic shutter capture fires before the user finishes framing a section, creating gap and tail-loss risk on long receipts.
Neither platform currently allows the package to request manual capture: VisionKit has no configuration API at all, and Android's `GmsDocumentScannerOptions` defines `CaptureMode` constants without a public builder setter (googlesamples/mlkit#846 is open, unanswered). [L1]

## Proposed Outcome

The scan result reports how many natively captured pages were discarded, the merged OCR result refuses to claim completeness when any page was discarded, and the README documents both the truncation behavior and practical manual-capture guidance.
No capture-mode API is added until upstream platform support exists. [L1] [L2]

## User Stories

1. As an app developer, I can detect that the scanner captured more pages than `maxPages` and that content may be missing, instead of receiving a silently truncated result. [L2]
2. As an app developer enabling `mergeOcrPages`, I never receive `isComplete == true` for a scan whose pages were partially discarded. [L2]
3. As a person scanning a long receipt, I can follow documented guidance to switch the scanner to manual shutter and to size `maxPages` so pages are not captured prematurely or dropped. [L1]
4. As a maintainer, I can point to a recorded upstream constraint explaining why no programmatic capture-mode option exists. [L1]

## Requirements

### Truncation Diagnostic

1. `ScanResultWire` gains an optional `discardedPageCount` field; absent means zero. [L2]
2. Both native implementations compute it defensively as `max(0, nativelyCapturedPages - effectiveMaxPages)`; on Android the GMS scanner enforces `setPageLimit` in-UI so the expected value is zero. [L2]
3. iOS continues to process the first `maxPages` pages in native order; this Spec surfaces the truncation, it does not change which pages are kept. [L2]
4. `ScanReceiptResult` gains `int discardedPageCount` defaulting to `0`, mapped from the wire in both platform packages.
5. When `mergeOcrPages` is enabled and `discardedPageCount > 0`, the returned `MergedOcrResult` must have `isComplete == false` even when every returned adjacent boundary is proven.
   This explicitly supersedes Spec 0001 Result Model requirement 7 (the unconditional one-page completeness rule) for the discarded-pages case, which is reachable on iOS because failed page processing (`compactMap`) can reduce a truncated scan to a single returned page. [L2]
6. Merge seam matching, boundary indexes, and rejected-page reporting are otherwise unchanged from Spec 0001.
7. The example app's merge diagnostics card displays the discarded page count when it is greater than zero.

### Capture Guidance and Upstream Constraint

1. The README documents that iOS discards pages beyond `maxPages` without native recourse and recommends `maxPages: 10` (the ceiling) when `mergeOcrPages` is enabled. [L2]
2. The README documents manual-shutter guidance: iOS offers an Auto/Manual toggle inside the scanner UI; the package cannot switch it programmatically. [L1]
3. Android in-scanner capture behavior is verified on a device during implementation before its guidance wording ships; the inspected public documentation does not describe the scanner UI's manual controls. [L1]
4. No `captureMode` option is added to `ScanReceiptOptions`, the Pigeon schema, or native code. [L1]
5. `CaptureMode` constants must never be passed to `setScannerMode`; the integer namespaces are unrelated. [L1]

### Versioning

1. The wire change ships as a coordinated 0.4.0 minor release of all four packages; 0.3.0 is already published and immutable. [L3]
2. The Pigeon contract change is made only in the root `pigeons/messages.dart` and regenerated with `melos run generate`; generated Dart, Swift, and Kotlin files are never hand-edited.

## Technical Decisions

- The diagnostic is acquisition metadata (a page count), not receipt-domain logic, so natively populating it does not violate the image-primitives boundary; the completeness policy that consumes it stays in the app-facing Dart package. [L2]
- The wire field is optional (`Int64?`) and absent maps to zero, but the generated `ScanResultWire.decode` indexes list positions directly, so mixed-version wire payloads (new Dart against an old native host, or the reverse) are not supported; compatibility relies entirely on the coordinated 0.4.0 version constraints across the four packages. [L3]
- The completeness override happens in the app package's merge orchestration (`receipt_scanner.dart`), not inside the pure merger, which remains a function of page texts only.

## Testing Strategy

- TDD at the existing Dart seams: fake-platform tests in `flutter_receipt_scanner` drive `discardedPageCount` mapping and the `isComplete` override; model tests in the platform interface cover the default and wire mapping in both directions.
- Widget test: the example diagnostics card shows the discarded count when positive and hides it at zero.
- No live scanner calls in automated tests; native behavior is covered by the physical acceptance protocol.
- Physical re-verification on iOS: capture more pages than `maxPages` and require the result to report the discarded count and an incomplete merge; append the run to the acceptance record. [L2]
- Repository verification: `melos run format`, `melos run analyze`, `melos run test`, `trunk fmt`, `trunk check`.

## Out of Scope

1. A `captureMode` scan option or any programmatic shutter control, until Android publishes a working public setter and its behavior is verified. [L1]
2. Changing which pages iOS keeps when truncating, raising the `maxPages` ceiling of 10, or enforcing the limit inside VisionKit.
3. Retrying, re-prompting, or automatically rescanning when truncation is detected.
4. All Spec 0001 exclusions (stitched bitmap, structured parsing, gallery merging, cloud OCR).

## Open Questions

1. Does the GMS scanner UI expose a user-visible manual shutter while auto-capture is active? Verify on a physical Android device before shipping the Android guidance wording (Capture Guidance requirement 3).

## Follow-Ups

1. Watch googlesamples/mlkit#846 and the `GmsDocumentScannerOptions.Builder` reference for a public capture-mode setter; a working setter reopens the `captureMode` option as a new Spec.
2. Fold the truncation re-verification into the pending Android physical acceptance run when a device becomes available.

## Notes

- Field evidence: [2026-07-30 physical acceptance record](../../notes/2026-07-30-physical-acceptance-record.md) — run 1 (rejected) demonstrates the silent truncation; run 2 (accepted) passes all gates with `maxPages: 10`.
- iOS truncation site: `flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/ReceiptScannerApiImpl.swift` (`pageCount = min(scan.pageCount, maxPages)`).
- Android options site: `flutter_receipt_scanner_android/android/src/main/kotlin/com/example/flutter_receipt_scanner_android/FlutterReceiptScannerPlugin.kt` (`setPageLimit`, `SCANNER_MODE_FULL`).
- [Apple VisionKit document camera](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller) — no configuration surface.
- [GmsDocumentScannerOptions.Builder](https://developers.google.com/android/reference/com/google/mlkit/vision/documentscanner/GmsDocumentScannerOptions.Builder) — public methods without a capture-mode setter.
- [googlesamples/mlkit#846](https://github.com/googlesamples/mlkit/issues/846) — open capture-mode bug report.

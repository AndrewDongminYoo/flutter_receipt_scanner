---
type: Work Item
title: Truncation Diagnostic End-to-End
parent: ../spec.md
---

## What to build

Add an optional `discardedPageCount` field to `ScanResultWire` in the root `pigeons/messages.dart` and regenerate all Pigeon outputs with `melos run generate`.
Compute the count defensively on both platforms as `max(0, nativelyCapturedPages - effectiveMaxPages)` — iOS keeps processing the first `maxPages` pages unchanged; Android's GMS scanner enforces `setPageLimit` in-UI so its expected value is zero.
Expose `ScanReceiptResult.discardedPageCount` (default `0`), map it in both platform packages, and force `MergedOcrResult.isComplete == false` in the app package's merge orchestration when the count is positive.
Show the discarded count in the example app's merge diagnostics card when it is greater than zero.
Bump all four package manifests, internal constraints, and changelogs to 0.4.0.

## Required context

- Wire↔model mapping conventions live in each platform package; the merge orchestration and completeness policy live in `flutter_receipt_scanner/lib/src/receipt_scanner.dart` — the pure merger in `ocr_page_merger.dart` stays a function of page texts only.
- Never hand-edit `messages.g.dart`, `Messages.g.swift`, or `Messages.g.kt`.
- iOS truncation site: `ReceiptScannerApiImpl.swift` (`pageCount = min(scan.pageCount, maxPages)`).
- Field evidence and the physical re-verification protocol: `docs/notes/2026-07-30-physical-acceptance-record.md`.

## Acceptance criteria

- [x] `ScanResultWire.discardedPageCount` is optional in the Pigeon schema; absent decodes as zero and all generated files are regenerated, not hand-edited.
- [x] iOS populates the count defensively while keeping the first `maxPages` pages in native order.
- [x] Android populates the count defensively (expected zero).
- [x] `ScanReceiptResult.discardedPageCount` defaults to `0` and is mapped from the wire in both platform packages.
- [x] With `mergeOcrPages` enabled and a positive discarded count, the merged result reports `isComplete == false` even when every returned boundary is proven; seam matching, boundary indexes, and rejected-page reporting are otherwise unchanged.
- [x] Android and iOS platform-package routing tests cover the wire-to-model conversion of the new field; a platform-interface test covers the model's `0` default; app-facing fake-platform tests cover the completeness override and preserve the count through the OCR-floor path, including when merging is disabled.
- [x] The example diagnostics card shows the discarded count when positive and hides it at zero, with widget coverage.
- [x] All four packages are bumped to 0.4.0 with changelog entries.
- [x] iOS physical re-verification: capturing more pages than `maxPages` reports the discarded count and an incomplete merge; the run is appended to the acceptance record.
- [x] `melos run format`, `melos run analyze`, `melos run test`, `trunk fmt`, and `trunk check` pass.

## Covers

- User Stories: 1, 2
- Requirements: Truncation Diagnostic 1-7; Versioning 1-2
- Testing Strategy: 1, 2, 4, 5
- Interview Ledger: L2, L3

## Blocked by

None - ready to start

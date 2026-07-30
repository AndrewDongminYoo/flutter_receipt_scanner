---
type: Interview Ledger
title: Long Receipt Capture Ergonomics Decisions
parent: spec.md
---

## Records

### L1

Status: current

Question: Can the automatic shutter be disabled programmatically when `mergeOcrPages` is enabled?

Answer: Not on either platform today.
iOS VisionKit's `VNDocumentCameraViewController` exposes no configuration API; the scanner UI has a built-in Auto/Manual toggle only the user can operate.
Android's `GmsDocumentScannerOptions` defines `CAPTURE_MODE_AUTO` and `CAPTURE_MODE_MANUAL` constants, but the public `Builder` exposes only `build`, `setGalleryImportAllowed`, `setPageLimit`, `setResultFormats`, and `setScannerMode` — there is no public capture-mode setter, and googlesamples/mlkit#846 (capture mode has no effect) is open without a Google response.

Decision: This Spec adds no `captureMode` option.
It documents in-scanner manual capture guidance instead and records the upstream constraint for later revisit.

Reason: An option neither platform can honor would be dead API surface; the constants without a setter suggest an unreleased feature.

Negative Requirements:

- Do not pass `CaptureMode` constants into `setScannerMode`; the integer namespaces are unrelated and the call has no effect.
- Do not add `captureMode` to `ScanReceiptOptions` until a documented public Android setter exists.

Source: User request 2026-07-30; Google API reference for `GmsDocumentScannerOptions.Builder`; googlesamples/mlkit issue 846.

### L2

Status: current

Question: Why did the 2026-07-30 iOS acceptance run 1 report a complete merge while the final three receipt lines were missing?

Answer: The operator captured one more page than `maxPages`.
VisionKit cannot enforce a page limit in its UI, so the iOS implementation silently processes only the first `maxPages` pages (`ReceiptScannerApiImpl.swift`, `pageCount = min(scan.pageCount, maxPages)`), and the dropped final page held the only copy of the last three lines.
Confirmed by operator reproduction.
Android's GMS scanner enforces `setPageLimit` in-UI, so the failure mode is iOS-only, but the discarded count must be computed defensively on both platforms.

Decision: Surface truncation as an explicit diagnostic (`discardedPageCount`) instead of dropping pages silently, and a merged OCR result must not report `isComplete == true` when pages were discarded.

Reason: A silently truncated scan is indistinguishable from a proven-complete one, which defeats the completeness contract of Spec 0001.

Source: docs/notes/2026-07-30-physical-acceptance-record.md; flutter_receipt_scanner_ios `ReceiptScannerApiImpl.swift`.

### L3

Status: current

Question: Where does this work live relative to Spec 0001?

Answer: In a new Spec with its own Work Items ("새로운 Work Item으로 만들어주세요").

Decision: Spec 0001 explicitly lists Pigeon transport and generated-file changes as out of scope, so the truncation diagnostic (which adds a wire field) requires this separate Spec.
Any wire change ships as a coordinated 0.4.0 minor release because 0.3.0 is already published.

Source: User approval 2026-07-30; Spec 0001 Out of Scope items 6 and 10.

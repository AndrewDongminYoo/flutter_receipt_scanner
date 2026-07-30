---
type: Work Item
title: Capture Guidance Documentation
parent: ../spec.md
---

## What to build

Document long-receipt capture ergonomics in both READMEs (root and `flutter_receipt_scanner/`): iOS discards scanner pages beyond `maxPages` without native recourse and `maxPages: 10` (the ceiling) is recommended when `mergeOcrPages` is enabled; the `discardedPageCount` diagnostic signals when it happened.
Add manual-shutter guidance: iOS offers an Auto/Manual toggle inside the scanner UI that the package cannot switch programmatically.
Record the upstream constraint: no `captureMode` option exists because Android's `GmsDocumentScannerOptions` defines `CaptureMode` constants without a public builder setter (googlesamples/mlkit#846 open); `CaptureMode` constants must never be passed to `setScannerMode`.

## Required context

- The existing "Long receipts (multi-page OCR merge)" README sections hold the support contract and capture guidance; extend them rather than adding parallel sections.
- Spec: `docs/specs/0002-capture-ergonomics/spec.md` (Capture Guidance and Upstream Constraint requirements).

## Acceptance criteria

- [ ] Both READMEs document the iOS truncation behavior, the `maxPages: 10` recommendation for merging, and the `discardedPageCount` diagnostic.
- [ ] Both READMEs document the iOS in-scanner Auto/Manual toggle and that programmatic capture-mode control does not exist on either platform.
- [ ] The upstream Android constraint is recorded with the issue reference, including the `setScannerMode` misuse warning.
- [ ] Android in-scanner guidance wording ships only after on-device verification; until then the READMEs document only the verified iOS toggle and state that Android in-scanner behavior is pending device verification.
- [ ] `trunk fmt` and `trunk check` pass on the touched files.

## Covers

- User Stories: 3, 4
- Requirements: Capture Guidance and Upstream Constraint 1-5
- Testing Strategy: 5
- Interview Ledger: L1

## Blocked by

- [01-truncation-diagnostic.md](01-truncation-diagnostic.md)

## Blocking decisions

- Verify on a physical Android device whether the GMS scanner UI exposes a user-visible manual shutter while auto-capture is active, before finalizing the Android guidance wording.

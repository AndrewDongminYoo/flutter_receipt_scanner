---
type: Work Item
title: Physical Device Acceptance
parent: ../spec.md
---

## What to build

Run and record the complete 600 mm, six-page camera acceptance scenario on one supported Android physical device and one iOS 16.0-or-newer physical device.
Verify capture order, JPEG dimensions and readability, OCR and seam accuracy, duration, and process stability.
Run the pinned public-dataset calibration locally and record complete counts, failures, and character error rates without checking third-party images into the repository.

## Required context

This Work Item is the release gate for the 11.0 support claim.
An emulator or simulator does not replace physical-device evidence.
Android documentation inspected for the parent Spec did not state an explicit long-term page-order guarantee, so observed order is mandatory evidence.

## Status

Blocked on Android hardware, not on work.
The **iOS half of every criterion below passed** on 2026-07-30 (iPhone 16 Pro / iOS 26.5.2: aggregate CER 0.0068, Hangul 0.0102, Latin 0.0120, 75/75 lines, zero duplicated seam lines) and is recorded in the [acceptance record](../../../notes/2026-07-30-physical-acceptance-record.md).
The boxes stay unchecked because each one reads "on both devices" and no physical Android device has been available.
Resume by running the same protocol on Android — nothing needs re-doing on iOS.

## Acceptance criteria

- [ ] The actual Android and iOS device models, OS versions, and relevant scanner dependencies are recorded.
- [ ] The 600 mm target is captured in six camera pages with approximately 20% overlap on both devices.
- [ ] Capture order equals the returned page URI order on both devices.
- [ ] Every returned JPEG is readable and has at least 1,200 pixels across the cropped receipt width.
- [ ] Both results are complete with no unmatched boundaries or rejected pages.
- [ ] Aggregate character error rate is no greater than 20% on each platform.
- [ ] Korean and Latin character error rates are each no greater than 25% on each platform.
- [ ] There is no missing non-overlap text and no duplicated accepted seam text.
- [ ] OCR plus Dart merging completes within 30 seconds after native UI return.
- [ ] Neither run crashes nor terminates from an out-of-memory condition.
- [ ] Appen, Humyn, and CORD calibration records include revision, expected count, processed count, skipped files, failures, and applicable character error rates.
- [ ] The final repository verification commands pass.

## Covers

- User Stories: 2, 4, 5
- Requirements: Support Contract; Page Ordering; Performance and Resource Limits
- Testing Strategy: Public Dataset Calibration; Physical End-to-End Acceptance; Repository Verification
- Interview Ledger: L1, L6, L8

## Blocked by

- [02-scan-api-orchestration.md](02-scan-api-orchestration.md)
- [03-fixtures-and-dataset-manifest.md](03-fixtures-and-dataset-manifest.md)
- [04-example-and-documentation.md](04-example-and-documentation.md)

## Blocking decisions

- Record the specific supported Android physical device available for the acceptance run.
- Record the specific iOS 16.0-or-newer physical device available for the acceptance run.

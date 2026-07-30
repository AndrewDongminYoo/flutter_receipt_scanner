---
type: Work Item
title: Example App and Documentation
parent: ../spec.md
---

## What to build

Add an example-app control that enables multi-page OCR merging only for compatible camera settings.
Display merged completeness, unmatched boundaries, rejected page indexes, and merged text.
Document the 11.0 support contract, six-page reference layout, approximately 20% capture overlap, incomplete-result handling, and version 1 gallery exclusion.

## Acceptance criteria

- [ ] The example app exposes an opt-in merge control.
- [ ] Enabling the control drives camera, OCR, and multi-page-compatible options.
- [ ] The result surface distinguishes complete and incomplete merges.
- [ ] The result surface displays unmatched boundaries, rejected page indexes, and merged OCR text.
- [ ] README documentation states the logical 11.0 ratio and 600 mm at 57.0 mm physical interpretation.
- [ ] README documentation explains the six-page layout and approximately 20% adjacent overlap.
- [ ] README documentation states that no stitched bitmap is returned and gallery merging is not supported in version 1.
- [ ] Widget or app-facing tests cover the observable merge diagnostics.
- [ ] Formatting, workspace analysis, the full workspace test suite, and non-Dart trunk checks pass.

## Covers

- User Stories: 2, 4, 5
- Requirements: Support Contract; Public API; Result Model; Out of Scope
- Testing Strategy: Physical End-to-End Acceptance preparation
- Interview Ledger: L1, L3, L4, L6

## Blocked by

- [02-scan-api-orchestration.md](02-scan-api-orchestration.md)
- [03-fixtures-and-dataset-manifest.md](03-fixtures-and-dataset-manifest.md)

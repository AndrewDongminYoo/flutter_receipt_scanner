---
type: Work Item
title: Deterministic Fixtures and Dataset Manifest
parent: ../spec.md
---

## What to build

Add project-authored Korean-plus-Latin source text and a deterministic generator for a 1,200 × 13,200 logical receipt split into six 1,200 × 2,640 images with 528-pixel overlap.
Add the specified incomplete and repeated-line variants.
Add a machine-readable manifest for the verified public Appen, Humyn, and CORD v2 benchmark inputs without downloading or committing third-party receipt photos during normal development or CI.

## Required context

Generated fixture images are derived artifacts.
The source text and generator are the source of truth.
Any Korean font required by the generator must have a pinned version, checksum, attribution, and compatible license.
KORIE is deferred until its archive and dataset-specific license are verified.

## Acceptance criteria

- [x] The canonical logical fixture is exactly 1,200 × 13,200 pixels.
- [x] Six page fixtures are exactly 1,200 × 2,640 pixels with 528-pixel adjacent overlap.
- [x] Regeneration produces deterministic checksums.
- [x] Missing-page, unmatched-boundary, repeated-line, segmentation-difference, and below-floor variants exist.
- [x] Canonical page OCR strings merge byte-for-byte to the canonical normalized receipt text.
- [x] Failure variants return exact incomplete diagnostics.
- [x] The dataset manifest records source URL, access date, license, expected public files, annotations, scripts, checksums when stable, and intended role.
- [x] Normal tests and CI require no network, authentication, Kaggle, Hugging Face, or third-party receipt photos.
- [x] Humyn is not used as character-error-rate ground truth.
- [x] Formatting, fixture tests, workspace analysis, and the full workspace test suite pass.

## Covers

- User Stories: 4, 5
- Requirements: Support Contract; Dataset and Fixture Policy
- Testing Strategy: Deterministic Fixture Tests; Public Dataset Calibration
- Interview Ledger: L1, L6, L7

## Blocked by

- [01-result-model-and-page-merger.md](01-result-model-and-page-merger.md)

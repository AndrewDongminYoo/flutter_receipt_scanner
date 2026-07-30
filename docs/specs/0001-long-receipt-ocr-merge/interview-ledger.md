---
type: Interview Ledger
title: Long Receipt OCR Page Merge Decisions
parent: spec.md
---

## Records

### L1

Status: current

Question: What is the longest receipt that the package must claim to support?

Answer: Support a logical receipt content aspect ratio of height divided by width up to 11.0.

Decision: The supported logical range is `contentHeight / contentWidth <= 11.0`.

Reason: Epson specifies receipt paper at 57.5 ± 0.5 mm and 79.5 ± 0.5 mm.
Using the minimum specified 57.0 mm width, a 600 mm receipt has an aspect ratio of 10.53, so 11.0 covers the requested 60 cm length with margin.

Source: User request and Epson TM-P80II Technical Reference Guide.

### L2

Status: current

Question: Does the 11.0 limit apply to one decoded JPEG or to the complete receipt assembled from multiple captures?

Answer: It applies to the logical receipt assembled from multiple ordered page images.

Decision: Version 1 must not allocate or return one 11:1 stitched bitmap.
It must retain the native JPEG pages and merge their OCR text in Dart.

Reason: The current Android path caps the processed image long edge at 3,072 pixels, while the repository boundary requires native packages to return image primitives and raw OCR rather than receipt-domain aggregation.

Negative Requirements:

- Do not create a giant stitched JPEG.
- Do not move receipt merge policy into Kotlin or Swift.
- Do not add the merge option to the Pigeon transport.

### L3

Status: current

Question: How is multi-page OCR merging enabled?

Answer: Add an app-facing `mergeOcrPages` boolean parameter to `scan()`, defaulting to `false`.

Decision: Existing callers keep their current behavior.
When enabled, the app-facing Dart package merges OCR from the ordered native page result after applying the existing OCR-quality annotations.

### L4

Status: current

Question: Which acquisition sources are supported by the first implementation?

Answer: Support `ScanSource.camera` only.

Decision: `mergeOcrPages: true` with `ScanSource.gallery` must fail validation before launching native UI.

Reason: Both native document scanners already support multi-page camera acquisition.
The current iOS gallery picker does not request ordered selection, and the Android photo picker documentation inspected during this investigation did not establish a cross-version ordering guarantee.
Adding a review-and-reorder gallery UI would materially expand scope.

### L5

Status: current

Question: How are page seams detected and what happens when a seam cannot be proven?

Answer: Compare only adjacent page suffix and prefix windows using normalized OCR lines.
Deduplicate a seam only when a deterministic similarity threshold is met.

Decision: A merge with any unmatched seam or OCR-floor-rejected page is returned as incomplete, with the affected indexes exposed.
The implementation must append unproven page text without deleting it and must never silently guess an overlap.

Reason: Preserving possibly duplicated text is safer than dropping receipt data.

### L6

Status: current

Question: What page layout demonstrates the 11.0 support contract?

Answer: Use a 1,200 × 13,200 logical receipt split into six 1,200 × 2,640 portrait pages with 528 pixels, or 20%, vertical overlap.

Decision: The deterministic long-receipt fixture and the physical 60 cm acceptance target use this six-page layout.

Reason: `2,640 + 5 × (2,640 - 528) = 13,200`, which is exactly 11 times the 1,200-pixel content width and stays within the existing ten-page native limit.

### L7

Status: current

Question: Which public data can support Korean and Latin OCR validation?

Answer: Use the five publicly downloadable, annotated Appen Korean receipt samples for Korean-plus-Latin calibration, the 20 unlabelled Humyn Korean receipt images for visual smoke testing, and CORD v2 for a larger annotated Latin receipt corpus.

Decision: Public datasets are local/manual benchmarks recorded through a manifest.
Checked-in continuous-integration fixtures must use project-authored Korean-plus-Latin content so dataset licensing, privacy, or availability cannot make CI non-reproducible.

Reason: The Appen public archive inspected on 2026-07-30 contains only five receipt image and JSON pairs despite the page advertising 1,500 images.
Humyn contains 20 images but no transcript or bounding-box labels.
CORD v2 has 1,000 annotated Indonesian receipts but is not Korean.

Negative Requirements:

- Do not commit third-party receipt photos by default.
- Do not treat unlabelled data as OCR accuracy ground truth.
- Do not claim a public long-receipt dataset was found.

### L8

Status: current

Question: What observable thresholds make the feature shippable?

Answer: Require exact deterministic seam behavior in Dart tests, aggregate character error rate no greater than 20% for the six-page physical target on both platforms, per-script character error rate no greater than 25%, no missing non-overlap text, no duplicated accepted seam text, and no crash or out-of-memory termination.

Decision: A feature implementation is not complete until one Android and one iOS physical-device run satisfy the 60 cm acceptance scenario.

Reason: Public receipt datasets found in this investigation do not cover the requested long geometry, so synthetic unit fixtures and a physical end-to-end target must jointly provide the support evidence.

### L9

Status: current

Question: Does the first version need configurable merge thresholds or a new runtime dependency?

Answer: No.

Decision: Keep overlap-window and similarity constants private and test-backed.
Implement normalization and bounded edit-distance comparison with Dart core libraries.

Reason: Public threshold configuration and a runtime dependency are unnecessary for the first shippable behavior and can be added later only if calibration proves a need.

### L10

Status: deferred

Question: Can KORIE become the primary Korean annotated benchmark?

Answer: [PARTIAL] The paper describes 748 Korean retail receipt images and 17,587 OCR word crops, but this investigation did not verify a stable public dataset download URL or a dataset-specific redistribution license.

Decision: Do not block version 1 on KORIE.
Re-evaluate it only after both the archive URL and dataset license are independently verified.

Source: KORIE paper DOI and DOAJ article record.

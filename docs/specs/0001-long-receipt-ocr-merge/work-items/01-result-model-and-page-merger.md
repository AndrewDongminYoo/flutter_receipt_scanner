---
type: Work Item
title: Public Result Model and OCR Page Merger
parent: ../spec.md
---

## What to build

Add the public `MergedOcrResult` model to the platform-interface package and an optional `mergedOcr` field to `ScanReceiptResult`.
Implement a private, pure Dart OCR page merger in the app-facing package.
The merger must preserve page URI order, compare only adjacent suffix and prefix windows, remove only proven overlap, and report incomplete results without deleting uncertain text.
Use only Dart core libraries and keep matching rules private.

## Required context

The native packages continue to return image primitives and raw OCR only.
This Work Item must not change Pigeon, generated files, Kotlin, or Swift.
The public result model lives in the platform-interface package because `ScanReceiptResult` is defined there, but the app-facing Dart package owns merge behavior.

## Acceptance criteria

- [x] `MergedOcrResult` exposes text, completeness, ordered page URIs, unmatched boundary indexes, and rejected page indexes as immutable fields.
- [x] `ScanReceiptResult.mergedOcr` is optional and defaults to null without breaking existing constructors.
- [x] Exact adjacent overlap with at least two distinct normalized lines is emitted once, choosing the deepest match without a line-count cap.
- [x] Case and whitespace normalization preserves earlier recognized text without fuzzy matching.
- [x] Approximate matches, quantity or price changes, and different line segmentation preserve all text and record the correct unmatched boundary.
- [x] Single-line matches and repeated identical rows split across a boundary remain unproven, preserving real purchases.
- [x] Repeated receipt lines outside the adjacent suffix and prefix are preserved.
- [x] Null or empty OCR and explicitly rejected page indexes produce an incomplete result.
- [x] One non-empty page produces a complete result.
- [x] Input image models, OCR strings, lists, and URIs are not mutated.
- [x] Ten pages with 200 OCR lines each merge within 100 ms in the targeted Dart test environment.
- [x] Focused tests, workspace analysis, and the full workspace test suite pass.

## Covers

Matching criteria were revised by [issue #3](https://github.com/AndrewDongminYoo/flutter_receipt_scanner/issues/3) to replace unsafe edit-distance matching.

- User Stories: 3
- Requirements: Result Model; OCR Merge; Performance and Resource Limits 1-2
- Testing Strategy: Pure Dart Unit Tests 3-9 and 11-12
- Interview Ledger: L2, L5, L9

## Blocked by

None - ready to start

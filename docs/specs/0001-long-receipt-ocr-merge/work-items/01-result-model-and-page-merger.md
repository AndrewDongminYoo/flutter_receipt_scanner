---
type: Work Item
title: Public Result Model and OCR Page Merger
parent: ../spec.md
---

## What to build

Add the public `MergedOcrResult` model to the platform-interface package and an optional `mergedOcr` field to `ScanReceiptResult`.
Implement a private, pure Dart OCR page merger in the app-facing package.
The merger must preserve page URI order, compare only adjacent suffix and prefix windows, remove only proven overlap, and report incomplete results without deleting uncertain text.
Use only Dart core libraries and keep matching constants private.

## Required context

The native packages continue to return image primitives and raw OCR only.
This Work Item must not change Pigeon, generated files, Kotlin, or Swift.
The public result model lives in the platform-interface package because `ScanReceiptResult` is defined there, but the app-facing Dart package owns merge behavior.

## Acceptance criteria

- [x] `MergedOcrResult` exposes text, completeness, ordered page URIs, unmatched boundary indexes, and rejected page indexes as immutable fields.
- [x] `ScanReceiptResult.mergedOcr` is optional and defaults to null without breaking existing constructors.
- [x] Exact adjacent overlap is emitted once.
- [x] Korean-plus-Latin overlap at or above the specified similarity threshold is emitted once.
- [x] An overlap below threshold is preserved and records the correct unmatched boundary.
- [x] A single-line candidate uses the stricter length and similarity threshold.
- [x] Repeated receipt lines outside the adjacent suffix and prefix are preserved.
- [x] Null or empty OCR and explicitly rejected page indexes produce an incomplete result.
- [x] One non-empty page produces a complete result.
- [x] Input image models, OCR strings, lists, and URIs are not mutated.
- [x] Ten pages with 200 OCR lines each merge within 100 ms in the targeted Dart test environment.
- [x] Focused tests, workspace analysis, and the full workspace test suite pass.

## Covers

- User Stories: 3
- Requirements: Result Model; OCR Merge; Performance and Resource Limits 1-2
- Testing Strategy: Pure Dart Unit Tests 3-9 and 11-12
- Interview Ledger: L2, L5, L9

## Blocked by

None - ready to start

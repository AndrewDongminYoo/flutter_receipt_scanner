---
type: Work Item
title: Scan API Orchestration
parent: ../spec.md
---

## What to build

Add the backward-compatible `mergeOcrPages` flag to the app-facing `scan()` function.
Validate OCR, camera source, and page-count requirements before native UI.
Snapshot native page order, apply the existing OCR-floor gate, restore annotated pages to capture order by URI, run the pure merger, and attach the result without changing native transport.

## Required context

Camera merging is the only supported acquisition source in version 1.
Gallery ordering and review UI remain out of scope.
An enabled one-page capture is a complete merge, cancellation has no merged result, and post-capture quality failures return diagnostics instead of throwing.

## Acceptance criteria

- [ ] `mergeOcrPages` defaults to false and preserves existing scan behavior.
- [ ] Invalid OCR, gallery-source, and maximum-page combinations throw `ArgumentError` before calling the platform.
- [ ] Native page order is snapshotted before OCR-floor partitioning.
- [ ] Annotated accepted and rejected pages are restored to original order using unique cache URIs.
- [ ] Duplicate page URIs fail explicitly rather than silently reordering pages.
- [ ] A requested merge attaches `MergedOcrResult` to success and rejected scan results.
- [ ] Cancellation retains `ScanStatus.cancelled` and `mergedOcr == null`.
- [ ] Native `ScanReceiptOptions`, Pigeon, generated files, Kotlin, and Swift remain unchanged.
- [ ] Focused scan and OCR-floor tests, workspace analysis, and the full workspace test suite pass.

## Covers

- User Stories: 1, 2, 3
- Requirements: Public API; Page Ordering; Errors and Diagnostics
- Testing Strategy: Pure Dart Unit Tests 1-2 and 10
- Interview Ledger: L2, L3, L4, L5

## Blocked by

- [01-result-model-and-page-merger.md](01-result-model-and-page-merger.md)

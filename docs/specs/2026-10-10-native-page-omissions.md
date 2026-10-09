# Native page omission diagnostics

Issue: <https://github.com/AndrewDongminYoo/flutter_receipt_scanner/issues/4>

## Problem

The iOS camera uses `compactMap` and the gallery skips nil image results.
The Flutter Android implementation also drops soft failures with `mapNotNull` and `mapIndexedNotNull`.
A surviving batch can therefore omit a page while `discardedPageCount` remains zero and merged OCR reports completeness.

## Contract

Preserve partial-batch success and the order of returned images.
Report captured or selected pages omitted from native image results through the existing `discardedPageCount` field.
The count equals the original input count minus the returned image count, including cap omissions, processing failures, and iOS gallery crop-editor skips.
Apply the page cap before processing and count each omitted page once.
Do not count Dart OCR-floor `rejectedImages`, because those images were returned.
Keep the existing wire layout and absent-field default of zero.
The existing Dart guard must report `isComplete: false` when this count is positive, including a one-image survivor.

For nonempty input batches whose processing returns no images, preserve existing outcomes: iOS camera and both Android processing paths retain `PROCESSING_FAILED`; iOS gallery retains `cancelled` when every selected image is skipped or fails, with its omitted count now present.
An empty picker cancellation has no selected pages to count.
This aggregate diagnostic deliberately does not distinguish a gallery processing failure from an editor cancellation.
Keep example count copy neutral about the omission cause.

## Scope and constraints

Change native acquisition batch accounting, its pure test seams, public field descriptions, and the example diagnostic label.
Do not add a new public field, change the whole-batch error policy, migrate Pigeon APIs, upgrade dependencies, or change receipt-domain OCR merging.
Do not use physical-device camera capture or actual photo-library access.
The native image primitives boundary remains unchanged.
The label change does not introduce layout, motion, or artwork requiring operator visual judgment.

## Acceptance and verification limits

- Native helper regressions cover a missing middle image, all failures, preserved order, empty input, successful input, and cap plus failure without processing overflow.
- Swift tests also cover camera inputs already limited before processing and iOS gallery skip accounting.
- Dart regressions preserve omitted counts, cancellation behavior, and one-survivor OCR incompleteness.
- Flutter workspace tests, Dart analysis, scoped formatting/lint, and independent local review must pass.
- Attempt available native builds/tests and state precisely which integration checks do not run.

The original task permits recording native verification that is unavailable.
The production Swift helper runs directly in macOS XCTest and the Kotlin helper in JVM JUnit; these are not acquisition or image-pipeline integration tests.
Existing iOS async-protocol/completion-handler and deployment-target mismatches block the example build/RunnerTests.
The offline Android cache lacks the pinned AGP 9.0.1.
These unrelated baseline blockers remain explicit PR limitations rather than expanding this issue into a native API/toolchain migration.

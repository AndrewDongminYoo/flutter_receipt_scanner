# Native page omission implementation and verification

Contract: [native page omission diagnostics](../specs/2026-10-10-native-page-omissions.md).

## Implementation steps

1. Verify issue #4, current main, existing PRs, account ownership, repository instructions, and both actual Flutter native acquisition implementations.
2. Extract small Swift/Kotlin batch seams and reproduce the omitted-middle-page count failure before implementing the count.
3. Compute omissions from the original count and successful image count; cap before processing; retain existing empty-batch status/error policies and image order.
4. Update the Pigeon field description and regenerate its outputs without changing wire code; update the public model and example label.
5. Add native helper, one-survivor OCR, cancellation-count, and example diagnostic regressions.
6. Run the project checks, inspect callers and sibling paths, perform mutation checks and independent review, and fix verified findings.
7. Commit by concern, push the scoped branch, open the PR, and inspect current-head CI and hosted review within the recorded loop budget.
8. Leave merge to the operator and preserve unavailable native integration checks in the PR and final report.

## Owned paths

- iOS `ReceiptScannerApiImpl.swift`, `GalleryPickerDelegate.swift`, `PageBatch.swift`, and the standalone batch XCTest package.
- Android `FlutterReceiptScannerPlugin.kt`, `PageBatch.kt`, and `PageBatchTest.kt`.
- Root Pigeon schema descriptions and generated Dart/Swift/Kotlin descriptions.
- `ScanReceiptResult` documentation, app-facing scan tests, README guidance, and example diagnostic copy/tests.
- This plan and the linked contract; Git-local loop state is not committed.

## Evidence and completion checks

- Regression mutation: omit failure accounting while keeping tests; the middle-failure count must fail as zero instead of one, then pass after restoration.
- Flutter: `dart run melos run test` and `flutter analyze --no-pub`.
- Swift helper: `swift test --package-path flutter_receipt_scanner_ios/ios`.
- Kotlin helper: run `PageBatchTest` with the native Gradle target when available; report any standalone cached-compiler/JUnit fallback separately.
- Native integration attempts: unsigned iOS example build/RunnerTests and Android native Gradle test, without physical-device or real-photo access.
- Formatting: scoped `dart format` and `trunk check`; generated code must differ only in its regenerated descriptions.
- Review: independent read-only review of the contract and complete candidate, with findings verified and repaired before publication.
- Publication: fixed personal account, clean candidate, exact pushed SHA, paginated hosted review evidence, and current-head CI.

Completed implementation and mutation evidence belongs to the preceding scoped fix commit.
The PR loop reuses those results and refreshes applicable checks after its documentation commit.
Native integration limitations are governed by the contract rather than claimed as passing tests.

---
type: Work Item
title: Contract and Capabilities
parent: ../spec.md
---

## What to build

Land the full transport and Dart contract for multilingual OCR, plus the capability query on both platforms, without yet changing how native scanning consumes the language list.

Add to the root `pigeons/messages.dart`: a trailing optional `ocrLanguages` list on `ScanOptionsWire`, and — declared after every existing class so shipped codec byte assignments stay stable — `OcrCapabilitiesWire`, `OcrModelStateWire`, a model-status wire enum, and an `@async getOcrCapabilities()` host method.
Regenerate with `melos run generate`.

Add `ScanReceiptOptions.ocrLanguages` (non-nullable, const default `['ko-KR', 'en-US']`), app-facing normalization (trim, drop exact duplicates preserving first occurrence) with `ArgumentError` before the platform call for an empty list or a tag empty after trimming, and always forward the resolved list on the wire.
Add the sealed `OcrCapabilities` model with `IosOcrCapabilities.supportedLanguages` and `AndroidOcrCapabilities.models`, `OcrModelState` (Unicode script id plus `ready` / `downloadRequired`), `FlutterReceiptScannerPlatform.getOcrCapabilities()` defaulting to `UnimplementedError`, and the top-level app-facing `getOcrCapabilities()`.

Implement the native capability query only: iOS reports the languages supported by the active Vision request revision at the `.accurate` recognition level; Android reports the five ML Kit script families using Google Play services module availability (`ModuleInstallClient.areModulesAvailable`) and must not trigger a download or open UI.
Add the dynamically delivered Play services recognizer dependencies for Latin, Japanese, Chinese, and Devanagari alongside the pinned bundled Korean artifact, pinning coordinates and versions from current ML Kit release documentation.

Scan behavior stays unchanged in this Work Item: natives keep their current recognizer selection until Work Item 02.

## Required context

- Wire-stability rule (append new Pigeon classes after existing ones or codec bytes shift) and the Android JVM test harness: project memory `rn-port-tracking`; the 0.4.0 `discardedPageCount` field is the precedent for a trailing optional wire field and its mixed-version posture.
- Platform packages `extend` `FlutterReceiptScannerPlatform` and hold wire↔model mapping in both directions; `ScanReceiptOptions` uses defaulted non-nullable fields.
- Upstream normative contract: `react-native-receipt-scanner/docs/specs/multilingual-ocr.md` (§Public API, §`getOcrCapabilities()`).
- Never hand-edit `messages.g.dart`, `Messages.g.swift`, or `Messages.g.kt`.

## Acceptance criteria

- [x] The Pigeon schema adds `ScanOptionsWire.ocrLanguages` as a trailing field and declares all new wire types and the `getOcrCapabilities()` host method after existing classes; every generated file is regenerated, not hand-edited.
- [x] `ScanReceiptOptions.ocrLanguages` defaults to `['ko-KR', 'en-US']` and the resolved list is always forwarded on the wire.
- [x] The app-facing `scan()` trims tags and removes exact duplicates preserving first occurrence, and throws `ArgumentError` before the platform call for an empty list or a tag empty after trimming.
- [x] The sealed `OcrCapabilities` model exposes `defaultLanguages` of `['ko-KR', 'en-US']`, iOS `supportedLanguages`, and Android `models` of `OcrModelState` with `ready` / `downloadRequired` status.
- [x] `FlutterReceiptScannerPlatform.getOcrCapabilities()` has a default `UnimplementedError` body, both platform packages override it, and the app-facing package exports a top-level `getOcrCapabilities()`.
- [x] iOS reports languages from the active Vision request revision at the `.accurate` level; Android reports the five script families via Play services module availability without triggering a download or opening UI.
- [x] Android adds only the dynamically delivered recognizer dependencies for Latin, Japanese, Chinese, and Devanagari, with pinned coordinates, alongside the bundled Korean artifact.
- [x] Default-language scans behave exactly as before this Work Item; no result field is renamed or removed.
- [x] Tests: platform-interface tests cover the options default and the sealed capability model; both platform routing tests cover `ocrLanguages` and capability wire↔model mapping in both directions; app-facing fake-platform tests cover normalization, `ArgumentError` pre-validation, explicit default forwarding, capability delegation, and acceptance of `mergeOcrPages` with a non-default language list.
- [x] `melos run format`, `melos run analyze`, `melos run test`, `trunk fmt`, and `trunk check` pass, plus `:flutter_receipt_scanner_android:compileDebugKotlin` and an iOS example build.

## Covers

- User Stories: 2, 3
- Requirements: Public API 1-9; Transport 1-4; Language Resolution 10 (dependency setup only); Versioning and Dependencies 2-3
- Testing Strategy: Dart seam TDD; example-free automated coverage
- Interview Ledger: L1, L2, L4

## Blocked by

None - ready to start

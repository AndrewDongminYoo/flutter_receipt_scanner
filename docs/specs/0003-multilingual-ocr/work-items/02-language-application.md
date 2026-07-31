---
type: Work Item
title: Language Application
parent: ../spec.md
---

## What to build

Make both natives consume the resolved language list, validating capability before any scanner or picker UI appears.

iOS: pass the resolved list to `OcrProcessor` instead of the hardcoded array, configuring every accurate and fast orientation-probe request with the same languages in caller priority order, with `automaticallyDetectsLanguage` disabled.
Canonicalize tags with the platform locale API, validate them against the languages supported by the active request revision at the `.accurate` level, and reject before UI presentation.
Preserve the existing `usesLanguageCorrection = false`, recognition level, minimum text height, rotation detection, confidence, and geometry behavior; the default list must produce the same request configuration as today.

Android: resolve each canonical tag to its likely Unicode script with `android.icu.util.ULocale.addLikelySubtags` and select exactly one recognizer per the Spec's script table.
Latin may accompany exactly one non-Latin script family; more than one non-Latin family rejects.
Before opening scan UI, construct the resolved recognizer, check its module with `ModuleInstallClient.areModulesAvailable`, continue when ready, trigger immediate installation when downloadable, wait for a terminal installed state, and unregister the install listener on success, failure, or cancellation.
Extend the existing scan-in-progress guard to cover model preparation so a concurrent call cannot start a second installation.
When `ocr == false`, perform no language validation, script resolution, or model work on either platform.

Surface the four failure conditions as `PlatformException` codes that reject before camera or gallery UI: `INVALID_OCR_LANGUAGE`, `OCR_LANGUAGE_NOT_SUPPORTED`, `OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED`, `OCR_MODEL_INSTALL_FAILED`.

## Required context

- The Spec's script-to-recognizer table is normative; `x-private`-style tags that canonicalize non-empty but resolve to no language are `OCR_LANGUAGE_NOT_SUPPORTED`, not `INVALID_OCR_LANGUAGE`.
- Language priority within one Android script model has no provider-level effect — order is retained for API parity only.
- Existing Kotlin JVM harness lives in `flutter_receipt_scanner_android/android/src/test/kotlin` (`:flutter_receipt_scanner_android:testDebugUnitTest`); iOS has no native test harness, so iOS-only behavior is covered by Dart tests plus physical QA in Work Item 03.
- Upstream normative contract: `react-native-receipt-scanner/docs/specs/multilingual-ocr.md` (§Language resolution, §Error contract); the implementation may split Android responsibilities into a resolver and model provider but must not introduce a generic OCR engine abstraction or provider plug-in system.
- Auto-rotation and OCR geometry must come from the same selected recognizer whose text is returned.

## Acceptance criteria

- [x] iOS applies the resolved list, in caller priority order, to every accurate and fast probe request with `automaticallyDetectsLanguage` disabled, and the default list produces the same request configuration as before.
- [x] iOS canonicalizes tags, validates them against the active revision at the `.accurate` level, and rejects unsupported tags before UI presentation.
- [x] Android resolves scripts with `ULocale.addLikelySubtags` per the Spec table and selects exactly one recognizer, permitting accompanying Latin.
- [x] Android rejects more than one non-Latin script family with `OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED`, and a valid tag resolving to no language with `OCR_LANGUAGE_NOT_SUPPORTED`.
- [x] Android never starts OCR before a required dynamic model is installed: availability check, immediate install, terminal-state wait, listener unregistered on success, failure, and cancellation, with `OCR_MODEL_INSTALL_FAILED` on failure or unknown module.
- [x] The scan-in-progress guard covers model preparation; a concurrent call cannot start a second installation.
- [x] `ocr == false` bypasses all language validation, script resolution, and model work on both platforms.
- [x] All four failure conditions reject before camera or gallery UI and are never converted into `ScanStatus.cancelled`, `ScanStatus.rejected`, an omitted `ocrText`, or an empty `ocrText`; post-capture recognition failures keep existing best-effort behavior.
- [x] Kotlin JVM tests cover the resolver: Korean plus Latin resolves to Korean, Japanese plus Latin to Japanese, Latin-only to Latin, two non-Latin families reject with the combination code, and a private-use tag rejects with the not-supported code.
- [x] Existing Korean and English behavior retains its baseline text, quality, rotation, and geometry.
- [x] `melos run format`, `melos run analyze`, `melos run test`, `trunk fmt`, `trunk check`, `:flutter_receipt_scanner_android:compileDebugKotlin`, `:flutter_receipt_scanner_android:testDebugUnitTest`, and an iOS example build pass.

## Covers

- User Stories: 1
- Requirements: Language Resolution 1-13; Errors 1-4
- Testing Strategy: Android JVM resolver tests; iOS coverage via Dart tests plus deferred physical QA
- Interview Ledger: L1

## Blocked by

- [01-contract-and-capabilities.md](01-contract-and-capabilities.md)

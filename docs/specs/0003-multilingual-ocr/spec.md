---
type: Spec
title: Multilingual OCR
---

## Problem

The OCR language boundary is hardcoded to Korean+Latin: iOS sets `recognitionLanguages = ["ko-KR", "en-US"]` (`flutter_receipt_scanner_ios/.../OcrProcessor.swift`), and Android pins the bundled `com.google.mlkit:text-recognition-korean` recognizer (`OcrProcessor.kt`, `build.gradle.kts`).
`ScanReceiptOptions` has no language field, so consumers cannot scan receipts in other languages, which limits production usability.

The operator already designed and shipped this expansion in the RN sibling: `react-native-receipt-scanner` v0.8.0 (2026-07-30) implements `docs/specs/multilingual-ocr.md`.
The Flutter package is a hand-port of RN, currently synced to v0.7.0 — exactly this release behind. [L1]

## Proposed Outcome

Port the RN multilingual-ocr contract faithfully, adapted to Pigeon/Dart and the federated package layout. [L1]
The expansion is additive: calls that rely on the default language list preserve the current Korean and English behavior exactly.
The package continues to return image primitives only — no receipt parsing, no country or language inference, no translation, no cloud OCR.

`mergeOcrPages` remains available with any valid language list; long-receipt calibration claims stay scoped to Korean+Latin. [L2]
The RN package's own long-receipt work is a sanctioned divergence and imposes no parity constraint here. [L3]

Ships as a coordinated 0.5.0 minor release of all four packages. [L4]

## User Stories

1. As an app developer, I can pass ordered BCP 47 language hints to `scan()` and receive raw OCR text for receipts in any language the active native provider supports, without importing provider-specific script enums. [L1]
2. As an app developer, I can query current OCR capability (`getOcrCapabilities()`) without triggering a model download or opening UI. [L1]
3. As an existing consumer, I upgrade without behavior change: omitting the option keeps the current Korean recognizer on Android and the `["ko-KR", "en-US"]` Vision configuration on iOS. [L1]
4. As a person scanning a long receipt in a non-default language, I can still enable `mergeOcrPages` and receive merged OCR with the usual diagnostics. [L2]
5. As a maintainer, I can distinguish provider support from measured accuracy in every public claim. [L2]

## Requirements

### Public API

1. `ScanReceiptOptions` gains `List<String> ocrLanguages` with const default `['ko-KR', 'en-US']`. [L4]
2. The first entry is the highest-priority hint; the option is effective only when `ocr == true`.
3. The app-facing `scan()` trims each tag, removes exact duplicates preserving first occurrence, and throws `ArgumentError` before the platform call when the list is empty or contains a tag that is empty after trimming. [L4]
4. The resolved list is always forwarded on the wire, so the native boundary stays deterministic. [L4]
5. The app-facing package exports a top-level `Future<OcrCapabilities> getOcrCapabilities()` delegating to `FlutterReceiptScannerPlatform.instance`. [L4]
6. The public capability model is a sealed `OcrCapabilities` (with `defaultLanguages` fixed at `['ko-KR', 'en-US']`) and two variants: [L4]
   - `IosOcrCapabilities.supportedLanguages` — exact identifiers from the active Vision request revision at the `.accurate` recognition level.
   - `AndroidOcrCapabilities.models` — a `List<OcrModelState>` covering the five ML Kit script families, where `OcrModelState` has a Unicode script identifier (`"Latn"`, `"Kore"`, `"Jpan"`, `"Hans"`, `"Hant"`, `"Deva"`) and a status of `ready` or `downloadRequired`.
7. The capability query must not request a model download or open UI, and reports capability regardless of any later `ocr` value.
8. `ScanReceiptResult`, `ReceiptImage`, `OcrQuality`, `OcrLine`, and `MergedOcrResult` are unchanged; no detected-language field is added.
9. The option does not change crop-editor strings, system scanner UI, the OCR floor, EXIF processing, or result filtering.

### Transport

1. `ScanOptionsWire` gains a trailing optional `ocrLanguages` list field; new wire types (`OcrCapabilitiesWire`, `OcrModelStateWire`, and a model-status wire enum) and the `@async` `getOcrCapabilities()` host method are declared after all existing classes so shipped codec byte assignments stay stable. [L4]
2. All changes are made only in the root `pigeons/messages.dart` and regenerated via `melos run generate`; generated Dart, Swift, and Kotlin files are never hand-edited.
3. Mixed-version wire payloads are not supported; compatibility relies on the coordinated 0.5.0 version constraints (same posture as the 0.4.0 `discardedPageCount` field).
4. `FlutterReceiptScannerPlatform` gains `getOcrCapabilities()` with a default `UnimplementedError` body; both platform packages override it and hold the wire↔model mapping. [L4]

### Language Resolution

1. Before presenting scanner or picker UI, native code canonicalizes every tag with the platform locale API; a tag is invalid when it is empty after trimming or the locale API cannot produce a language identifier.
2. Duplicate canonical tags are removed preserving order; at least one canonical tag is required when OCR is enabled.
3. iOS configures every accurate and fast orientation-probe request with the same resolved language list, in caller priority order, with `automaticallyDetectsLanguage` disabled and the existing `usesLanguageCorrection = false`, recognition level, minimum text height, rotation detection, confidence, and geometry behavior preserved.
4. iOS validates requested tags against the languages supported by the active request revision at the `.accurate` level and rejects unsupported tags before UI presentation.
5. The default `['ko-KR', 'en-US']` must produce the same iOS request configuration as the current implementation.
6. Android resolves each canonical tag to its likely Unicode script with `android.icu.util.ULocale.addLikelySubtags` and maps scripts to recognizers:

   | Unicode script         | ML Kit recognizer |
   | ---------------------- | ----------------- |
   | `Latn`                 | Latin             |
   | `Kore`                 | Korean            |
   | `Jpan`, `Hira`, `Kana` | Japanese          |
   | `Hans`, `Hant`, `Hani` | Chinese           |
   | `Deva`                 | Devanagari        |

7. Latin may accompany exactly one non-Latin script family (each non-Latin recognizer covers mixed-in Latin characters); more than one non-Latin family rejects with `OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED`.
8. A syntactically valid tag that resolves to no language (e.g. `x-private`) rejects with `OCR_LANGUAGE_NOT_SUPPORTED`, not `INVALID_OCR_LANGUAGE`.
9. Language priority within one Android script model has no provider-level effect; the order is retained for API parity.
10. The Korean recognizer stays bundled and serves the default list; Latin, Japanese, Chinese, and Devanagari use Google Play services dynamically delivered recognizers (approximately 260 KB versus approximately 4 MB per script architecture bundled).
11. Before opening scan UI Android must: construct the resolved recognizer, check its module with `ModuleInstallClient.areModulesAvailable`, continue when ready, trigger immediate installation when downloadable, wait for a terminal installed state, unregister the install listener on success/failure/cancellation, and reject with `OCR_MODEL_INSTALL_FAILED` on installation failure or an unknown module.
12. The existing scan-in-progress guard covers model preparation as well as scanner UI and processing; a concurrent call must not start another installation.
13. When `ocr == false`, no language validation, script resolution, or model work happens on either platform.

### Errors

1. Native rejections surface as `PlatformException` codes, before camera or gallery UI appears: [L4]

   | Code                                     | Condition                                                                          |
   | ---------------------------------------- | ---------------------------------------------------------------------------------- |
   | `INVALID_OCR_LANGUAGE`                   | A tag fails native canonicalization.                                               |
   | `OCR_LANGUAGE_NOT_SUPPORTED`             | The active iOS Vision request or Android script resolver cannot serve a valid tag. |
   | `OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED` | Android received more than one non-Latin script family.                            |
   | `OCR_MODEL_INSTALL_FAILED`               | A required Android Play services OCR module could not be installed or was unknown. |

2. Dart-side pre-validation failures (empty list, empty tag) throw `ArgumentError` before the platform call. [L4]
3. These failures must never be converted into `ScanStatus.cancelled`, `ScanStatus.rejected`, an omitted `ocrText`, or an empty `ocrText`.
4. Post-capture recognition failures keep the existing best-effort behavior; this Spec changes model-selection failure semantics only.

### Merge Interplay

1. `mergeOcrPages: true` is accepted with any valid `ocrLanguages`; existing merge validation (`ocr`, camera source, `maxPages >= 2`) is unchanged. [L2]
2. Seam matching, thresholds, boundary and rejected-page diagnostics, and the `discardedPageCount` completeness override operate unchanged on whatever text the selected recognizer returns.
3. Documentation labels the 11.0 aspect-ratio support claim and the seam similarity thresholds as validated for Korean+Latin only; other scripts are "provider-supported, uncalibrated". [L2]
4. Release notes must not claim improved OCR or merge accuracy for uncalibrated languages.
5. Long-receipt merge design carries no RN-parity obligation in either direction. [L3]

### Example App

1. The options form gains an editable OCR language list control (comma-separated BCP 47 input seeded with the default) that is disabled when `ocr` is off.
2. A capabilities action invokes `getOcrCapabilities()` and renders the platform variant (supported languages on iOS; per-script model states on Android) without triggering downloads.
3. Configuration errors from the new codes surface in the existing error display path with their `PlatformException` code visible.

### Versioning and Dependencies

1. All four packages bump to 0.5.0 with changelog entries; publish follows RELEASING.md dependency order. [L4]
2. Android adds only the dynamically delivered non-default recognizer dependencies (Play services ML Kit text-recognition artifacts for Latin, Japanese, Chinese, Devanagari) alongside the pinned bundled Korean artifact; exact artifact coordinates and versions are pinned at implementation from the current ML Kit release notes.
3. After any manifest edit, the workspace lockfile is regenerated in the same commit.

## Technical Decisions

- Faithful port of the RN v0.8.0 contract; deviations are limited to Pigeon transport, Dart idiom, and federation structure. [L1]
- The Dart default lives on `ScanReceiptOptions` as a non-nullable defaulted field rather than RN's optional-plus-wrapper-forward; the observable native boundary is identical. [L4]
- No web capability variant — the plugin has no web endorsement. [L4]
- No generic OCR engine abstraction or provider plug-in system in this phase (explicitly rejected upstream).
- Android script resolution may split into an independently testable resolver and model provider, mirroring RN's `OcrModelManager` split, if it aids the existing JVM test harness.

## Testing Strategy

- TDD at the Dart seams: app-package fake-platform tests drive normalization (trim/dedupe/priority), `ArgumentError` pre-validation, explicit default forwarding, `ocr: false` bypass, capability delegation, and merge-interplay acceptance; platform-interface tests cover the sealed capability model and options default; platform-package routing tests cover wire↔model mapping of `ocrLanguages` and capabilities in both directions.
- Android JVM unit tests (existing `src/test/kotlin` harness) cover the script-resolution table: ko+Latn→Korean, ja+Latn→Japanese, Latin-only→Latin, two non-Latin families→`OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED`, private-use tag→`OCR_LANGUAGE_NOT_SUPPORTED`.
- iOS has no native test harness; iOS-only behavior is covered by Dart-side tests plus physical QA.
- Example widget tests cover the language control (default seed, disabled without `ocr`) and rendering of a canned capabilities result; no live platform calls in automated tests.
- Physical QA (iOS device available now): default Korean+English regression scan, one supported non-default language scan, and one syntactically-valid-unsupported rejection before UI. Android physical QA (dynamic model download, offline `OCR_MODEL_INSTALL_FAILED`, install-wait flow) is deferred until an Android device is available and recorded in the acceptance record when run.
- The initial release may ship without foreign-language receipt fixtures: Korean/English fixtures are the regression evidence; unit tests are the deterministic evidence; uncalibrated scripts are labeled as such.
- Repository verification: `melos run format`, `melos run analyze`, `melos run test`, `trunk fmt`, `trunk check`; Android Kotlin compiles via `:flutter_receipt_scanner_android:compileDebugKotlin` plus `:flutter_receipt_scanner_android:testDebugUnitTest`; iOS compiles via the example release build. One heavy mobile job at a time.

## Out of Scope

1. Merchant/total/tax/currency/date/line-item extraction; country, locale, or language inference; translation or transliteration.
2. Cloud OCR, upload, retry, or server validation.
3. Multi-model OCR and cross-model result merging; automatic script detection before recognizer selection.
4. Per-language OCR floors or calibration defaults; foreign-language fixture corpora (follow-up).
5. Crop-editor or scanner-UI localization driven by OCR language hints.
6. Pluggable OCR providers or a generic engine abstraction.
7. Package or public type renaming; web platform support claims.
8. Syncing long-receipt merge design with RN in either direction. [L3]

## Status

Implemented and published as 0.5.0 on 2026-08-02 (PR #5, merged as `fff9b76`).
Work Items 01-03 are complete; iOS device confirmation is recorded in the [acceptance record](../../notes/2026-07-30-physical-acceptance-record.md).
Android hardware QA remains outstanding — see Open Questions.

## Open Questions

1. ~~Exact Play services dynamic recognizer artifact coordinates and versions~~ — resolved at implementation: `play-services-mlkit-text-recognition:19.0.1` plus the `-chinese` / `-devanagari` / `-japanese` variants at `16.0.1`, alongside the bundled `com.google.mlkit:text-recognition-korean:16.0.1`.
2. Which Android physical device will run the deferred dynamic-download QA (same blocker as Spec 0001/0002 Android acceptance). Until then the install-wait flow and the offline `OCR_MODEL_INSTALL_FAILED` path are unverified on hardware.

## Follow-Ups

1. Decompose into Work Items (`act-create-issues-flutter`).
2. Foreign-language fixture corpus and per-script calibration, organized by script and source, with no unredacted personal or payment data.
3. Extend `compute_cer.dart` per-script filters when calibration fixtures for new scripts land.

## Notes

- Normative upstream contract: `/Volumes/dongminyu/Development/01_personal/react-native-receipt-scanner/docs/specs/multilingual-ocr.md` (Implemented; RN 0.8.0, PR #16).
- Current hardcoded sites: `flutter_receipt_scanner_ios/.../OcrProcessor.swift` (`recognitionLanguages = ["ko-KR", "en-US"]`, `usesLanguageCorrection = false`), `flutter_receipt_scanner_android/.../OcrProcessor.kt` (`KoreanTextRecognizerOptions`), `flutter_receipt_scanner_android/android/build.gradle.kts` (`text-recognition-korean:16.0.1`).
- Wire-stability rule and JVM test harness: project memory `rn-port-tracking`.
- External references: [ML Kit Text Recognition v2](https://developers.google.com/ml-kit/vision/text-recognition/v2), [supported languages](https://developers.google.com/ml-kit/vision/text-recognition/v2/languages), [ModuleInstallClient](https://developers.google.com/android/reference/com/google/android/gms/common/moduleinstall/ModuleInstallClient), [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest).

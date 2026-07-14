# Spec-vs-Code Gap Closure — Design & Plan

Date: 2026-07-14.
Author: Dongmin Yu (personal / AndrewDongminYoo).
Scope: close the deltas found by the 2026-07-14 spec-vs-code audit against
`docs/specs/2026-07-11-native-port-map.md`, approved for full scope (all 8 items).

## Discipline (from oracle precedent)

- The four intentional cross-platform asymmetries (rotation CW/CCW, OCR
  rotation-invariance, EXIF-output, confidence wiring) are NOT gaps — do not
  "unify" them.
- Native (Swift/Kotlin) deltas stay **QA-pending** until on-device verification;
  `flutter analyze` / `flutter test` do not clear them.
- Dart/test deltas are fully verifiable now via `melos run test` / `analyze`.

## Items

Ordered for implementation: fully-verifiable Dart first, native next, the
structural refactor last (so a codegen problem cannot block the rest).

### Group A — Dart / config (verifiable now)

**DART-1 [major] Platform routing tests.**
The `@visibleForTesting ReceiptScannerApi? api` injection seam on both
`FlutterReceiptScannerIos` / `FlutterReceiptScannerAndroid` is unused; wire↔model
conversion (`_optionsToWire`, `_resultFromWire`, `_ocrQualityFromWire`,
`_gpsFromWire`) is untested.
Fix: add `test/routing_test.dart` in each platform package injecting a fake
`ReceiptScannerApi`, asserting options→wire mapping and a representative
result→model round-trip (incl. `OcrQuality` null textLength/lineCount, null-GPS).
Verify: `melos run test`.

**DART-2 [minor] Split the gate-bypass test.**
`ocr_floor_gate_test.dart:23` sets `ocr:false` AND `disabled()` together, so
neither disjunct arm of `if (!ocr || floor.isDisabled)` is isolated.
Fix: replace with two cases — `ocr:false` + active floor, and `ocr:true` +
`disabled()` — each asserting bypass. Verify: `melos run test`.

**DART-3 [minor] Android `targetSdk 36`.**
`build.gradle.kts` sets `compileSdk 36` / `minSdk 24` but no `targetSdk`.
Fix: add `targetSdk = 36` to `defaultConfig`. Verify: `melos run analyze`
(functional impact nil for a library module; closing an explicit spec line).

### Group B — Native (QA-pending)

**iOS-1 [major] Camera `NO_ACTIVITY` guard.**
`ReceiptScannerApiImpl.swift` camera path presents via
`topViewController()?.present(...)`; if nil, `present` is a silent no-op,
`completion` is never called or cleared → Dart `scan()` hangs and every later
call returns `scan_in_progress` permanently. The gallery path already guards this.
Fix: mirror the gallery guard — if no presenting VC, fail the completion with
the `NO_ACTIVITY` error and clear `completion` before returning.

**iOS-2 [minor] OCR final-pass fallback text.**
`OcrProcessor.swift:71` falls back to 0° `pass0.text` when the final `.accurate`
pass returns nil; the winning probe's text was discarded (probe loop keeps only
count/degrees), so on that edge `ocrText` is 0°-oriented while `rotationDegrees != 0`.
Fix: retain the winning probe's recognized text during the probe loop and fall
back to it (per §6.1 step 7) instead of `pass0.text`.

**AND-1 [minor] Friendly scanner-init message.**
`FlutterReceiptScannerPlugin.kt:124` forwards the raw GMS exception message.
Fix: special-case `GmsNetworkStack` / `AuthPII` substrings into
Play-Services-update guidance text (per §1.2 step 3), keeping the
`SCANNER_INIT_FAILED` code.

**iOS-3 [cosmetic] Error-code parity.**
Adopt the RN uppercase code set on BOTH platforms for consistency:
`SCAN_IN_PROGRESS`, `NO_ACTIVITY`, `NOT_SUPPORTED`, `SCANNER_INIT_FAILED`,
`PROCESSING_FAILED`, `CAMERA_FAILED`, `OUT_OF_MEMORY` (+ uppercase any
platform-specific extras like `GALLERY_LAUNCH_FAILED`). No Dart consumer keys on
codes today, so this is non-breaking; it aligns iOS's `unavailable`/`scan_failed`
and both platforms' lowercase strings to the spec.

### Group C — Refactor (last)

**DART-4 [refactor] Consolidate the Pigeon schema to a single source.**
Today `_ios/pigeons/messages.dart` and `_android/pigeons/messages.dart` are
byte-identical except output config, and each emits its own
`lib/src/messages.g.dart`; they can silently diverge.
Approach: one schema (repo root `pigeons/messages.dart`) whose `@ConfigurePigeon`
emits `dartOut` → `flutter_receipt_scanner_platform_interface/lib/src/messages.g.dart`,
`swiftOut` → the iOS package, `kotlinOut` → the Android package. platform_interface
re-exports the generated `ReceiptScannerApi` + wire types; the iOS/Android Dart
registrants import them from platform_interface instead of their own `src/`.
Delete the two per-package schemas and their generated Dart. Update
`melos run generate` to a single root pigeon run.
Verify: `melos run generate` regenerates clean, `melos run analyze` + `melos run test`
green. This is the largest diff and touches codegen + imports in three packages —
it is intentionally last and can be dropped without affecting Groups A/B.

## Verification summary

- Group A + the Dart side of C: `melos run analyze` and `melos run test` must be green.
- Group B + native side of C: compile clean; behavior is **QA-pending** on device/simulator.
- Commit per concern (conventional + gitmoji), Dart/native/refactor grouped.

## Non-goals

Not touching the four intentional asymmetries, the §7.2 origin classification
(spec-internal tension, documented in code), or the behavior-neutral camera EXIF
white-list. No new dependencies.

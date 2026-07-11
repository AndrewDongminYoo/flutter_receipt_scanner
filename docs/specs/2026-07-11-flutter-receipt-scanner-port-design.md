# flutter_receipt_scanner — Design Spec

Status: approved for skeleton milestone (2026-07-11).
Author: Dongmin Yu (personal / AndrewDongminYoo).

## 1. Goal

Reconstruct the existing `react-native-receipt-scanner` package as a federated Flutter plugin named `flutter_receipt_scanner`, exposing on-device receipt image acquisition, crop, orientation normalization, JPEG compression, EXIF extraction, and OCR (raw string) to Flutter apps on iOS and Android.

This is a **clean-room re-derivation**, not a port.
No native `.m`/`.mm`/`.kt` implementation source is copied or adapted.
The only references used are the public API contract (`src/types.ts`), the design rationale (the RN repo's ADR docs, which describe mechanism), and public framework documentation (VisionKit, Vision, ML Kit).

## 2. Non-goals (scope boundary — inherits ADR-003)

The plugin owns **image primitive operations only**.
Out of scope, and to be rejected in review:

- Receipt domain parsing (store name, amount, date).
- Upload transport, cloud OCR (e.g. Azure), duplicate detection.
- Any network or vendor SDK beyond the on-device scanner/OCR frameworks.

The reject-on-sight test (three questions, from ADR-003): does a change read/write outside JPEG bytes + EXIF + OCR string? add a network/vendor SDK? expose a public field needing domain interpretation? Any "yes" → reject.

## 3. Key decisions (collected 2026-07-11)

| Decision        | Choice                      | Note                                                                                                                                                                                                                                      |
| --------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Native sourcing | Clean-room re-derivation    | No copy/port; conforms to the operator's recorded IP discipline (`ip-hygiene-expression-vs-mechanic`, `employer-ip-moonlighting-risk`). The conservative path is safe regardless of the still-open "employment terms reviewed?" question. |
| Transport       | Pigeon codegen              | Type-safe message classes generated for Dart/Swift/Kotlin. New precedent (prior federated plugin used MethodChannel+EventChannel).                                                                                                        |
| First milestone | iOS camera walking skeleton | Thinnest end-to-end slice through every layer.                                                                                                                                                                                            |

## 4. Package layout (federated — follows `ble_proximity_signal` precedent)

```log
flutter_receipt_scanner/                              ← repo root (pub workspace + melos workspace)
├─ pubspec.yaml                                       (workspace + melos declaration)
├─ melos.yaml
├─ pigeons/messages.dart                              ← Pigeon schema (single source of truth)
├─ packages/
│  ├─ flutter_receipt_scanner/                        ← app-facing: scan() + OCR-floor gate (Dart)
│  │  └─ example/                                     ← example app
│  ├─ flutter_receipt_scanner_platform_interface/     ← abstract interface (extend, not implement)
│  ├─ flutter_receipt_scanner_android/                ← Kotlin handler (skeleton: unimplemented)
│  └─ flutter_receipt_scanner_ios/                    ← Swift handler (skeleton: camera path)
└─ docs/
```

Conventions carried forward from the prior federated plugin:

- **Extend, never implement.** The platform interface is an abstract class that platform packages _extend_, calling `registerWith()` to set the static `instance`.
  Extending preserves source-compatibility when the interface adds methods with default implementations.
- **Four-touchpoint update obligation.** Adding one interface method requires updates in: the default impl in the platform-interface package, the Android Dart class, the iOS Dart class, and the native handler.
  Pigeon removes the channel-name byte-sync failure mode by generating the wire contract.
- **Package-prefixed public symbols** to keep the federated boundary visible at the call site.
- **Independent versioning** per package (start at `0.1.0`).

## 5. Transport — Pigeon schema

`pigeons/messages.dart` re-expresses `src/types.ts` faithfully as Pigeon data classes plus one HostApi.

Enums (Pigeon `enum`): `ScanSource { camera, gallery }`, `ImageOrigin { camera, screenshot, download, unknown }`, `ScanStatus { success, cancelled, rejected }`.

Data classes: `OcrFloor`, `ScanOptions`, `ReceiptExif` (white-list fields + optional `gps` + optional `raw`), `OcrQuality`, `ReceiptImage`, `ScanResult`.

Host API:

```dart
@HostApi()
abstract class ReceiptScannerApi {
  @async
  ScanResult scan(ScanOptions options);
}
```

Field parity with `types.ts` is the contract.
`ScanOptions` defaults live in Dart (`DEFAULT_SCAN_OPTIONS` re-derived), applied before the Pigeon call.

## 6. Boundary decision — OCR-floor gate lives in Dart

The OCR-floor acceptance gate and `OcrQuality` derivation run in the **app-facing Dart package**, not in native code — mirroring how `scan.native.tsx` does the partitioning on the JS side in the RN package.
Native returns image primitives (JPEG + EXIF + raw OCR text + per-image confidence); Dart derives `textLength`/`lineCount`, applies the floor, and partitions `images` vs `rejectedImages`.

This keeps native strictly at image primitives and puts the testable, platform-independent logic in Dart.

Re-derived rules (from `scan.native.tsx`):

- Floor applies only when `ocr == true` and `ocrFloor != false`.
- Absent confidence is treated as satisfied (never gate on a field that was not produced).
- `status: rejected` when every image falls below the floor and at least one was captured; otherwise `success` with `rejectedImages` carrying the offending captures.

## 7. Walking skeleton scope (first milestone)

**iOS `source: "camera"` only, end-to-end:**

VisionKit document scanner → write JPEG to cache dir → Vision OCR (`ko-KR`, `en-US`) → return Pigeon `ScanResult` → Dart applies the OCR-floor gate → `scan()` result.

Rationale for iOS camera as the skeleton path: VisionKit's `VNDocumentCameraViewController` needs no custom crop UI, so it exercises every layer (federation, Pigeon marshalling, native framework call, Dart post-processing) with the least surface area.

Deferred to later milestones (skeleton returns `PlatformException` / `unimplemented`):

- Android (all paths).
- iOS `source: "gallery"` + custom crop editor.
- `autoRotate` pixel rotation, `cropAutoConfirm`, `includeRawExif`, GPS EXIF.

## 8. Testing

- **app-facing package:** unit tests for the OCR-floor gate and `OcrQuality` derivation — the highest-value re-derived logic. Cover: OCR off (no gate), `ocrFloor: false`, all-rejected → `rejected`, partial-pass → `success` with populated `rejectedImages`, absent-confidence-satisfied.
- **platform_interface:** routing test against the Pigeon-generated mock host API.
- **Lint/format:** `very_good_analysis`, `dart format --line-length 120`, 2-space indent.
  Dart is owned by melos + `flutter`; Kotlin/Swift/YAML/Markdown by trunk (Dart disabled in trunk, per precedent).

## 9. Clean-room discipline (IP gate)

Native Swift/Kotlin handlers are written from scratch using standard framework calls.
Referenced material is limited to: (a) the public API contract `src/types.ts`, (b) ADR docs describing mechanism, (c) public framework documentation.
No copy-paste of native implementation expression, string tables, or schema from the RN repo.

## 10. Verification (skeleton milestone)

1. `dart run pigeon --input pigeons/messages.dart` regenerates without error → verify: generated files compile.
2. `melos bootstrap` resolves all four packages → verify: `melos list` shows four packages.
3. `flutter analyze` clean across packages → verify: zero issues.
4. `flutter test` in app-facing package → verify: OCR-floor gate tests pass.
5. Example app builds and runs the iOS camera path on a simulator/device → verify: a scanned page returns a `ScanResult` with a valid `file://` JPEG uri and OCR text.

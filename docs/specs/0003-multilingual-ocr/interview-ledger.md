---
type: Interview Ledger
title: Multilingual OCR Decisions
parent: spec.md
---

## Records

### L1

Status: current

Question: How should the fixed Korean+Latin ML dependency boundary expand to multilingual recognition?

Recommended Answer:

- Port the react-native-receipt-scanner v0.8.0 `multilingual-ocr.md` contract faithfully, adapted to Pigeon/Dart: ordered BCP 47 `ocrLanguages` hints defaulting to `["ko-KR", "en-US"]`, a read-only `getOcrCapabilities()` query, and Android one-script resolution with the Korean recognizer bundled and Latin/Japanese/Chinese/Devanagari delivered dynamically through Google Play services.
- Do not redesign as a script enum; a script-parity contract was proposed first and withdrawn once the shipped RN precedent surfaced.

Answer: 좋습니다. 진행해주세요.

Decision: The Flutter contract is a faithful port of `react-native-receipt-scanner/docs/specs/multilingual-ocr.md` (Implemented, shipped in RN 0.8.0 on 2026-07-30, PR #16); only Pigeon/Dart/federation adaptations may differ.

Reason: The Flutter native layer is a hand-port of RN (project memory `rn-port-tracking`); re-deriving a contract the operator shipped one day earlier would diverge from reviewed precedent and raise port-tracking cost.

Source: Oracle precedent lookup 2026-07-31; `react-native-receipt-scanner/docs/specs/multilingual-ocr.md`.

### L2

Status: current

Question: How do `mergeOcrPages` (Flutter-only long-receipt merge) and `ocrLanguages` interact?

Recommended Answer:

- Allow `mergeOcrPages: true` with any valid `ocrLanguages` — the merger (trimmed-line normalization + Levenshtein seam matching) is script-agnostic.
- Label the 11.0 aspect-ratio support claim and the seam similarity thresholds (0.85 / 0.92) as validated for Korean+Latin only; other scripts are "provider-supported, uncalibrated" per the RN accuracy-claims wording.

Answer: 추천안 (전 언어 허용 + 보정 범위 명시)으로 진행해주세요.

Decision: No language restriction on merging; calibration scope is documented, not enforced.

Negative Requirements:

- Do not reject `mergeOcrPages` + non-default `ocrLanguages` combinations.
- Do not claim merge accuracy or the 11.0 ratio for scripts without a representative fixture corpus and recorded measurements.

### L3

Status: current

Question: Does the RN package's own long-receipt work constrain this Spec?

Answer: RN is implementing long-receipt stitching with a deliberately different design from Flutter's `ocr_page_merger`; the RN side argued its case and the operator approved the divergence (2026-07-31).

Decision: Long-receipt merge designs are a sanctioned divergence point — neither direction syncs merge design without explicit operator direction. The multilingual×merge interplay contract (L2) is therefore Flutter-specific and carries no RN-parity obligation.

Source: Operator statement 2026-07-31.

### L4

Status: current

Question: Which Flutter/federation adaptations apply to the ported contract?

Answer: Resolved from repository conventions without further interview.

Decision:

- Pigeon wire: `ScanOptionsWire` gains a trailing `ocrLanguages` field; new wire types (`OcrCapabilitiesWire`, `OcrModelStateWire`, status enum) and the new `@async getOcrCapabilities()` host method are declared after existing classes to keep codec byte assignments stable (`rn-port-tracking` wire-class rule).
- No web capability variant — this plugin has no web endorsement.
- Error mapping: the four RN error codes surface as native `PlatformException` codes rejecting before scanner/picker UI; Dart-side pre-validation (empty list, empty tag after trimming) throws `ArgumentError` in the app-facing `scan()` before the platform call, mirroring the existing `mergeOcrPages` validation precedent.
- `ScanReceiptOptions.ocrLanguages` is non-nullable with const default `['ko-KR', 'en-US']`, matching the options class's defaulted-field style; the wire always carries the resolved list so the native boundary stays deterministic.
- `getOcrCapabilities()` is a new platform-interface method with a default `UnimplementedError` body (extend-not-implement safety) and a top-level app-facing function like `scan()`; the public result is a sealed `OcrCapabilities` with `IosOcrCapabilities` and `AndroidOcrCapabilities` variants.
- Coordinated 0.5.0 minor release of all four packages (0.4.0 is published and immutable).

Source: Repository conventions (spec 0001/0002, platform interface source, `rn-port-tracking` memory).

# Physical Device Acceptance Record — Long Receipt OCR Merge

Work Item: [05-physical-device-acceptance.md](../specs/0001-long-receipt-ocr-merge/work-items/05-physical-device-acceptance.md)

Printed target: `flutter_receipt_scanner/test/fixtures/long_receipt/logical_receipt.png` (1,200 × 13,200 px, content ratio 11.0), printed at 57.0 mm width × 627 mm length.
A 627 mm print at ratio 11.0 covers the documented 600 mm / ≥ 57.0 mm claim.

CER measurement: paste the example app's merged OCR text into a file and run, from `flutter_receipt_scanner/`:

```bash
dart run tool/receipt_benchmark/compute_cer.dart <merged_text_file>
```

## Devices

| Field              | Android   | iOS                             |
| ------------------ | --------- | ------------------------------- |
| Model              | [UNKNOWN] | iPhone 16 Pro                   |
| OS version         | [UNKNOWN] | iOS 26.5.2 (23F84)              |
| Scanner dependency | [UNKNOWN] | VisionKit + Vision (OS-bundled) |
| Run date           | [UNKNOWN] | 2026-07-30                      |

## Acceptance gates

| Gate                                                               | Android   | iOS    |
| ------------------------------------------------------------------ | --------- | ------ |
| Six camera pages captured with ~20% overlap                        | [UNKNOWN] | pass¹  |
| Capture order equals returned page URI order                       | [UNKNOWN] | pass   |
| Every JPEG readable, ≥ 1,200 px across cropped receipt width       | [UNKNOWN] | pass²  |
| `mergedOcr.isComplete == true`, no unmatched boundaries or rejects | [UNKNOWN] | pass   |
| Aggregate CER ≤ 0.20                                               | [UNKNOWN] | 0.0068 |
| Hangul CER ≤ 0.25                                                  | [UNKNOWN] | 0.0102 |
| Latin CER ≤ 0.25                                                   | [UNKNOWN] | 0.0120 |
| No missing non-overlap text, no duplicated accepted seam text      | [UNKNOWN] | pass³  |
| OCR + merge within 30 s after native UI return                     | [UNKNOWN] | pass²  |
| No crash or out-of-memory termination                              | [UNKNOWN] | pass   |

¹ Manual-shutter capture with sectioned ~20% overlap; the exact page count of the accepted run was confirmed on-device but not transcribed into this record. [PARTIAL]
² Read from the example app on-device by the operator and confirmed within the gate; numeric values not transcribed. [PARTIAL]
³ Verified against the canonical fixture text: 75/75 non-empty lines present in order, zero duplicated lines, all 54 item lines exactly once.

## iOS run log

Target was home-printed. Example app built with `flutter build ios --release` and installed via `flutter install`.

- **Run 1 (rejected)** — auto shutter, `maxPages: 6`, one more capture than `maxPages`. CER passed (aggregate 0.0380, Hangul 0.0780, Latin 0.0422) but the final three receipt lines were missing from the merged text while the merge itself reported no unmatched boundaries: the iOS implementation silently truncates scanner pages beyond `maxPages` (`ReceiptScannerApiImpl.swift`, `pageCount = min(scan.pageCount, maxPages)`), because VisionKit's UI cannot enforce a page limit. Confirmed by operator reproduction. GMS on Android enforces the limit in-UI, so the failure mode is iOS-only.
- **Run 2 (accepted)** — manual shutter (VisionKit's built-in Auto/Manual toggle), `maxPages: 10`. All gates above pass; merged text covers the full receipt through the final line.
- **Run 3 (truncation diagnostic, 2026-07-31)** — 0.4.0 build implementing Spec `0002-capture-ergonomics` Work Item 01. Three pages captured with `maxPages: 2`; the result card surfaced `폐기된 페이지: 1장 (maxPages 초과로 미처리)` and the merge reported incomplete. Operator-confirmed on-device, closing the silent-truncation gap demonstrated by Run 1.

Findings for follow-up:

1. iOS silently drops pages beyond `maxPages` — a long-receipt footgun. Candidate 0.4.0 work: surface a truncation diagnostic (or at minimum document it); until then, set `maxPages` to the ceiling (10) when merging.
2. Auto shutter fires before framing, causing gap/tail risk. iOS exposes no programmatic control (VisionKit UI toggle only). Android's `GmsDocumentScannerOptions` defines `CAPTURE_MODE_AUTO`/`CAPTURE_MODE_MANUAL` constants but its public `Builder` has no capture-mode setter (googlesamples/mlkit#846 open, unanswered), so no programmatic control exists on either platform — tracked in Spec `0002-capture-ergonomics`.

## Public dataset calibration

| Dataset | Revision  | Expected files | Processed | Skipped   | Failures  | Aggregate CER | Hangul CER | Latin CER |
| ------- | --------- | -------------- | --------- | --------- | --------- | ------------- | ---------- | --------- |
| Appen   | [UNKNOWN] | 5              | [UNKNOWN] | [UNKNOWN] | [UNKNOWN] | [UNKNOWN]     | [UNKNOWN]  | [UNKNOWN] |
| Humyn   | [UNKNOWN] | 20             | [UNKNOWN] | [UNKNOWN] | [UNKNOWN] | n/a (smoke)   | n/a        | n/a       |
| CORD v2 | [UNKNOWN] | [UNKNOWN]      | [UNKNOWN] | [UNKNOWN] | [UNKNOWN] | [UNKNOWN]     | n/a        | [UNKNOWN] |

Humyn has no verified transcripts and is restricted to a no-crash, non-empty-OCR smoke check.

## Notes

The Android acceptance run and the public dataset calibration have not been executed: no physical Android device was available on 2026-07-30, and the calibration requires Kaggle/Hugging Face downloads that are a separate decision.
The 11.0 support claim's full release gate requires both platform runs; this record currently evidences iOS only.

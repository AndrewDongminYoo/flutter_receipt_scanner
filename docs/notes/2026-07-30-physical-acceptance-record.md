# Physical Device Acceptance Record — Long Receipt OCR Merge

Work Item: [05-physical-device-acceptance.md](../specs/0001-long-receipt-ocr-merge/work-items/05-physical-device-acceptance.md)

Printed target: `flutter_receipt_scanner/test/fixtures/long_receipt/logical_receipt.png` (1,200 × 13,200 px, content ratio 11.0), printed at 57.0 mm width × 627 mm length.
A 627 mm print at ratio 11.0 covers the documented 600 mm / ≥ 57.0 mm claim.

CER measurement: paste the example app's merged OCR text into a file and run, from `flutter_receipt_scanner/`:

```bash
dart run tool/receipt_benchmark/compute_cer.dart <merged_text_file>
```

## Devices

| Field              | Android   | iOS       |
| ------------------ | --------- | --------- |
| Model              | [UNKNOWN] | [UNKNOWN] |
| OS version         | [UNKNOWN] | [UNKNOWN] |
| Scanner dependency | [UNKNOWN] | [UNKNOWN] |
| Run date           | [UNKNOWN] | [UNKNOWN] |

## Acceptance gates

| Gate                                                               | Android   | iOS       |
| ------------------------------------------------------------------ | --------- | --------- |
| Six camera pages captured with ~20% overlap                        | [UNKNOWN] | [UNKNOWN] |
| Capture order equals returned page URI order                       | [UNKNOWN] | [UNKNOWN] |
| Every JPEG readable, ≥ 1,200 px across cropped receipt width       | [UNKNOWN] | [UNKNOWN] |
| `mergedOcr.isComplete == true`, no unmatched boundaries or rejects | [UNKNOWN] | [UNKNOWN] |
| Aggregate CER ≤ 0.20                                               | [UNKNOWN] | [UNKNOWN] |
| Hangul CER ≤ 0.25                                                  | [UNKNOWN] | [UNKNOWN] |
| Latin CER ≤ 0.25                                                   | [UNKNOWN] | [UNKNOWN] |
| No missing non-overlap text, no duplicated accepted seam text      | [UNKNOWN] | [UNKNOWN] |
| OCR + merge within 30 s after native UI return                     | [UNKNOWN] | [UNKNOWN] |
| No crash or out-of-memory termination                              | [UNKNOWN] | [UNKNOWN] |

## Public dataset calibration

| Dataset | Revision  | Expected files | Processed | Skipped   | Failures  | Aggregate CER | Hangul CER | Latin CER |
| ------- | --------- | -------------- | --------- | --------- | --------- | ------------- | ---------- | --------- |
| Appen   | [UNKNOWN] | 5              | [UNKNOWN] | [UNKNOWN] | [UNKNOWN] | [UNKNOWN]     | [UNKNOWN]  | [UNKNOWN] |
| Humyn   | [UNKNOWN] | 20             | [UNKNOWN] | [UNKNOWN] | [UNKNOWN] | n/a (smoke)   | n/a        | n/a       |
| CORD v2 | [UNKNOWN] | [UNKNOWN]      | [UNKNOWN] | [UNKNOWN] | [UNKNOWN] | [UNKNOWN]     | n/a        | [UNKNOWN] |

Humyn has no verified transcripts and is restricted to a no-crash, non-empty-OCR smoke check.

## Notes

[UNKNOWN]

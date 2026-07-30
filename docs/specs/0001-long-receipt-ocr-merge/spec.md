---
type: Spec
title: Long Receipt OCR Page Merge
---

## Problem

The package processes each native scanner page as an independent JPEG and returns independent raw OCR strings.
It does not define a maximum logical receipt length, preserve a merged OCR representation, detect duplicated overlap between adjacent captures, or expose whether a multi-page receipt was assembled completely.

The requested support target is a receipt up to 60 cm long or an equivalent explicit vertical aspect ratio.
A single very tall bitmap is not a safe contract because the current Android image processor limits the processed long edge to 3,072 pixels, and Apple Vision OCR uses a minimum text height relative to the complete image height.
Both constraints reduce useful text resolution as a single image becomes taller.

The public dataset search found Korean-plus-Latin receipt data, but no verified public dataset whose images cover the requested 60 cm or 11:1 geometry.
The implementation therefore needs public-language calibration data plus a deterministic project-owned long-receipt target.

## Proposed Outcome

Add an opt-in `mergeOcrPages` flag to the app-facing `scan()` function.
When enabled for a multi-page camera scan, the package keeps every native JPEG unchanged, orders pages by the native scan result, deduplicates proven OCR overlap at adjacent page seams, and returns one diagnostic merged OCR result.

The documented support contract is a logical receipt content aspect ratio of `height / width <= 11.0`.
This covers a 600 mm receipt on the minimum 57.0 mm paper width allowed by Epson's 57.5 ± 0.5 mm specification because `600 / 57.0 = 10.53`. [L1]

The reference acceptance artifact is a 1,200 × 13,200 logical receipt split into six 1,200 × 2,640 page images with 528 pixels, or 20%, overlap between adjacent pages. [L6]
The feature merges OCR data only and does not allocate a 13,200-pixel-tall output image. [L2]

## User Stories

1. As an app developer, I can enable multi-page OCR merging without changing existing scan behavior for callers that leave the flag disabled. [L3]
2. As a person scanning a long receipt, I can capture consecutive overlapping sections in one camera session and receive one ordered OCR string.
3. As an app developer, I can distinguish a proven complete merge from an incomplete result and identify unmatched seams or OCR-rejected pages. [L5]
4. As a maintainer, I can reproduce the 11.0 aspect-ratio claim with deterministic Korean-plus-Latin fixtures and physical Android and iOS acceptance runs. [L6] [L8]
5. As a maintainer, I can run optional public-dataset calibration without checking third-party receipt photos into the repository. [L7]

## Requirements

### Support Contract

1. The supported logical receipt content ratio is `contentHeight / contentWidth <= 11.0`. [L1]
2. The physical interpretation is a receipt up to 600 mm long when its paper width is at least 57.0 mm.
3. The ratio applies to the assembled logical content, not to the raw camera frame and not to one returned JPEG. [L2]
4. The version 1 reference layout is six portrait pages with page ratio 2.2 and 20% vertical overlap. [L6]
5. Each reference page must contain at least 1,200 pixels across the cropped receipt width before OCR.
6. The existing native maximum of ten pages remains unchanged.
7. The implementation must not reject an otherwise valid scan solely because it cannot infer a physical paper size from pixels.
8. The 11.0 limit is a tested capability claim, not a runtime physical-length measurement.

### Public API

1. The app-facing function adds one backward-compatible named parameter:

```dart
Future<ScanReceiptResult> scan({
  ScanReceiptOptions options = const ScanReceiptOptions(),
  OcrFloorOrDisabled ocrFloor = const OcrFloorOrDisabled.floor(kDefaultOcrFloor),
  bool mergeOcrPages = false,
})
```

2. `mergeOcrPages` defaults to `false`. [L3]
3. `mergeOcrPages: true` requires `options.ocr == true`.
4. `mergeOcrPages: true` requires `options.source == ScanSource.camera`. [L4]
5. `mergeOcrPages: true` requires `options.maxPages >= 2`.
6. An invalid combination throws `ArgumentError` before `FlutterReceiptScannerPlatform.instance.scan(options)` is called.
7. A user who enables merging but completes capture with one page receives a complete one-page merged result whose text equals that page's normalized non-empty OCR lines.
8. Cancellation preserves the existing `ScanStatus.cancelled` behavior and returns `mergedOcr == null`.
9. Native platform implementations continue to accept the existing `ScanReceiptOptions`.
10. The Pigeon schema and generated Swift, Kotlin, and Dart transport files do not change. [L2]

### Result Model

1. `ScanReceiptResult` gains an optional `MergedOcrResult? mergedOcr` field.
2. `MergedOcrResult` has this minimum public shape:

```dart
final class MergedOcrResult {
  const MergedOcrResult({
    required this.text,
    required this.isComplete,
    required this.pageUris,
    this.unmatchedBoundaryIndexes = const [],
    this.rejectedPageIndexes = const [],
  });

  final String text;
  final bool isComplete;
  final List<String> pageUris;
  final List<int> unmatchedBoundaryIndexes;
  final List<int> rejectedPageIndexes;
}
```

3. `pageUris` preserves the native page order and provides the mapping for all zero-based page and boundary indexes.
4. Boundary index `i` means the seam between `pageUris[i]` and `pageUris[i + 1]`.
5. `rejectedPageIndexes` contains pages that did not pass the configured OCR floor.
6. `isComplete` is true only when every page has non-empty OCR, every page passes the configured OCR floor or the floor is explicitly disabled, and every adjacent boundary is proven.
7. `isComplete` is true for a non-empty one-page result because it has no boundary to prove.
8. A requested merge may be present when the top-level status is `ScanStatus.rejected` so diagnostics and partial OCR remain available.
9. `images`, `rejectedImages`, their JPEG files, and their raw `ocrText` values retain current behavior.
10. The app-facing package populates `mergedOcr`.
    Native platform packages leave it null.

### Page Ordering

1. Camera pages are consumed in the order returned by VisionKit or the ML Kit document scanner.
2. The merger snapshots the native `images` list before the OCR-floor gate partitions it.
3. After the gate, annotated page values are mapped back to the original order by their unique cache URI.
4. Duplicate page URIs are treated as an internal state error and must not be silently reordered.
5. [PARTIAL] Apple documents page-numbered access to document-camera scan images, and the current Swift implementation iterates them in index order.
6. [PARTIAL] Google's API returns a page list and the current Kotlin implementation iterates it in list order, but the inspected public documentation did not state an explicit long-term ordering guarantee.
7. Android and iOS physical-device tests must therefore verify capture order before the support claim ships.

### OCR Merge

1. Merge input is `ReceiptImage.ocrText` from all captured pages in original order.
2. OCR-floor acceptance and geometric support remain separate decisions.
   The floor determines page signal quality, while the merger determines page order and overlap. [L2]
3. The merger splits each page on newline, trims surrounding whitespace from each line, and drops empty lines from the merged output.
4. Matching normalization collapses consecutive whitespace, applies lowercase conversion, and otherwise preserves Korean, Latin, digits, and punctuation.
5. Matching normalization is used only for seam comparison.
   The emitted text uses the trimmed recognized lines from the earlier page and the non-overlapping lines from the later page.
6. For each adjacent boundary, compare suffix and prefix windows containing one through eight lines.
7. Candidate similarity is `1 - levenshteinDistance / max(leftLength, rightLength)` on the normalized joined window.
8. A normal candidate is accepted only when both normalized windows contain at least 12 characters and similarity is at least 0.85.
9. If either candidate window contains only one line, both normalized windows must contain at least 24 characters and similarity must be at least 0.92.
10. The selected candidate maximizes the shorter normalized character count, then similarity, then the number of prefix lines removed.
    This tie-breaking order must be deterministic.
11. An accepted boundary keeps the prior page suffix and removes only the matched prefix lines from the next page.
12. An unmatched boundary appends every non-empty line from the next page, records the boundary index, and makes the result incomplete. [L5]
13. A page with null or empty OCR records that page index as rejected for merge completeness and makes each adjacent boundary unmatched.
14. A page rejected by the OCR floor is still represented in `pageUris` and may contribute its raw OCR text, but its index appears in `rejectedPageIndexes` and the merge is incomplete.
15. The algorithm must not compare non-adjacent pages or globally remove repeated receipt lines such as headers, taxes, or totals.
16. Matching constants remain private in version 1. [L9]
17. The implementation uses bounded Dart code and adds no runtime dependency. [L9]

### Dataset and Fixture Policy

1. The repository adds a machine-readable local benchmark manifest that records dataset name, source URL, access date, license, expected public files, checksums when stable, annotation type, scripts present, and intended test role.
2. The manifest does not download data during normal package tests, `melos bootstrap`, or CI.
3. Public receipt photos remain ignored local benchmark inputs unless a later legal and privacy review explicitly approves redistribution. [L7]
4. The checked-in long-receipt fixture uses project-authored Korean-plus-Latin text and contains no real person's transaction, location, payment, phone, membership, or account data.
5. If fixture generation requires a Korean font, the generator pins an OFL-compatible font version, checksum, attribution, and license.
6. Generated fixture images are derived artifacts.
   The source text and generator are the source of truth.
7. The fixture set contains:
   - One complete 11.0 logical receipt split into six pages with 20% overlap.
   - One fixture with a missing page.
   - One fixture with a boundary that has no overlap.
   - One fixture with repeated legitimate lines away from the seam.
   - One fixture whose OCR line segmentation differs on the two sides of a seam.
   - One fixture with a page below the default OCR floor.
8. The public datasets have these roles:
   - Appen OCR Image Data of Korean Documents provides five publicly downloadable Korean receipt image and JSON pairs with text polygon labels for manual Korean-plus-Latin calibration.
   - Humyn Korean Receipts Dataset provides 20 publicly downloadable 1,536 × 2,048 images for unlabelled Korean-plus-Latin visual smoke testing.
   - CORD v2 provides 1,000 annotated Indonesian receipts for broader Latin-script receipt calibration.
9. [PARTIAL] The Appen landing page advertises 1,500 Korean receipt images, while the public archive inspected on 2026-07-30 contained five receipt pairs.
   The manifest must pin the observed public subset rather than assume access to 1,500 files.
10. [PARTIAL] The Humyn dataset card declares a 1K-to-10K size category, while its repository API exposed 20 image files on 2026-07-30.
    The manifest must pin the observed 20 files.
11. Humyn must not be used to calculate character error rate because it has no verified transcripts.
12. KORIE remains an optional follow-up until its dataset archive and dataset-specific license are verified. [L10]

### Errors and Diagnostics

1. Invalid option combinations fail before native UI.
2. Scan cancellation is not an error.
3. Missing OCR, OCR-floor rejection, and unmatched seams do not throw after the user completes a scan.
   They return an incomplete merged result.
4. The merger must not delete uncertain content to make a result appear complete.
5. Exceptions must use existing package error conventions and must not introduce a new exception hierarchy.

### Performance and Resource Limits

1. The merger holds OCR strings and diagnostics only.
   It must not decode, copy, concatenate, or retain bitmap bytes. [L2]
2. A ten-page unit benchmark with 200 OCR lines per page must complete in at most 100 ms in a Dart profile-mode benchmark on the development Mac mini.
3. The six-page physical acceptance scan must finish OCR and Dart merging within 30 seconds after the native scanner UI returns on each acceptance device.
4. The six-page acceptance run must not terminate from an out-of-memory condition or crash.
5. Each returned JPEG remains individually readable after the merge.

## Technical Decisions

### Package Boundary

The optional flag and merge orchestration belong in [`flutter_receipt_scanner/lib/src/receipt_scanner.dart`](../../../flutter_receipt_scanner/lib/src/receipt_scanner.dart).
The pure merger belongs in a new private `flutter_receipt_scanner/lib/src/ocr_page_merger.dart`.
The public result model belongs in the platform-interface model package because [`ScanReceiptResult`](../../../flutter_receipt_scanner_platform_interface/lib/src/models/scan_receipt_result.dart) is already defined there.
This type placement does not authorize native merge logic.

No native Kotlin, Swift, Pigeon schema, or generated-file change is expected.
If implementation discovery proves that page order is not preserved by either camera SDK, stop and revise this Spec before adding native ordering state.

### Scan Flow

The app-facing flow is:

```plaintext
validate merge option
  -> run native multi-page scan
  -> snapshot native page order
  -> apply existing Dart OCR-floor annotations and partition
  -> rebuild the annotated pages in snapshot order by URI
  -> merge adjacent OCR suffix/prefix windows
  -> return existing scan status and image lists plus mergedOcr
```

The existing `applyOcrFloor` thresholds remain unchanged at a minimum trimmed text length of 12 and a minimum of two non-empty lines.
Confidence remains reporting-only at its current default.

### Expected Implementation Scope

The likely production and public-example changes are:

1. [`flutter_receipt_scanner/lib/src/receipt_scanner.dart`](../../../flutter_receipt_scanner/lib/src/receipt_scanner.dart) for option validation and orchestration.
2. `flutter_receipt_scanner/lib/src/ocr_page_merger.dart` for the pure bounded merge algorithm.
3. [`flutter_receipt_scanner/lib/flutter_receipt_scanner.dart`](../../../flutter_receipt_scanner/lib/flutter_receipt_scanner.dart) for the new public result export.
4. `flutter_receipt_scanner_platform_interface/lib/src/models/merged_ocr_result.dart` for `MergedOcrResult`.
5. [`flutter_receipt_scanner_platform_interface/lib/src/models/scan_receipt_result.dart`](../../../flutter_receipt_scanner_platform_interface/lib/src/models/scan_receipt_result.dart) for the optional field.
6. [`flutter_receipt_scanner_platform_interface/lib/src/models/models.dart`](../../../flutter_receipt_scanner_platform_interface/lib/src/models/models.dart) and the package barrel for exports.
7. App-facing and platform-interface unit tests for validation, result construction, ordering, exact seams, fuzzy seams, incomplete seams, and floor interaction.
8. The example app for an opt-in camera merge control and visible complete/incomplete diagnostics.
9. A local benchmark manifest, deterministic fixture source and generator, generated images, and fixture documentation.
10. Package README documentation for capture overlap guidance and the 11.0 support contract.

This scope is broader than five files because it adds a public result type, an observable example flow, and reproducible support evidence.
It must still avoid unrelated refactoring, formatting-only changes, and native transport changes.

## Testing Strategy

### Pure Dart Unit Tests

1. Verify the flag defaults to disabled and preserves the previous result exactly.
2. Verify invalid `ocr`, `source`, and `maxPages` combinations throw before the fake platform receives a call.
3. Verify a one-page result is complete.
4. Verify exact two-line overlap is removed once.
5. Verify a fuzzy Korean-plus-Latin overlap at or above threshold is removed once.
6. Verify a candidate below threshold is preserved and records an unmatched boundary.
7. Verify a single-line candidate uses the stricter threshold.
8. Verify repeated totals away from the adjacent suffix and prefix are preserved.
9. Verify null OCR and OCR-floor-rejected pages make the merge incomplete.
10. Verify cancellation returns no merged result.
11. Verify input page lists, raw OCR strings, and image URIs are not mutated.
12. Verify the ten-page, 200-lines-per-page benchmark stays within 100 ms.

### Deterministic Fixture Tests

1. Generate the 1,200 × 13,200 logical receipt from project-authored Korean-plus-Latin source text.
2. Split it into six 1,200 × 2,640 images with 528-pixel overlaps and verify dimensions and checksums.
3. Feed canonical page OCR strings into the pure merger and require byte-for-byte equality with the canonical normalized receipt text.
4. Require zero duplicated accepted seam lines.
5. Require zero missing non-overlap lines.
6. Require the missing-page, unmatched-boundary, and rejected-page fixtures to report `isComplete == false` with exact diagnostic indexes.

### Public Dataset Calibration

1. Run Appen's five public annotated Korean receipt samples as a manual Korean-plus-Latin OCR calibration.
2. Report aggregate character error rate and separate Korean and Latin character error rates from the JSON labels.
3. Run Humyn's 20 public images as a no-crash, non-empty-OCR smoke check only.
4. Run a pinned CORD v2 split as a larger Latin receipt calibration and record aggregate character error rate.
5. Record dataset revision, file count, skipped files, and failures so no truncated or partial run is reported as exhaustive.
6. Do not make CI depend on Kaggle, Hugging Face, authentication, network availability, or mutable remote datasets.

### Physical End-to-End Acceptance

1. Print the project-owned target at 600 mm long and at least 57.0 mm wide.
2. Capture it in six camera pages with approximately 20% overlap using the example app.
3. Run once on a physical Android device supported by the package and once on a physical iOS 16.0-or-newer device.
4. Require native page order to equal capture order.
5. Require every output JPEG to be readable and at least 1,200 pixels wide across the cropped receipt.
6. Require `mergedOcr.isComplete == true`.
7. Require no unmatched boundaries and no rejected pages.
8. Require aggregate character error rate no greater than 20%.
9. Require Korean and Latin character error rate no greater than 25% each.
10. Require no missing non-overlap text and no duplicated accepted seam text.
11. Require OCR plus merge completion within 30 seconds after native UI return.
12. Require no crash or out-of-memory termination. [L8]

The exact physical device models must be recorded with the result.
An emulator or simulator run does not replace this gate.

### Repository Verification

Implementation verification must run:

```bash
melos run format
melos run analyze
melos run test
trunk fmt
trunk check
```

If a fixture generator changes, regenerate fixtures first and verify its deterministic checksums before the repository commands.
Run only one heavy mobile job at a time.

## Out of Scope

1. Returning one stitched receipt JPEG, PDF, or bitmap. [L2]
2. Structured receipt parsing such as merchant, item, tax, total, date, or payment-field reconciliation.
3. Gallery selection ordering, review, drag-to-reorder, or gallery page merging. [L4]
4. Cloud OCR or server-side processing.
5. Changing native OCR engines or document scanner SDKs.
6. Changing the Pigeon transport or generated Swift, Kotlin, or Dart.
7. Runtime measurement of physical millimetres from image pixels.
8. Exposing similarity thresholds as public configuration. [L9]
9. Claiming support above aspect ratio 11.0.
10. Redistributing public receipt photos without a separate license and privacy review. [L7]

## Open Questions

1. Which exact Android and iOS physical device models will be the release acceptance devices?
   This does not block pure Dart implementation, but the 11.0 support claim cannot ship until both runs are recorded.
2. Does the ML Kit document scanner preserve capture order as a documented API guarantee in a source not found during this investigation?
   Until confirmed, the physical Android ordering test remains mandatory.
3. Can KORIE provide a stable public archive and a dataset-specific license?
   Until confirmed, it remains outside the required benchmark. [L10]

## Follow-Ups

1. Decompose implementation into a public-model slice, pure merger slice, scan orchestration slice, example/documentation slice, and benchmark/physical-acceptance slice.
2. Calibrate the private similarity constants against the deterministic fixtures and the five Appen annotated samples before changing them.
3. Consider ordered gallery support only as a separate Spec that includes explicit selection order and a review-and-reorder surface.
4. Consider structured line-item merging only after raw text merge completeness is proven.

## Notes

### Repository Evidence

- The repository boundary states that native packages return image primitives and raw OCR while receipt-domain logic stays in the app-facing Dart package in [`AGENTS.md`](../../../AGENTS.md).
- The current app-facing [`scan()`](../../../flutter_receipt_scanner/lib/src/receipt_scanner.dart) calls the native platform and then applies the OCR floor.
- The current [`applyOcrFloor`](../../../flutter_receipt_scanner/lib/src/ocr_floor.dart) uses defaults of 12 trimmed characters, two non-empty lines, and report-only zero confidence.
- The current public [`ScanReceiptResult`](../../../flutter_receipt_scanner_platform_interface/lib/src/models/scan_receipt_result.dart) contains only status, accepted images, and rejected images.
- The current Android image processor limits the processed long edge to 3,072 pixels in `flutter_receipt_scanner_android/android/src/main/kotlin/com/example/flutter_receipt_scanner_android/ImageProcessor.kt`.
- The current native scanners constrain `maxPages` to one through ten and process pages individually.

### External Evidence

- [Epson TM-P80II Technical Reference Guide](https://files.support.epson.com/pdf/pos/bulk/tm-p80iiac_trg_en_reve.pdf) specifies 57.5 ± 0.5 mm and 79.5 ± 0.5 mm receipt paper widths.
- [Apple Vision `minimumTextHeight`](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/minimumtextheight) defines minimum text height relative to image height and documents a default of 1/32.
- [Apple VisionKit document camera](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller) provides page-numbered scanned images.
- [Google ML Kit document scanner](https://developers.google.com/ml-kit/vision/doc-scanner/android) supports a configurable page limit and returns page JPEGs.
- [Humyn Korean Receipts Dataset](https://huggingface.co/datasets/HumynLabs/Korean_Receipts_Dataset) is public under CC BY 4.0 and contains Korean receipt photos with Latin content.
- [Appen OCR Image Data of Korean Documents](https://www.kaggle.com/datasets/appenlimited/ocr-image-data-of-korean-documents) is public under CC BY-SA 4.0 and exposes a small annotated Korean receipt sample.
- [CORD repository](https://github.com/clovaai/cord) and [CORD v2 dataset](https://huggingface.co/datasets/naver-clova-ix/cord-v2) provide 1,000 annotated Indonesian receipts under CC BY 4.0.
- [SROIE paper](https://arxiv.org/abs/2103.10213) and the [ICDAR 2019 SROIE public mirror](https://huggingface.co/datasets/jsdnrs/ICDAR2019-SROIE) are optional Latin receipt references and are not required by this Spec.
- [KORIE paper](https://doi.org/10.3390/math14010187) and its [DOAJ record](https://doaj.org/article/73a35fe4ce324bba8d23a6b1f9e38cd0) describe a Korean receipt corpus, but a stable dataset download and dataset-specific license were not verified. [L10]

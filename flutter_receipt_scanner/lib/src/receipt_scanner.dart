import 'package:flutter_receipt_scanner/src/ocr_floor.dart';
import 'package:flutter_receipt_scanner/src/ocr_page_merger.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// Launches the native scan flow, then applies the Dart-side OCR-floor gate.
///
/// [options] configures the native acquisition and processing.
/// [ocrFloor] configures the Dart-side acceptance gate applied to the returned images.
/// [mergeOcrPages] assembles ordered camera-page OCR without creating a stitched bitmap.
///
/// Returns a [ScanReceiptResult] whose `images` passed the floor (or all images
/// when the floor is disabled), whose `rejectedImages` carries the rest, and whose
/// `mergedOcr` contains requested page-merge diagnostics.
Future<ScanReceiptResult> scan({
  ScanReceiptOptions options = const ScanReceiptOptions(),
  OcrFloorOrDisabled ocrFloor = const OcrFloorOrDisabled.floor(
    kDefaultOcrFloor,
  ),
  bool mergeOcrPages = false,
}) async {
  if (mergeOcrPages) _validateMergeOptions(options);
  // The language option is moot without OCR — never let it gate a scan that
  // will not run recognition (native code skips it for the same reason).
  final resolved = options.ocr ? _resolveOcrLanguages(options) : options;

  final native = await FlutterReceiptScannerPlatform.instance.scan(resolved);
  final nativePageUris = mergeOcrPages && native.status == ScanStatus.success
      ? _snapshotNativePageUris(native.images)
      : const <String>[];
  final gated = applyOcrFloor(native, ocr: options.ocr, floor: ocrFloor);
  if (!mergeOcrPages || native.status != ScanStatus.success) return gated;

  final orderedPages = _restoreNativePageOrder(nativePageUris, gated);
  final rejectedUris = gated.rejectedImages.map((image) => image.uri).toSet();
  final rejectedPageIndexes = <int>{
    for (var index = 0; index < orderedPages.length; index++)
      if (rejectedUris.contains(orderedPages[index].uri)) index,
  };
  var mergedOcr = mergeReceiptOcrPages(
    orderedPages,
    rejectedPageIndexes: rejectedPageIndexes,
  );
  if (native.discardedPageCount > 0 && mergedOcr.isComplete) {
    // A natively dropped page means the logical receipt is not fully covered,
    // even when every returned adjacent boundary is proven (supersedes the
    // unconditional one-page completeness rule of spec 0001).
    mergedOcr = MergedOcrResult(
      text: mergedOcr.text,
      isComplete: false,
      pageUris: mergedOcr.pageUris,
      unmatchedBoundaryIndexes: mergedOcr.unmatchedBoundaryIndexes,
      rejectedPageIndexes: mergedOcr.rejectedPageIndexes,
    );
  }

  return ScanReceiptResult(
    status: gated.status,
    images: gated.images,
    rejectedImages: gated.rejectedImages,
    mergedOcr: mergedOcr,
    discardedPageCount: gated.discardedPageCount,
  );
}

/// Reports current on-device OCR capability without downloading a model or
/// opening UI.
Future<OcrCapabilities> getOcrCapabilities() => FlutterReceiptScannerPlatform.instance.getOcrCapabilities();

/// Trims tags and drops exact duplicates, keeping the first occurrence.
///
/// Native code owns canonicalization and provider capability validation; this
/// only rejects input that is structurally unusable.
ScanReceiptOptions _resolveOcrLanguages(ScanReceiptOptions options) {
  final normalized = <String>[];
  for (final tag in options.ocrLanguages) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        options.ocrLanguages,
        'options.ocrLanguages',
        'must not contain an empty language tag',
      );
    }
    if (!normalized.contains(trimmed)) normalized.add(trimmed);
  }
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      options.ocrLanguages,
      'options.ocrLanguages',
      'must not be empty',
    );
  }
  return options.copyWith(ocrLanguages: normalized);
}

void _validateMergeOptions(ScanReceiptOptions options) {
  if (!options.ocr) {
    throw ArgumentError.value(
      options.ocr,
      'options.ocr',
      'must be true when mergeOcrPages is enabled',
    );
  }
  if (options.source != ScanSource.camera) {
    throw ArgumentError.value(
      options.source,
      'options.source',
      'must be ScanSource.camera when mergeOcrPages is enabled',
    );
  }
  if (options.maxPages < 2) {
    throw ArgumentError.value(
      options.maxPages,
      'options.maxPages',
      'must be at least 2 when mergeOcrPages is enabled',
    );
  }
}

List<String> _snapshotNativePageUris(List<ReceiptImage> nativePages) {
  final uris = <String>[];
  final seen = <String>{};
  for (final page in nativePages) {
    if (!seen.add(page.uri)) {
      throw StateError('Duplicate receipt page URI: ${page.uri}');
    }
    uris.add(page.uri);
  }
  return List.unmodifiable(uris);
}

List<ReceiptImage> _restoreNativePageOrder(
  List<String> nativePageUris,
  ScanReceiptResult gated,
) {
  final annotatedByUri = <String, ReceiptImage>{
    for (final page in [...gated.images, ...gated.rejectedImages]) page.uri: page,
  };
  return [
    for (final uri in nativePageUris)
      annotatedByUri[uri] ??
          (throw StateError(
            'OCR floor result is missing receipt page URI: $uri',
          )),
  ];
}

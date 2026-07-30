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

  final native = await FlutterReceiptScannerPlatform.instance.scan(options);
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
  final mergedOcr = mergeReceiptOcrPages(
    orderedPages,
    rejectedPageIndexes: rejectedPageIndexes,
  );

  return ScanReceiptResult(
    status: gated.status,
    images: gated.images,
    rejectedImages: gated.rejectedImages,
    mergedOcr: mergedOcr,
  );
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

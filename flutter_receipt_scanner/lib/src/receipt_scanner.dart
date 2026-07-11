import 'package:flutter_receipt_scanner/src/ocr_floor.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// Launches the native scan flow, then applies the Dart-side OCR-floor gate.
///
/// [options] configures the native acquisition/processing; [ocrFloor] configures
/// the Dart-side acceptance gate applied to the returned images.
///
/// Returns a [ScanReceiptResult] whose `images` passed the floor (or all images
/// when the floor is disabled) and whose `rejectedImages` carries the rest.
Future<ScanReceiptResult> scan({
  ScanReceiptOptions options = const ScanReceiptOptions(),
  OcrFloorOrDisabled ocrFloor = const OcrFloorOrDisabled.floor(kDefaultOcrFloor),
}) async {
  final native = await FlutterReceiptScannerPlatform.instance.scan(options);
  return applyOcrFloor(native, ocr: options.ocr, floor: ocrFloor);
}

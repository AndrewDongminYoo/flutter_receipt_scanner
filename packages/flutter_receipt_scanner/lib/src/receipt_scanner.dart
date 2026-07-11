import 'package:flutter_receipt_scanner/src/ocr_floor.dart';
import 'package:flutter_receipt_scanner/src/scan_options.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// Launches the native scan flow, then applies the Dart-side OCR-floor gate.
///
/// Returns a [ScanResult] whose `images` passed the floor (or all images when
/// the floor is disabled) and whose `rejectedImages` carries the rest.
Future<ScanResult> scan([ScanReceiptOptions options = kDefaultScanOptions]) async {
  final native = await FlutterReceiptScannerPlatform.instance.scan(options.toMessage());
  return applyOcrFloor(native, ocr: options.ocr, floor: options.ocrFloor);
}

import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingPlatform extends FlutterReceiptScannerPlatform {
  ScanOptions? received;

  @override
  Future<ScanResult> scan(ScanOptions options) async {
    received = options;
    return ScanResult(
      status: ScanStatus.success,
      images: [
        ReceiptImage(
          uri: 'file:///tmp/a.jpg',
          width: 1,
          height: 1,
          fileName: 'a.jpg',
          mimeType: 'image/jpeg',
          fileSize: 1,
          ocrText: 'a receipt line\nsecond line',
          ocrQuality: OcrQuality(confidence: 0.9),
          imageOrigin: ImageOrigin.camera,
        ),
      ],
      rejectedImages: [],
    );
  }
}

void main() {
  test('scan forwards options and applies the gate', () async {
    final platform = _RecordingPlatform();
    FlutterReceiptScannerPlatform.instance = platform;

    final result = await scan(const ScanReceiptOptions(maxPages: 3));

    expect(platform.received?.maxPages, 3);
    expect(result.status, ScanStatus.success);
    expect(result.images.length, 1);
  });
}

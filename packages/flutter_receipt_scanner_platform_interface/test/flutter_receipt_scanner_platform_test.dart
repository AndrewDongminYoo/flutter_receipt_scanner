import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends FlutterReceiptScannerPlatform {
  @override
  Future<ScanResult> scan(ScanOptions options) async =>
      ScanResult(status: ScanStatus.cancelled, images: [], rejectedImages: []);
}

class _BadImpl implements FlutterReceiptScannerPlatform {
  @override
  Future<ScanResult> scan(ScanOptions options) => throw UnimplementedError();
}

void main() {
  test('default instance is the Pigeon-backed platform', () {
    expect(FlutterReceiptScannerPlatform.instance, isA<PigeonReceiptScannerPlatform>());
  });

  test('a properly-extended platform can be set as instance', () {
    final fake = _FakePlatform();
    FlutterReceiptScannerPlatform.instance = fake;
    expect(FlutterReceiptScannerPlatform.instance, same(fake));
  });

  test('setting a plain-implements instance is rejected by the token guard', () {
    expect(() => FlutterReceiptScannerPlatform.instance = _BadImpl(), throwsA(isA<AssertionError>()));
  });
}

import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends FlutterReceiptScannerPlatform {
  @override
  Future<ScanReceiptResult> scan(ScanReceiptOptions options) async =>
      const ScanReceiptResult(status: ScanStatus.cancelled);
}

class _BadImpl implements FlutterReceiptScannerPlatform {
  @override
  Future<ScanReceiptResult> scan(ScanReceiptOptions options) => throw UnimplementedError();
}

void main() {
  test('a properly-extended platform can be set as instance', () {
    final fake = _FakePlatform();
    FlutterReceiptScannerPlatform.instance = fake;
    expect(FlutterReceiptScannerPlatform.instance, same(fake));
  });

  test('setting a plain-implements instance is rejected by the token guard', () {
    expect(
      () => FlutterReceiptScannerPlatform.instance = _BadImpl(),
      throwsA(isA<AssertionError>()),
    );
  });
}

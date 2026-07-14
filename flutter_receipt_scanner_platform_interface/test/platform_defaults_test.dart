import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

// A platform that extends the interface without overriding scan(), so calling
// scan() falls through to the base default implementation.
class _DefaultScanPlatform extends FlutterReceiptScannerPlatform {}

void main() {
  // Capture the pristine default (`_UnimplementedReceiptScanner`) during the
  // collection phase — every file's main() body runs before any test callback,
  // so `instance` here is untouched even when very_good's --optimization merges
  // all test files into one isolate and another file later sets `instance`.
  final defaultInstance = FlutterReceiptScannerPlatform.instance;

  test('the base scan() default throws UnimplementedError', () {
    expect(
      () => _DefaultScanPlatform().scan(const ScanReceiptOptions()),
      throwsA(isA<UnimplementedError>()),
    );
  });

  test('the default instance has no implementation and throws UnsupportedError', () {
    expect(
      () => defaultInstance.scan(const ScanReceiptOptions()),
      throwsA(isA<UnsupportedError>()),
    );
  });
}

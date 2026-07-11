import 'package:flutter_receipt_scanner_ios/flutter_receipt_scanner_ios.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registerWith installs the iOS platform as the instance', () {
    FlutterReceiptScannerIos.registerWith();
    expect(
      FlutterReceiptScannerPlatform.instance,
      isA<FlutterReceiptScannerIos>(),
    );
  });
}

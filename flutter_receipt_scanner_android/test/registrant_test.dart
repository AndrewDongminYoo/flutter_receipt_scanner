import 'package:flutter_receipt_scanner_android/flutter_receipt_scanner_android.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registerWith installs the Android platform as the instance', () {
    FlutterReceiptScannerAndroid.registerWith();
    expect(
      FlutterReceiptScannerPlatform.instance,
      isA<FlutterReceiptScannerAndroid>(),
    );
  });
}

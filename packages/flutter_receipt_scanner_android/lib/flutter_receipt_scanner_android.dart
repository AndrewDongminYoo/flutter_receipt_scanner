import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// Android registrant. Skeleton milestone: the native `scan` handler is not
/// implemented yet and returns an `unimplemented` error.
class FlutterReceiptScannerAndroid {
  /// Installs the Pigeon-backed platform as the active implementation.
  static void registerWith() {
    FlutterReceiptScannerPlatform.instance = PigeonReceiptScannerPlatform();
  }
}

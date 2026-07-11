import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// iOS registrant. Flutter calls [registerWith] via the `dartPluginClass`
/// hook declared in this package's pubspec.
class FlutterReceiptScannerIos {
  /// Installs the Pigeon-backed platform as the active implementation.
  static void registerWith() {
    FlutterReceiptScannerPlatform.instance = PigeonReceiptScannerPlatform();
  }
}

import 'package:flutter_receipt_scanner_platform_interface/src/flutter_receipt_scanner_platform.dart';
import 'package:flutter_receipt_scanner_platform_interface/src/messages.g.dart';

/// Default [FlutterReceiptScannerPlatform] backed by the Pigeon-generated
/// [ReceiptScannerApi].
///
/// Shared by both platform packages — the native handler registered on each
/// platform answers the call, so the Dart side needs no per-platform variation.
class PigeonReceiptScannerPlatform extends FlutterReceiptScannerPlatform {
  /// Creates the default platform, optionally with an injected [api] for tests.
  PigeonReceiptScannerPlatform({ReceiptScannerApi? api}) : _api = api ?? ReceiptScannerApi();

  final ReceiptScannerApi _api;

  @override
  Future<ScanResult> scan(ScanOptions options) => _api.scan(options);
}

import 'package:flutter_receipt_scanner_platform_interface/src/models/models.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that platform implementations of `flutter_receipt_scanner`
/// must implement.
///
/// Platform implementations should `extend` this class rather than `implement`
/// it — extending picks up default implementations, so newly added methods do
/// not break existing platform packages.
abstract class FlutterReceiptScannerPlatform extends PlatformInterface {
  /// Constructs a platform implementation.
  FlutterReceiptScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterReceiptScannerPlatform _instance = _UnimplementedReceiptScanner();

  /// The default instance to use.
  static FlutterReceiptScannerPlatform get instance => _instance;

  /// Platform packages set this from their `registerWith` hook.
  static set instance(FlutterReceiptScannerPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Launches the native scan flow and returns image primitives (JPEG + EXIF +
  /// raw OCR text + confidence + origin). The OCR-floor acceptance gate is
  /// applied by the app-facing package, not here.
  Future<ScanReceiptResult> scan(ScanReceiptOptions options) {
    throw UnimplementedError('scan() has not been implemented.');
  }
}

/// Fallback used on platforms with no registered implementation.
final class _UnimplementedReceiptScanner extends FlutterReceiptScannerPlatform {
  @override
  Future<ScanReceiptResult> scan(ScanReceiptOptions options) {
    throw UnsupportedError(
      'flutter_receipt_scanner has no implementation on this platform.',
    );
  }
}

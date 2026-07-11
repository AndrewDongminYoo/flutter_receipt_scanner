import 'package:flutter_receipt_scanner_platform_interface/src/messages.g.dart';
import 'package:flutter_receipt_scanner_platform_interface/src/pigeon_receipt_scanner.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface every platform implementation of `flutter_receipt_scanner`
/// extends.
///
/// Platform packages must `extend` this class (never `implements`) so that new
/// methods added with default implementations do not break them.
abstract class FlutterReceiptScannerPlatform extends PlatformInterface {
  /// Constructs a platform implementation, verifying it against the shared
  /// [_token] so plain `implements` subclasses are rejected.
  FlutterReceiptScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterReceiptScannerPlatform _instance = PigeonReceiptScannerPlatform();

  /// The active platform implementation.
  static FlutterReceiptScannerPlatform get instance => _instance;

  /// Sets the active platform implementation. Platform registrants call this
  /// from their `registerWith` hook.
  static set instance(FlutterReceiptScannerPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Launches the native scan flow and returns image primitives.
  ///
  /// The OCR-floor acceptance gate is applied by the app-facing package, not
  /// here — this layer stays at image primitives only.
  Future<ScanResult> scan(ScanOptions options) {
    throw UnimplementedError('scan() has not been implemented.');
  }
}

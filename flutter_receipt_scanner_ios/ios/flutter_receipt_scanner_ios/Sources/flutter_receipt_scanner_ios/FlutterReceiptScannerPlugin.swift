import Flutter
import UIKit

/// Registers the generated `ReceiptScannerApi` handler on the plugin channel.
public class FlutterReceiptScannerPlugin: NSObject, FlutterPlugin {
  // Held statically so the handler outlives `register(with:)`.
  private static var apiImpl: ReceiptScannerApiImpl?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let impl = ReceiptScannerApiImpl()
    apiImpl = impl
    ReceiptScannerApiSetup.setUp(binaryMessenger: registrar.messenger(), api: impl)
  }
}

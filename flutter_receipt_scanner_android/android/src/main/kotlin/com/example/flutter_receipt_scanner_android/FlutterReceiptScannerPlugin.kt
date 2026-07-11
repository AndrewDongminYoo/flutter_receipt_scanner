package com.example.flutter_receipt_scanner_android

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Android plugin registration. Skeleton milestone: `scan` is not implemented
 * and returns an `unimplemented` error so the federated wiring can be verified
 * end-to-end before the native scanner path lands.
 */
class FlutterReceiptScannerPlugin :
    FlutterPlugin,
    ReceiptScannerApi {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ReceiptScannerApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ReceiptScannerApi.setUp(binding.binaryMessenger, null)
    }

    override fun scan(
        options: ScanOptionsWire,
        callback: (Result<ScanResultWire>) -> Unit,
    ) {
        callback(
            Result.failure(
                FlutterError("unimplemented", "Android scan is not implemented yet.", null),
            ),
        )
    }
}

package com.example.flutter_receipt_scanner_android

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/**
 * Android plugin. Camera path only: routes `source: camera` through the GMS ML
 * Kit Document Scanner and processes each page (orientation, OCR + rotation,
 * JPEG, EXIF). The GMS result returns via [PluginRegistry.ActivityResultListener],
 * so the plugin is [ActivityAware] and holds the Pigeon callback across the trip.
 */
class FlutterReceiptScannerPlugin :
    FlutterPlugin,
    ActivityAware,
    ReceiptScannerApi,
    PluginRegistry.ActivityResultListener {
    private var appContext: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private var pendingCallback: ((Result<ScanResultWire>) -> Unit)? = null
    private var pendingOptions: ScanOptionsWire? = null

    private companion object {
        const val SCAN_REQUEST_CODE = 0x5EC0
    }

    // MARK: - FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        ReceiptScannerApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ReceiptScannerApi.setUp(binding.binaryMessenger, null)
        appContext = null
    }

    // MARK: - ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    // MARK: - ReceiptScannerApi

    override fun scan(
        options: ScanOptionsWire,
        callback: (Result<ScanResultWire>) -> Unit,
    ) {
        if (pendingCallback != null) {
            callback(Result.failure(FlutterError("scan_in_progress", "A scan is already in progress.", null)))
            return
        }
        if ((options.source ?: ScanSourceWire.CAMERA) != ScanSourceWire.CAMERA) {
            callback(Result.failure(FlutterError("unimplemented", "source: gallery is not implemented yet.", null)))
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            callback(Result.failure(FlutterError("no_activity", "Plugin is not attached to an Activity.", null)))
            return
        }

        pendingCallback = callback
        pendingOptions = options
        executor.execute { appContext?.let { ImageProcessor.deletePreviousSessionFiles(it) } }

        val maxPages = maxOf(1, (options.maxPages ?: 1).toInt())
        val scannerOptions =
            GmsDocumentScannerOptions
                .Builder()
                .setGalleryImportAllowed(false)
                .setPageLimit(maxPages)
                .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
                .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
                .build()

        GmsDocumentScanning
            .getClient(scannerOptions)
            .getStartScanIntent(activity)
            .addOnSuccessListener { intentSender ->
                runCatching {
                    activity.startIntentSenderForResult(intentSender, SCAN_REQUEST_CODE, null, 0, 0, 0)
                }.onFailure { reject("scanner_launch_failed", it.message) }
            }.addOnFailureListener { reject("scanner_init_failed", it.message) }
    }

    // MARK: - ActivityResultListener

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode != SCAN_REQUEST_CODE) return false
        if (pendingCallback == null) return true

        if (resultCode == Activity.RESULT_CANCELED) {
            resolve(ScanResultWire(status = ScanStatusWire.CANCELLED, images = emptyList(), rejectedImages = emptyList()))
            return true
        }
        val result = GmsDocumentScanningResult.fromActivityResultIntent(data)
        val pages = result?.pages ?: emptyList()
        val options = pendingOptions ?: ScanOptionsWire()

        executor.execute {
            val context = appContext
            if (context == null) {
                reject("no_context", "Application context unavailable.")
                return@execute
            }
            val ocr = OcrProcessor()
            try {
                val images =
                    pages.mapNotNull { page ->
                        ResultBuilder.processCameraPage(context, page.imageUri, options, ocr)
                    }
                if (images.isEmpty() && pages.isNotEmpty()) {
                    reject("processing_failed", "Failed to process the scanned pages.")
                } else {
                    resolve(ScanResultWire(status = ScanStatusWire.SUCCESS, images = images, rejectedImages = emptyList()))
                }
            } catch (e: OutOfMemoryError) {
                reject("out_of_memory", e.message)
            } finally {
                ocr.close()
            }
        }
        return true
    }

    private fun resolve(result: ScanResultWire) {
        val callback = pendingCallback
        pendingCallback = null
        pendingOptions = null
        mainHandler.post { callback?.invoke(Result.success(result)) }
    }

    private fun reject(
        code: String,
        message: String?,
    ) {
        val callback = pendingCallback
        pendingCallback = null
        pendingOptions = null
        mainHandler.post { callback?.invoke(Result.failure(FlutterError(code, message, null))) }
    }
}

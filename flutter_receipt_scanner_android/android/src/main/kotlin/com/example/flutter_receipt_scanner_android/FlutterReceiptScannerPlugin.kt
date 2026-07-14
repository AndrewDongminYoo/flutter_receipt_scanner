package com.example.flutter_receipt_scanner_android

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
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
        const val GALLERY_REQUEST_CODE = 0x5EC1
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
        val activity = activityBinding?.activity
        if (activity == null) {
            callback(Result.failure(FlutterError("no_activity", "Plugin is not attached to an Activity.", null)))
            return
        }

        pendingCallback = callback
        pendingOptions = options
        executor.execute { appContext?.let { ImageProcessor.deletePreviousSessionFiles(it) } }

        val maxPages = maxOf(1, (options.maxPages ?: 1).toInt())

        // Gallery path: the system photo picker + custom quad-crop editor live in
        // CropEditorActivity, which returns cached file:// URIs + per-image corners.
        // Android always shows the editor — cropAutoConfirm is ignored (port map §2.4).
        if ((options.source ?: ScanSourceWire.CAMERA) == ScanSourceWire.GALLERY) {
            runCatching {
                @Suppress("DEPRECATION")
                activity.startActivityForResult(
                    Intent(activity, CropEditorActivity::class.java)
                        .putExtra(CropEditorActivity.EXTRA_MAX_IMAGES, maxPages),
                    GALLERY_REQUEST_CODE,
                )
            }.onFailure { reject("GALLERY_LAUNCH_FAILED", it.message) }
            return
        }

        // Camera path: GMS ML Kit Document Scanner.
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
                }.onFailure { reject("SCANNER_LAUNCH_FAILED", it.message) }
            }.addOnFailureListener { reject("SCANNER_INIT_FAILED", friendlyScannerInitMessage(it.message)) }
    }

    /**
     * Maps a GMS scanner-init failure into guidance. GmsNetworkStack / AuthPII errors mean
     * Play Services is missing or outdated, so surface an actionable message instead of the
     * raw internal exception text (port map §1.2).
     */
    private fun friendlyScannerInitMessage(raw: String?): String {
        val message = raw.orEmpty()
        return if (message.contains("GmsNetworkStack") || message.contains("AuthPII")) {
            "Google Play services must be updated to run the document scanner; please update it and retry."
        } else {
            message.ifEmpty { "Failed to initialize the document scanner." }
        }
    }

    // MARK: - ActivityResultListener

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean =
        when (requestCode) {
            SCAN_REQUEST_CODE -> {
                handleCameraResult(resultCode, data)
                true
            }

            GALLERY_REQUEST_CODE -> {
                handleGalleryResult(resultCode, data)
                true
            }

            else -> {
                false
            }
        }

    private fun handleCameraResult(
        resultCode: Int,
        data: Intent?,
    ) {
        if (pendingCallback == null) return

        if (resultCode == Activity.RESULT_CANCELED) {
            resolve(ScanResultWire(status = ScanStatusWire.CANCELLED, images = emptyList(), rejectedImages = emptyList()))
            return
        }
        val result = GmsDocumentScanningResult.fromActivityResultIntent(data)
        val pages = result?.pages ?: emptyList()
        val options = pendingOptions ?: ScanOptionsWire()

        executor.execute {
            val context = appContext
            if (context == null) {
                reject("NO_CONTEXT", "Application context unavailable.")
                return@execute
            }
            val ocr = OcrProcessor()
            try {
                val images =
                    pages.mapNotNull { page ->
                        ResultBuilder.processCameraPage(context, page.imageUri, options, ocr)
                    }
                if (images.isEmpty() && pages.isNotEmpty()) {
                    reject("PROCESSING_FAILED", "Failed to process the scanned pages.")
                } else {
                    resolve(ScanResultWire(status = ScanStatusWire.SUCCESS, images = images, rejectedImages = emptyList()))
                }
            } catch (e: OutOfMemoryError) {
                reject("OUT_OF_MEMORY", e.message)
            } finally {
                ocr.close()
            }
        }
    }

    private fun handleGalleryResult(
        resultCode: Int,
        data: Intent?,
    ) {
        if (pendingCallback == null) return
        val options = pendingOptions ?: ScanOptionsWire()

        val uris = data?.getStringArrayExtra(CropEditorActivity.EXTRA_ORIGINAL_URIS)
        val allCorners = data?.getFloatArrayExtra(CropEditorActivity.EXTRA_ALL_CORNERS)
        if (resultCode != Activity.RESULT_OK || uris.isNullOrEmpty() || allCorners == null) {
            resolve(ScanResultWire(status = ScanStatusWire.CANCELLED, images = emptyList(), rejectedImages = emptyList()))
            return
        }

        executor.execute {
            val context = appContext
            if (context == null) {
                reject("NO_CONTEXT", "Application context unavailable.")
                return@execute
            }
            val ocr = OcrProcessor()
            try {
                val images =
                    uris.mapIndexedNotNull { i, uriStr ->
                        val uri = Uri.parse(uriStr)
                        val corners =
                            allCorners.copyOfRange(
                                i * CropEditorActivity.CORNERS_PER_IMAGE,
                                (i + 1) * CropEditorActivity.CORNERS_PER_IMAGE,
                            )
                        ResultBuilder.processGalleryImage(context, uri, corners, options, ocr)
                    }
                if (images.isEmpty() && uris.isNotEmpty()) {
                    reject("PROCESSING_FAILED", "Failed to process the selected images.")
                } else {
                    resolve(ScanResultWire(status = ScanStatusWire.SUCCESS, images = images, rejectedImages = emptyList()))
                }
            } catch (e: OutOfMemoryError) {
                reject("OUT_OF_MEMORY", e.message)
            } finally {
                ocr.close()
            }
        }
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

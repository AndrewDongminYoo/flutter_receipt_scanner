package com.example.flutter_receipt_scanner_android

import android.content.Context
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.TextRecognizerOptionsInterface
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

/**
 * The ML Kit Text Recognition v2 script families this package ships.
 *
 * Korean is the bundled model (in the APK, always ready); the rest are Google
 * Play services dynamically delivered recognizers, so their readiness must be
 * queried before a scan runs.
 */
enum class OcrScriptFamily(
    val bundled: Boolean,
    /** Unicode script identifiers reported for this family. */
    val scripts: List<String>,
) {
    KOREAN(bundled = true, scripts = listOf("Kore")),
    LATIN(bundled = false, scripts = listOf("Latn")),
    JAPANESE(bundled = false, scripts = listOf("Jpan")),
    CHINESE(bundled = false, scripts = listOf("Hans", "Hant")),
    DEVANAGARI(bundled = false, scripts = listOf("Deva")),
    ;

    /** Fresh recognizer options for this family. */
    fun options(): TextRecognizerOptionsInterface =
        when (this) {
            KOREAN -> KoreanTextRecognizerOptions.Builder().build()
            LATIN -> TextRecognizerOptions.Builder().build()
            JAPANESE -> JapaneseTextRecognizerOptions.Builder().build()
            CHINESE -> ChineseTextRecognizerOptions.Builder().build()
            DEVANAGARI -> DevanagariTextRecognizerOptions.Builder().build()
        }

    /** A new recognizer client for this family. Callers must `close()` it. */
    fun newRecognizer(): TextRecognizer = TextRecognition.getClient(options())
}

/**
 * Reports which script models can recognize text now.
 *
 * Read-only by contract: never triggers a download and never opens UI. Blocks
 * on [Tasks.await], so it must be called from a background thread.
 */
object OcrModelProvider {
    /** One entry per reported Unicode script, in [OcrScriptFamily] order. */
    fun capabilities(context: Context): List<OcrModelStateWire> {
        val moduleInstall = ModuleInstall.getClient(context)
        return OcrScriptFamily.entries.flatMap { family ->
            val status =
                if (family.bundled) {
                    OcrModelStatusWire.READY
                } else {
                    availabilityOf(family, moduleInstall)
                }
            family.scripts.map { OcrModelStateWire(script = it, status = status) }
        }
    }

    private fun availabilityOf(
        family: OcrScriptFamily,
        moduleInstall: com.google.android.gms.common.moduleinstall.ModuleInstallClient,
    ): OcrModelStatusWire {
        val recognizer = family.newRecognizer()
        return try {
            val response = Tasks.await(moduleInstall.areModulesAvailable(recognizer))
            if (response.areModulesAvailable()) OcrModelStatusWire.READY else OcrModelStatusWire.DOWNLOAD_REQUIRED
        } catch (e: Exception) {
            // An unavailable or unknown module is not an error for a read-only
            // capability query — report it as needing a download.
            OcrModelStatusWire.DOWNLOAD_REQUIRED
        } finally {
            recognizer.close()
        }
    }
}

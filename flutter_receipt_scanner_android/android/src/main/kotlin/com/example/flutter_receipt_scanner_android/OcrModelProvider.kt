package com.example.flutter_receipt_scanner_android

import android.content.Context
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.TextRecognizerOptionsInterface
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

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

/** Why a requested language list cannot be served by an ML Kit recognizer. */
sealed class OcrLanguageException(
    val code: String,
    override val message: String,
) : Exception(message) {
    /** A tag is empty or ICU produced no language identifier. */
    class Invalid(
        tag: String,
    ) : OcrLanguageException(
            "INVALID_OCR_LANGUAGE",
            "Not a usable BCP 47 language tag: \"$tag\".",
        )

    /** A syntactically valid tag that resolves to no supported script. */
    class NotSupported(
        tag: String,
    ) : OcrLanguageException(
            "OCR_LANGUAGE_NOT_SUPPORTED",
            "On-device text recognition does not support \"$tag\".",
        )

    /** More than one non-Latin script family was requested. */
    class CombinationNotSupported(
        scripts: Collection<String>,
    ) : OcrLanguageException(
            "OCR_LANGUAGE_COMBINATION_NOT_SUPPORTED",
            "Only one non-Latin script can be recognized per scan; got ${scripts.joinToString(", ")}.",
        )

    /** The dynamic module install failed. */
    class InstallFailed(
        message: String,
    ) : OcrLanguageException("OCR_MODEL_INSTALL_FAILED", message)
}

/**
 * Resolves BCP 47 language hints to exactly one ML Kit recognizer.
 *
 * ML Kit selects a model by script, not by language priority, so tags are
 * mapped to their likely Unicode script with ICU. Latin may accompany one
 * non-Latin family because every non-Latin recognizer also reads the Latin
 * characters mixed into receipts.
 */
object OcrScriptResolver {
    private val SCRIPT_TO_FAMILY =
        mapOf(
            "Latn" to OcrScriptFamily.LATIN,
            "Kore" to OcrScriptFamily.KOREAN,
            "Hang" to OcrScriptFamily.KOREAN,
            "Jpan" to OcrScriptFamily.JAPANESE,
            "Hira" to OcrScriptFamily.JAPANESE,
            "Kana" to OcrScriptFamily.JAPANESE,
            "Hans" to OcrScriptFamily.CHINESE,
            "Hant" to OcrScriptFamily.CHINESE,
            "Hani" to OcrScriptFamily.CHINESE,
            "Deva" to OcrScriptFamily.DEVANAGARI,
        )

    /**
     * Returns the single family serving [tags].
     *
     * @throws OcrLanguageException when a tag is unusable, resolves to no
     *   supported script, or the list needs more than one non-Latin family.
     */
    fun resolve(tags: List<String>): OcrScriptFamily {
        if (tags.isEmpty()) throw OcrLanguageException.Invalid("")
        val families = LinkedHashSet<OcrScriptFamily>()
        for (tag in tags) {
            val trimmed = tag.trim()
            if (trimmed.isEmpty()) throw OcrLanguageException.Invalid(tag)
            val locale =
                android.icu.util.ULocale
                    .addLikelySubtags(
                        android.icu.util.ULocale
                            .forLanguageTag(trimmed),
                    )
            // A private-use tag such as "x-private" parses but carries no
            // language — that is a capability failure, not a syntax one.
            if (locale.language.isNullOrEmpty()) throw OcrLanguageException.NotSupported(tag)
            families += SCRIPT_TO_FAMILY[locale.script] ?: throw OcrLanguageException.NotSupported(tag)
        }
        val nonLatin = families.filter { it != OcrScriptFamily.LATIN }
        return when {
            nonLatin.size > 1 -> throw OcrLanguageException.CombinationNotSupported(nonLatin.map { it.name })
            nonLatin.size == 1 -> nonLatin.single()
            else -> OcrScriptFamily.LATIN
        }
    }
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

    /**
     * Blocks until [family]'s model can recognize text, installing it when the
     * provider offers a download.
     *
     * Bundled families return immediately. Must be called from a background
     * thread; the install listener is always unregistered before returning.
     *
     * @throws OcrLanguageException with `OCR_MODEL_INSTALL_FAILED` when the
     *   module is unknown or its installation does not complete.
     */
    fun ensureInstalled(
        context: Context,
        family: OcrScriptFamily,
    ) {
        if (family.bundled) return
        val moduleInstall = ModuleInstall.getClient(context)
        val recognizer = family.newRecognizer()
        try {
            if (Tasks.await(moduleInstall.areModulesAvailable(recognizer)).areModulesAvailable()) return
            val latch = CountDownLatch(1)
            val failure = AtomicReference<String?>(null)
            val listener =
                InstallStatusListener { update ->
                    when (update.installState) {
                        ModuleInstallStatusUpdate.InstallState.STATE_COMPLETED -> {
                            latch.countDown()
                        }

                        ModuleInstallStatusUpdate.InstallState.STATE_FAILED -> {
                            failure.set("Installation failed with error code ${update.errorCode}.")
                            latch.countDown()
                        }

                        ModuleInstallStatusUpdate.InstallState.STATE_CANCELED -> {
                            failure.set("Installation was cancelled.")
                            latch.countDown()
                        }

                        else -> {
                            Unit
                        }
                    }
                }
            val request =
                ModuleInstallRequest
                    .newBuilder()
                    .addApi(recognizer)
                    .setListener(listener)
                    .build()
            try {
                val response = Tasks.await(moduleInstall.installModules(request))
                // Already present: no update is ever delivered to the listener.
                if (response.areModulesAlreadyInstalled()) return
                if (!latch.await(INSTALL_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                    throw installFailed("Timed out waiting for the ${family.name} OCR model to install.")
                }
                failure.get()?.let { throw installFailed("${family.name} OCR model: $it") }
            } finally {
                moduleInstall.unregisterListener(listener)
            }
        } catch (e: OcrLanguageException) {
            throw e
        } catch (e: Exception) {
            throw installFailed("${family.name} OCR model is unavailable: ${e.message ?: "unknown module"}")
        } finally {
            recognizer.close()
        }
    }

    private const val INSTALL_TIMEOUT_SECONDS = 120L

    private fun installFailed(message: String) = OcrLanguageException.InstallFailed(message)
}

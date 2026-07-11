package com.example.flutter_receipt_scanner_android

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** EXIF white-list plus the subset written back to the output file. */
class ExifResult(
    val wire: ReceiptExifWire,
    private val make: String?,
    private val model: String?,
    private val software: String?,
    private val dateTime: String?,
    private val dateTimeOriginal: String?,
    private val dateTimeDigitized: String?,
) {
    /** Writes the durable subset to [file] as `ORIENTATION_NORMAL`. Must run last. */
    fun writeTo(file: File) {
        val exif = ExifInterface(file.absolutePath)
        exif.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
        make?.let { exif.setAttribute(ExifInterface.TAG_MAKE, it) }
        model?.let { exif.setAttribute(ExifInterface.TAG_MODEL, it) }
        software?.let { exif.setAttribute(ExifInterface.TAG_SOFTWARE, it) }
        dateTime?.let { exif.setAttribute(ExifInterface.TAG_DATETIME, it) }
        dateTimeOriginal?.let { exif.setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, it) }
        dateTimeDigitized?.let { exif.setAttribute(ExifInterface.TAG_DATETIME_DIGITIZED, it) }
        exif.saveAttributes()
    }
}

/**
 * Bitmap decode, orientation, JPEG recompression, EXIF read/synthesis/write, and
 * the cache-file lifecycle. Faithful port of the RN `ImageProcessor`.
 */
object ImageProcessor {
    private const val FILE_PREFIX = "receipt_"

    /** Deletes the previous session's `receipt_*.jpg` cache files. */
    fun deletePreviousSessionFiles(context: Context) {
        context.cacheDir
            .listFiles()
            ?.filter { it.name.startsWith(FILE_PREFIX) }
            ?.forEach { it.delete() }
    }

    /** Decodes [uri] and applies its source EXIF rotation so pixels are upright. */
    fun decodeOriented(
        context: Context,
        uri: Uri,
    ): Bitmap? {
        val decoded =
            context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it)
            } ?: return null
        val orientation =
            context.contentResolver.openInputStream(uri)?.use {
                ExifInterface(it).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            } ?: ExifInterface.ORIENTATION_NORMAL
        return applyExifOrientation(decoded, orientation)
    }

    /** Rotates [bitmap] clockwise by 90/180/270 degrees (Android convention). */
    fun rotate(
        bitmap: Bitmap,
        degreesCw: Int,
    ): Bitmap {
        val d = ((degreesCw % 360) + 360) % 360
        if (d == 0) return bitmap
        val matrix = Matrix().apply { postRotate(d.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    /** Encodes [bitmap] to a JPEG cache file at [quality] (0.0–1.0). */
    fun encodeJpeg(
        context: Context,
        bitmap: Bitmap,
        quality: Double,
    ): File? {
        val file = File(context.cacheDir, "$FILE_PREFIX${System.currentTimeMillis()}.jpg")
        val q = (quality * 100).toInt().coerceIn(1, 100)
        return runCatching {
            file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, q, it) }
            file
        }.getOrNull()
    }

    /**
     * Reads the source EXIF white-list. For camera captures (document scanner
     * drops source EXIF) missing device info is synthesized so the result carries
     * a `make`/`model`/`dateTimeOriginal`.
     */
    fun readExif(
        context: Context,
        uri: Uri,
        includeExif: Boolean,
        synthesizeDeviceInfo: Boolean,
    ): ExifResult? {
        if (!includeExif) return null
        val exif = context.contentResolver.openInputStream(uri)?.use { ExifInterface(it) }
        val now = timestamp()

        val make =
            exif?.getAttribute(ExifInterface.TAG_MAKE)
                ?: if (synthesizeDeviceInfo) Build.MANUFACTURER else null
        val model =
            exif?.getAttribute(ExifInterface.TAG_MODEL)
                ?: if (synthesizeDeviceInfo) Build.MODEL else null
        val software = exif?.getAttribute(ExifInterface.TAG_SOFTWARE)
        val dateTime = exif?.getAttribute(ExifInterface.TAG_DATETIME)
        val dateTimeOriginal =
            exif?.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
                ?: if (synthesizeDeviceInfo) now else null
        val dateTimeDigitized = exif?.getAttribute(ExifInterface.TAG_DATETIME_DIGITIZED)

        val wire =
            ReceiptExifWire(
                orientation = 1L,
                make = make,
                model = model,
                software = software,
                dateTime = dateTime,
                dateTimeOriginal = dateTimeOriginal,
                dateTimeDigitized = dateTimeDigitized,
                iso =
                    exif
                        ?.getAttributeInt(ExifInterface.TAG_ISO_SPEED_RATINGS, 0)
                        ?.takeIf { it > 0 }
                        ?.toDouble(),
                fNumber = exif?.getAttributeDouble(ExifInterface.TAG_F_NUMBER, 0.0)?.takeIf { it > 0 },
                focalLength =
                    exif
                        ?.getAttributeDouble(ExifInterface.TAG_FOCAL_LENGTH, 0.0)
                        ?.takeIf { it > 0 },
                flash = exif?.getAttributeInt(ExifInterface.TAG_FLASH, -1)?.takeIf { it >= 0 }?.toLong(),
                whiteBalance =
                    exif
                        ?.getAttributeInt(ExifInterface.TAG_WHITE_BALANCE, -1)
                        ?.takeIf { it >= 0 }
                        ?.toLong(),
            )
        return ExifResult(
            wire = wire,
            make = make,
            model = model,
            software = software,
            dateTime = dateTime,
            dateTimeOriginal = dateTimeOriginal,
            dateTimeDigitized = dateTimeDigitized,
        )
    }

    private fun applyExifOrientation(
        bitmap: Bitmap,
        orientation: Int,
    ): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun timestamp(): String = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US).format(Date())
}

package com.example.flutter_receipt_scanner_android

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.util.Log
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.sqrt

/** Perspective-corrected gallery bitmap plus its parsed source EXIF. */
class GalleryImage(
    val bitmap: Bitmap,
    val exif: ExifResult?,
)

/** EXIF white-list plus the subset written back to the output file. */
class ExifResult(
    val wire: ReceiptExifWire,
    private val make: String?,
    private val model: String?,
    private val software: String?,
    private val dateTime: String?,
    private val dateTimeOriginal: String?,
    private val dateTimeDigitized: String?,
    private val gpsLatitude: Double? = null,
    private val gpsLongitude: Double? = null,
    private val gpsAltitude: Double? = null,
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
        val lat = gpsLatitude
        val lng = gpsLongitude
        if (lat != null && lng != null) exif.setLatLong(lat, lng)
        gpsAltitude?.let { exif.setAltitude(it) }
        exif.saveAttributes()
    }
}

/**
 * Bitmap decode, orientation, JPEG recompression, EXIF read/synthesis/write, and
 * the cache-file lifecycle. Faithful port of the RN `ImageProcessor`.
 */
object ImageProcessor {
    private const val FILE_PREFIX = "receipt_"
    private const val LOG_TAG = "ReceiptScanner.Image"

    /**
     * Longer-side cap (px) for the gallery re-decode. Lower than 4096 because
     * [applyExifRotation]'s transient peak is risky on 2GB-RAM devices; raising it
     * costs visible OCR accuracy only above ~3000 px on Korean receipts.
     */
    private const val GALLERY_MAX_DIM = 3072

    /** EXIF tag values whose payload is binary or large enough to bloat the IPC bridge. */
    private val rawTagDenyList: Set<String> =
        setOf(
            "JPEGInterchangeFormat",
            "JPEGInterchangeFormatLength",
            "ThumbnailImageWidth",
            "ThumbnailImageLength",
            "ThumbnailImage",
            "MakerNote",
            "UserComment",
        )

    /**
     * All standard EXIF tag *names* exposed by ExifInterface as `TAG_*` String constants,
     * resolved once via reflection so the list is not hand-maintained.
     */
    private val rawTagNames: List<String> by lazy {
        ExifInterface::class
            .java
            .declaredFields
            .asSequence()
            .filter { f ->
                f.name.startsWith("TAG_") &&
                    java.lang.reflect.Modifier
                        .isStatic(f.modifiers) &&
                    f.type == String::class.java
            }.mapNotNull { f ->
                try {
                    f.isAccessible = true
                    f.get(null) as? String
                } catch (_: Exception) {
                    null
                }
            }.toList()
    }

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

    /**
     * Gallery path: re-decodes [uri] at [GALLERY_MAX_DIM], re-applies the source EXIF
     * rotation, scales the full-resolution [corners] into the decoded bitmap's space
     * (the editor measured them against the 2048-px preview decode, so the sample
     * factors differ), perspective-corrects, and reads the source EXIF.
     *
     * Returns the corrected bitmap (NOT yet OCR-rotated or encoded) plus the parsed
     * EXIF. The caller runs OCR on the bitmap, applies any autoRotate, encodes the
     * JPEG, then writes EXIF last — mirroring [ResultBuilder.processCameraPage].
     * (RN encoded inside `processGallery` and OCR'd the file; this port OCRs the
     * in-memory bitmap for parity with the camera path — behavior-neutral.)
     *
     * @param corners `[tl.x, tl.y, tr.x, tr.y, br.x, br.y, bl.x, bl.y]` in full-resolution pixels.
     */
    fun processGallery(
        context: Context,
        uri: Uri,
        corners: FloatArray,
        includeExif: Boolean,
        includeGpsExif: Boolean,
        includeRawExif: Boolean,
    ): GalleryImage {
        val exifOrientation = readExifOrientation(context, uri)
        val (raw, sample) = decodeBitmapSampled(context, uri, GALLERY_MAX_DIM)
        val oriented = applyExifRotation(raw, exifOrientation)
        // corners arrive in full-resolution oriented space (the editor's originalWidth/Height,
        // derived from the 2048 preview sample); scale by 1/sample to match this decode.
        val scaledCorners =
            if (sample == 1) {
                corners
            } else {
                val factor = 1f / sample.toFloat()
                FloatArray(corners.size) { i -> corners[i] * factor }
            }
        val corrected = perspectiveCorrectedBitmap(oriented, scaledCorners)
        oriented.recycle()

        // Pixels are already rotation-corrected; force orientation NORMAL so callers don't
        // apply a second rotation. Gallery imports honestly report null device info
        // (synthesizeDeviceInfo = false), unlike the camera path.
        val exif =
            if (includeExif) {
                readGalleryExif(context, uri, includeGpsExif, includeRawExif)
            } else {
                null
            }
        return GalleryImage(corrected, exif)
    }

    /**
     * Infers imageOrigin from the MediaStore bucket name, with an EXIF heuristic as
     * fallback. Never returns `download` from the EXIF fallback — a gallery image with
     * no camera metadata is `unknown` unless the bucket name explicitly matches
     * `download`/`downloads` (Android/iOS intended asymmetry, port map §7.2).
     *
     * Note: as wired by [CropEditorActivity], [uri] is a `file://` cache copy, so the
     * MediaStore branch is effectively inert and the EXIF heuristic decides — matching RN.
     */
    fun inferOrigin(
        context: Context,
        uri: Uri,
        exif: ExifResult?,
    ): ImageOriginWire {
        if (uri.scheme == "content") {
            try {
                context.contentResolver
                    .query(
                        uri,
                        arrayOf(MediaStore.Images.Media.BUCKET_DISPLAY_NAME),
                        null,
                        null,
                        null,
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            when (cursor.getString(0)?.lowercase()) {
                                "camera" -> return ImageOriginWire.CAMERA
                                "screenshots", "screenshot" -> return ImageOriginWire.SCREENSHOT
                                "download", "downloads" -> return ImageOriginWire.DOWNLOAD
                            }
                        }
                    }
            } catch (_: Exception) {
            }
        }
        val wire = exif?.wire
        if (wire?.dateTimeOriginal != null) return ImageOriginWire.CAMERA
        if (wire?.make != null && wire.model != null) return ImageOriginWire.CAMERA
        return ImageOriginWire.UNKNOWN
    }

    /**
     * Reads the full source EXIF white-list (+ GPS, + raw passthrough) for the gallery
     * path. `orientation` is forced to `NORMAL` because the output pixels are upright;
     * device info is never synthesized (gallery imports report honest nulls).
     */
    private fun readGalleryExif(
        context: Context,
        uri: Uri,
        includeGps: Boolean,
        includeRawExif: Boolean,
    ): ExifResult {
        val exif = openExif(context, uri) ?: return emptyGalleryExif()

        val make = exif.getAttribute(ExifInterface.TAG_MAKE)
        val model = exif.getAttribute(ExifInterface.TAG_MODEL)
        val software = exif.getAttribute(ExifInterface.TAG_SOFTWARE)
        val dateTime = exif.getAttribute(ExifInterface.TAG_DATETIME)
        val dateTimeOriginal = exif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
        val dateTimeDigitized = exif.getAttribute(ExifInterface.TAG_DATETIME_DIGITIZED)

        var gpsLat: Double? = null
        var gpsLng: Double? = null
        if (includeGps) {
            val latLon = FloatArray(2)
            @Suppress("DEPRECATION")
            if (exif.getLatLong(latLon)) {
                gpsLat = latLon[0].toDouble()
                gpsLng = latLon[1].toDouble()
            }
        }
        val gpsAlt = if (includeGps) exif.getAltitudeOrNull() else null
        val gps =
            if (gpsLat != null && gpsLng != null) {
                GpsDataWire(
                    latitude = gpsLat,
                    longitude = gpsLng,
                    altitude = gpsAlt,
                    timestamp = if (includeGps) exif.getAttribute(ExifInterface.TAG_GPS_TIMESTAMP) else null,
                    speed = if (includeGps) exif.getAttributeDoubleOrNull(ExifInterface.TAG_GPS_SPEED) else null,
                    heading =
                        if (includeGps) {
                            exif.getAttributeDoubleOrNull(ExifInterface.TAG_GPS_IMG_DIRECTION)
                                ?: exif.getAttributeDoubleOrNull(ExifInterface.TAG_GPS_DEST_BEARING)
                        } else {
                            null
                        },
                )
            } else {
                null
            }

        val wire =
            ReceiptExifWire(
                orientation = ExifInterface.ORIENTATION_NORMAL.toLong(),
                colorSpace = exif.getAttributeIntOrNull(ExifInterface.TAG_COLOR_SPACE)?.toLong(),
                lightSource = exif.getAttributeIntOrNull(ExifInterface.TAG_LIGHT_SOURCE)?.toLong(),
                exifVersion = exif.getAttribute(ExifInterface.TAG_EXIF_VERSION),
                make = make,
                model = model,
                software = software,
                dateTime = dateTime,
                dateTimeOriginal = dateTimeOriginal,
                dateTimeDigitized = dateTimeDigitized,
                exposureTime = exif.getAttributeDoubleOrNull(ExifInterface.TAG_EXPOSURE_TIME),
                fNumber = exif.getAttributeDoubleOrNull(ExifInterface.TAG_F_NUMBER),
                iso =
                    (
                        exif.getAttributeIntOrNull(ExifInterface.TAG_ISO_SPEED)
                            ?: exif.getAttributeIntOrNull(ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY)
                    )?.toDouble(),
                focalLength = exif.getAttributeDoubleOrNull(ExifInterface.TAG_FOCAL_LENGTH),
                flash = exif.getAttributeIntOrNull(ExifInterface.TAG_FLASH)?.toLong(),
                whiteBalance = exif.getAttributeIntOrNull(ExifInterface.TAG_WHITE_BALANCE)?.toLong(),
                exposureMode = exif.getAttributeIntOrNull(ExifInterface.TAG_EXPOSURE_MODE)?.toLong(),
                exposureProgram = exif.getAttributeIntOrNull(ExifInterface.TAG_EXPOSURE_PROGRAM)?.toLong(),
                meteringMode = exif.getAttributeIntOrNull(ExifInterface.TAG_METERING_MODE)?.toLong(),
                gps = gps,
                raw = if (includeRawExif) buildRawExifMap(exif, includeGps) else null,
            )

        return ExifResult(
            wire = wire,
            make = make,
            model = model,
            software = software,
            dateTime = dateTime,
            dateTimeOriginal = dateTimeOriginal,
            dateTimeDigitized = dateTimeDigitized,
            gpsLatitude = gpsLat,
            gpsLongitude = gpsLng,
            gpsAltitude = gpsAlt,
        )
    }

    private fun emptyGalleryExif(): ExifResult =
        ExifResult(
            wire = ReceiptExifWire(orientation = ExifInterface.ORIENTATION_NORMAL.toLong()),
            make = null,
            model = null,
            software = null,
            dateTime = null,
            dateTimeOriginal = null,
            dateTimeDigitized = null,
        )

    private fun openExif(
        context: Context,
        uri: Uri,
    ): ExifInterface? =
        if (uri.scheme == "content") {
            context.contentResolver.openInputStream(uri)?.use { ExifInterface(it) }
        } else {
            uri.path?.let { ExifInterface(it) }
        }

    private fun ExifInterface.getAttributeDoubleOrNull(tag: String): Double? {
        val value = getAttributeDouble(tag, Double.NaN)
        return if (value.isNaN()) null else value
    }

    private fun ExifInterface.getAttributeIntOrNull(tag: String): Int? {
        val value = getAttributeInt(tag, Int.MIN_VALUE)
        return if (value == Int.MIN_VALUE) null else value
    }

    private fun ExifInterface.getAltitudeOrNull(): Double? {
        val value = getAltitude(Double.NaN)
        return if (value.isNaN()) null else value
    }

    /**
     * Flat map of every `ExifInterface.TAG_*` string attribute with a non-null value.
     * Binary/thumbnail fields are excluded; GPS-prefixed tags are skipped when
     * [includeGps] is false. Values are the raw strings ExifInterface returns.
     */
    private fun buildRawExifMap(
        exif: ExifInterface,
        includeGps: Boolean,
    ): Map<String, Any?> {
        val raw = LinkedHashMap<String, Any?>(rawTagNames.size)
        for (tag in rawTagNames) {
            if (!includeGps && tag.startsWith("GPS")) continue
            if (rawTagDenyList.contains(tag)) continue
            val value = exif.getAttribute(tag) ?: continue
            raw[tag] = value
        }
        return raw
    }

    // Reads EXIF TAG_ORIENTATION without decoding the full bitmap.
    private fun readExifOrientation(
        context: Context,
        uri: Uri,
    ): Int =
        try {
            openExif(context, uri)
                ?.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                ?: ExifInterface.ORIENTATION_NORMAL
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }

    /**
     * Decodes [uri] with `inSampleSize` chosen so the longer side fits within [maxDim].
     * Returns the bitmap plus the power-of-two `inSampleSize` applied; coordinates in the
     * full-resolution source must be scaled by `1 / sample` to map into the decoded bitmap.
     */
    fun decodeBitmapSampled(
        context: Context,
        uri: Uri,
        maxDim: Int,
    ): Pair<Bitmap, Int> {
        val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        if (uri.scheme == "content") {
            openContentStream(context, uri).use { BitmapFactory.decodeStream(it, null, boundsOpts) }
        } else {
            val path = requireNotNull(uri.path) { "URI has no path: $uri" }
            BitmapFactory.decodeFile(path, boundsOpts)
        }

        var sample = 1
        var w = boundsOpts.outWidth
        var h = boundsOpts.outHeight
        while (w > maxDim || h > maxDim) {
            sample *= 2
            w /= 2
            h /= 2
        }

        val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap =
            if (uri.scheme == "content") {
                openContentStream(context, uri).use { BitmapFactory.decodeStream(it, null, decodeOpts) }
            } else {
                BitmapFactory.decodeFile(requireNotNull(uri.path), decodeOpts)
            } ?: throw IllegalArgumentException("Failed to decode image: $uri")
        return Pair(bitmap, sample)
    }

    /**
     * Rotates [bitmap] per [exifOrientation] (an `ExifInterface.ORIENTATION_*` constant),
     * recycling [bitmap] and returning the rotated copy when rotation is needed; otherwise
     * returns [bitmap] unchanged. Caller owns the returned bitmap. Handles the transpose /
     * transverse cases the camera-path helper does not.
     */
    fun applyExifRotation(
        bitmap: Bitmap,
        exifOrientation: Int,
    ): Bitmap {
        val matrix = Matrix()
        when (exifOrientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> {
                matrix.postRotate(90f)
            }

            ExifInterface.ORIENTATION_ROTATE_180 -> {
                matrix.postRotate(180f)
            }

            ExifInterface.ORIENTATION_ROTATE_270 -> {
                matrix.postRotate(270f)
            }

            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> {
                matrix.postScale(-1f, 1f)
            }

            ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                matrix.postScale(1f, -1f)
            }

            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postScale(-1f, 1f)
                matrix.postRotate(90f)
            }

            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postScale(-1f, 1f)
                matrix.postRotate(270f)
            }

            else -> {
                return bitmap
            }
        }
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        bitmap.recycle()
        return rotated
    }

    // Applies a perspective warp from the source quad to a canonical output rectangle.
    // Caller must recycle the returned bitmap. Does not recycle [bitmap].
    private fun perspectiveCorrectedBitmap(
        bitmap: Bitmap,
        corners: FloatArray,
    ): Bitmap {
        require(corners.size == 8) { "corners must have 8 elements" }
        if (QuadGeometry.isDistorted(corners)) {
            return boundingBoxCrop(bitmap, corners)
        }
        val tlX = corners[0]
        val tlY = corners[1]
        val trX = corners[2]
        val trY = corners[3]
        val brX = corners[4]
        val brY = corners[5]
        val blX = corners[6]
        val blY = corners[7]

        fun dist(
            ax: Float,
            ay: Float,
            bx: Float,
            by: Float,
        ) = sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))

        val topW = dist(tlX, tlY, trX, trY)
        val botW = dist(blX, blY, brX, brY)
        val leftH = dist(tlX, tlY, blX, blY)
        val rightH = dist(trX, trY, brX, brY)

        val outW = ((topW + botW) / 2f).toInt().coerceAtLeast(1)
        val outH = ((leftH + rightH) / 2f).toInt().coerceAtLeast(1)

        val dst =
            floatArrayOf(
                0f,
                0f,
                outW.toFloat(),
                0f,
                outW.toFloat(),
                outH.toFloat(),
                0f,
                outH.toFloat(),
            )

        val matrix = Matrix()
        matrix.setPolyToPoly(corners, 0, dst, 0, 4)

        val output = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        canvas.drawBitmap(bitmap, matrix, Paint(Paint.FILTER_BITMAP_FLAG))
        return output
    }

    // Distorted quad → crop the axis-aligned bounding box of the corners instead of warping.
    private fun boundingBoxCrop(
        bitmap: Bitmap,
        corners: FloatArray,
    ): Bitmap {
        val xs = floatArrayOf(corners[0], corners[2], corners[4], corners[6])
        val ys = floatArrayOf(corners[1], corners[3], corners[5], corners[7])
        val left = xs.min().toInt().coerceIn(0, bitmap.width - 1)
        val top = ys.min().toInt().coerceIn(0, bitmap.height - 1)
        val right = xs.max().toInt().coerceIn(left + 1, bitmap.width)
        val bottom = ys.max().toInt().coerceIn(top + 1, bitmap.height)
        val cropped = Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
        // createBitmap can return the SAME instance for a full-frame immutable crop; the
        // contract is that the return is always independently recyclable, so copy in that case.
        return if (cropped === bitmap) {
            cropped.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, false)
        } else {
            cropped
        }
    }

    /**
     * Open a `content://` [uri] as an [InputStream], falling back to
     * [android.content.ContentResolver.openFileDescriptor] when `openInputStream`
     * returns null (the Photo Picker provider graceful-nulls on some URIs).
     */
    private fun openContentStream(
        context: Context,
        uri: Uri,
    ): InputStream {
        val cr = context.contentResolver
        cr.openInputStream(uri)?.let { return it }
        Log.w(LOG_TAG, "openInputStream returned null; falling back to openFileDescriptor uri=$uri")
        val pfd =
            cr.openFileDescriptor(uri, "r")
                ?: throw IOException("Cannot open content URI: $uri (mimeType=${cr.getType(uri)})")
        return ParcelFileDescriptor.AutoCloseInputStream(pfd)
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

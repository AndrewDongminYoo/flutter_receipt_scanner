import 'package:flutter_receipt_scanner_platform_interface/src/models/gps_data.dart';

/// Per-image EXIF metadata. White-list fields are populated when the platform
/// exposes them; values are normalized across platforms. Reach into [raw] (with
/// `includeRawExif: true`) for tags outside the white-list.
///
/// Note: the white-list [orientation] is always `1` (output pixels are
/// orientation-normalized); `raw['Orientation']` holds the original value.
final class ReceiptExif {
  /// Creates an EXIF white-list block.
  const ReceiptExif({
    this.orientation,
    this.colorSpace,
    this.lightSource,
    this.exifVersion,
    this.make,
    this.model,
    this.software,
    this.dateTime,
    this.dateTimeOriginal,
    this.dateTimeDigitized,
    this.exposureTime,
    this.fNumber,
    this.iso,
    this.focalLength,
    this.flash,
    this.whiteBalance,
    this.exposureMode,
    this.exposureProgram,
    this.meteringMode,
    this.gps,
    this.raw,
  });

  /// Always `1` — output pixels are orientation-normalized.
  final int? orientation;

  /// EXIF `ColorSpace` tag. `1` = sRGB, `65535` = uncalibrated.
  final int? colorSpace;

  /// EXIF `LightSource` tag.
  final int? lightSource;

  /// EXIF version string, e.g. `"0220"`.
  final String? exifVersion;

  /// TIFF `Make` tag — manufacturer string.
  final String? make;

  /// TIFF `Model` tag — device model string.
  final String? model;

  /// TIFF `Software` tag. Use the value, not mere presence, for fraud filtering.
  final String? software;

  /// TIFF `DateTime` tag (file modification time).
  final String? dateTime;

  /// EXIF `DateTimeOriginal` tag (shutter moment).
  final String? dateTimeOriginal;

  /// EXIF `DateTimeDigitized` tag (digitization moment).
  final String? dateTimeDigitized;

  /// Exposure time in seconds.
  final double? exposureTime;

  /// Aperture f-number.
  final double? fNumber;

  /// ISO sensitivity, normalized to a single number.
  final double? iso;

  /// Focal length in millimeters.
  final double? focalLength;

  /// EXIF `Flash` tag (bitfield).
  final int? flash;

  /// EXIF `WhiteBalance` tag. `0` = auto, `1` = manual.
  final int? whiteBalance;

  /// EXIF `ExposureMode` tag.
  final int? exposureMode;

  /// EXIF `ExposureProgram` tag.
  final int? exposureProgram;

  /// EXIF `MeteringMode` tag.
  final int? meteringMode;

  /// GPS coordinates (only when `includeGpsExif` is true).
  final GpsData? gps;

  /// Raw EXIF/TIFF/GPS attributes (only when `includeRawExif` is true). Binary
  /// fields are excluded; GPS keys are absent unless `includeGpsExif` is true.
  final Map<String, Object?>? raw;
}

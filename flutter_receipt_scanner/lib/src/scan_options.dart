import 'package:flutter_receipt_scanner/src/ocr_floor.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// Dart-facing scan options. Every field has a default from
/// [kDefaultScanOptions] and is filled before the native call.
class ScanReceiptOptions {
  /// Creates options; omitted fields use the package defaults.
  const ScanReceiptOptions({
    this.source = ScanSource.camera,
    this.maxPages = 1,
    this.quality = 0.82,
    this.includeExif = true,
    this.includeGpsExif = false,
    this.ocr = true,
    this.cropAutoConfirm = false,
    this.autoRotate = true,
    this.includeRawExif = false,
    this.minimumTextHeight = 0,
    this.ocrFloor = const OcrFloorOrDisabled.floor(kDefaultOcrFloor),
  });

  /// Acquisition path.
  final ScanSource source;

  /// Maximum pages the user may capture (coerced to `>= 1` natively).
  final int maxPages;

  /// JPEG compression quality in `[0.0, 1.0]`.
  final double quality;

  /// Read and attach the normalized EXIF white-list.
  final bool includeExif;

  /// Copy the GPS dictionary onto `exif.gps` when present in the source.
  final bool includeGpsExif;

  /// Run on-device OCR and attach the joined text.
  final bool ocr;

  /// Skip the crop editor on a high-confidence quadrilateral (gallery only).
  final bool cropAutoConfirm;

  /// Rotate output pixels to the upright orientation using the OCR signal.
  final bool autoRotate;

  /// Include the full raw EXIF/TIFF/GPS dictionary on `exif.raw`.
  final bool includeRawExif;

  /// iOS-only Vision `minimumTextHeight` fraction; `0` uses the package default.
  final double minimumTextHeight;

  /// Acceptance gate applied in Dart after the native call.
  final OcrFloorOrDisabled ocrFloor;

  /// Maps to the Pigeon wire type. `ocrFloor` is intentionally not sent — the
  /// gate is applied in Dart so native stays at image primitives (ADR-003).
  ScanOptions toMessage() => ScanOptions(
    source: source,
    maxPages: maxPages,
    quality: quality,
    includeExif: includeExif,
    includeGpsExif: includeGpsExif,
    ocr: ocr,
    cropAutoConfirm: cropAutoConfirm,
    autoRotate: autoRotate,
    includeRawExif: includeRawExif,
    minimumTextHeight: minimumTextHeight,
  );
}

/// The package-default options.
const ScanReceiptOptions kDefaultScanOptions = ScanReceiptOptions();

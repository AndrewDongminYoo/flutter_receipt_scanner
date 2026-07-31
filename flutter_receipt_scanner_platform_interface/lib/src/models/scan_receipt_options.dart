import 'package:flutter_receipt_scanner_platform_interface/src/models/ocr_capabilities.dart';
import 'package:flutter_receipt_scanner_platform_interface/src/models/scan_enums.dart';

/// Native-facing scan options. This is the contract forwarded to a platform
/// implementation; the Dart-side OCR-floor gate is configured separately by the
/// app-facing package, so it is intentionally absent here.
final class ScanReceiptOptions {
  /// Creates scan options. Every field has a receipt-tuned default.
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
    this.ocrGeometry = false,
    this.ocrLanguages = kDefaultOcrLanguages,
  });

  /// Acquisition path.
  final ScanSource source;

  /// Maximum pages the user may capture (coerced to `1..10` natively).
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

  /// Attach per-line OCR text-region boxes on `ReceiptImage.ocrLines`. Requires
  /// [ocr]; the boxes are expressed in the output image's pixel space.
  final bool ocrGeometry;

  /// Ordered BCP 47 language hints for on-device OCR. Effective only when [ocr]
  /// is `true`; the first entry has the highest priority on platforms that
  /// support ordered languages.
  ///
  /// Android selects one recognizer per script rather than by language
  /// priority, so the order is retained for API parity there.
  final List<String> ocrLanguages;

  /// Returns a copy with [ocrLanguages] replaced. Used by the app-facing
  /// package to forward the normalized language list.
  ScanReceiptOptions copyWith({List<String>? ocrLanguages}) => ScanReceiptOptions(
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
    ocrGeometry: ocrGeometry,
    ocrLanguages: ocrLanguages ?? this.ocrLanguages,
  );
}

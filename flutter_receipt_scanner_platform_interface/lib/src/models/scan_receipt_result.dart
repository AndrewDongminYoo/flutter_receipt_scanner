import 'package:flutter_receipt_scanner_platform_interface/src/models/merged_ocr_result.dart';
import 'package:flutter_receipt_scanner_platform_interface/src/models/receipt_image.dart';
import 'package:flutter_receipt_scanner_platform_interface/src/models/scan_enums.dart';

/// Result of a scan. [status] is the primary discriminator; [images] and
/// [rejectedImages] are always lists for interface symmetry.
final class ScanReceiptResult {
  /// Creates a scan result.
  const ScanReceiptResult({
    required this.status,
    this.images = const [],
    this.rejectedImages = const [],
    this.mergedOcr,
    this.discardedPageCount = 0,
  });

  /// Outcome of the scan.
  final ScanStatus status;

  /// Images that passed the OCR floor (or all images, when no floor applied).
  final List<ReceiptImage> images;

  /// Images captured but below the OCR floor. Always a list (possibly empty).
  final List<ReceiptImage> rejectedImages;

  /// Ordered OCR text assembled by the app-facing package when requested.
  final MergedOcrResult? mergedOcr;

  /// Natively captured pages dropped before processing.
  ///
  /// Non-zero only on iOS, whose VisionKit scanner cannot enforce a page limit
  /// in its UI: pages beyond `maxPages` are discarded and counted here.
  final int discardedPageCount;
}

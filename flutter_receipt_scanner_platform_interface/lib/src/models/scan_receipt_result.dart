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

  /// Captured or selected pages omitted from the native result.
  ///
  /// Includes pages beyond `maxPages`, image-processing failures on either
  /// platform, and iOS gallery photos skipped by cancelling their crop editor.
  /// Does not include [rejectedImages], which still have usable image results.
  /// iOS gallery batches with no returned images retain [ScanStatus.cancelled],
  /// including when processing failed; this count still reports their omissions.
  final int discardedPageCount;
}

import 'package:flutter_receipt_scanner_platform_interface/src/models/receipt_exif.dart';
import 'package:flutter_receipt_scanner_platform_interface/src/models/scan_enums.dart';

/// Derived OCR quality metrics. Populated whenever OCR ran.
final class OcrQuality {
  /// Creates OCR quality metrics.
  const OcrQuality({
    required this.textLength,
    required this.lineCount,
    this.confidence,
  });

  /// Character count of the trimmed OCR text.
  final int textLength;

  /// Number of non-empty lines in the OCR text.
  final int lineCount;

  /// Mean OCR confidence (0.0–1.0). Undefined when OCR was disabled or no text
  /// was recognized. Reporting-only until distributions are validated
  /// comparable across platforms.
  final double? confidence;
}

/// One recognized text line and the axis-aligned box it occupies.
///
/// Coordinates are top-left-origin pixels of the shipped image
/// ([ReceiptImage.width] x [ReceiptImage.height], post-rotation, post-crop).
/// Populated only when the `ocrGeometry` option was set. Lines with empty text
/// or a degenerate box are omitted, so this does not line up index-wise with
/// [ReceiptImage.ocrText]'s newline-separated lines.
final class OcrLine {
  /// Creates one OCR line box.
  const OcrLine({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.confidence,
  });

  /// The recognized line text.
  final String text;

  /// Left edge of the box, in output-image pixels.
  final int x;

  /// Top edge of the box, in output-image pixels.
  final int y;

  /// Box width in pixels.
  final int width;

  /// Box height in pixels.
  final int height;

  /// Per-line OCR confidence (0.0–1.0), when the recognizer reported one.
  final double? confidence;
}

/// One image returned by a scan. Backed by a JPEG file in the app cache
/// directory; the [uri] is stable until the next scan call and does not survive
/// app restarts.
final class ReceiptImage {
  /// Creates a receipt image.
  const ReceiptImage({
    required this.uri,
    required this.width,
    required this.height,
    required this.fileName,
    required this.fileSize,
    required this.imageOrigin,
    this.mimeType = 'image/jpeg',
    this.ocrText,
    this.ocrQuality,
    this.exif,
    this.ocrLines,
  });

  /// `file://`-scheme URI to the cached JPEG.
  final String uri;

  /// Pixel width of the output (post-rotation, post-crop).
  final int width;

  /// Pixel height of the output (post-rotation, post-crop).
  final int height;

  /// File name segment of [uri].
  final String fileName;

  /// File size in bytes.
  final int fileSize;

  /// Origin classification. Always present.
  final ImageOrigin imageOrigin;

  /// MIME type — always `image/jpeg` today.
  final String mimeType;

  /// OCR text joined by newlines. Present only when OCR ran.
  final String? ocrText;

  /// Derived OCR quality metrics. Present whenever OCR ran.
  final OcrQuality? ocrQuality;

  /// EXIF white-list. Present only when `includeExif` is true.
  final ReceiptExif? exif;

  /// Per-line OCR text-region boxes. Present only when `ocrGeometry` was set.
  final List<OcrLine>? ocrLines;

  /// Returns a copy with the given fields replaced.
  ReceiptImage copyWith({OcrQuality? ocrQuality}) => ReceiptImage(
    uri: uri,
    width: width,
    height: height,
    fileName: fileName,
    fileSize: fileSize,
    imageOrigin: imageOrigin,
    mimeType: mimeType,
    ocrText: ocrText,
    ocrQuality: ocrQuality ?? this.ocrQuality,
    exif: exif,
    ocrLines: ocrLines,
  );
}

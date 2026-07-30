import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// Acceptance thresholds applied to OCR output. When any field falls below its
/// floor, the corresponding image is moved from `images` into `rejectedImages`.
class OcrFloor {
  /// Creates a floor. Missing arguments fall back to the package defaults.
  const OcrFloor({
    this.minTextLength = 12,
    this.minLines = 2,
    this.minConfidence = 0,
  });

  /// Minimum trimmed text length, in characters.
  final int minTextLength;

  /// Minimum non-empty line count.
  final int minLines;

  /// Minimum mean OCR confidence (0.0–1.0). Reporting-only until distributions
  /// are validated comparable across platforms.
  final double minConfidence;
}

/// Package-default OCR floor.
const OcrFloor kDefaultOcrFloor = OcrFloor();

/// Either an active [OcrFloor] or an explicit "disabled" marker.
class OcrFloorOrDisabled {
  /// Wraps an active floor.
  const OcrFloorOrDisabled.floor(OcrFloor value) : _value = value, isDisabled = false;

  /// Disables the gate entirely.
  const OcrFloorOrDisabled.disabled() : _value = null, isDisabled = true;

  final OcrFloor? _value;

  /// Whether the gate is disabled.
  final bool isDisabled;

  /// The active floor. Only valid when [isDisabled] is `false`.
  OcrFloor get value => _value!;
}

/// Derives [OcrQuality] from joined OCR text (trimmed character count plus
/// non-empty line count), preserving native confidence when present.
OcrQuality deriveQuality(String text, {double? confidence}) {
  final trimmedLength = text.trim().length;
  var lineCount = 0;
  for (final line in text.split('\n')) {
    if (line.trim().isNotEmpty) lineCount++;
  }
  return OcrQuality(
    textLength: trimmedLength,
    lineCount: lineCount,
    confidence: confidence,
  );
}

bool _meetsFloor(OcrQuality q, OcrFloor floor) {
  if (q.textLength < floor.minTextLength) return false;
  if (q.lineCount < floor.minLines) return false;
  // Absent confidence => satisfied: never gate on a field that was not
  // produced (OCR disabled, or no text recognized).
  final c = q.confidence;
  if (c != null && c < floor.minConfidence) return false;
  return true;
}

/// Applies the acceptance gate to a native [ScanReceiptResult].
///
/// Non-success statuses pass through untouched. When the floor is disabled or
/// OCR did not run, every image passes with an empty `rejectedImages`.
/// Otherwise images are partitioned; if all fall below the floor the status
/// becomes [ScanStatus.rejected].
ScanReceiptResult applyOcrFloor(
  ScanReceiptResult native, {
  required bool ocr,
  required OcrFloorOrDisabled floor,
}) {
  if (native.status != ScanStatus.success) {
    return native;
  }

  final annotated = native.images.map((img) {
    final text = img.ocrText;
    if (text == null) return img;
    return img.copyWith(
      ocrQuality: deriveQuality(text, confidence: img.ocrQuality?.confidence),
    );
  }).toList();

  if (!ocr || floor.isDisabled) {
    return ScanReceiptResult(
      status: ScanStatus.success,
      images: annotated,
      discardedPageCount: native.discardedPageCount,
    );
  }

  final passed = <ReceiptImage>[];
  final rejected = <ReceiptImage>[];
  for (final img in annotated) {
    final q = img.ocrQuality;
    final ok = q != null && _meetsFloor(q, floor.value);
    (ok ? passed : rejected).add(img);
  }

  if (passed.isEmpty && rejected.isNotEmpty) {
    return ScanReceiptResult(
      status: ScanStatus.rejected,
      rejectedImages: rejected,
      discardedPageCount: native.discardedPageCount,
    );
  }
  return ScanReceiptResult(
    status: ScanStatus.success,
    images: passed,
    rejectedImages: rejected,
    discardedPageCount: native.discardedPageCount,
  );
}

import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptImage _img(String text, {double? confidence}) => ReceiptImage(
  uri: 'file:///tmp/a.jpg',
  width: 1,
  height: 1,
  fileName: 'a.jpg',
  fileSize: 1,
  imageOrigin: ImageOrigin.camera,
  ocrText: text,
  ocrQuality: confidence == null ? null : OcrQuality(textLength: 0, lineCount: 0, confidence: confidence),
);

void main() {
  test('deriveQuality counts trimmed length and non-empty lines', () {
    final q = deriveQuality('line one\n\n  line two  \n', confidence: 0.9);
    expect(q.textLength, 'line one\n\n  line two'.trim().length);
    expect(q.lineCount, 2);
    expect(q.confidence, 0.9);
  });

  test('ocr:false alone bypasses the gate even with an active floor', () {
    // Image is below the active floor (1 char < 12, 1 line < 2); it must still
    // pass because ocr is off — isolates the `!ocr` arm of the disjunction.
    final native = ScanReceiptResult(
      status: ScanStatus.success,
      images: [_img('x')],
    );
    final r = applyOcrFloor(
      native,
      ocr: false,
      floor: const OcrFloorOrDisabled.floor(kDefaultOcrFloor),
    );
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
    expect(r.rejectedImages, isEmpty);
  });

  test('disabled floor alone bypasses the gate even when ocr is true', () {
    // Same below-floor image, but with ocr on and the floor disabled — isolates
    // the `floor.isDisabled` arm of the disjunction.
    final native = ScanReceiptResult(
      status: ScanStatus.success,
      images: [_img('x')],
    );
    final r = applyOcrFloor(
      native,
      ocr: true,
      floor: const OcrFloorOrDisabled.disabled(),
    );
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
    expect(r.rejectedImages, isEmpty);
  });

  test('all images below floor -> rejected', () {
    final native = ScanReceiptResult(
      status: ScanStatus.success,
      images: [_img('short')], // 5 chars < 12, 1 line < 2
    );
    final r = applyOcrFloor(
      native,
      ocr: true,
      floor: const OcrFloorOrDisabled.floor(kDefaultOcrFloor),
    );
    expect(r.status, ScanStatus.rejected);
    expect(r.images, isEmpty);
    expect(r.rejectedImages.length, 1);
  });

  test('partial pass -> success with populated rejectedImages', () {
    final native = ScanReceiptResult(
      status: ScanStatus.success,
      images: [_img('a receipt line\nsecond line here'), _img('nope')],
    );
    final r = applyOcrFloor(
      native,
      ocr: true,
      floor: const OcrFloorOrDisabled.floor(kDefaultOcrFloor),
    );
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
    expect(r.rejectedImages.length, 1);
  });

  test('absent confidence is treated as satisfied', () {
    final native = ScanReceiptResult(
      status: ScanStatus.success,
      images: [_img('a receipt line\nsecond line here')], // no confidence
    );
    const floor = OcrFloorOrDisabled.floor(
      OcrFloor(minTextLength: 1, minLines: 1, minConfidence: 0.99),
    );
    final r = applyOcrFloor(native, ocr: true, floor: floor);
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
  });

  test('non-success native status passes through untouched', () {
    const native = ScanReceiptResult(status: ScanStatus.cancelled);
    final r = applyOcrFloor(
      native,
      ocr: true,
      floor: const OcrFloorOrDisabled.floor(kDefaultOcrFloor),
    );
    expect(r.status, ScanStatus.cancelled);
  });
}

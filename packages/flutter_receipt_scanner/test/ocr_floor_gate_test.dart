import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptImage _img(String text, {double? confidence}) => ReceiptImage(
  uri: 'file:///tmp/a.jpg',
  width: 1,
  height: 1,
  fileName: 'a.jpg',
  mimeType: 'image/jpeg',
  fileSize: 1,
  ocrText: text,
  ocrQuality: OcrQuality(confidence: confidence),
  imageOrigin: ImageOrigin.camera,
);

void main() {
  test('deriveQuality counts trimmed length and non-empty lines', () {
    final q = deriveQuality('line one\n\n  line two  \n', confidence: 0.9);
    expect(q.textLength, 'line one\n\n  line two'.trim().length);
    expect(q.lineCount, 2);
    expect(q.confidence, 0.9);
  });

  test('gate disabled when ocr is false: everything passes, no rejects', () {
    final native = ScanResult(status: ScanStatus.success, images: [_img('x')], rejectedImages: []);
    final r = applyOcrFloor(native, ocr: false, floor: const OcrFloorOrDisabled.disabled());
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
    expect(r.rejectedImages, isEmpty);
  });

  test('all images below floor -> rejected', () {
    final native = ScanResult(
      status: ScanStatus.success,
      images: [_img('short')], // 5 chars < 12, 1 line < 2
      rejectedImages: [],
    );
    final r = applyOcrFloor(native, ocr: true, floor: const OcrFloorOrDisabled.floor(kDefaultOcrFloor));
    expect(r.status, ScanStatus.rejected);
    expect(r.images, isEmpty);
    expect(r.rejectedImages.length, 1);
  });

  test('partial pass -> success with populated rejectedImages', () {
    final native = ScanResult(
      status: ScanStatus.success,
      images: [_img('a receipt line\nsecond line here'), _img('nope')],
      rejectedImages: [],
    );
    final r = applyOcrFloor(native, ocr: true, floor: const OcrFloorOrDisabled.floor(kDefaultOcrFloor));
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
    expect(r.rejectedImages.length, 1);
  });

  test('absent confidence is treated as satisfied', () {
    final native = ScanResult(
      status: ScanStatus.success,
      images: [_img('a receipt line\nsecond line here')], // no confidence
      rejectedImages: [],
    );
    const floor = OcrFloorOrDisabled.floor(OcrFloor(minTextLength: 1, minLines: 1, minConfidence: 0.99));
    final r = applyOcrFloor(native, ocr: true, floor: floor);
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
  });

  test('non-success native status passes through untouched', () {
    final native = ScanResult(status: ScanStatus.cancelled, images: [], rejectedImages: []);
    final r = applyOcrFloor(native, ocr: true, floor: const OcrFloorOrDisabled.floor(kDefaultOcrFloor));
    expect(r.status, ScanStatus.cancelled);
  });
}

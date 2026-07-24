import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

// Constructors are intentionally invoked WITHOUT `const` so the constructor
// lines register as executed under coverage (compile-time-const folding would
// otherwise leave the hand-written model constructors uncovered).
void main() {
  test('GpsData holds every field', () {
    const gps = GpsData(
      latitude: 37.5,
      longitude: 127,
      altitude: 12.3,
      timestamp: '2026:07:14 09:00:00',
      speed: 4.2,
      heading: 90,
    );

    expect(gps.latitude, 37.5);
    expect(gps.longitude, 127.0);
    expect(gps.altitude, 12.3);
    expect(gps.timestamp, '2026:07:14 09:00:00');
    expect(gps.speed, 4.2);
    expect(gps.heading, 90);
  });

  test('GpsData leaves optionals null when omitted', () {
    const gps = GpsData(latitude: 1, longitude: 2);

    expect(gps.altitude, isNull);
    expect(gps.timestamp, isNull);
    expect(gps.speed, isNull);
    expect(gps.heading, isNull);
  });

  test('ReceiptExif holds the white-list fields, gps and raw', () {
    const exif = ReceiptExif(
      orientation: 1,
      colorSpace: 1,
      lightSource: 0,
      exifVersion: '0220',
      make: 'Apple',
      model: 'iPhone 15',
      software: '17.0',
      dateTime: '2026:07:14 09:00:00',
      dateTimeOriginal: '2026:07:14 08:59:00',
      dateTimeDigitized: '2026:07:14 08:59:30',
      exposureTime: 0.02,
      fNumber: 1.8,
      iso: 100,
      focalLength: 5.1,
      flash: 16,
      whiteBalance: 0,
      exposureMode: 0,
      exposureProgram: 2,
      meteringMode: 5,
      gps: GpsData(latitude: 37.5, longitude: 127),
      raw: {'Orientation': 6},
    );

    expect(exif.orientation, 1);
    expect(exif.colorSpace, 1);
    expect(exif.lightSource, 0);
    expect(exif.exifVersion, '0220');
    expect(exif.make, 'Apple');
    expect(exif.model, 'iPhone 15');
    expect(exif.software, '17.0');
    expect(exif.dateTime, '2026:07:14 09:00:00');
    expect(exif.dateTimeOriginal, '2026:07:14 08:59:00');
    expect(exif.dateTimeDigitized, '2026:07:14 08:59:30');
    expect(exif.exposureTime, 0.02);
    expect(exif.fNumber, 1.8);
    expect(exif.iso, 100);
    expect(exif.focalLength, 5.1);
    expect(exif.flash, 16);
    expect(exif.whiteBalance, 0);
    expect(exif.exposureMode, 0);
    expect(exif.exposureProgram, 2);
    expect(exif.meteringMode, 5);
    expect(exif.gps!.latitude, 37.5);
    expect(exif.raw!['Orientation'], 6);
  });

  test('ReceiptExif defaults every field to null', () {
    const exif = ReceiptExif();

    expect(exif.orientation, isNull);
    expect(exif.gps, isNull);
    expect(exif.raw, isNull);
  });

  test('OcrQuality holds derived metrics', () {
    const quality = OcrQuality(textLength: 42, lineCount: 5, confidence: 0.9);

    expect(quality.textLength, 42);
    expect(quality.lineCount, 5);
    expect(quality.confidence, 0.9);
  });

  test('OcrQuality leaves confidence null when omitted', () {
    const quality = OcrQuality(textLength: 1, lineCount: 1);

    expect(quality.confidence, isNull);
  });

  test(
    'ReceiptImage holds every field and defaults mimeType to image/jpeg',
    () {
      const image = ReceiptImage(
        uri: 'file:///tmp/receipt.jpg',
        width: 800,
        height: 1200,
        fileName: 'receipt.jpg',
        fileSize: 4096,
        imageOrigin: ImageOrigin.camera,
        ocrText: 'line one\nline two',
        ocrQuality: OcrQuality(textLength: 16, lineCount: 2, confidence: 0.8),
        exif: ReceiptExif(make: 'Apple'),
        ocrLines: [
          OcrLine(
            text: 'line one',
            x: 10,
            y: 20,
            width: 100,
            height: 18,
            confidence: 0.9,
          ),
        ],
      );

      expect(image.uri, 'file:///tmp/receipt.jpg');
      expect(image.width, 800);
      expect(image.height, 1200);
      expect(image.fileName, 'receipt.jpg');
      expect(image.fileSize, 4096);
      expect(image.imageOrigin, ImageOrigin.camera);
      expect(image.mimeType, 'image/jpeg');
      expect(image.ocrText, 'line one\nline two');
      expect(image.ocrQuality!.textLength, 16);
      expect(image.exif!.make, 'Apple');
      expect(image.ocrLines!.single.text, 'line one');
      expect(image.ocrLines!.single.x, 10);
      expect(image.ocrLines!.single.height, 18);
      expect(image.ocrLines!.single.confidence, 0.9);
    },
  );

  test('ReceiptImage leaves optional OCR/EXIF fields null when omitted', () {
    const image = ReceiptImage(
      uri: 'file:///tmp/bare.jpg',
      width: 1,
      height: 1,
      fileName: 'bare.jpg',
      fileSize: 1,
      imageOrigin: ImageOrigin.unknown,
    );

    expect(image.ocrText, isNull);
    expect(image.ocrQuality, isNull);
    expect(image.exif, isNull);
  });

  test('ReceiptImage.copyWith replaces ocrQuality and preserves the rest', () {
    const original = ReceiptImage(
      uri: 'file:///tmp/receipt.jpg',
      width: 800,
      height: 1200,
      fileName: 'receipt.jpg',
      fileSize: 4096,
      imageOrigin: ImageOrigin.screenshot,
      ocrText: 'raw',
      ocrQuality: OcrQuality(textLength: 3, lineCount: 1),
      exif: ReceiptExif(make: 'Google'),
    );

    final replaced = original.copyWith(
      ocrQuality: const OcrQuality(
        textLength: 20,
        lineCount: 4,
        confidence: 0.95,
      ),
    );

    // Replaced field takes the new value.
    expect(replaced.ocrQuality!.textLength, 20);
    expect(replaced.ocrQuality!.confidence, 0.95);
    // Every other field is carried over unchanged.
    expect(replaced.uri, original.uri);
    expect(replaced.width, original.width);
    expect(replaced.height, original.height);
    expect(replaced.fileName, original.fileName);
    expect(replaced.fileSize, original.fileSize);
    expect(replaced.imageOrigin, original.imageOrigin);
    expect(replaced.mimeType, original.mimeType);
    expect(replaced.ocrText, original.ocrText);
    expect(replaced.exif, same(original.exif));
  });

  test(
    'ReceiptImage.copyWith keeps the existing ocrQuality when none is given',
    () {
      const quality = OcrQuality(textLength: 3, lineCount: 1);
      const original = ReceiptImage(
        uri: 'file:///tmp/receipt.jpg',
        width: 1,
        height: 1,
        fileName: 'receipt.jpg',
        fileSize: 1,
        imageOrigin: ImageOrigin.camera,
        ocrQuality: quality,
      );

      // No ocrQuality passed => `?? this.ocrQuality` keeps the original.
      expect(original.copyWith().ocrQuality, same(quality));
    },
  );

  test('ScanReceiptOptions applies receipt-tuned defaults', () {
    const options = ScanReceiptOptions();

    expect(options.source, ScanSource.camera);
    expect(options.maxPages, 1);
    expect(options.quality, 0.82);
    expect(options.includeExif, isTrue);
    expect(options.includeGpsExif, isFalse);
    expect(options.ocr, isTrue);
    expect(options.cropAutoConfirm, isFalse);
    expect(options.autoRotate, isTrue);
    expect(options.includeRawExif, isFalse);
    expect(options.minimumTextHeight, 0);
    expect(options.ocrGeometry, isFalse);
  });

  test('ScanReceiptOptions overrides every default', () {
    const options = ScanReceiptOptions(
      source: ScanSource.gallery,
      maxPages: 3,
      quality: 0.5,
      includeExif: false,
      includeGpsExif: true,
      ocr: false,
      cropAutoConfirm: true,
      autoRotate: false,
      includeRawExif: true,
      minimumTextHeight: 0.25,
      ocrGeometry: true,
    );

    expect(options.source, ScanSource.gallery);
    expect(options.maxPages, 3);
    expect(options.quality, 0.5);
    expect(options.includeExif, isFalse);
    expect(options.includeGpsExif, isTrue);
    expect(options.ocr, isFalse);
    expect(options.cropAutoConfirm, isTrue);
    expect(options.autoRotate, isFalse);
    expect(options.includeRawExif, isTrue);
    expect(options.minimumTextHeight, 0.25);
    expect(options.ocrGeometry, isTrue);
  });

  test(
    'ScanReceiptResult defaults images and rejectedImages to empty lists',
    () {
      const result = ScanReceiptResult(status: ScanStatus.cancelled);

      expect(result.status, ScanStatus.cancelled);
      expect(result.images, isEmpty);
      expect(result.rejectedImages, isEmpty);
    },
  );
}

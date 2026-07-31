import 'package:flutter_receipt_scanner_ios/flutter_receipt_scanner_ios.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the wire options it receives and returns a canned wire result,
/// so the test exercises the pure wire<->model conversion in the registrant.
class _FakeReceiptScannerApi extends ReceiptScannerApi {
  _FakeReceiptScannerApi(this._result, {OcrCapabilitiesWire? capabilities})
    : _capabilities = capabilities ?? OcrCapabilitiesWire();

  final ScanResultWire _result;
  final OcrCapabilitiesWire _capabilities;
  ScanOptionsWire? captured;

  @override
  Future<ScanResultWire> scan(ScanOptionsWire options) async {
    captured = options;
    return _result;
  }

  @override
  Future<OcrCapabilitiesWire> getOcrCapabilities() async => _capabilities;
}

ScanResultWire _emptySuccess() => ScanResultWire(
  status: ScanStatusWire.success,
  images: <ReceiptImageWire>[],
  rejectedImages: <ReceiptImageWire>[],
);

void main() {
  test('scan maps ScanReceiptOptions to the wire options', () async {
    final fake = _FakeReceiptScannerApi(_emptySuccess());
    await FlutterReceiptScannerIos(api: fake).scan(
      const ScanReceiptOptions(
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
      ),
    );

    final wire = fake.captured!;
    expect(wire.source, ScanSourceWire.gallery);
    expect(wire.maxPages, 3);
    expect(wire.quality, 0.5);
    expect(wire.includeExif, false);
    expect(wire.includeGpsExif, true);
    expect(wire.ocr, false);
    expect(wire.cropAutoConfirm, true);
    expect(wire.autoRotate, false);
    expect(wire.includeRawExif, true);
    expect(wire.minimumTextHeight, 0.25);
    expect(wire.ocrLanguages, ['ko-KR', 'en-US']);
  });

  test('scan forwards a custom ocrLanguages list on the wire', () async {
    final fake = _FakeReceiptScannerApi(_emptySuccess());
    await FlutterReceiptScannerIos(api: fake).scan(
      const ScanReceiptOptions(ocrLanguages: ['ja-JP', 'en-US']),
    );

    expect(fake.captured!.ocrLanguages, ['ja-JP', 'en-US']);
  });

  test('getOcrCapabilities maps supported languages to the public model', () async {
    final fake = _FakeReceiptScannerApi(
      _emptySuccess(),
      capabilities: OcrCapabilitiesWire(supportedLanguages: <String>['ko-KR', 'en-US', 'ja-JP']),
    );

    final capabilities = await FlutterReceiptScannerIos(api: fake).getOcrCapabilities();

    expect(capabilities, isA<IosOcrCapabilities>());
    expect((capabilities as IosOcrCapabilities).supportedLanguages, ['ko-KR', 'en-US', 'ja-JP']);
    expect(capabilities.defaultLanguages, ['ko-KR', 'en-US']);
  });

  test('getOcrCapabilities defaults an absent language list to empty', () async {
    final fake = _FakeReceiptScannerApi(_emptySuccess(), capabilities: OcrCapabilitiesWire());

    final capabilities = await FlutterReceiptScannerIos(api: fake).getOcrCapabilities();

    expect((capabilities as IosOcrCapabilities).supportedLanguages, isEmpty);
  });

  test(
    'scan maps wire discardedPageCount and defaults an absent one to zero',
    () async {
      final withCount = ScanResultWire(
        status: ScanStatusWire.success,
        images: <ReceiptImageWire>[],
        rejectedImages: <ReceiptImageWire>[],
        discardedPageCount: 2,
      );
      final mapped = await FlutterReceiptScannerIos(
        api: _FakeReceiptScannerApi(withCount),
      ).scan(const ScanReceiptOptions());
      expect(mapped.discardedPageCount, 2);

      final absent = await FlutterReceiptScannerIos(
        api: _FakeReceiptScannerApi(_emptySuccess()),
      ).scan(const ScanReceiptOptions());
      expect(absent.discardedPageCount, 0);
    },
  );

  test(
    'scan maps the wire result (status, images, exif, gps) to models',
    () async {
      final image = ReceiptImageWire(
        uri: 'file:///tmp/receipt_1.jpg',
        width: 800,
        height: 1200,
        fileName: 'receipt_1.jpg',
        mimeType: 'image/jpeg',
        fileSize: 4096,
        imageOrigin: ImageOriginWire.screenshot,
        ocrText: 'line one\nline two',
        // Native sends confidence only; textLength/lineCount are null on the wire.
        ocrQuality: OcrQualityWire(confidence: 0.9),
        exif: ReceiptExifWire(
          orientation: 1,
          make: 'Apple',
          gps: GpsDataWire(latitude: 37.5, longitude: 127, altitude: 12.3),
        ),
        ocrLines: <OcrLineWire>[
          OcrLineWire(
            text: 'line one',
            x: 10,
            y: 20,
            width: 300,
            height: 40,
            confidence: 0.87,
          ),
        ],
      );
      final rejected = ReceiptImageWire(
        uri: 'file:///tmp/receipt_2.jpg',
        width: 10,
        height: 10,
        fileName: 'receipt_2.jpg',
        mimeType: 'image/jpeg',
        fileSize: 128,
        imageOrigin: ImageOriginWire.unknown,
      );
      final fake = _FakeReceiptScannerApi(
        ScanResultWire(
          status: ScanStatusWire.success,
          images: <ReceiptImageWire>[image],
          rejectedImages: <ReceiptImageWire>[rejected],
        ),
      );

      final result = await FlutterReceiptScannerIos(
        api: fake,
      ).scan(const ScanReceiptOptions());

      expect(result.status, ScanStatus.success);
      expect(result.images, hasLength(1));
      expect(result.rejectedImages, hasLength(1));

      final img = result.images.single;
      expect(img.uri, 'file:///tmp/receipt_1.jpg');
      expect(img.imageOrigin, ImageOrigin.screenshot);
      expect(img.ocrText, 'line one\nline two');
      // Null wire textLength/lineCount coerce to 0; confidence is preserved.
      expect(img.ocrQuality!.textLength, 0);
      expect(img.ocrQuality!.lineCount, 0);
      expect(img.ocrQuality!.confidence, 0.9);
      expect(img.exif!.make, 'Apple');
      expect(img.exif!.gps!.latitude, 37.5);
      expect(img.exif!.gps!.longitude, 127.0);
      final line = img.ocrLines!.single;
      expect(line.text, 'line one');
      expect(line.x, 10);
      expect(line.y, 20);
      expect(line.width, 300);
      expect(line.height, 40);
      expect(line.confidence, 0.87);
      expect(result.rejectedImages.single.imageOrigin, ImageOrigin.unknown);
      expect(result.rejectedImages.single.ocrLines, isNull);
    },
  );

  test('scan drops GPS when latitude or longitude is missing', () async {
    final fake = _FakeReceiptScannerApi(
      ScanResultWire(
        status: ScanStatusWire.success,
        images: <ReceiptImageWire>[
          ReceiptImageWire(
            uri: 'file:///tmp/receipt_3.jpg',
            width: 800,
            height: 1200,
            fileName: 'receipt_3.jpg',
            mimeType: 'image/jpeg',
            fileSize: 4096,
            imageOrigin: ImageOriginWire.camera,
            exif: ReceiptExifWire(
              // Longitude missing => guard drops the whole GpsData.
              gps: GpsDataWire(latitude: 37.5),
            ),
          ),
        ],
        rejectedImages: <ReceiptImageWire>[],
      ),
    );

    final result = await FlutterReceiptScannerIos(
      api: fake,
    ).scan(const ScanReceiptOptions());

    expect(result.images.single.exif!.gps, isNull);
  });

  test('scan maps the cancelled wire status', () async {
    final fake = _FakeReceiptScannerApi(
      ScanResultWire(
        status: ScanStatusWire.cancelled,
        images: <ReceiptImageWire>[],
        rejectedImages: <ReceiptImageWire>[],
      ),
    );

    final result = await FlutterReceiptScannerIos(
      api: fake,
    ).scan(const ScanReceiptOptions());

    expect(result.status, ScanStatus.cancelled);
  });

  test('scan maps the rejected wire status and download origin', () async {
    final fake = _FakeReceiptScannerApi(
      ScanResultWire(
        status: ScanStatusWire.rejected,
        images: <ReceiptImageWire>[],
        rejectedImages: <ReceiptImageWire>[
          ReceiptImageWire(
            uri: 'file:///tmp/receipt_4.jpg',
            width: 640,
            height: 480,
            fileName: 'receipt_4.jpg',
            mimeType: 'image/jpeg',
            fileSize: 256,
            imageOrigin: ImageOriginWire.download,
          ),
        ],
      ),
    );

    final result = await FlutterReceiptScannerIos(
      api: fake,
    ).scan(const ScanReceiptOptions());

    expect(result.status, ScanStatus.rejected);
    expect(result.rejectedImages.single.imageOrigin, ImageOrigin.download);
  });
}

import 'dart:collection';

import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptImage _image(String uri, String? text) => ReceiptImage(
  uri: uri,
  width: 1200,
  height: 2640,
  fileName: uri.split('/').last,
  fileSize: 1,
  imageOrigin: ImageOrigin.camera,
  ocrText: text,
);

const _defaultResult = ScanReceiptResult(
  status: ScanStatus.success,
  images: [
    ReceiptImage(
      uri: 'file:///tmp/a.jpg',
      width: 1200,
      height: 2640,
      fileName: 'a.jpg',
      fileSize: 1,
      imageOrigin: ImageOrigin.camera,
      ocrText: 'a receipt line\nsecond line',
      ocrQuality: OcrQuality(textLength: 0, lineCount: 0, confidence: 0.9),
    ),
  ],
);

class _RecordingPlatform extends FlutterReceiptScannerPlatform {
  _RecordingPlatform({this.result = _defaultResult, this._capabilities});

  final ScanReceiptResult result;
  final OcrCapabilities? _capabilities;
  ScanReceiptOptions? received;
  int callCount = 0;
  int capabilityCallCount = 0;

  @override
  Future<ScanReceiptResult> scan(ScanReceiptOptions options) async {
    callCount++;
    received = options;
    return result;
  }

  @override
  Future<OcrCapabilities> getOcrCapabilities() async {
    capabilityCallCount++;
    return _capabilities!;
  }
}

final class _ChangingIterationList extends ListBase<ReceiptImage> {
  _ChangingIterationList(this._firstIteration, this._laterIterations);

  final List<ReceiptImage> _firstIteration;
  final List<ReceiptImage> _laterIterations;
  var _iterationCount = 0;

  @override
  Iterator<ReceiptImage> get iterator => (_iterationCount++ == 0 ? _firstIteration : _laterIterations).iterator;

  @override
  int get length => (_iterationCount == 0 ? _firstIteration : _laterIterations).length;

  @override
  set length(int value) => throw UnsupportedError('Immutable test list');

  @override
  ReceiptImage operator [](int index) => (_iterationCount == 0 ? _firstIteration : _laterIterations)[index];

  @override
  void operator []=(int index, ReceiptImage value) => throw UnsupportedError('Immutable test list');
}

void main() {
  test(
    'scan forwards options and leaves page merging disabled by default',
    () async {
      final platform = _RecordingPlatform();
      FlutterReceiptScannerPlatform.instance = platform;

      final result = await scan(
        options: const ScanReceiptOptions(maxPages: 3),
      );

      expect(platform.received?.maxPages, 3);
      expect(platform.callCount, 1);
      expect(result.status, ScanStatus.success);
      expect(result.images.length, 1);
      expect(result.mergedOcr, isNull);
    },
  );

  group('ocrLanguages', () {
    test('forwards the package default when the caller sets none', () async {
      final platform = _RecordingPlatform();
      FlutterReceiptScannerPlatform.instance = platform;

      await scan();

      expect(platform.received?.ocrLanguages, ['ko-KR', 'en-US']);
    });

    test('trims tags and drops duplicates preserving priority', () async {
      final platform = _RecordingPlatform();
      FlutterReceiptScannerPlatform.instance = platform;

      await scan(
        options: const ScanReceiptOptions(
          ocrLanguages: [' ja-JP ', 'en-US', 'ja-JP', '  en-US'],
        ),
      );

      expect(platform.received?.ocrLanguages, ['ja-JP', 'en-US']);
    });

    test('preserves every other option while normalizing', () async {
      final platform = _RecordingPlatform();
      FlutterReceiptScannerPlatform.instance = platform;

      await scan(
        options: const ScanReceiptOptions(maxPages: 5, quality: 0.4, ocrLanguages: [' hi-IN ']),
      );

      expect(platform.received?.ocrLanguages, ['hi-IN']);
      expect(platform.received?.maxPages, 5);
      expect(platform.received?.quality, 0.4);
    });

    final invalidLanguages = <(String, List<String>)>[
      ('an empty list', <String>[]),
      ('an empty tag', <String>['ko-KR', '']),
      ('a whitespace-only tag', <String>['   ']),
    ];

    for (final (name, languages) in invalidLanguages) {
      test('$name fails before calling the platform', () async {
        final platform = _RecordingPlatform();
        FlutterReceiptScannerPlatform.instance = platform;

        await expectLater(
          scan(options: ScanReceiptOptions(ocrLanguages: languages)),
          throwsArgumentError,
        );

        expect(platform.callCount, 0);
      });
    }

    for (final (name, languages) in invalidLanguages) {
      test('$name is ignored when OCR is disabled', () async {
        final platform = _RecordingPlatform();
        FlutterReceiptScannerPlatform.instance = platform;

        // The option is moot without OCR, so it must never gate the scan.
        final result = await scan(
          options: ScanReceiptOptions(ocr: false, ocrLanguages: languages),
        );

        expect(result.status, ScanStatus.success);
        expect(platform.callCount, 1);
      });
    }
  });

  group('getOcrCapabilities', () {
    test('delegates to the registered platform', () async {
      final capabilities = IosOcrCapabilities(supportedLanguages: ['ko-KR', 'ja-JP']);
      final platform = _RecordingPlatform(capabilities: capabilities);
      FlutterReceiptScannerPlatform.instance = platform;

      final result = await getOcrCapabilities();

      expect(result, same(capabilities));
      expect(platform.capabilityCallCount, 1);
      expect(platform.callCount, 0);
    });
  });

  group('merge option validation', () {
    final invalidOptions = <(String, ScanReceiptOptions)>[
      (
        'OCR disabled',
        const ScanReceiptOptions(maxPages: 2, ocr: false),
      ),
      (
        'gallery source',
        const ScanReceiptOptions(source: ScanSource.gallery, maxPages: 2),
      ),
      (
        'only one allowed page',
        const ScanReceiptOptions(),
      ),
    ];

    for (final (name, options) in invalidOptions) {
      test('$name fails before calling the platform', () async {
        final platform = _RecordingPlatform();
        FlutterReceiptScannerPlatform.instance = platform;

        await expectLater(
          scan(options: options, mergeOcrPages: true),
          throwsArgumentError,
        );

        expect(platform.callCount, 0);
        expect(platform.received, isNull);
      });
    }
  });

  test('enabled merge attaches complete OCR in native page order', () async {
    final platform = _RecordingPlatform(
      result: ScanReceiptResult(
        status: ScanStatus.success,
        images: [
          _image(
            'file:///tmp/first.jpg',
            '서울 마트\n상품 A 1,000\n중간 합계 1,000',
          ),
          _image(
            'file:///tmp/second.jpg',
            '상품 A 1,000\n중간 합계 1,000\nTOTAL 1,100',
          ),
        ],
      ),
    );
    FlutterReceiptScannerPlatform.instance = platform;

    final result = await scan(
      options: const ScanReceiptOptions(maxPages: 2),
      mergeOcrPages: true,
    );

    expect(result.status, ScanStatus.success);
    expect(
      result.mergedOcr?.text,
      '서울 마트\n상품 A 1,000\n중간 합계 1,000\nTOTAL 1,100',
    );
    expect(result.mergedOcr?.isComplete, isTrue);
    expect(
      result.mergedOcr?.pageUris,
      ['file:///tmp/first.jpg', 'file:///tmp/second.jpg'],
    );
  });

  test(
    'restores original page order after the OCR floor partitions pages',
    () async {
      final platform = _RecordingPlatform(
        result: ScanReceiptResult(
          status: ScanStatus.success,
          images: [
            _image(
              'file:///tmp/first.jpg',
              'first accepted line\nsecond accepted line',
            ),
            _image('file:///tmp/middle.jpg', 'short'),
            _image(
              'file:///tmp/last.jpg',
              'last accepted line\nanother accepted line',
            ),
          ],
        ),
      );
      FlutterReceiptScannerPlatform.instance = platform;

      final result = await scan(
        options: const ScanReceiptOptions(maxPages: 3),
        mergeOcrPages: true,
      );

      expect(result.images.map((image) => image.uri), [
        'file:///tmp/first.jpg',
        'file:///tmp/last.jpg',
      ]);
      expect(result.rejectedImages.map((image) => image.uri), [
        'file:///tmp/middle.jpg',
      ]);
      expect(result.mergedOcr?.pageUris, [
        'file:///tmp/first.jpg',
        'file:///tmp/middle.jpg',
        'file:///tmp/last.jpg',
      ]);
      expect(result.mergedOcr?.rejectedPageIndexes, [1]);
      expect(result.mergedOcr?.isComplete, isFalse);
    },
  );

  test(
    'attaches merge diagnostics when the OCR floor rejects every page',
    () async {
      final platform = _RecordingPlatform(
        result: ScanReceiptResult(
          status: ScanStatus.success,
          images: [
            _image('file:///tmp/first.jpg', 'short'),
            _image('file:///tmp/second.jpg', 'tiny'),
          ],
        ),
      );
      FlutterReceiptScannerPlatform.instance = platform;

      final result = await scan(
        options: const ScanReceiptOptions(maxPages: 2),
        mergeOcrPages: true,
      );

      expect(result.status, ScanStatus.rejected);
      expect(result.images, isEmpty);
      expect(result.rejectedImages.length, 2);
      expect(result.mergedOcr, isNotNull);
      expect(result.mergedOcr?.rejectedPageIndexes, [0, 1]);
      expect(result.mergedOcr?.isComplete, isFalse);
    },
  );

  test(
    'a one-page capture is a complete merge when maxPages allows multiple pages',
    () async {
      final platform = _RecordingPlatform();
      FlutterReceiptScannerPlatform.instance = platform;

      final result = await scan(
        options: const ScanReceiptOptions(maxPages: 2),
        mergeOcrPages: true,
      );

      expect(result.mergedOcr?.text, 'a receipt line\nsecond line');
      expect(result.mergedOcr?.isComplete, isTrue);
      expect(result.mergedOcr?.pageUris, ['file:///tmp/a.jpg']);
    },
  );

  test('merging is accepted with a non-default language list', () async {
    final platform = _RecordingPlatform(
      result: ScanReceiptResult(
        status: ScanStatus.success,
        images: [
          _image('file:///tmp/first.jpg', '東京ストア\n商品 A 1,000\n小計 1,000'),
          _image('file:///tmp/second.jpg', '商品 A 1,000\n小計 1,000\n合計 1,100'),
        ],
      ),
    );
    FlutterReceiptScannerPlatform.instance = platform;

    final result = await scan(
      options: const ScanReceiptOptions(maxPages: 2, ocrLanguages: ['ja-JP', 'en-US']),
      mergeOcrPages: true,
    );

    expect(platform.received?.ocrLanguages, ['ja-JP', 'en-US']);
    expect(result.mergedOcr?.text, '東京ストア\n商品 A 1,000\n小計 1,000\n合計 1,100');
    expect(result.mergedOcr?.isComplete, isTrue);
  });

  test('discarded native pages force an incomplete merge', () async {
    final platform = _RecordingPlatform(
      result: ScanReceiptResult(
        status: ScanStatus.success,
        images: [
          _image(
            'file:///tmp/first.jpg',
            '서울 마트\n상품 A 1,000\n중간 합계 1,000',
          ),
          _image(
            'file:///tmp/second.jpg',
            '상품 A 1,000\n중간 합계 1,000\nTOTAL 1,100',
          ),
        ],
        discardedPageCount: 1,
      ),
    );
    FlutterReceiptScannerPlatform.instance = platform;

    final result = await scan(
      options: const ScanReceiptOptions(maxPages: 2),
      mergeOcrPages: true,
    );

    // Every returned boundary is proven, but a natively dropped page means the
    // logical receipt is not fully covered — never claim completeness.
    expect(result.mergedOcr?.isComplete, isFalse);
    expect(result.mergedOcr?.unmatchedBoundaryIndexes, isEmpty);
    expect(result.mergedOcr?.rejectedPageIndexes, isEmpty);
    expect(
      result.mergedOcr?.text,
      '서울 마트\n상품 A 1,000\n중간 합계 1,000\nTOTAL 1,100',
    );
    expect(result.discardedPageCount, 1);
  });

  test('discarded count is preserved when merging is disabled', () async {
    final platform = _RecordingPlatform(
      result: ScanReceiptResult(
        status: ScanStatus.success,
        images: _defaultResult.images,
        discardedPageCount: 2,
      ),
    );
    FlutterReceiptScannerPlatform.instance = platform;

    final result = await scan(options: const ScanReceiptOptions(maxPages: 3));

    expect(result.discardedPageCount, 2);
    expect(result.mergedOcr, isNull);
  });

  test('cancellation never attaches merged OCR', () async {
    final platform = _RecordingPlatform(
      result: const ScanReceiptResult(status: ScanStatus.cancelled),
    );
    FlutterReceiptScannerPlatform.instance = platform;

    final result = await scan(
      options: const ScanReceiptOptions(maxPages: 2),
      mergeOcrPages: true,
    );

    expect(result.status, ScanStatus.cancelled);
    expect(result.mergedOcr, isNull);
  });

  test('duplicate native page URIs fail explicitly', () async {
    final platform = _RecordingPlatform(
      result: ScanReceiptResult(
        status: ScanStatus.success,
        images: [
          _image(
            'file:///tmp/duplicate.jpg',
            'first accepted line\nsecond accepted line',
          ),
          _image(
            'file:///tmp/duplicate.jpg',
            'third accepted line\nfourth accepted line',
          ),
        ],
      ),
    );
    FlutterReceiptScannerPlatform.instance = platform;

    await expectLater(
      scan(
        options: const ScanReceiptOptions(maxPages: 2),
        mergeOcrPages: true,
      ),
      throwsStateError,
    );

    expect(platform.callCount, 1);
  });

  test('missing OCR-floor page URI fails explicitly', () async {
    final first = _image(
      'file:///tmp/first.jpg',
      'first accepted line\nsecond accepted line',
    );
    final missing = _image(
      'file:///tmp/missing.jpg',
      'third accepted line\nfourth accepted line',
    );
    final platform = _RecordingPlatform(
      result: ScanReceiptResult(
        status: ScanStatus.success,
        images: _ChangingIterationList([first, missing], [first]),
      ),
    );
    FlutterReceiptScannerPlatform.instance = platform;

    await expectLater(
      scan(
        options: const ScanReceiptOptions(maxPages: 2),
        mergeOcrPages: true,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'OCR floor result is missing receipt page URI: file:///tmp/missing.jpg',
        ),
      ),
    );
  });
}

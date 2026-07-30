import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_receipt_scanner/src/ocr_page_merger.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/receipt_benchmark/fixture_generator.dart';

void main() {
  final packageDirectory = Directory.current;
  final fixtureDirectory = Directory.fromUri(
    packageDirectory.uri.resolve('test/fixtures/long_receipt/'),
  );
  final fixtureManifest = _readJson(
    File.fromUri(fixtureDirectory.uri.resolve('fixture_manifest.json')),
  );

  test('canonical fixture records the required 11:1 geometry', () {
    final logicalImage = _map(fixtureManifest['logicalImage']);
    final pages = _list(
      fixtureManifest['pages'],
    ).map(_map).toList(growable: false);

    expect(logicalImage['width'], 1200);
    expect(logicalImage['height'], 13200);
    expect(fixtureManifest['pageStep'], 2112);
    expect(fixtureManifest['overlap'], 528);
    expect(pages, hasLength(6));
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      expect(page['width'], 1200);
      expect(page['height'], 2640);
      expect(page['top'], index * 2112);
      expect(page['overlapWithPrevious'], index == 0 ? 0 : 528);
    }
  });

  test(
    'checked-in PNG dimensions and checksums match the fixture manifest',
    () {
      final images = [
        _map(fixtureManifest['logicalImage']),
        ..._list(fixtureManifest['pages']).map(_map),
      ];

      for (final image in images) {
        final file = File.fromUri(
          fixtureDirectory.uri.resolve(image['file']! as String),
        );
        final bytes = file.readAsBytesSync();
        final size = _pngSize(bytes);

        expect(size.width, image['width'], reason: file.path);
        expect(size.height, image['height'], reason: file.path);
        expect(
          sha256.convert(bytes).toString(),
          image['sha256'],
          reason: file.path,
        );
      }
    },
  );

  test('pinned font and license checksums match the fixture source', () {
    final source = _readJson(
      File.fromUri(
        packageDirectory.uri.resolve(
          'tool/receipt_benchmark/fixture_source.json',
        ),
      ),
    );
    final font = _map(source['font']);
    final benchmarkDirectory = packageDirectory.uri.resolve(
      'tool/receipt_benchmark/',
    );

    for (final entry in {
      font['file']! as String: font['sha256']! as String,
      font['licenseFile']! as String: font['licenseSha256']! as String,
    }.entries) {
      final bytes = File.fromUri(
        benchmarkDirectory.resolve(entry.key),
      ).readAsBytesSync();
      expect(sha256.convert(bytes).toString(), entry.value);
    }
    expect(font['revision'], '7ff85c87f93ea6cca5f41c69f2e4edcb90240f26');
    expect(font['license'], 'OFL-1.1');
  });

  test('regeneration reproduces the checked-in image checksums', () async {
    final outputDirectory = await Directory.systemTemp.createTemp(
      'flutter_receipt_scanner_fixture_',
    );
    try {
      final regenerated = await generateLongReceiptFixtures(
        packageDirectory: packageDirectory,
        outputDirectory: outputDirectory,
      );
      final expectedImages = [
        _map(fixtureManifest['logicalImage']),
        ..._list(fixtureManifest['pages']).map(_map),
      ];
      final regeneratedImages = [
        _map(regenerated['logicalImage']),
        ..._list(regenerated['pages']).map(_map),
      ];

      expect(
        regeneratedImages.map((image) => image['sha256']),
        expectedImages.map((image) => image['sha256']),
      );
    } finally {
      await outputDirectory.delete(recursive: true);
    }
  });

  test('canonical OCR pages merge byte-for-byte to the canonical text', () {
    final pages = _list(fixtureManifest['pages'])
        .map(_map)
        .map((page) {
          final index = page['index']! as int;
          return _receiptPage(
            index: index,
            originalIndex: index,
            ocrText: page['ocrText']! as String,
            fixtureDirectory: fixtureDirectory,
          );
        })
        .toList(growable: false);

    final result = mergeReceiptOcrPages(pages);

    expect(result.text, fixtureManifest['canonicalText']);
    expect(result.isComplete, isTrue);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
    expect(result.rejectedPageIndexes, isEmpty);
  });

  final variants = _map(fixtureManifest['variants']);
  for (final entry in variants.entries) {
    test('${entry.key} variant returns exact merge diagnostics', () {
      final variant = _map(entry.value);
      final originalIndexes = _list(variant['pageOriginalIndexes']).cast<int>();
      final ocrTexts = _list(variant['ocrTexts']).cast<String>();
      final pages = List.generate(
        ocrTexts.length,
        (index) => _receiptPage(
          index: index,
          originalIndex: originalIndexes[index],
          ocrText: ocrTexts[index],
          fixtureDirectory: fixtureDirectory,
        ),
        growable: false,
      );
      final rejectedIndexes = _list(
        variant['rejectedPageIndexes'],
      ).cast<int>().toSet();
      final expected = _map(variant['expected']);

      final result = mergeReceiptOcrPages(
        pages,
        rejectedPageIndexes: rejectedIndexes,
      );

      expect(result.text, expected['text']);
      expect(result.isComplete, expected['isComplete']);
      expect(
        result.unmatchedBoundaryIndexes,
        _list(expected['unmatchedBoundaryIndexes']),
      );
      expect(
        result.rejectedPageIndexes,
        _list(expected['rejectedPageIndexes']),
      );
    });
  }

  test('public dataset manifest pins offline manual calibration inputs', () {
    final manifest = _readJson(
      File.fromUri(
        packageDirectory.uri.resolve('tool/receipt_benchmark/datasets.json'),
      ),
    );
    final policy = _map(manifest['ciPolicy']);
    final datasets = _list(
      manifest['datasets'],
    ).map(_map).toList(growable: false);

    expect(manifest['accessedAt'], '2026-07-30');
    expect(policy['networkRequired'], isFalse);
    expect(policy['authenticationRequired'], isFalse);
    expect(policy['thirdPartyImagesCommitted'], isFalse);
    expect(datasets.map((dataset) => dataset['id']), {
      'appen-korean-documents-v1',
      'humyn-korean-receipts-656cef5',
      'cord-v2-7f0115a',
    });
    for (final dataset in datasets) {
      expect(dataset['sourceUrl'], isNotEmpty);
      expect(dataset['revision'], isNotEmpty);
      expect(_map(dataset['license'])['spdx'], isNotEmpty);
      expect(_map(dataset['expectedPublicFiles']), isNotEmpty);
      expect(_map(dataset['annotations'])['kind'], isNotEmpty);
      expect(dataset['scripts'], isA<List<Object?>>());
      expect(dataset['checksums'], isA<List<Object?>>());
      expect(dataset['intendedRole'], isNotEmpty);
      expect(dataset['enabledInCi'], isFalse);
    }

    final humyn = datasets.singleWhere(
      (dataset) => dataset['id'] == 'humyn-korean-receipts-656cef5',
    );
    expect(_map(humyn['expectedPublicFiles'])['imageCount'], 20);
    expect(_map(humyn['annotations'])['groundTruthAvailable'], isFalse);
    expect(humyn['cerGroundTruth'], isFalse);

    final cord = datasets.singleWhere(
      (dataset) => dataset['id'] == 'cord-v2-7f0115a',
    );
    final splits = _map(_map(cord['expectedPublicFiles'])['splits']);
    expect(
      splits.values.cast<int>().reduce((left, right) => left + right),
      1000,
    );

    final appen = datasets.singleWhere(
      (dataset) => dataset['id'] == 'appen-korean-documents-v1',
    );
    expect(_map(appen['expectedPublicFiles'])['receiptImageCount'], 5);
    expect(_map(appen['expectedPublicFiles'])['receiptAnnotationCount'], 5);
  });
}

Map<String, Object?> _readJson(File file) => (jsonDecode(file.readAsStringSync())! as Map<Object?, Object?>).cast();

Map<String, Object?> _map(Object? value) => (value! as Map<Object?, Object?>).cast();

List<Object?> _list(Object? value) => value! as List<Object?>;

({int width, int height}) _pngSize(List<int> bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24 || !_equalBytes(bytes.take(8), signature)) {
    throw const FormatException('Expected a PNG image.');
  }
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (width: data.getUint32(16), height: data.getUint32(20));
}

bool _equalBytes(Iterable<int> left, List<int> right) {
  final values = left.toList(growable: false);
  if (values.length != right.length) return false;
  for (var index = 0; index < values.length; index++) {
    if (values[index] != right[index]) return false;
  }
  return true;
}

ReceiptImage _receiptPage({
  required int index,
  required int originalIndex,
  required String ocrText,
  required Directory fixtureDirectory,
}) {
  final fileName = 'page_${(originalIndex + 1).toString().padLeft(2, '0')}.png';
  final file = File.fromUri(fixtureDirectory.uri.resolve(fileName));
  return ReceiptImage(
    uri: '${file.uri}#sequence=$index',
    width: 1200,
    height: 2640,
    fileName: fileName,
    fileSize: file.lengthSync(),
    imageOrigin: ImageOrigin.camera,
    mimeType: 'image/png',
    ocrText: ocrText,
  );
}

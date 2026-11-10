import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';
import 'package:flutter_receipt_scanner/src/ocr_page_merger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_scanner_core/receipt_scanner_core.dart';

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;
List<Object?> _list(Object? value) => value! as List<Object?>;
List<int> _indexes(Object? value) => _list(value).cast<int>();
String _pageUri(int index) => 'file:///contract/page-$index.jpg';

ReceiptImage _page(int index, String? text, {double? confidence}) => ReceiptImage(
  uri: _pageUri(index),
  width: 1,
  height: 1,
  fileName: 'page-$index.jpg',
  fileSize: 1,
  imageOrigin: ImageOrigin.camera,
  ocrText: text,
  ocrQuality: confidence == null ? null : OcrQuality(textLength: 0, lineCount: 0, confidence: confidence),
);

void main() {
  test('pilot seam rejects invalid counts', () {
    final pages = [_page(0, 'coffee 1000\nbread 2000'), _page(1, 'coffee 1000\nbread 2000')];
    for (final count in [-1, 3]) {
      expect(() => mergeReceiptOcrPages(pages, overlapMatcher: (_, _) => count), throwsStateError);
    }
  });
  final directory = Directory('test/fixtures/ocr-contracts/v1');
  final corpus = _map(jsonDecode(File('${directory.path}/contract.json').readAsStringSync()));
  final manifest = _map(jsonDecode(File('${directory.path}/manifest.json').readAsStringSync()));

  test('shared OCR snapshot matches its pinned checksums', () {
    expect(corpus['schemaVersion'], 1);
    expect(manifest['schemaVersion'], 1);
    final files = _map(manifest['files']);
    for (final name in ['contract.json', 'schema.json']) {
      final bytes = File('${directory.path}/$name').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), files[name], reason: '$name checksum mismatch');
    }
  });

  for (final matcher in <OverlapMatcher?>[null, findReceiptOverlap]) {
    for (final fixture in _list(corpus['mergeCases']).map(_map)) {
      test('merge ${matcher == null ? 'dart' : 'native'}: ${fixture['id']}', () {
        final texts = _list(fixture['pages']).cast<String?>();
        final pages = [for (var index = 0; index < texts.length; index++) _page(index, texts[index])];
        final rejected = _indexes(fixture['rejectedPageIndexes']).toSet();
        if (fixture['expectedError'] == 'RangeError') {
          expect(
            () => mergeReceiptOcrPages(pages, rejectedPageIndexes: rejected, overlapMatcher: matcher),
            throwsRangeError,
          );
          return;
        }
        final result = mergeReceiptOcrPages(pages, rejectedPageIndexes: rejected, overlapMatcher: matcher);
        expect({
          'text': result.text,
          'isComplete': result.isComplete,
          'unmatchedBoundaryIndexes': result.unmatchedBoundaryIndexes,
          'rejectedPageIndexes': result.rejectedPageIndexes,
        }, fixture['expected']);
        expect(result.pageUris, pages.map((page) => page.uri).toList());
      });
    }
  }

  for (final fixture in _list(corpus['qualityCases']).map(_map)) {
    test('quality: ${fixture['id']}', () {
      final input = _map(fixture['input']);
      final inputs = _list(input['pages']).map(_map).toList();
      final pages = [
        for (var index = 0; index < inputs.length; index++)
          _page(index, inputs[index]['text'] as String?, confidence: (inputs[index]['confidence'] as num?)?.toDouble()),
      ];
      final floorValue = input['floor'];
      final floor = floorValue is Map<String, Object?>
          ? OcrFloor(
              minTextLength: floorValue['minTextLength']! as int,
              minLines: floorValue['minLines']! as int,
              minConfidence: (floorValue['minConfidence']! as num).toDouble(),
            )
          : kDefaultOcrFloor;
      final result = applyOcrFloor(
        ScanReceiptResult(status: ScanStatus.values.byName(input['status']! as String), images: pages),
        ocr: input['ocr']! as bool,
        floor: floorValue == false ? const OcrFloorOrDisabled.disabled() : OcrFloorOrDisabled.floor(floor),
      );
      final imagesByUri = {
        for (final page in [...result.images, ...result.rejectedImages]) page.uri: page,
      };
      final qualities = [
        for (final page in pages)
          if (imagesByUri[page.uri]?.ocrQuality case final quality?)
            {'textLength': quality.textLength, 'lineCount': quality.lineCount, 'confidence': quality.confidence}
          else
            null,
      ];
      expect({
        'status': result.status.name,
        'acceptedPageIndexes': result.images.map((image) => pages.indexWhere((page) => page.uri == image.uri)).toList(),
        'rejectedPageIndexes': result.rejectedImages
            .map((image) => pages.indexWhere((page) => page.uri == image.uri))
            .toList(),
        'qualities': qualities,
      }, fixture['expected']);
    });
  }
}

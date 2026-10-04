import 'package:flutter_receipt_scanner/src/ocr_page_merger.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptImage _page(int index, String? text) => ReceiptImage(
  uri: 'file:///tmp/page-$index.jpg',
  width: 1200,
  height: 2640,
  fileName: 'page-$index.jpg',
  fileSize: 1,
  imageOrigin: ImageOrigin.camera,
  ocrText: text,
);

void main() {
  group('issue #3 false overlap regressions', () {
    test('preserves identical purchases at a single-line boundary', () {
      const purchase = '서울우유 1L 흰우유 990ml    1     2,000';
      final result = mergeReceiptOcrPages([
        _page(0, '영수증 RECEIPT\n$purchase'),
        _page(1, '$purchase\nTOTAL 4,000'),
      ]);

      expect(result.text, '영수증 RECEIPT\n$purchase\n$purchase\nTOTAL 4,000');
      expect(result.isComplete, isFalse);
      expect(result.unmatchedBoundaryIndexes, [0]);
    });

    test('preserves similar purchases with different quantities and amounts', () {
      const first = '서울우유 1L 흰우유 990ml    1     2,000';
      const second = '서울우유 1L 흰우유 990ml    2     4,000';
      final result = mergeReceiptOcrPages([
        _page(0, '영수증 RECEIPT\n$first'),
        _page(1, '$second\nTOTAL 6,000'),
      ]);

      expect(result.text, '영수증 RECEIPT\n$first\n$second\nTOTAL 6,000');
      expect(result.isComplete, isFalse);
      expect(result.unmatchedBoundaryIndexes, [0]);
    });

    test('preserves two similar purchase rows on each side of a boundary', () {
      const first = '서울우유 흰우유 1L 1 2,000\n서울우유 흰우유 1L 2 4,000';
      const second = '서울우유 흰우유 1L 3 6,000\n서울우유 흰우유 1L 4 8,000';
      final result = mergeReceiptOcrPages([
        _page(0, '영수증 RECEIPT\n$first'),
        _page(1, '$second\nTOTAL 20,000'),
      ]);

      expect(result.text, '영수증 RECEIPT\n$first\n$second\nTOTAL 20,000');
      expect(result.isComplete, isFalse);
      expect(result.unmatchedBoundaryIndexes, [0]);
    });

    test('chooses a nine-line overlap before a repeated two-line header', () {
      const sharedLines = [
        '--------------------',
        '품목 ITEM 수량 QTY 금액 AMOUNT',
        '사과 APPLE 1 1,000',
        '우유 MILK 2 4,000',
        '식빵 BREAD 1 3,000',
        '바나나 BANANA 3 6,000',
        '당근 CARROT 1 2,000',
        '--------------------',
        '품목 ITEM 수량 QTY 금액 AMOUNT',
      ];
      final shared = sharedLines.join('\n');
      final result = mergeReceiptOcrPages([
        _page(0, '영수증 RECEIPT\n$shared'),
        _page(1, '$shared\nTOTAL 16,000'),
      ]);

      expect(result.text, '영수증 RECEIPT\n$shared\nTOTAL 16,000');
      expect(result.text.split('\n'), hasLength(11));
      expect(result.isComplete, isTrue);
      expect(result.unmatchedBoundaryIndexes, isEmpty);
    });
  });

  test('one non-empty page is complete', () {
    final result = mergeReceiptOcrPages([_page(0, '  서울 마트  \n\n  TOTAL 1,000  ')]);

    expect(result.text, '서울 마트\nTOTAL 1,000');
    expect(result.isComplete, isTrue);
    expect(result.pageUris, ['file:///tmp/page-0.jpg']);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
    expect(result.rejectedPageIndexes, isEmpty);
  });

  test('exact adjacent overlap is emitted once', () {
    final result = mergeReceiptOcrPages([
      _page(0, '서울 마트\n상품 A 1,000\n중간 합계 1,000'),
      _page(1, '상품 A 1,000\n중간 합계 1,000\n부가세 100\nTOTAL 1,100'),
    ]);

    expect(result.text, '서울 마트\n상품 A 1,000\n중간 합계 1,000\n부가세 100\nTOTAL 1,100');
    expect(result.isComplete, isTrue);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
  });

  test('a one-character OCR difference is preserved and reported', () {
    final result = mergeReceiptOcrPages([
      _page(0, '영수증 RECEIPT\n아메리카노 AMERICANO 4,500\n카페라떼 CAFE LATTE 5,000'),
      _page(1, '아메리카노 AMERICANO 4,500\n카페라떼 CAFE LATE 5,000\nTOTAL 합계 9,500'),
    ]);

    expect(
      result.text,
      '영수증 RECEIPT\n아메리카노 AMERICANO 4,500\n카페라떼 CAFE LATTE 5,000\n'
      '아메리카노 AMERICANO 4,500\n카페라떼 CAFE LATE 5,000\nTOTAL 합계 9,500',
    );
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0]);
  });

  test('unmatched text is preserved and reported', () {
    final result = mergeReceiptOcrPages([
      _page(0, '첫 번째 상품 1,000\n두 번째 상품 2,000'),
      _page(1, '완전히 다른 문장 7,700\n새로운 항목 8,800'),
    ]);

    expect(result.text, '첫 번째 상품 1,000\n두 번째 상품 2,000\n완전히 다른 문장 7,700\n새로운 항목 8,800');
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0]);
  });

  test('short single-line candidate is preserved and reported', () {
    final result = mergeReceiptOcrPages([_page(0, '상점\nTOTAL 1,000'), _page(1, 'TOTAL 1,000\n감사합니다')]);

    expect(result.text, '상점\nTOTAL 1,000\nTOTAL 1,000\n감사합니다');
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0]);
  });

  test('long exact single-line candidate is preserved and reported', () {
    final result = mergeReceiptOcrPages([
      _page(0, '상점\nORDER 20260730 PAYMENT APPROVED 123456'),
      _page(1, 'ORDER 20260730 PAYMENT APPROVED 123456\n감사합니다'),
    ]);

    expect(
      result.text,
      '상점\nORDER 20260730 PAYMENT APPROVED 123456\nORDER 20260730 PAYMENT APPROVED 123456\n감사합니다',
    );
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0]);
  });

  test('repeated line away from the seam is preserved', () {
    final result = mergeReceiptOcrPages([
      _page(0, '서울 마트\n상품 A 1,000\n다음 페이지 계속\n중간 합계 1,000'),
      _page(1, '다음 페이지 계속\n중간 합계 1,000\n서울 마트\nTOTAL 1,100'),
    ]);

    expect(result.text, '서울 마트\n상품 A 1,000\n다음 페이지 계속\n중간 합계 1,000\n서울 마트\nTOTAL 1,100');
    expect(result.isComplete, isTrue);
  });

  test('null and empty OCR pages are rejected without dropping later text', () {
    final result = mergeReceiptOcrPages([
      _page(0, '첫 페이지 본문\n계속되는 내용'),
      _page(1, null),
      _page(2, '세 번째 페이지\nTOTAL 3,000'),
      _page(3, ' \n '),
    ]);

    expect(result.text, '첫 페이지 본문\n계속되는 내용\n세 번째 페이지\nTOTAL 3,000');
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0, 1, 2]);
    expect(result.rejectedPageIndexes, [1, 3]);
  });

  test('explicitly rejected page makes an otherwise proven merge incomplete', () {
    final result = mergeReceiptOcrPages(
      [_page(0, '서울 마트\n상품 A 1,000\n중간 합계 1,000'), _page(1, '상품 A 1,000\n중간 합계 1,000\nTOTAL 1,100')],
      rejectedPageIndexes: const {1},
    );

    expect(result.text, '서울 마트\n상품 A 1,000\n중간 합계 1,000\nTOTAL 1,100');
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
    expect(result.rejectedPageIndexes, [1]);
  });

  test('empty page list returns an incomplete empty result', () {
    final result = mergeReceiptOcrPages(const []);

    expect(result.text, isEmpty);
    expect(result.isComplete, isFalse);
    expect(result.pageUris, isEmpty);
  });

  test('out-of-range rejected page index fails before merging', () {
    expect(() => mergeReceiptOcrPages([_page(0, '영수증 RECEIPT')], rejectedPageIndexes: const {1}), throwsRangeError);
  });

  test('exact distinct lines have no character limit', () {
    final shared = '${'A' * 600}\n${'B' * 600}';

    final result = mergeReceiptOcrPages([_page(0, '첫 페이지\n$shared'), _page(1, '$shared\n마지막 페이지')]);

    expect(result.text, '첫 페이지\n$shared\n마지막 페이지');
    expect(result.isComplete, isTrue);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
  });

  test('long partial overlap preserves the unproven line suffix', () {
    final shared = 'A' * 600;

    final result = mergeReceiptOcrPages([_page(0, '첫 페이지\nLEFT-$shared'), _page(1, '$shared-RIGHT\n마지막 페이지')]);

    expect(result.text, '첫 페이지\nLEFT-$shared\n$shared-RIGHT\n마지막 페이지');
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0]);
  });

  test('identical purchases split two per page are preserved and reported', () {
    const repeated = 'REPEATED OVERLAP LINE 1234567890';

    final result = mergeReceiptOcrPages([
      _page(0, '$repeated\n$repeated'),
      _page(1, '$repeated\n$repeated\nTOTAL 1,000'),
    ]);

    expect(result.text, '$repeated\n$repeated\n$repeated\n$repeated\nTOTAL 1,000');
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0]);
  });

  test('exact distinct overlap preserves similar surrounding purchases', () {
    const first = 'ITEM 001 ORIGINAL RECEIPT ROW';
    const second = 'ITEM 002 SHARED RECEIPT ROW';
    const third = 'ITEM 003 SHARED RECEIPT ROW';
    const fourth = 'ITEM 004 NEW RECEIPT ROW';

    final result = mergeReceiptOcrPages([_page(0, '$first\n$second\n$third'), _page(1, '$second\n$third\n$fourth')]);

    expect(result.text, '$first\n$second\n$third\n$fourth');
    expect(result.isComplete, isTrue);
  });

  test('matching ignores case and whitespace but preserves earlier recognized text', () {
    final result = mergeReceiptOcrPages([
      _page(0, '상점\n  우유  MILK\t1 2,000  \n\n빵 BREAD 1 3,000'),
      _page(1, '우유 milk 1 2,000\n빵   bread 1 3,000\nTOTAL 5,000'),
    ]);

    expect(result.text, '상점\n우유  MILK\t1 2,000\n빵 BREAD 1 3,000\nTOTAL 5,000');
    expect(result.isComplete, isTrue);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
  });

  test('distinctness is checked after case and whitespace normalization', () {
    const left = '우유 MILK 1 2,000\n우유  milk 1 2,000';
    const right = '우유 milk 1 2,000\n우유 MILK 1 2,000';
    final result = mergeReceiptOcrPages([_page(0, left), _page(1, right)]);

    expect(result.text, '$left\n$right');
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0]);
  });

  test('short distinct lines can prove an exact overlap', () {
    final result = mergeReceiptOcrPages([_page(0, 'START\nA\nB'), _page(1, 'A\nB\nEND')]);

    expect(result.text, 'START\nA\nB\nEND');
    expect(result.isComplete, isTrue);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
  });

  test('repeated purchases within a distinct exact overlap retain their count', () {
    const shared = '우유 MILK 1 2,000\n우유 MILK 1 2,000\n빵 BREAD 1 3,000';
    final result = mergeReceiptOcrPages([_page(0, '영수증 RECEIPT\n$shared'), _page(1, '$shared\nTOTAL 7,000')]);

    expect(result.text, '영수증 RECEIPT\n$shared\nTOTAL 7,000');
    expect(result.text.split('\n').where((line) => line == '우유 MILK 1 2,000'), hasLength(2));
    expect(result.isComplete, isTrue);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
  });

  test('different OCR line segmentation is preserved and reported', () {
    const first = '우유 MILK 1 2,000\n빵 BREAD 1 3,000';
    const second = '우유 MILK 1 2,000 빵 BREAD 1 3,000';
    final result = mergeReceiptOcrPages([
      _page(0, '영수증 RECEIPT\n$first'),
      _page(1, '$second\nTOTAL 5,000'),
    ]);

    expect(result.text, '영수증 RECEIPT\n$first\n$second\nTOTAL 5,000');
    expect(result.isComplete, isFalse);
    expect(result.unmatchedBoundaryIndexes, [0]);
  });

  test('a fully overlapped middle page still proves the next adjacent boundary', () {
    const shared = '우유 MILK 1 2,000\n빵 BREAD 1 3,000';

    final result = mergeReceiptOcrPages([
      _page(0, '영수증 RECEIPT\n$shared'),
      _page(1, shared),
      _page(2, '$shared\nTOTAL 5,000'),
    ]);

    expect(result.text, '영수증 RECEIPT\n$shared\nTOTAL 5,000');
    expect(result.isComplete, isTrue);
    expect(result.unmatchedBoundaryIndexes, isEmpty);
  });

  test('does not mutate inputs', () {
    final pages = [_page(0, '서울 마트\n상품 A 1,000\n중간 합계 1,000'), _page(1, '상품 A 1,000\n중간 합계 1,000\nTOTAL 1,100')];
    final originalUris = pages.map((page) => page.uri).toList();
    final originalTexts = pages.map((page) => page.ocrText).toList();

    final result = mergeReceiptOcrPages(pages);

    expect(pages.map((page) => page.uri), originalUris);
    expect(pages.map((page) => page.ocrText), originalTexts);
    expect(result.pageUris, originalUris);
    expect(() => result.pageUris.add('file:///tmp/mutated.jpg'), throwsUnsupportedError);
  });

  test('ten pages with 200 lines each merge within 100 ms after warm-up', () {
    final pages = List.generate(10, (pageIndex) {
      final lines = List.generate(200, (lineIndex) => 'PAGE $pageIndex LINE $lineIndex ITEM 1234567890');
      if (pageIndex > 0) {
        lines
          ..[0] = 'SHARED OVERLAP LINE ALPHA 1234567890'
          ..[1] = 'SHARED OVERLAP LINE BETA 0987654321';
      }
      if (pageIndex < 9) {
        lines
          ..[198] = 'SHARED OVERLAP LINE ALPHA 1234567890'
          ..[199] = 'SHARED OVERLAP LINE BETA 0987654321';
      }
      return _page(pageIndex, lines.join('\n'));
    });

    mergeReceiptOcrPages(pages);
    final stopwatch = Stopwatch()..start();
    final result = mergeReceiptOcrPages(pages);
    stopwatch.stop();

    expect(result.isComplete, isTrue);
    expect(result.text.split('\n'), hasLength(1982));
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 100)));
  });
}

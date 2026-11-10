// Copyright (c) 2026 Dongmin, Yu. MIT License; see LICENSE.
import 'dart:isolate';

import 'package:receipt_scanner_core/receipt_scanner_core.dart';
import 'package:test/test.dart';

void main() {
  test('deepest overlap preserves literal UTF-16 semantics', () {
    expect(
      findReceiptOverlap(
        ['prefix', 'coffee 1000', 'bread 2000'],
        ['coffee 1000', 'bread 2000', 'tail'],
      ),
      2,
    );
    expect(
      findReceiptOverlap(['same row', 'same row'], ['same row', 'same row']),
      0,
    );
    expect(findReceiptOverlap(['a', 'b'], ['a', 'b']), 0);
    expect(findReceiptOverlap([], ['coffee 1000', 'bread 2000']), 0);
    expect(findReceiptOverlap(['😀😀😀', '가나다라마바'], ['😀😀😀', '가나다라마바']), 2);
  });
  test('repeated serial and concurrent calls agree', () async {
    int batch() {
      var total = 0;
      for (var i = 0; i < 10000; i++) {
        total += findReceiptOverlap(
          ['coffee 1000', 'bread 2000'],
          ['coffee 1000', 'bread 2000'],
        );
      }
      return total;
    }

    expect(batch(), 20000);
    expect(
      await Future.wait(List.generate(4, (_) => Isolate.run(batch))),
      everyElement(20000),
    );
  });
}

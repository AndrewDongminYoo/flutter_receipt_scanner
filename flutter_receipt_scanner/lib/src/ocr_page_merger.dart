import 'dart:math' as math;

import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

final _whitespace = RegExp(r'\s+');

/// Merges ordered page OCR while preserving text at unproven boundaries.
MergedOcrResult mergeReceiptOcrPages(List<ReceiptImage> pages, {Set<int> rejectedPageIndexes = const {}}) {
  _validateRejectedIndexes(rejectedPageIndexes, pages.length);

  final linesByPage = pages.map((page) => _nonEmptyLines(page.ocrText)).toList(growable: false);
  final comparisonLinesByPage = linesByPage
      .map((lines) => lines.map(_comparisonLine).toList(growable: false))
      .toList(growable: false);
  final rejected = <int>{...rejectedPageIndexes};
  for (var index = 0; index < linesByPage.length; index++) {
    if (linesByPage[index].isEmpty) rejected.add(index);
  }

  final mergedLines = linesByPage.isEmpty ? <String>[] : [...linesByPage.first];
  final unmatchedBoundaries = <int>[];

  for (var pageIndex = 1; pageIndex < linesByPage.length; pageIndex++) {
    final previousLines = linesByPage[pageIndex - 1];
    final currentLines = linesByPage[pageIndex];
    if (previousLines.isEmpty || currentLines.isEmpty) {
      unmatchedBoundaries.add(pageIndex - 1);
      mergedLines.addAll(currentLines);
      continue;
    }

    final overlap = _findOverlap(comparisonLinesByPage[pageIndex - 1], comparisonLinesByPage[pageIndex]);
    if (overlap == 0) {
      unmatchedBoundaries.add(pageIndex - 1);
      mergedLines.addAll(currentLines);
      continue;
    }
    mergedLines.addAll(currentLines.skip(overlap));
  }

  final sortedRejected = rejected.toList()..sort();
  return MergedOcrResult(
    text: mergedLines.join('\n'),
    isComplete: pages.isNotEmpty && sortedRejected.isEmpty && unmatchedBoundaries.isEmpty,
    pageUris: pages.map((page) => page.uri).toList(growable: false),
    unmatchedBoundaryIndexes: unmatchedBoundaries,
    rejectedPageIndexes: sortedRejected,
  );
}

void _validateRejectedIndexes(Set<int> indexes, int pageCount) {
  for (final index in indexes) {
    if (index < 0 || index >= pageCount) {
      throw RangeError.range(index, 0, pageCount - 1, 'rejectedPageIndexes');
    }
  }
}

List<String> _nonEmptyLines(String? text) {
  if (text == null) return const [];
  return text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList(growable: false);
}

// Compare normalized lines deepest-first so a repeated header cannot hide a
// longer overlap. Approximate matches can erase real quantity or price changes.
int _findOverlap(List<String> leftLines, List<String> rightLines) {
  for (var depth = math.min(leftLines.length, rightLines.length); depth >= 2; depth--) {
    final leftStart = leftLines.length - depth;
    var matches = true;
    var hasDistinctLines = false;
    for (var index = 0; index < depth; index++) {
      if (leftLines[leftStart + index] != rightLines[index]) {
        matches = false;
        break;
      }
      if (rightLines[index] != rightLines.first) hasDistinctLines = true;
    }
    // One row, even repeated many times, is not enough evidence of overlap:
    // consecutive identical purchases must remain visible at an unproven seam.
    if (matches && hasDistinctLines) return depth;
  }
  return 0;
}

String _comparisonLine(String line) => line.toLowerCase().replaceAll(_whitespace, ' ').trim();

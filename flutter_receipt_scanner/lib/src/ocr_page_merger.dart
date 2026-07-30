import 'dart:math' as math;

import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

const _maxWindowLines = 8;
const _minimumWindowCharacters = 12;
const _minimumWindowSimilarity = 0.85;
const _minimumSingleLineCharacters = 24;
const _minimumSingleLineSimilarity = 0.92;
const _maxComparisonCharacters = 512;

final _whitespace = RegExp(r'\s+');

/// Merges ordered page OCR while preserving text at unproven boundaries.
MergedOcrResult mergeReceiptOcrPages(
  List<ReceiptImage> pages, {
  Set<int> rejectedPageIndexes = const {},
}) {
  _validateRejectedIndexes(rejectedPageIndexes, pages.length);

  final linesByPage = pages.map((page) => _nonEmptyLines(page.ocrText)).toList(growable: false);
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

    final overlap = _findOverlap(previousLines, currentLines);
    if (overlap == null) {
      unmatchedBoundaries.add(pageIndex - 1);
      mergedLines.addAll(currentLines);
      continue;
    }
    mergedLines.addAll(currentLines.skip(overlap.rightLineCount));
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

_Overlap? _findOverlap(List<String> leftLines, List<String> rightLines) {
  final leftLimit = math.min(_maxWindowLines, leftLines.length);
  final rightLimit = math.min(_maxWindowLines, rightLines.length);
  final leftWindows = List.generate(
    leftLimit,
    (index) => _comparisonText(leftLines.sublist(leftLines.length - index - 1)),
    growable: false,
  );
  final rightWindows = List.generate(
    rightLimit,
    (index) => _comparisonText(rightLines.sublist(0, index + 1)),
    growable: false,
  );
  _Overlap? best;

  for (var rightCount = 1; rightCount <= rightLimit; rightCount++) {
    final right = rightWindows[rightCount - 1];
    for (var leftCount = 1; leftCount <= leftLimit; leftCount++) {
      final left = leftWindows[leftCount - 1];
      final singleLine = leftCount == 1 || rightCount == 1;
      final minimumCharacters = singleLine ? _minimumSingleLineCharacters : _minimumWindowCharacters;
      final minimumSimilarity = singleLine ? _minimumSingleLineSimilarity : _minimumWindowSimilarity;
      final shorterLength = math.min(left.length, right.length);
      if (shorterLength < minimumCharacters) continue;
      final longerLength = math.max(left.length, right.length);
      if ((longerLength - shorterLength) / longerLength > 1 - minimumSimilarity) {
        continue;
      }

      final exactMatch = left == right;
      if (!exactMatch && longerLength > _maxComparisonCharacters) continue;
      final similarity = exactMatch ? 1.0 : _similarity(left, right);
      if (similarity < minimumSimilarity) continue;

      final candidate = _Overlap(
        leftLineCount: leftCount,
        rightLineCount: rightCount,
        comparedCharacters: shorterLength,
        similarity: similarity,
      );
      if (candidate.isBetterThan(best)) best = candidate;
    }
  }
  return best;
}

String _comparisonText(List<String> lines) =>
    lines.map((line) => line.toLowerCase().replaceAll(_whitespace, ' ').trim()).join(' ');

double _similarity(String left, String right) {
  final longestLength = math.max(left.length, right.length);
  if (longestLength == 0) return 1;
  return 1 - (_levenshteinDistance(left, right) / longestLength);
}

int _levenshteinDistance(String left, String right) {
  if (left == right) return 0;
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;

  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
    final current = List<int>.filled(right.length + 1, 0)..[0] = leftIndex + 1;
    for (var rightIndex = 0; rightIndex < right.length; rightIndex++) {
      final substitutionCost = left.codeUnitAt(leftIndex) == right.codeUnitAt(rightIndex) ? 0 : 1;
      current[rightIndex + 1] = math.min(
        math.min(current[rightIndex] + 1, previous[rightIndex + 1] + 1),
        previous[rightIndex] + substitutionCost,
      );
    }
    previous = current;
  }
  return previous.last;
}

final class _Overlap {
  const _Overlap({
    required this.leftLineCount,
    required this.rightLineCount,
    required this.comparedCharacters,
    required this.similarity,
  });

  final int leftLineCount;
  final int rightLineCount;
  final int comparedCharacters;
  final double similarity;

  bool isBetterThan(_Overlap? other) {
    if (other == null) return true;
    if (similarity != other.similarity) return similarity > other.similarity;
    if (comparedCharacters != other.comparedCharacters) {
      return comparedCharacters > other.comparedCharacters;
    }
    return false;
  }
}

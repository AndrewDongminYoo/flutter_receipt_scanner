Map<String, Object?> buildReceiptFixtureVariants(
  List<String> pageTexts,
  List<String> canonicalLines,
) {
  final canonicalText = canonicalLines.join('\n');
  final missingIndexes = [0, 1, 3, 4, 5];
  final unmatchedPages = [...pageTexts];
  final unmatchedLines = unmatchedPages[3].split('\n')
    ..[0] = '경계 손실 BOUNDARY LOST XA91'
    ..[1] = '연결 실패 SEAM FAILURE QZ47'
    ..[2] = '복구 보류 RECOVERY PENDING MK63';
  unmatchedPages[3] = unmatchedLines.join('\n');

  final repeatedPages = [...pageTexts];
  final repeatedLines = repeatedPages[2].split('\n');
  repeatedLines.insert(8, repeatedLines[7]);
  repeatedPages[2] = repeatedLines.join('\n');
  final repeatedCanonicalLines = [...canonicalLines]..insert(32, canonicalLines[31]);

  final segmentedPages = [...pageTexts];
  final segmentedLines = segmentedPages[3].split('\n');
  final joinedBoundary = segmentedLines.take(3).join(' ');
  segmentedPages[3] = [joinedBoundary, ...segmentedLines.skip(3)].join('\n');

  return {
    'missingPage': {
      'pageOriginalIndexes': missingIndexes,
      'ocrTexts': [for (final index in missingIndexes) pageTexts[index]],
      'rejectedPageIndexes': <int>[],
      'expected': {
        'text': _mergeExactPages(
          [for (final index in missingIndexes) pageTexts[index]],
          unmatchedBoundaryIndexes: const {1},
        ),
        'isComplete': false,
        'unmatchedBoundaryIndexes': [1],
        'rejectedPageIndexes': <int>[],
      },
    },
    'unmatchedBoundary': {
      'pageOriginalIndexes': [0, 1, 2, 3, 4, 5],
      'ocrTexts': unmatchedPages,
      'rejectedPageIndexes': <int>[],
      'expected': {
        'text': _mergeExactPages(
          unmatchedPages,
          unmatchedBoundaryIndexes: const {2},
        ),
        'isComplete': false,
        'unmatchedBoundaryIndexes': [2],
        'rejectedPageIndexes': <int>[],
      },
    },
    'repeatedLine': {
      'pageOriginalIndexes': [0, 1, 2, 3, 4, 5],
      'ocrTexts': repeatedPages,
      'rejectedPageIndexes': <int>[],
      'expected': {
        'text': repeatedCanonicalLines.join('\n'),
        'isComplete': true,
        'unmatchedBoundaryIndexes': <int>[],
        'rejectedPageIndexes': <int>[],
      },
    },
    'segmentationDifference': {
      'pageOriginalIndexes': [0, 1, 2, 3, 4, 5],
      'ocrTexts': segmentedPages,
      'rejectedPageIndexes': <int>[],
      'expected': {
        'text': canonicalText,
        'isComplete': true,
        'unmatchedBoundaryIndexes': <int>[],
        'rejectedPageIndexes': <int>[],
      },
    },
    'belowFloor': {
      'pageOriginalIndexes': [0, 1, 2, 3, 4, 5],
      'ocrTexts': pageTexts,
      'rejectedPageIndexes': [2],
      'expected': {
        'text': canonicalText,
        'isComplete': false,
        'unmatchedBoundaryIndexes': <int>[],
        'rejectedPageIndexes': [2],
      },
    },
  };
}

String _mergeExactPages(
  List<String> pages, {
  Set<int> unmatchedBoundaryIndexes = const {},
}) {
  final merged = pages.first.split('\n');
  for (var index = 1; index < pages.length; index++) {
    final lines = pages[index].split('\n');
    merged.addAll(
      unmatchedBoundaryIndexes.contains(index - 1) ? lines : lines.skip(3),
    );
  }
  return merged.join('\n');
}

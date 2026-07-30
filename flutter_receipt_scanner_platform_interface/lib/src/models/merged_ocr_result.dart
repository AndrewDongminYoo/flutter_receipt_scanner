/// OCR text assembled from ordered receipt pages with seam diagnostics.
final class MergedOcrResult {
  /// Creates an immutable merged OCR result.
  MergedOcrResult({
    required this.text,
    required this.isComplete,
    required List<String> pageUris,
    List<int> unmatchedBoundaryIndexes = const [],
    List<int> rejectedPageIndexes = const [],
  }) : pageUris = List.unmodifiable(pageUris),
       unmatchedBoundaryIndexes = List.unmodifiable(unmatchedBoundaryIndexes),
       rejectedPageIndexes = List.unmodifiable(rejectedPageIndexes);

  /// Ordered OCR text with proven adjacent overlap removed.
  final String text;

  /// Whether every page was usable and every adjacent boundary was proven.
  final bool isComplete;

  /// Cache URIs in the page order used by the merger.
  final List<String> pageUris;

  /// Zero-based indexes of unproven boundaries.
  ///
  /// Index `i` represents the boundary between [pageUris] entries `i` and `i + 1`.
  final List<int> unmatchedBoundaryIndexes;

  /// Zero-based page indexes that were empty or rejected by the OCR floor.
  final List<int> rejectedPageIndexes;
}

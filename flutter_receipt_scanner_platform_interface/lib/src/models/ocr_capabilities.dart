/// The language list used when a caller does not supply [ScanReceiptOptions.ocrLanguages].
const List<String> kDefaultOcrLanguages = ['ko-KR', 'en-US'];

/// Whether a script model can recognize text now or needs a download first.
enum OcrModelStatus {
  /// Recognition can run immediately.
  ready,

  /// The provider must download the model before recognition can run.
  downloadRequired,
}

/// One script family's readiness on Android.
final class OcrModelState {
  /// Creates a script-model state.
  const OcrModelState({required this.script, required this.status});

  /// Unicode script identifier such as `Latn`, `Kore`, `Jpan`, `Hans`, `Hant`, or `Deva`.
  final String script;

  /// Whether the model is ready or must be downloaded.
  final OcrModelStatus status;
}

/// Native OCR capability, reported without downloading a model or opening UI.
///
/// The two variants are not symmetric on purpose: iOS Vision reports exact
/// language identifiers, while Android ML Kit selects a recognizer by script.
sealed class OcrCapabilities {
  const OcrCapabilities();

  /// The language list used when a caller supplies none.
  List<String> get defaultLanguages => kDefaultOcrLanguages;
}

/// iOS capability: the languages the active Vision request revision supports
/// at the accurate recognition level.
final class IosOcrCapabilities extends OcrCapabilities {
  /// Creates an iOS capability report.
  IosOcrCapabilities({required List<String> supportedLanguages})
    : supportedLanguages = List.unmodifiable(supportedLanguages);

  /// Exact identifiers returned by the active request revision.
  final List<String> supportedLanguages;
}

/// Android capability: the ML Kit Text Recognition v2 script families this
/// package ships, and whether each is installed.
final class AndroidOcrCapabilities extends OcrCapabilities {
  /// Creates an Android capability report.
  AndroidOcrCapabilities({required List<OcrModelState> models}) : models = List.unmodifiable(models);

  /// Readiness per script family.
  final List<OcrModelState> models;
}

# Long receipt benchmark assets

`fixture_source.json` and `fixture_generator.dart` are the source of truth for the project-authored Korean-plus-Latin 11:1 fixture.
The checked-in PNG files under `test/fixtures/long_receipt/` are derived artifacts.
The generator uses the pinned NanumGothic font in `fonts/`, verifies the font and OFL license checksums before rendering, and writes image checksums into `fixture_manifest.json`.

Regenerate the checked-in fixture from the package directory:

```bash
flutter test tool/receipt_benchmark/generate_fixtures_test.dart
```

Run the offline fixture and merge checks:

```bash
flutter test test/long_receipt_fixture_test.dart
```

`datasets.json` pins the manually inspected Appen, Humyn, and CORD v2 public inputs.
Normal tests and CI parse this manifest but never fetch those datasets.
No third-party receipt image is stored in this repository.
Humyn has no verified transcript annotations and is therefore restricted to visual smoke testing, not character-error-rate measurement.
KORIE is intentionally absent until both a stable public archive and a dataset-specific license are verified.

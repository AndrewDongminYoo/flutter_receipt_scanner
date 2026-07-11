# Repository Guidelines

## Project Structure & Module Organization

- Root is a Melos workspace for a federated Flutter plugin, split into packages:
  - `flutter_receipt_scanner/` (app-facing plugin API; example app in `flutter_receipt_scanner/example/`)
  - `flutter_receipt_scanner_platform_interface/` (abstract platform interface plus the Pigeon-generated Dart messaging in `lib/src/messages.g.dart`)
  - `flutter_receipt_scanner_android/` (Android implementation; native code in `android/`)
  - `flutter_receipt_scanner_ios/` (iOS implementation; native code in `ios/`)
- `pigeons/messages.dart` is the single source of truth for the host/native transport (see Pigeon below).
- Tests live in each package's `test/` directory.

## Package Scope & Responsibility Boundary

- The native packages (`_android`, `_ios`) return **image primitives only**: acquired/cropped image, orientation-normalised JPEG, EXIF, and the raw on-device OCR string.
- The **OCR-floor gate** — the receipt-detection heuristic that decides whether a scanned image clears the minimum OCR signal to be treated as a receipt — lives in the app-facing `flutter_receipt_scanner` Dart package, **not** in native code. Keep receipt domain logic out of the platform implementations.

## Transport: Pigeon

- The host/native message contract is defined in `pigeons/messages.dart` and code-generated for Dart, Swift, and Kotlin.
- Regenerate after editing the schema:
  - `dart run pigeon --input pigeons/messages.dart` (or `melos run generate`).
- Never hand-edit generated Pigeon output; change `pigeons/messages.dart` and regenerate.

## Build, Test, and Development Commands

- `melos bootstrap` — resolve and link all workspace packages.
- `melos run analyze` — run `dart analyze` across every package.
- `melos run test` — run `flutter test` for every package that has a `test/` directory.
- `melos run format` — apply `dart fix` and format all Dart files at 120 columns.
- `melos run generate` — regenerate the Pigeon message contract.
- `cd flutter_receipt_scanner/example && flutter run` — run the example app locally.
- `trunk fmt` / `trunk check` — format and lint all non-Dart files per `.trunk/trunk.yaml`.

## Coding Style & Naming Conventions

- Dart code follows `very_good_analysis` (`analysis_options.yaml`) and is formatted with `dart format --line-length 120`.
- Indentation: 2 spaces for Dart and YAML.
- Prefer clear, package-scoped names (e.g., `FlutterReceiptScanner*` in plugin code).
- Dart is **owned by Flutter/Melos, not trunk** — trunk disables the `dart` linter on purpose (`.trunk/trunk.yaml`).
  Kotlin (ktlint), Swift (swiftformat), YAML (yamllint), Markdown (markdownlint), GitHub Actions (actionlint), and security scanners are owned by trunk.

## Platform Baselines

- iOS deployment target: **16.0**.
- Android `minSdk`: **24**.

## Testing Guidelines

- Framework: `flutter_test` (add `mocktail` where doubles are needed).
- Keep tests next to the package they validate (e.g., `flutter_receipt_scanner/test`).
- Name tests by behavior using `*_test.dart`.

## Commit & Pull Request Guidelines

- Commit messages follow Conventional Commits with gitmoji: `type: emoji subject` (e.g., `feat: ✨ add ...`, `docs: 📝 ...`, `chore: 🔨 ...`).
- Commit messages and code identifiers are in English; Korean comments and user-facing strings are intentional — do not translate them.
- PRs should include a concise description and link related issues when applicable.

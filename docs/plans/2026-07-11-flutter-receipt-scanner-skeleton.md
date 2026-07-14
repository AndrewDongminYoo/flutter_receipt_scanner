# flutter_receipt_scanner Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a federated Flutter plugin `flutter_receipt_scanner` whose iOS camera path scans a receipt end-to-end (VisionKit → JPEG → Vision OCR → typed Pigeon result → Dart OCR-floor gate).

**Architecture:** Four federated packages (app-facing, platform-interface, android, ios) in one repo that is both a Dart pub workspace and a melos workspace. Pigeon generates the typed wire contract across Dart/Swift/Kotlin. The OCR-floor acceptance gate and quality derivation live in the app-facing Dart package (native returns image primitives only — ADR-003 boundary).

**Tech Stack:** Flutter 3.44.6 (stable), Dart 3.12.2, Pigeon, melos, plugin_platform_interface, very_good_analysis. iOS: Swift + VisionKit + Vision + ImageIO. Android: Kotlin (skeleton stub).

## Global Constraints

- Clean-room only: never copy/adapt native `.m`/`.mm`/`.kt` source, string tables, or schema from `react-native-receipt-scanner`. Reference only `src/types.ts` (public contract), ADR docs (mechanism), and public framework docs.
- Scope = image primitives only (ADR-003). No receipt parsing, no upload, no cloud OCR, no network/vendor SDK beyond on-device scanner/OCR frameworks.
- Native returns image primitives; the OCR-floor gate + `OcrQuality` derivation run in Dart.
- `extend`, never `implements`, the platform interface.
- Public Dart symbols package-prefixed. Each package independently versioned, start `0.1.0`.
- Dart format: `dart format --line-length 120`, 2-space indent. Lint: `very_good_analysis`. Dart is owned by flutter/melos — do NOT enable Dart in trunk.
- iOS deployment target 16.0 (Korean OCR via `VNRecognizeTextRequest`). Android minSdk 24.
- Conventional Commits, no Co-Author lines, no `Claude-Session` trailer.
- Skeleton milestone: only iOS `source: "camera"`. Every other path returns unimplemented.

---

### Task 1: Repo scaffold — pub + melos workspace with four packages

**Files:**

- Create: `pubspec.yaml` (root — pub workspace + melos config; melos 7 keeps its config here, `melos.yaml` no longer exists)
- Create: `analysis_options.yaml` (root)
- Create: `.gitignore`
- Create: `packages/flutter_receipt_scanner_platform_interface/pubspec.yaml`
- Create: `packages/flutter_receipt_scanner_platform_interface/lib/flutter_receipt_scanner_platform_interface.dart` (placeholder export)
- Create: `packages/flutter_receipt_scanner/pubspec.yaml`
- Create: `packages/flutter_receipt_scanner/lib/flutter_receipt_scanner.dart` (placeholder)
- Create: `packages/flutter_receipt_scanner_ios/pubspec.yaml`
- Create: `packages/flutter_receipt_scanner_ios/lib/flutter_receipt_scanner_ios.dart` (placeholder)
- Create: `packages/flutter_receipt_scanner_android/pubspec.yaml`
- Create: `packages/flutter_receipt_scanner_android/lib/flutter_receipt_scanner_android.dart` (placeholder)

**Interfaces:**

- Consumes: nothing (first task).
- Produces: a resolvable four-package workspace. Package names: `flutter_receipt_scanner`, `flutter_receipt_scanner_platform_interface`, `flutter_receipt_scanner_ios`, `flutter_receipt_scanner_android`.

- [ ] **Step 1: Root `pubspec.yaml`**

```yaml
name: flutter_receipt_scanner_workspace
publish_to: none
environment:
  sdk: ">=3.12.0 <4.0.0"
workspace:
  - packages/flutter_receipt_scanner_platform_interface
  - packages/flutter_receipt_scanner
  - packages/flutter_receipt_scanner_ios
  - packages/flutter_receipt_scanner_android
dev_dependencies:
  melos: ^7.0.0
# melos 7 reads its config from this key (melos.yaml is removed in v7).
melos:
  scripts:
    analyze:
      run: dart analyze .
      exec:
        concurrency: 4
    test:
      run: flutter test
      exec:
        concurrency: 4
      packageFilters:
        dirExists: test
    format:
      run: dart format --line-length 120 .
```

- [ ] **Step 2 (removed): melos.yaml is not used in melos 7 — config lives in the root pubspec `melos:` key above.**

- [ ] **Step 3: Root `analysis_options.yaml`**

```yaml
include: package:very_good_analysis/analysis_options.yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/example/**"
```

- [ ] **Step 4: `.gitignore`**

```gitignore
.dart_tool/
.packages
build/
pubspec_overrides.yaml
.fvm/
*.iml
.idea/
ios/Pods/
ios/.symlinks/
Podfile.lock
```

- [ ] **Step 5: Platform-interface `pubspec.yaml`**

```yaml
name: flutter_receipt_scanner_platform_interface
description: Platform interface for flutter_receipt_scanner.
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
  plugin_platform_interface: ^2.1.8
dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^7.0.0
  pigeon: ^22.0.0
```

Placeholder `lib/flutter_receipt_scanner_platform_interface.dart`:

```dart
library;
// Exports added in Task 2 and Task 3.
```

- [ ] **Step 6: app-facing `pubspec.yaml`**

```yaml
name: flutter_receipt_scanner
description: On-device receipt image acquisition, crop, EXIF, and OCR for Flutter.
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_receipt_scanner_platform_interface: ^0.1.0
  flutter_receipt_scanner_ios: ^0.1.0
  flutter_receipt_scanner_android: ^0.1.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^7.0.0
flutter:
  plugin:
    platforms:
      android:
        default_package: flutter_receipt_scanner_android
      ios:
        default_package: flutter_receipt_scanner_ios
```

Placeholder `lib/flutter_receipt_scanner.dart`:

```dart
library;
// Public API added in Task 4.
```

- [ ] **Step 7: iOS package `pubspec.yaml`**

```yaml
name: flutter_receipt_scanner_ios
description: iOS implementation of flutter_receipt_scanner.
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_receipt_scanner_platform_interface: ^0.1.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^7.0.0
flutter:
  plugin:
    implements: flutter_receipt_scanner
    platforms:
      ios:
        dartPluginClass: FlutterReceiptScannerIos
        pluginClass: FlutterReceiptScannerPlugin
        sharedDarwinSource: false
```

Placeholder `lib/flutter_receipt_scanner_ios.dart`:

```dart
library;
// Registrant added in Task 5.
```

- [ ] **Step 8: Android package `pubspec.yaml`**

```yaml
name: flutter_receipt_scanner_android
description: Android implementation of flutter_receipt_scanner.
version: 0.1.0
publish_to: none
resolution: workspace
environment:
  sdk: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_receipt_scanner_platform_interface: ^0.1.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^7.0.0
flutter:
  plugin:
    implements: flutter_receipt_scanner
    platforms:
      android:
        dartPluginClass: FlutterReceiptScannerAndroid
        pluginClass: FlutterReceiptScannerPlugin
```

Placeholder `lib/flutter_receipt_scanner_android.dart`:

```dart
library;
// Registrant added in Task 6.
```

- [ ] **Step 9: Resolve the workspace**

Run: `cd /Users/dongminyu/Development/01_personal/flutter_receipt_scanner && flutter pub get`
Expected: resolves all four packages with no version conflict. (`very_good_analysis`/`pigeon` versions may be bumped by the resolver — accept whatever it picks and keep the caret ranges.)

- [ ] **Step 10: Verify melos sees four packages**

Run: `dart run melos list`
Expected: lists `flutter_receipt_scanner`, `flutter_receipt_scanner_android`, `flutter_receipt_scanner_ios`, `flutter_receipt_scanner_platform_interface`.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: scaffold federated four-package workspace"
```

---

### Task 2: Pigeon schema and code generation

**Files:**

- Create: `pigeons/messages.dart`
- Create: `packages/flutter_receipt_scanner_platform_interface/tool/generate_pigeon.sh`
- Generated (by pigeon, do not hand-edit): `packages/flutter_receipt_scanner_platform_interface/lib/src/messages.g.dart`, `packages/flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/Messages.g.swift`, `packages/flutter_receipt_scanner_android/android/src/main/kotlin/com/example/flutter_receipt_scanner_android/Messages.g.kt`

**Interfaces:**

- Consumes: Task 1 workspace.
- Produces: Pigeon Dart classes `ScanSource`, `ImageOrigin`, `ScanStatus`, `OcrFloorMessage`, `ScanOptions`, `ReceiptExif`, `GpsData`, `OcrQuality`, `ReceiptImage`, `ScanResult`, and `ReceiptScannerApi` (Dart client) with `Future<ScanResult> scan(ScanOptions options)`. Swift `ReceiptScannerApi` protocol + `setUp`. Kotlin `ReceiptScannerApi` interface + `setUp`.

- [ ] **Step 1: Write `pigeons/messages.dart`** (faithful re-expression of `src/types.ts`)

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut:
        'packages/flutter_receipt_scanner_platform_interface/lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    swiftOut:
        'packages/flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    kotlinOut:
        'packages/flutter_receipt_scanner_android/android/src/main/kotlin/com/example/flutter_receipt_scanner_android/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.example.flutter_receipt_scanner_android',
    ),
    dartPackageName: 'flutter_receipt_scanner_platform_interface',
  ),
)
enum ScanSource { camera, gallery }

enum ImageOrigin { camera, screenshot, download, unknown }

enum ScanStatus { success, cancelled, rejected }

class OcrFloorMessage {
  int? minTextLength;
  int? minLines;
  double? minConfidence;
}

class ScanOptions {
  ScanSource? source;
  int? maxPages;
  double? quality;
  bool? includeExif;
  bool? includeGpsExif;
  bool? ocr;
  bool? cropAutoConfirm;
  bool? autoRotate;
  bool? includeRawExif;
  double? minimumTextHeight;
}

class GpsData {
  double? latitude;
  double? longitude;
  double? altitude;
  String? timestamp;
  double? speed;
  double? heading;
}

class ReceiptExif {
  int? orientation;
  int? colorSpace;
  int? lightSource;
  String? exifVersion;
  String? make;
  String? model;
  String? software;
  String? dateTime;
  String? dateTimeOriginal;
  String? dateTimeDigitized;
  double? exposureTime;
  double? fNumber;
  double? iso;
  double? focalLength;
  int? flash;
  int? whiteBalance;
  int? exposureMode;
  int? exposureProgram;
  int? meteringMode;
  GpsData? gps;
  Map<String, Object?>? raw;
}

class OcrQuality {
  int? textLength;
  int? lineCount;
  double? confidence;
}

// Pigeon reads only the fields (no explicit constructor). Non-null fields
// become `required` named params in the generated constructor, so always-present
// output fields never need a Dart null-check.
class ReceiptImage {
  String uri;
  int width;
  int height;
  String fileName;
  String mimeType;
  int fileSize;
  ImageOrigin imageOrigin;
  // Genuinely optional (populated only when the option is enabled / text found).
  String? ocrText;
  OcrQuality? ocrQuality;
  ReceiptExif? exif;
}

class ScanResult {
  ScanStatus status;
  List<ReceiptImage> images;
  List<ReceiptImage> rejectedImages;
}

@HostApi()
abstract class ReceiptScannerApi {
  @async
  ScanResult scan(ScanOptions options);
}
```

- [ ] **Step 2: Write the generation helper `tool/generate_pigeon.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
dart run pigeon --input pigeons/messages.dart
```

- [ ] **Step 3: Run Pigeon generation**

Run: `cd /Users/dongminyu/Development/01_personal/flutter_receipt_scanner && dart run pigeon --input pigeons/messages.dart`
Expected: creates `messages.g.dart`, `Messages.g.swift`, `Messages.g.kt` with no error.

- [ ] **Step 4: Export the generated Dart from platform-interface barrel**

Edit `packages/flutter_receipt_scanner_platform_interface/lib/flutter_receipt_scanner_platform_interface.dart`:

```dart
library;

export 'src/messages.g.dart';
// Platform interface export added in Task 3.
```

- [ ] **Step 5: Analyze**

Run: `cd /Users/dongminyu/Development/01_personal/flutter_receipt_scanner && flutter analyze packages/flutter_receipt_scanner_platform_interface`
Expected: no issues (generated file is excluded from lint by root `analysis_options.yaml`).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add pigeon schema and generated messages"
```

---

### Task 3: Platform interface (extend-not-implement) + Pigeon-backed default

**Files:**

- Create: `packages/flutter_receipt_scanner_platform_interface/lib/src/flutter_receipt_scanner_platform.dart`
- Create: `packages/flutter_receipt_scanner_platform_interface/lib/src/pigeon_receipt_scanner.dart`
- Modify: `packages/flutter_receipt_scanner_platform_interface/lib/flutter_receipt_scanner_platform_interface.dart`
- Test: `packages/flutter_receipt_scanner_platform_interface/test/flutter_receipt_scanner_platform_test.dart`

**Interfaces:**

- Consumes: `ReceiptScannerApi`, `ScanOptions`, `ScanResult` from Task 2.
- Produces: abstract `FlutterReceiptScannerPlatform extends PlatformInterface` with `static FlutterReceiptScannerPlatform get instance` / `set instance`, and `Future<ScanResult> scan(ScanOptions options)`. Concrete `PigeonReceiptScannerPlatform extends FlutterReceiptScannerPlatform` wrapping `ReceiptScannerApi`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlatform extends FlutterReceiptScannerPlatform {
  _FakePlatform() : super(token: _token);
  static final Object _token = Object();
  @override
  Future<ScanResult> scan(ScanOptions options) async =>
      ScanResult(status: ScanStatus.cancelled, images: [], rejectedImages: []);
}

class _BadImpl implements FlutterReceiptScannerPlatform {
  @override
  Future<ScanResult> scan(ScanOptions options) => throw UnimplementedError();
}

void main() {
  test('default instance is the Pigeon-backed platform', () {
    expect(
      FlutterReceiptScannerPlatform.instance,
      isA<PigeonReceiptScannerPlatform>(),
    );
  });

  test('a properly-extended platform can be set as instance', () {
    final fake = _FakePlatform();
    FlutterReceiptScannerPlatform.instance = fake;
    expect(FlutterReceiptScannerPlatform.instance, same(fake));
  });

  test('setting a plain-implements instance is rejected by the token guard', () {
    expect(
      () => FlutterReceiptScannerPlatform.instance = _BadImpl(),
      throwsA(isA<AssertionError>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/flutter_receipt_scanner_platform_interface && flutter test test/flutter_receipt_scanner_platform_test.dart`
Expected: FAIL — `FlutterReceiptScannerPlatform` / `PigeonReceiptScannerPlatform` not defined.

- [ ] **Step 3: Write `flutter_receipt_scanner_platform.dart`**

```dart
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'messages.g.dart';
import 'pigeon_receipt_scanner.dart';

/// The interface every platform implementation of `flutter_receipt_scanner`
/// extends. Platform packages must `extend` this class (not `implements`) so
/// new methods with defaults do not break them.
abstract class FlutterReceiptScannerPlatform extends PlatformInterface {
  FlutterReceiptScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterReceiptScannerPlatform _instance =
      PigeonReceiptScannerPlatform();

  static FlutterReceiptScannerPlatform get instance => _instance;

  static set instance(FlutterReceiptScannerPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Launches the native scan flow and returns image primitives. The
  /// OCR-floor acceptance gate is applied by the app-facing package, not here.
  Future<ScanResult> scan(ScanOptions options) {
    throw UnimplementedError('scan() has not been implemented.');
  }
}
```

- [ ] **Step 4: Write `pigeon_receipt_scanner.dart`**

```dart
import 'flutter_receipt_scanner_platform.dart';
import 'messages.g.dart';

/// Default [FlutterReceiptScannerPlatform] backed by the Pigeon-generated
/// [ReceiptScannerApi]. Shared by both platform packages — the native handler
/// registered on each platform answers the call.
class PigeonReceiptScannerPlatform extends FlutterReceiptScannerPlatform {
  PigeonReceiptScannerPlatform({ReceiptScannerApi? api})
      : _api = api ?? ReceiptScannerApi();

  final ReceiptScannerApi _api;

  @override
  Future<ScanResult> scan(ScanOptions options) => _api.scan(options);
}
```

- [ ] **Step 5: Update the barrel export**

`packages/flutter_receipt_scanner_platform_interface/lib/flutter_receipt_scanner_platform_interface.dart`:

```dart
library;

export 'src/flutter_receipt_scanner_platform.dart';
export 'src/messages.g.dart';
export 'src/pigeon_receipt_scanner.dart';
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd packages/flutter_receipt_scanner_platform_interface && flutter test`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add platform interface with pigeon-backed default"
```

---

### Task 4: App-facing `scan()` + defaults + OCR-floor gate (Dart-side domain of ADR-003)

**Files:**

- Create: `packages/flutter_receipt_scanner/lib/src/scan_options.dart` (public options + defaults)
- Create: `packages/flutter_receipt_scanner/lib/src/ocr_floor.dart` (floor config + gate logic)
- Create: `packages/flutter_receipt_scanner/lib/src/receipt_scanner.dart` (`scan()` entry)
- Modify: `packages/flutter_receipt_scanner/lib/flutter_receipt_scanner.dart` (barrel)
- Test: `packages/flutter_receipt_scanner/test/ocr_floor_gate_test.dart`
- Test: `packages/flutter_receipt_scanner/test/scan_test.dart`

**Interfaces:**

- Consumes: `FlutterReceiptScannerPlatform`, `ScanOptions`, `ScanResult`, `ReceiptImage`, `OcrQuality`, `ScanStatus` from Task 3.
- Produces: `Future<ScanReceiptResult> scan({ScanReceiptOptions options})`, `ScanReceiptOptions` (Dart-facing), `OcrFloor`, `kDefaultOcrFloor`, `kDefaultScanOptions`, and pure functions `deriveQuality(String text, {double? confidence})` and `applyOcrFloor(ScanResult native, {required bool ocr, OcrFloorOrDisabled floor})`.

> The gate re-derives `scan.native.tsx`: floor applies only when `ocr == true` and not disabled; absent confidence is treated as satisfied; all-rejected → `ScanStatus.rejected`.

- [ ] **Step 1: Write the failing gate test** `test/ocr_floor_gate_test.dart`

```dart
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptImage _img(String text, {double? confidence}) => ReceiptImage(
      uri: 'file:///tmp/a.jpg',
      width: 1,
      height: 1,
      fileName: 'a.jpg',
      mimeType: 'image/jpeg',
      fileSize: 1,
      ocrText: text,
      ocrQuality: OcrQuality(confidence: confidence),
      imageOrigin: ImageOrigin.camera,
    );

void main() {
  test('deriveQuality counts trimmed length and non-empty lines', () {
    final q = deriveQuality('line one\n\n  line two  \n', confidence: 0.9);
    expect(q.textLength, 'line one\n\n  line two'.trim().length);
    expect(q.lineCount, 2);
    expect(q.confidence, 0.9);
  });

  test('gate disabled when ocr is false: everything passes, no rejects', () {
    final native = ScanResult(
      status: ScanStatus.success,
      images: [_img('x')],
      rejectedImages: [],
    );
    final r = applyOcrFloor(native, ocr: false, floor: const OcrFloorOrDisabled.disabled());
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
    expect(r.rejectedImages, isEmpty);
  });

  test('all images below floor -> rejected', () {
    final native = ScanResult(
      status: ScanStatus.success,
      images: [_img('short')], // 5 chars < 12, 1 line < 2
      rejectedImages: [],
    );
    final r = applyOcrFloor(native, ocr: true, floor: OcrFloorOrDisabled.floor(kDefaultOcrFloor));
    expect(r.status, ScanStatus.rejected);
    expect(r.images, isEmpty);
    expect(r.rejectedImages.length, 1);
  });

  test('partial pass -> success with populated rejectedImages', () {
    final native = ScanResult(
      status: ScanStatus.success,
      images: [_img('a receipt line\nsecond line here'), _img('nope')],
      rejectedImages: [],
    );
    final r = applyOcrFloor(native, ocr: true, floor: OcrFloorOrDisabled.floor(kDefaultOcrFloor));
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
    expect(r.rejectedImages.length, 1);
  });

  test('absent confidence is treated as satisfied', () {
    final native = ScanResult(
      status: ScanStatus.success,
      images: [_img('a receipt line\nsecond line here')], // no confidence
      rejectedImages: [],
    );
    final floor = OcrFloorOrDisabled.floor(const OcrFloor(minTextLength: 1, minLines: 1, minConfidence: 0.99));
    final r = applyOcrFloor(native, ocr: true, floor: floor);
    expect(r.status, ScanStatus.success);
    expect(r.images.length, 1);
  });

  test('non-success native status passes through untouched', () {
    final native = ScanResult(status: ScanStatus.cancelled, images: [], rejectedImages: []);
    final r = applyOcrFloor(native, ocr: true, floor: OcrFloorOrDisabled.floor(kDefaultOcrFloor));
    expect(r.status, ScanStatus.cancelled);
  });
}
```

- [ ] **Step 2: Run gate test to verify it fails**

Run: `cd packages/flutter_receipt_scanner && flutter test test/ocr_floor_gate_test.dart`
Expected: FAIL — `deriveQuality` / `applyOcrFloor` / `OcrFloor` / `OcrFloorOrDisabled` / `kDefaultOcrFloor` not defined.

- [ ] **Step 3: Write `lib/src/ocr_floor.dart`**

```dart
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// Acceptance thresholds applied to OCR output. Re-derived from the RN
/// package's `OcrFloor` contract.
class OcrFloor {
  const OcrFloor({
    this.minTextLength = 12,
    this.minLines = 2,
    this.minConfidence = 0,
  });

  final int minTextLength;
  final int minLines;
  final double minConfidence;
}

/// Package-default OCR floor.
const OcrFloor kDefaultOcrFloor = OcrFloor();

/// Either an active [OcrFloor] or an explicit "disabled" marker (mirrors the
/// RN `ocrFloor: false`).
class OcrFloorOrDisabled {
  const OcrFloorOrDisabled.floor(OcrFloor value)
      : _value = value,
        isDisabled = false;
  const OcrFloorOrDisabled.disabled()
      : _value = null,
        isDisabled = true;

  final OcrFloor? _value;
  final bool isDisabled;

  OcrFloor get value => _value!;
}

/// Derives [OcrQuality] from joined OCR text (trimmed char count + non-empty
/// line count), preserving native confidence when present.
OcrQuality deriveQuality(String text, {double? confidence}) {
  final trimmedLength = text.trim().length;
  var lineCount = 0;
  for (final line in text.split('\n')) {
    if (line.trim().isNotEmpty) lineCount++;
  }
  return OcrQuality(
    textLength: trimmedLength,
    lineCount: lineCount,
    confidence: confidence,
  );
}

bool _meetsFloor(OcrQuality q, OcrFloor floor) {
  if ((q.textLength ?? 0) < floor.minTextLength) return false;
  if ((q.lineCount ?? 0) < floor.minLines) return false;
  // Absent confidence => satisfied (never gate on a field not produced).
  final c = q.confidence;
  if (c != null && c < floor.minConfidence) return false;
  return true;
}

/// Applies the acceptance gate to a native [ScanResult]. Non-success statuses
/// pass through. When the floor is disabled or OCR did not run, all images
/// pass with an empty `rejectedImages`.
ScanResult applyOcrFloor(
  ScanResult native, {
  required bool ocr,
  required OcrFloorOrDisabled floor,
}) {
  if (native.status != ScanStatus.success) {
    return ScanResult(
      status: native.status,
      images: native.images ?? [],
      rejectedImages: native.rejectedImages ?? [],
    );
  }

  final images = (native.images ?? []).whereType<ReceiptImage>().toList();
  final annotated = images.map((img) {
    final text = img.ocrText;
    if (text == null) return img;
    return _copyWithQuality(img, deriveQuality(text, confidence: img.ocrQuality?.confidence));
  }).toList();

  if (!ocr || floor.isDisabled) {
    return ScanResult(status: ScanStatus.success, images: annotated, rejectedImages: []);
  }

  final passed = <ReceiptImage>[];
  final rejected = <ReceiptImage>[];
  for (final img in annotated) {
    final q = img.ocrQuality;
    final ok = q != null && _meetsFloor(q, floor.value);
    (ok ? passed : rejected).add(img);
  }

  if (passed.isEmpty && rejected.isNotEmpty) {
    return ScanResult(status: ScanStatus.rejected, images: [], rejectedImages: rejected);
  }
  return ScanResult(status: ScanStatus.success, images: passed, rejectedImages: rejected);
}

ReceiptImage _copyWithQuality(ReceiptImage img, OcrQuality quality) => ReceiptImage(
      uri: img.uri,
      width: img.width,
      height: img.height,
      fileName: img.fileName,
      mimeType: img.mimeType,
      fileSize: img.fileSize,
      ocrText: img.ocrText,
      ocrQuality: quality,
      exif: img.exif,
      imageOrigin: img.imageOrigin,
    );
```

- [ ] **Step 4: Run gate test to verify it passes**

Run: `cd packages/flutter_receipt_scanner && flutter test test/ocr_floor_gate_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Write `lib/src/scan_options.dart`**

```dart
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

import 'ocr_floor.dart';

/// Dart-facing scan options. All fields have defaults from [kDefaultScanOptions].
class ScanReceiptOptions {
  const ScanReceiptOptions({
    this.source = ScanSource.camera,
    this.maxPages = 1,
    this.quality = 0.82,
    this.includeExif = true,
    this.includeGpsExif = false,
    this.ocr = true,
    this.cropAutoConfirm = false,
    this.autoRotate = true,
    this.includeRawExif = false,
    this.minimumTextHeight = 0,
    this.ocrFloor = const OcrFloorOrDisabled.floor(kDefaultOcrFloor),
  });

  final ScanSource source;
  final int maxPages;
  final double quality;
  final bool includeExif;
  final bool includeGpsExif;
  final bool ocr;
  final bool cropAutoConfirm;
  final bool autoRotate;
  final bool includeRawExif;
  final double minimumTextHeight;
  final OcrFloorOrDisabled ocrFloor;

  /// Maps to the Pigeon wire type. `ocrFloor` is intentionally NOT sent —
  /// the gate is applied in Dart (ADR-003).
  ScanOptions toMessage() => ScanOptions(
        source: source,
        maxPages: maxPages,
        quality: quality,
        includeExif: includeExif,
        includeGpsExif: includeGpsExif,
        ocr: ocr,
        cropAutoConfirm: cropAutoConfirm,
        autoRotate: autoRotate,
        includeRawExif: includeRawExif,
        minimumTextHeight: minimumTextHeight,
      );
}

const ScanReceiptOptions kDefaultScanOptions = ScanReceiptOptions();
```

- [ ] **Step 6: Write `lib/src/receipt_scanner.dart`**

```dart
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

import 'ocr_floor.dart';
import 'scan_options.dart';

/// Launches the native scan flow, then applies the Dart-side OCR-floor gate.
Future<ScanResult> scan([ScanReceiptOptions options = kDefaultScanOptions]) async {
  final native = await FlutterReceiptScannerPlatform.instance.scan(options.toMessage());
  return applyOcrFloor(native, ocr: options.ocr, floor: options.ocrFloor);
}
```

- [ ] **Step 7: Update the app-facing barrel** `lib/flutter_receipt_scanner.dart`

```dart
library;

export 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart'
    show
        ImageOrigin,
        OcrQuality,
        ReceiptExif,
        ReceiptImage,
        ScanResult,
        ScanSource,
        ScanStatus;

export 'src/ocr_floor.dart';
export 'src/receipt_scanner.dart';
export 'src/scan_options.dart';
```

- [ ] **Step 8: Write `test/scan_test.dart`** (scan() wires platform + gate)

```dart
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingPlatform extends FlutterReceiptScannerPlatform {
  ScanOptions? received;
  @override
  Future<ScanResult> scan(ScanOptions options) async {
    received = options;
    return ScanResult(
      status: ScanStatus.success,
      images: [
        ReceiptImage(
          uri: 'file:///tmp/a.jpg', width: 1, height: 1, fileName: 'a.jpg',
          mimeType: 'image/jpeg', fileSize: 1,
          ocrText: 'a receipt line\nsecond line', ocrQuality: OcrQuality(confidence: 0.9),
          imageOrigin: ImageOrigin.camera,
        ),
      ],
      rejectedImages: [],
    );
  }
}

void main() {
  test('scan forwards options and applies the gate', () async {
    final platform = _RecordingPlatform();
    FlutterReceiptScannerPlatform.instance = platform;

    final result = await scan(const ScanReceiptOptions(maxPages: 3));

    expect(platform.received?.maxPages, 3);
    expect(result.status, ScanStatus.success);
    expect(result.images.length, 1);
  });
}
```

- [ ] **Step 9: Run the full app-facing suite**

Run: `cd packages/flutter_receipt_scanner && flutter test`
Expected: PASS (all tests across both files).

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: add app-facing scan() with dart-side ocr-floor gate"
```

---

### Task 5: iOS native handler — clean-room VisionKit camera path

**Files:**

- Create: `packages/flutter_receipt_scanner_ios/lib/flutter_receipt_scanner_ios.dart` (Dart registrant)
- Create: `packages/flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios.podspec`
- Create: `packages/flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/FlutterReceiptScannerPlugin.swift`
- Create: `packages/flutter_receipt_scanner_ios/ios/flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/ReceiptScannerApiImpl.swift`
- Test: `packages/flutter_receipt_scanner_ios/test/registrant_test.dart`

**Interfaces:**

- Consumes: generated Swift `ReceiptScannerApi`, `ScanResult`, `ScanOptions` (Task 2); Dart `FlutterReceiptScannerPlatform`, `PigeonReceiptScannerPlatform` (Task 3).
- Produces: `FlutterReceiptScannerIos.registerWith()` (Dart) setting the platform instance; native `FlutterReceiptScannerPlugin` registering `ReceiptScannerApiImpl`.

> Clean-room: the Swift below is written from framework docs (VisionKit `VNDocumentCameraViewController`, `VNRecognizeTextRequest`, `ImageIO`/`UTType` JPEG write). Do not consult the RN repo's `.m` files.

- [ ] **Step 1: Write the failing Dart registrant test** `test/registrant_test.dart`

```dart
import 'package:flutter_receipt_scanner_ios/flutter_receipt_scanner_ios.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('registerWith installs the Pigeon-backed platform', () {
    FlutterReceiptScannerIos.registerWith();
    expect(
      FlutterReceiptScannerPlatform.instance,
      isA<PigeonReceiptScannerPlatform>(),
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/flutter_receipt_scanner_ios && flutter test`
Expected: FAIL — `FlutterReceiptScannerIos` not defined.

- [ ] **Step 3: Write the Dart registrant** `lib/flutter_receipt_scanner_ios.dart`

```dart
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// iOS registrant. Flutter calls [registerWith] via the `dartPluginClass`
/// hook declared in this package's pubspec.
class FlutterReceiptScannerIos {
  static void registerWith() {
    FlutterReceiptScannerPlatform.instance = PigeonReceiptScannerPlatform();
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd packages/flutter_receipt_scanner_ios && flutter test`
Expected: PASS.

- [ ] **Step 5: Write the podspec** `ios/flutter_receipt_scanner_ios.podspec`

```ruby
Pod::Spec.new do |s|
  s.name             = 'flutter_receipt_scanner_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of flutter_receipt_scanner.'
  s.description      = 'On-device receipt scanning via VisionKit and Vision.'
  s.homepage         = 'https://github.com/AndrewDongminYoo/flutter_receipt_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Dongmin Yu' => 'ydm2790@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_receipt_scanner_ios/Sources/flutter_receipt_scanner_ios/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'VisionKit', 'Vision', 'ImageIO', 'CoreGraphics', 'UniformTypeIdentifiers'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
```

- [ ] **Step 6: Write `FlutterReceiptScannerPlugin.swift`** (registration)

```swift
import Flutter
import UIKit

public class FlutterReceiptScannerPlugin: NSObject, FlutterPlugin {
  private static var apiImpl: ReceiptScannerApiImpl?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let impl = ReceiptScannerApiImpl()
    apiImpl = impl
    ReceiptScannerApiSetup.setUp(binaryMessenger: messenger, api: impl)
  }
}
```

- [ ] **Step 7: Write `ReceiptScannerApiImpl.swift`** (camera path only)

```swift
import Flutter
import ImageIO
import UIKit
import UniformTypeIdentifiers
import Vision
import VisionKit

/// Clean-room iOS implementation of the generated `ReceiptScannerApi`.
/// Skeleton milestone: `source == .camera` only. Other paths return
/// `ScanStatus.cancelled` is NOT used for unimplemented — a FlutterError is.
final class ReceiptScannerApiImpl: NSObject, ReceiptScannerApi,
  VNDocumentCameraViewControllerDelegate {

  private var completion: ((Result<ScanResult, Error>) -> Void)?
  private var options: ScanOptions?

  func scan(
    options: ScanOptions,
    completion: @escaping (Result<ScanResult, Error>) -> Void
  ) {
    guard (options.source ?? .camera) == .camera else {
      completion(.failure(
        PigeonError(code: "unimplemented",
                    message: "Only source: camera is implemented in the skeleton.",
                    details: nil)))
      return
    }
    guard VNDocumentCameraViewController.isSupported else {
      completion(.failure(
        PigeonError(code: "unavailable",
                    message: "Document scanning is not supported on this device.",
                    details: nil)))
      return
    }
    self.completion = completion
    self.options = options
    DispatchQueue.main.async {
      let scanner = VNDocumentCameraViewController()
      scanner.delegate = self
      Self.topViewController()?.present(scanner, animated: true)
    }
  }

  // MARK: - VNDocumentCameraViewControllerDelegate

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFinishWith scan: VNDocumentCameraScan
  ) {
    controller.dismiss(animated: true)
    let opts = options ?? ScanOptions()
    let maxPages = max(1, Int(opts.maxPages ?? 1))
    let pageCount = min(scan.pageCount, maxPages)

    var images: [ReceiptImage] = []
    for index in 0..<pageCount {
      let uiImage = scan.imageOfPage(at: index)
      if let image = Self.process(uiImage, options: opts) {
        images.append(image)
      }
    }
    finish(.success(ScanResult(
      status: .success, images: images, rejectedImages: [])))
  }

  func documentCameraViewControllerDidCancel(
    _ controller: VNDocumentCameraViewController
  ) {
    controller.dismiss(animated: true)
    finish(.success(ScanResult(status: .cancelled, images: [], rejectedImages: [])))
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController, didFailWithError error: Error
  ) {
    controller.dismiss(animated: true)
    finish(.failure(PigeonError(code: "scan_failed",
                                message: error.localizedDescription, details: nil)))
  }

  // MARK: - Processing

  private static func process(_ image: UIImage, options: ScanOptions) -> ReceiptImage? {
    guard let cg = image.cgImage else { return nil }
    let quality = CGFloat(options.quality ?? 0.82)
    let fileName = "receipt_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(6)).jpg"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    guard let dest = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
    // Always normalize orientation to Up (1) on output.
    let props: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: quality,
      kCGImagePropertyOrientation: CGImagePropertyOrientation.up.rawValue,
    ]
    CGImageDestinationAddImage(dest, cg, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return nil }

    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
    var ocrText: String?
    var confidence: Double?
    if options.ocr ?? true {
      let ocr = Self.recognizeText(cg)
      ocrText = ocr.text
      confidence = ocr.confidence
    }

    return ReceiptImage(
      uri: url.absoluteString,
      width: Int64(cg.width),
      height: Int64(cg.height),
      fileName: fileName,
      mimeType: "image/jpeg",
      fileSize: Int64(size ?? 0),
      ocrText: ocrText,
      ocrQuality: ocrText == nil ? nil : OcrQuality(confidence: confidence),
      exif: nil,
      imageOrigin: .camera)
  }

  private static func recognizeText(_ cg: CGImage) -> (text: String?, confidence: Double?) {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ko-KR", "en-US"]
    request.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
    try? handler.perform([request])
    guard let observations = request.results, !observations.isEmpty else {
      return (nil, nil)
    }
    var lines: [String] = []
    var confSum: Float = 0
    var confCount = 0
    for obs in observations {
      guard let top = obs.topCandidates(1).first else { continue }
      lines.append(top.string)
      confSum += top.confidence
      confCount += 1
    }
    let text = lines.isEmpty ? nil : lines.joined(separator: "\n")
    let confidence = confCount == 0 ? nil : Double(confSum / Float(confCount))
    return (text, confidence)
  }

  private func finish(_ result: Result<ScanResult, Error>) {
    let c = completion
    completion = nil
    options = nil
    c?(result)
  }

  private static func topViewController() -> UIViewController? {
    var top = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
```

> Note: the exact generated Swift symbol for `setUp` may be `ReceiptScannerApiSetup.setUp` or `ReceiptScannerApi.setUp` depending on the Pigeon version. After Task 2 generation, open `Messages.g.swift`, confirm the setup symbol and the `PigeonError` type name, and adjust Steps 6–7 to match. This is a mechanical name reconciliation, not a design change.

- [ ] **Step 8: Analyze the Dart side**

Run: `cd /Users/dongminyu/Development/01_personal/flutter_receipt_scanner && flutter analyze packages/flutter_receipt_scanner_ios`
Expected: no issues. (Swift is compiled later by the example app build in Task 7.)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(ios): add clean-room visionkit camera scan handler"
```

---

### Task 6: Android skeleton stub (unimplemented)

**Files:**

- Create: `packages/flutter_receipt_scanner_android/lib/flutter_receipt_scanner_android.dart`
- Create: `packages/flutter_receipt_scanner_android/android/build.gradle`
- Create: `packages/flutter_receipt_scanner_android/android/src/main/AndroidManifest.xml`
- Create: `packages/flutter_receipt_scanner_android/android/src/main/kotlin/com/example/flutter_receipt_scanner_android/FlutterReceiptScannerPlugin.kt`
- Test: `packages/flutter_receipt_scanner_android/test/registrant_test.dart`

**Interfaces:**

- Consumes: generated Kotlin `ReceiptScannerApi`, `ScanOptions`, `ScanResult` (Task 2); Dart `FlutterReceiptScannerPlatform`, `PigeonReceiptScannerPlatform` (Task 3).
- Produces: `FlutterReceiptScannerAndroid.registerWith()`; native plugin that answers `scan` with an unimplemented error.

- [ ] **Step 1: Write the failing registrant test** `test/registrant_test.dart`

```dart
import 'package:flutter_receipt_scanner_android/flutter_receipt_scanner_android.dart';
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('registerWith installs the Pigeon-backed platform', () {
    FlutterReceiptScannerAndroid.registerWith();
    expect(
      FlutterReceiptScannerPlatform.instance,
      isA<PigeonReceiptScannerPlatform>(),
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/flutter_receipt_scanner_android && flutter test`
Expected: FAIL — `FlutterReceiptScannerAndroid` not defined.

- [ ] **Step 3: Write the Dart registrant** `lib/flutter_receipt_scanner_android.dart`

```dart
import 'package:flutter_receipt_scanner_platform_interface/flutter_receipt_scanner_platform_interface.dart';

/// Android registrant. Skeleton milestone: native `scan` is unimplemented.
class FlutterReceiptScannerAndroid {
  static void registerWith() {
    FlutterReceiptScannerPlatform.instance = PigeonReceiptScannerPlatform();
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd packages/flutter_receipt_scanner_android && flutter test`
Expected: PASS.

- [ ] **Step 5: Write `android/build.gradle`**

```gradle
group = "com.example.flutter_receipt_scanner_android"
version = "0.1.0"

buildscript {
    ext.kotlin_version = "2.0.21"
    repositories { google(); mavenCentral() }
    dependencies {
        classpath "com.android.tools.build:gradle:8.6.0"
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

rootProject.allprojects { repositories { google(); mavenCentral() } }

apply plugin: "com.android.library"
apply plugin: "kotlin-android"

android {
    namespace = "com.example.flutter_receipt_scanner_android"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
```

- [ ] **Step 6: Write `AndroidManifest.xml`**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" />
```

- [ ] **Step 7: Write `FlutterReceiptScannerPlugin.kt`**

```kotlin
package com.example.flutter_receipt_scanner_android

import io.flutter.embedding.engine.plugins.FlutterPlugin

class FlutterReceiptScannerPlugin : FlutterPlugin, ReceiptScannerApi {
  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    ReceiptScannerApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    ReceiptScannerApi.setUp(binding.binaryMessenger, null)
  }

  override fun scan(options: ScanOptions, callback: (Result<ScanResult>) -> Unit) {
    callback(
      Result.failure(
        FlutterError("unimplemented", "Android scan is not implemented yet.", null),
      ),
    )
  }
}
```

> Note: confirm the generated Kotlin callback signature (`(Result<ScanResult>) -> Unit`) and the `FlutterError` type in `Messages.g.kt` after Task 2, and reconcile if the Pigeon version differs.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(android): add skeleton stub returning unimplemented"
```

---

### Task 7: Example app + iOS end-to-end verification + docs

**Files:**

- Create: `packages/flutter_receipt_scanner/example/` (via `flutter create`)
- Modify: `packages/flutter_receipt_scanner/example/lib/main.dart`
- Modify: `packages/flutter_receipt_scanner/example/ios/Runner/Info.plist` (camera usage string)
- Create: `README.md` (root — usage + scope note)
- Create: `LICENSE` (BSD 3-Clause)

**Interfaces:**

- Consumes: `scan`, `ScanReceiptOptions`, `ScanResult` (Task 4).
- Produces: a runnable example demonstrating the iOS camera path.

- [ ] **Step 1: Create the example app**

Run:

```bash
cd packages/flutter_receipt_scanner
flutter create --platforms=ios,android --org com.example example
```

Then add the plugin dep to `example/pubspec.yaml` under `dependencies:`:

```yaml
flutter_receipt_scanner:
  path: ../
```

- [ ] **Step 2: Write `example/lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_receipt_scanner/flutter_receipt_scanner.dart';

void main() => runApp(const _App());

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  String _status = 'idle';
  ScanResult? _result;

  Future<void> _scan() async {
    setState(() => _status = 'scanning…');
    try {
      final result = await scan(const ScanReceiptOptions(maxPages: 1));
      setState(() {
        _result = result;
        _status = result.status.name;
      });
    } on Object catch (e) {
      setState(() => _status = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _result?.images.isNotEmpty ?? false ? _result!.images.first : null;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Receipt Scanner')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('status: $_status'),
              if (img != null) ...[
                const SizedBox(height: 8),
                Text('uri: ${img.fileName}'),
                Text('ocr chars: ${img.ocrQuality?.textLength ?? 0}'),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _scan, child: const Text('Scan')),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add camera usage description to `example/ios/Runner/Info.plist`**

Add inside the top-level `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan receipts with the camera.</string>
```

- [ ] **Step 4: Analyze + test the whole workspace**

Run: `cd /Users/dongminyu/Development/01_personal/flutter_receipt_scanner && dart run melos run analyze && dart run melos run test`
Expected: analyze clean; all package tests pass.

- [ ] **Step 5: Build + run the iOS example (device or simulator)**

Run:

```bash
cd packages/flutter_receipt_scanner/example
flutter build ios --no-codesign --simulator
```

Expected: Swift compiles (validates Task 5 symbol reconciliation). Then run on a physical device (`flutter run`) and tap **Scan**: VisionKit opens, capture a receipt, confirm the app shows `status: success` and a non-zero `ocr chars`. (VisionKit camera needs a real device; the simulator build only proves compilation.)

- [ ] **Step 6: Write root `README.md`** (usage + ADR-003 scope note + host-permission note: iOS `NSCameraUsageDescription`).

- [ ] **Step 7: Add `LICENSE`** (BSD 3-Clause, holder "Dongmin Yu").

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add example app and iOS end-to-end verification"
```

---

## Verification (whole skeleton)

Run from repo root:

```bash
dart run pigeon --input pigeons/messages.dart   # regenerates cleanly
dart run melos list                             # four packages
dart run melos run analyze                       # zero issues
dart run melos run test                          # all Dart tests pass
cd packages/flutter_receipt_scanner/example && flutter build ios --no-codesign --simulator
```

Milestone acceptance: on a physical iOS device, tapping **Scan** opens VisionKit, and a captured receipt returns `ScanResult(status: success)` with a valid `file://` JPEG uri and non-empty OCR text.

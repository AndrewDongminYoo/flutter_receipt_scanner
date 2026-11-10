# Flutter FFI Overlap Pilot Report

## Decision and scope

This is an explicit pilot for RN issue #68, not production adoption.
The operator confirmed the current delivery scope as implementation and virtual-device verification because physical hardware is unavailable; the original physical acceptance gates remain incomplete and RN issue #68 remains open.
The accepted [RN contract](https://github.com/AndrewDongminYoo/react-native-receipt-scanner/blob/main/docs/specs/ocr-overlap-pilot.md) retains all numerical budgets; issue #70 owns adoption.
The operator scoped this delivery to implementation and virtual-device verification on 2026-11-10 because no Android physical device is available.
RN issue #68 remains open for the measurement gates below.

Flutter baseline: `66ac09dca3f20163fc4e55fd7982f3b23d38d853`.
Candidate: the implementation diff accompanying this report; a final candidate SHA must be recorded before physical measurements.
Core source: ABI 1, RN `fb37f24a86014829a31897ca891d45a78208aa6c`, complete `cpp/receipt_core` snapshot under `receipt_scanner_core/third_party/receipt_core` with MIT license and SHA-256 manifest.

Ordinary scanner calls still use the Dart matcher.
The app-facing package uses core only as a development dependency; the explicit example consumes it normally.
The internal matcher callback validates returned counts; public barrels, scanner signatures and platform transports remain unchanged.
Dart owns normalization, original trimmed text, assembly, quality and floor policy.
The FFI wrapper checks ABI and uint32 sizes, owns UTF-16 buffers/descriptors/output and releases them through an Arena in a `finally` block.
The native call is synchronous, allocation-free and retains no pointers.

## Host evidence

Commands below ran on the development macOS host on 2026-11-10.
Run package commands from their named package directories unless stated otherwise.

| Scenario                                     | Invocation                                                                                                                                                                                                         | Exit | Observable output                                                                                                                                                  |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Intended red assertion before implementation | Core: `dart test test/overlap_test.dart --plain-name 'deepest overlap preserves literal UTF-16 semantics' --reporter expanded`                                                                                     | 1    | Expected 2, actual 0 against a real stub; imports and native build hook succeeded                                                                                  |
| Generated bindings                           | Core: `dart run tool/ffigen.dart`                                                                                                                                                                                  | 0    | Generated binding and recorded-use mapping under `lib/src/third_party/`                                                                                            |
| Initial ownership and ABI suite              | Core: `dart test --reporter expanded`                                                                                                                                                                              | 0    | Four tests passed: overlap examples, serial plus four isolate batches of 10,000 calls, success/partial-allocation cleanup, malformed descriptor/null/layout checks |
| Shared corpus                                | App: `flutter test test/ocr_contracts_test.dart --reporter expanded`                                                                                                                                               | 0    | 81 tests passed: 29 merge fixtures through each matcher, 21 Dart quality fixtures, checksum and invalid callback checks                                            |
| Frozen workload reader                       | App: `flutter test test/overlap_pilot_test.dart --reporter expanded`                                                                                                                                               | 0    | Two tests passed; all 48 complete merge operations agree                                                                                                           |
| Independent RN generator oracle              | RN: `node -e` requiring `pilot/workloads.js`, SHA-256 of `JSON.stringify(workloads())`                                                                                                                             | 0    | `be17e753bd70cf21e358ceb3221adf66283ed52a2b32549877c9a52ad4ab86ce`; Dart reader matches exactly                                                                    |
| Intentional fixture corruption               | App: `flutter test test/overlap_pilot_test.dart --dart-define=OVERLAP_PILOT_CORRUPT_EXPECTATION=true --plain-name 'headless consumer validates literal fixtures and complete workload parity' --reporter expanded` | 1    | `Bad state: Fixture mismatch: empty-pages`                                                                                                                         |
| Standalone package analysis                  | Core: `dart analyze .`                                                                                                                                                                                             | 0    | No issues found                                                                                                                                                    |
| Publication inventory                        | Core: `dart pub publish --dry-run`                                                                                                                                                                                 | 0    | Package has 0 warnings; full snapshot, hook and generated bindings included; compressed archive approximately 15 KB                                                |
| Independently unpacked source consumer       | Root: `python3 receipt_scanner_core/tool/verify_packed.py`                                                                                                                                                         | 0    | Snapshot verified, offline dependency resolution, source build and `PACKED_CONSUMER_PASS overlap=2`; independently assembled source archive 14,674 bytes           |

The independent verifier builds an independently assembled source archive, then unpacks it into a temporary directory and resolves a separate Dart consumer offline.
It removes only the extracted package's workspace-resolution marker to stand alone.
This is distinct from the pub dry-run inventory and does not claim inspection of a downloaded published artifact.
There is no build-time core download.

The final suite additionally covers uint32 overflow before allocation and the exact accepted snapshot identity.
Final workspace checks and mobile results are recorded below; earlier partial runs do not substitute for these checks.

## Reproduction and frozen inputs

The headless consumer is `flutter_receipt_scanner/example/lib/overlap_pilot.dart`.
Run `flutter run --target lib/overlap_pilot.dart` from the example directory.
It checks literal expected merge results and URI order for all 29 fixtures through both matchers, then all 48 synthetic sets through complete Dart assembly.
It prints `OVERLAP_PILOT_PASS mergeCases=29 workloads=48 abi=1 source=fb37f24a86014829a31897ca891d45a78208aa6c` only after parity succeeds.
Its embedded corpus is compared to the checksum-verified source fixture by a host test.
A parent-directory Flutter asset initially passed host file reading but was omitted from the APK; the first Android run failed before parity.
The embedded corpus removes that asset-path dependency; subsequent Android and iOS runs below passed the same parity reader.

`pilot_workloads.dart` ports frozen RN generator v1: seed `0x69c0ffee`, small/typical/stress, none/half/full/near, ASCII/Korean/supplementary/whitespace-case variants, 48 ordered sets.
Dart UTF-16 substring behavior and LCG arithmetic preserve the RN workload hash, including truncated supplementary sequences.
`--dart-define=PILOT_BENCHMARK=true` explicitly enables five paired runs, alternating baseline/candidate order, 100 warmups and 1,000 samples per set.
The harness records raw microsecond samples, median, p95 and consumed output lengths for the complete operation including normalization, conversion, allocation, native matching, cleanup and final assembly.
Device/OS/compiler/runtime/thermal metadata must be recorded by the measurement operator.
Do not use debug builds or simulator measurements to claim physical-device latency acceptance.

## Dependencies and distribution

Compatible installed packages are `ffigen 23.0.0`, `hooks 2.2.0`, `code_assets 2.2.0`, `native_toolchain_c 0.19.6` and `ffi 2.2.0`.
Build-hook dependencies are normal dependencies so consumers can compile source.
`ffigen 21` requires code-assets 1 and cannot resolve with the selected toolchain; version 23 supplies the compatible generator API.
Generator/test constraints require shared-lockfile analyzer 13.3.0, analyzer-shared 103 and package-config 2.2 instead of the former 14.7/111/3 versions.
Existing runtime direct dependencies were not upgraded.
The hook builds optimized C++17, disables exceptions/RTTI, hides non-ABI symbols and uses Android static C++ linking plus 16 KiB maximum page alignment.

CI checks source manifest/inventory, pinned source identity, generated binding drift, Dart tests, shared corpus and independently unpacked source consumption.
The Linux sanitizer job runs ASan and UBSan, with leak detection enabled, and uses an explicit Flutter fixture path for the unchanged upstream corpus reader.
The iOS Simulator CI job builds the headless `lib/overlap_pilot.dart` consumer, then `tool/run_overlap_simulator.py` launches the packaged app and checks all 29 merge fixtures and 48 workloads through its exact completion marker.
The separate manual `example/integration_test/overlap_pilot_test.dart` regression uses Flutter SDK `integration_test`; its driver dependencies are development-only.
Android pilot runtime parity is locally verified; continuous Android CI currently runs the existing Kotlin suite rather than this pilot.
The vendored CMake corpus test's default path assumes the RN layout; CI invokes that reader explicitly rather than editing the immutable snapshot.
Configured CI jobs are not recorded as executed remote evidence.

## Incomplete acceptance gates

Physical Android and iOS release timing, the five paired numerical comparisons and stress geometric mean are incomplete.
Retained managed-plus-native profiler evidence after five 10,000-call batches is incomplete; allocator balance and host RSS cannot replace that evidence.
Paired clean/no-op build medians, stripped release native-code growth per architecture and mobile compressed artifact growth are incomplete.
The approximate source archive size is diagnostic and is not a paired growth measurement.
Android 16 KiB runtime execution remains incomplete on a 4 KiB emulator even when ELF/ZIP alignment checks succeed.
The direct records below cover mobile parity, independently packed mobile consumers and final workspace gates.
These limits retain the Dart default and prevent an adoption claim.

## Final verification records

The root retained complete local gate logs and checked the final production LCOV records.
Host: macOS arm64, Flutter 3.47.9, Dart 3.13.7, Xcode 26.6.
Android: Play-enabled arm64 Android 17/API 37 emulator, 4 KiB pages, Debug.
iOS: iPhone 17 Simulator, iOS 26.5, Debug.
The packed mobile consumers used an independently archived and extracted core in a fresh workspace copy, resolved offline without original package build caches.

| Gate                                                  | Observed result                                                                                                   | Limit                                                                              |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Workspace analysis                                    | Six packages, no issues                                                                                           | Static analysis                                                                    |
| `dart run melos run test:ci`                          | Core 6; Flutter app 155, Android 10, iOS 10, platform interface 24, example 5; all passed                         | Host execution                                                                     |
| `flutter analyze lib test` in four published packages | No issues                                                                                                         | Existing strict package gate                                                       |
| Production LCOV                                       | App 135/135, Android 92/92, iOS 86/86, platform interface 55/55                                                   | Generated Pigeon Dart excluded under CI policy                                     |
| Binding regeneration and source integrity             | No generated drift; manifest and canonical bytes verified                                                         | Pinned source only                                                                 |
| Offline unpacked source consumer                      | `PACKED_CONSUMER_PASS overlap=2`, archive 14,716 bytes at this check                                              | Observed archive, not reproducibility or paired release growth                     |
| Final pub dry-run                                     | 15 KB compressed, zero warnings; hook, bindings and sources included                                              | Inventory; nothing published                                                       |
| Original Android example                              | 29 merge fixtures and 48 workloads passed; hot restart repeated the marker                                        | Local Debug consumer                                                               |
| Packed Android consumer                               | 29 merge fixtures and 48 workloads passed                                                                         | Emulator integration                                                               |
| Packed iOS consumer                                   | 29 merge fixtures and 48 workloads passed; hot restart repeated the marker                                        | Simulator integration                                                              |
| Manual iOS SDK integration test                       | Passed on the Simulator                                                                                           | CI now uses native launch instead of VM discovery                                  |
| Fresh Simulator native launch                         | Current PID and timestamp matched the pinned 29/48 marker; app cleanup passed                                     | No physical latency claim                                                          |
| Native log-reader controls                            | Five tests passed, rejecting other PID, stale time, wrong revision and missing marker                             | Reader protocol only                                                               |
| Packed Android artifact                               | Core 4,472 bytes; two LOAD alignments `0x4000`; libc/libdl only; two defined ABI exports; ZIP 16 KiB check passed | Debug artifact, no 16 KiB runtime or paired release-size claim                     |
| Canonical CMake safety                                | ASan and UBSan: core, C ABI, shared corpus and vendor snapshot passed                                             | macOS leak detection disabled; Linux CI enables it                                 |
| Formatting and Trunk                                  | Scoped formatting and full changed-file check passed                                                              | Immutable vendor bytes excluded only from Prettier; integrity checks remain active |

Independent core and pipeline reviews found no blocking code issues.
Physical measurement gates remain incomplete under the operator-confirmed scope.

## CI transport regression

At head `f15f827`, [the hosted iOS job](https://github.com/AndrewDongminYoo/flutter_receipt_scanner/actions/runs/42731384970) reached a successful integration-test Xcode build, then produced no Dart test-start output before its 15-minute job limit.
Flutter 3.47.9 waits for the VM URI through an asynchronously started Simulator log reader; [Flutter issue #181771](https://github.com/flutter/flutter/issues/181771#issuecomment-3891689120) describes a matching race.
That is a plausible cause, not a confirmed diagnosis of the hosted runner.

The algorithm gate does not need VM attachment or UI driving.
CI now builds the explicit headless app once and launches it directly with `simctl`.
The runner reads persisted unified-log JSON after launch, matching the launched PID, a timestamp after launch, and the exact fixture/workload/ABI/source marker.
It fails on missing completion, a different process, a stale event, a different revision, or a bounded timeout; it terminates only the app it launched.
Five reader tests include negative controls for those false-pass paths.
A fresh local Simulator completed the native parity run with the pinned 29/48 marker; raw console-only capture was rejected because Flutter writes that marker to unified logging.
The existing 15-minute CI job limit and all pilot acceptance budgets remain unchanged.

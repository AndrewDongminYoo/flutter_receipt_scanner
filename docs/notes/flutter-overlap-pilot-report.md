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

The independent verifier builds a independently assembled source archive, then unpacks it into a temporary directory and resolves a separate Dart consumer offline.
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
The existing iOS Simulator CI job additionally executes `example/integration_test/overlap_pilot_test.dart` against all 29 merge fixtures and 48 workloads.
This uses Flutter SDK `integration_test`; its driver dependencies are development-only.
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

Worker final host records:

| Scenario                                 | Invocation                                                                                                                                                 | Exit | Output                                                                                   |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------- |
| Final core suite including size/identity | Core: `dart test --reporter expanded`                                                                                                                      | 0    | All 6 tests passed                                                                       |
| Complete workspace strict analysis       | Root: `dart run melos run analyze`                                                                                                                         | 0    | All 6 packages: No issues found                                                          |
| Scoped formatting                        | Root: `dart format --output=none --set-exit-if-changed` over core lib/hook/generator/tests, merger, contract/pilot tests and headless/workload entrypoints | 0    | 14 files, 0 changed                                                                      |
| Final snapshot check                     | Root: `python3 receipt_scanner_core/third_party/receipt_core/vendor.py --check`                                                                            | 0    | ABI v1 verified at pinned revision                                                       |
| App coverage reader                      | Python reader of each `SF:lib/` record in `flutter_receipt_scanner/coverage/lcov.info`                                                                     | 0    | Zero uncovered lines in `ocr_floor.dart`, `receipt_scanner.dart`, `ocr_page_merger.dart` |

`dart run melos run test:ci` exited 0 after core and all five Flutter packages passed.
Its streamed transcript was truncated by the tool, so root must retain a complete final reader before using it as exhaustive evidence.
Root integration records still required: scoped Trunk, Android/iOS Simulator parity, packed mobile consumer execution and artifact checks.

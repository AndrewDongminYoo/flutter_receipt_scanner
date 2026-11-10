# Flutter FFI Overlap Pilot

Tracking: [RN issue #68](https://github.com/AndrewDongminYoo/react-native-receipt-scanner/issues/68).
The accepted [pilot contract](https://github.com/AndrewDongminYoo/react-native-receipt-scanner/blob/main/docs/specs/ocr-overlap-pilot.md) owns compatibility and numerical budgets.

## Scope

Add an explicit synthetic FFI pilot through a new `receipt_scanner_core` Dart workspace package.
Vendor ABI v1 from RN source `fb37f24a86014829a31897ca891d45a78208aa6c` with its license and complete SHA-256 manifest.
Keep normalization, original text, page assembly and quality policy in Dart; ordinary scanner calls retain the Dart matcher.
Pigeon and the federated native plugins retain their existing contracts.

## Implementation

1. Add source-only native assets, generated bindings and a buffer-owning wrapper; observe a real overlap assertion fail before implementing the wrapper.
2. Exercise invalid input, cleanup, concurrent calls and the shared merge/quality corpus; prove a corrupted expectation fails.
3. Add a test-only merger seam and headless consuming example with the frozen 48 synthetic workload sets.
4. Update workspace, Melos and CI discovery, regenerate the lockfile and verify independently packed source contents.
5. Run host safety/parity, applicable Android 16 KiB checks and Android/iOS Simulator consumer execution, one heavy job at a time.
6. Record host and mobile evidence, exact revisions and measurement limits in `docs/notes/flutter-overlap-pilot-report.md`; review the complete candidate before publication.

## Verification

Run `melos run analyze`, the workspace tests, package-level analysis and coverage gates, scoped Dart formatting and Trunk formatting/checks.
Native assets must compile from a packed package without fetching core source.
Use the accepted five paired release-run protocol for physical-device timing, retained-memory profiling, package growth and clean/no-op build costs.
The operator scoped this delivery to implementation and virtual-device verification because an Android physical device is unavailable.
Missing physical-device or profiler evidence remains incomplete, RN issue #68 stays open, and this delivery does not claim numerical acceptance.
Preserve all thresholds and leave production adoption to RN issue #70.

# Receipt Scanner Core Pilot

Explicit experimental Dart FFI adapter for ABI v1 of the vendored MIT overlap core.
Ordinary `flutter_receipt_scanner.scan()` calls retain the Dart matcher.
The wrapper accepts normalized lines, owns all UTF-16 buffers and descriptors, checks the ABI and releases allocations even after partial failure.
Native code performs only synchronous overlap matching; normalization, quality and assembly stay in Dart.

```sh
flutter pub get # workspace root
cd receipt_scanner_core
dart run tool/ffigen.dart
dart test
dart analyze
python3 third_party/receipt_core/vendor.py --check
python3 tool/verify_packed.py
dart pub publish --dry-run
```

The build hook compiles local source with `native_toolchain_c`; no core source download occurs.
Generated bindings and recorded-use mapping live in `lib/src/third_party/`.
The full upstream snapshot, license, immutable revision and checksums live in `third_party/receipt_core/`.
Do not edit the vendored snapshot or generated bindings directly.
The source-archive verifier unpacks independently and executes an offline Dart consumer; it does not establish mobile distribution acceptance.
Physical performance, retained memory and mobile artifact budgets remain subject to the accepted RN pilot contract.

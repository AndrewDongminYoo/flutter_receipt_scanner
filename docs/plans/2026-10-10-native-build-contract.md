# Native build contract execution

Contract: [native build contract](../specs/2026-10-10-native-build-contract.md).

1. Verify the latest main, account, original merged PR, existing worktrees, and remaining budget.
2. Reproduce the actual iOS build failure and inspect locked Pigeon callback generation and Flutter deployment-target propagation.
3. Update the root schema annotations and regenerate; run `flutter build ios --simulator --config-only --no-pub` before direct Xcode tests so Flutter propagates the existing iOS 16 project setting into its generated package.
4. Replace the placeholder Simulator test with synthetic native batch/wire regressions and validate the production plugin through the example build.
5. Resolve the pinned Android graph online with task-local caches and run the native unit-test target without device access.
6. Run Flutter tests, analysis, formatting, independent review, and scoped commits.
7. Publish one follow-up PR explaining the remaining verification after PR 17; observe exact-head CI/code/security review and leave merge to the operator.

Owned paths are the root Pigeon schema and generated outputs, the scoped `.swiftformat` configuration, example iOS configuration and RunnerTests, and this contract/plan.
Android source changes are permitted only if the normal pinned native build identifies a concrete defect related to this verification.

The default typeSugar formatter rule reproduces an Any/Equatable compile error when it rewrites the generated Optional enum pattern.
Retain the generator output through a file-specific formatter rule exception, without hand-editing generated code.

## Reproduce native verification

Run `flutter pub get --enforce-lockfile` at the workspace root.
Prepare the iOS example with `flutter build ios --simulator --debug --no-pub` from the example directory; this propagates the supported deployment target into the generated Swift package.
Then run `xcodebuild test` for the Runner scheme on a fresh Simulator, with task-local `-derivedDataPath`, `-clonedSourcePackagesDirPath`, `-resultBundlePath`, and `CODE_SIGNING_ALLOWED=NO`.
RunnerTests checks the real plugin's callback protocol/capability completion and production batch/wire/null helpers using synthetic input.
It does not exercise camera/gallery UI or photo decoding.
For Android, use the existing example's Gradle wrapper and `:flutter_receipt_scanner_android:testDebugUnitTest`, with `GRADLE_USER_HOME` and `ANDROID_USER_HOME` set to disposable task directories.
Resolve the existing pins online rather than treating a missing offline cache as a code defect.

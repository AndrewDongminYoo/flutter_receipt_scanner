# Native build contract after PR 17

PR 17 merged the page omission fix while iOS integration could not compile and Android verification used a standalone helper fallback.
This follow-up makes the existing native implementations buildable and checks their regressions without changing scan policy.

## Contract

Use the root Pigeon schema and the locked Pigeon version to generate callback completions matching the native implementations.
Keep message fields, codecs, method channels, Dart futures, and public APIs unchanged.
Preserve Pigeon's explicit Optional enum pattern by restricting the SwiftFormat typeSugar rule for its generated Swift file only.
Preserve the supported iOS 16 and Android 24 baselines.
Keep dependency versions pinned and resolve Android dependencies from official repositories using isolated task caches.
Do not modify security settings, credentials, or global configuration; do not access user-installed apps, physical cameras, or actual photos.

## Acceptance

- Observe the iOS protocol compile failure before the fix, then compile the Simulator example successfully.
- Run meaningful Simulator native regressions with synthetic input and the production batch helper.
- Run Android native Gradle unit tests, including page omission regressions, through the normal dependency graph.
- Run Flutter workspace tests, analysis, scoped formatting, independent review, and exact-head CI/code/security review.
- State any remaining native pipeline limitations accurately.

## Boundaries

One follow-up PR is authorized because PR 17 is already merged.
Continue the recorded additional budget of two changed heads and 120 minutes.
Merge, deployment, version release, branch deletion, and memory recording are not authorized.
No visual output changes are planned.

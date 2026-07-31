---
type: Work Item
title: Example, Documentation, and 0.5.0 Release
parent: ../spec.md
---

## What to build

Expose the feature in the example app, document it with honest calibration scope, and cut the coordinated 0.5.0 release.

Example app: add an editable OCR language list control (comma-separated BCP 47 input seeded with `ko-KR, en-US`) that is disabled when `ocr` is off, a capabilities action that invokes `getOcrCapabilities()` and renders the platform variant (supported languages on iOS, per-script model states on Android) without triggering downloads, and surfacing of the new configuration errors in the existing error display path with the `PlatformException` code visible.

Documentation: add a multilingual OCR section to both READMEs covering the option, the default-preserving behavior, the capability query, the four error codes, and the Android bundled-versus-dynamic model distinction.
Label the 11.0 aspect-ratio support claim and the seam similarity thresholds as validated for Korean plus Latin only; other scripts are provider-supported and uncalibrated.
Release notes must not claim improved OCR or merge accuracy for uncalibrated languages.

Release: bump all four packages to 0.5.0 with changelog entries, regenerate the workspace lockfile in the same commit, and publish in RELEASING.md dependency order after operator approval.

iOS physical QA before release: a default Korean plus English regression scan, one supported non-default language scan, and one syntactically valid but unsupported tag rejected before UI.
Record the runs in `docs/notes/2026-07-30-physical-acceptance-record.md`.
Android physical QA (dynamic model download, install-wait flow, offline `OCR_MODEL_INSTALL_FAILED`) stays deferred until an Android device is available.

## Required context

- `flutter_receipt_scanner/example/lib/main.dart` is already large — keep diffs surgical and do not decompose the UI without an explicit request.
- The READMEs' existing "Long receipts (multi-page OCR merge)" sections hold the support contract and capture guidance; extend them rather than adding parallel sections.
- Release procedure and tag pattern: `RELEASING.md`; publishing is external impact and needs operator approval before tags are pushed.
- Merge behavior is unchanged by language selection: seam matching, thresholds, boundary and rejected-page diagnostics, and the `discardedPageCount` completeness override operate on whatever text the selected recognizer returns.

## Acceptance criteria

- [ ] The example exposes a comma-separated BCP 47 language control seeded with the default and disabled when `ocr` is off.
- [ ] The example renders a `getOcrCapabilities()` result per platform variant without triggering downloads, and shows the new error codes in the existing error path.
- [ ] Example widget tests cover the language control (default seed and disabled state) and rendering of a canned capabilities result, with no live platform calls.
- [ ] Both READMEs document the option, default-preserving behavior, capability query, four error codes, and the Android bundled-versus-dynamic model distinction.
- [ ] Both READMEs label the 11.0 claim and seam thresholds as Korean-plus-Latin calibrated, with other scripts marked provider-supported and uncalibrated.
- [ ] All four packages are bumped to 0.5.0 with changelog entries that make no accuracy claims for uncalibrated languages, and the lockfile is regenerated in the same commit.
- [ ] iOS physical QA covers the default regression scan, one non-default supported language, and one unsupported tag rejected before UI; results are appended to the acceptance record.
- [ ] `melos run format`, `melos run analyze`, `melos run test`, `trunk fmt`, and `trunk check` pass, and `dart pub publish --dry-run` reports zero warnings in all four packages.
- [ ] Publication happens only after operator approval, in RELEASING.md dependency order, with each publish workflow verified before the next tag is pushed.

## Covers

- User Stories: 4, 5
- Requirements: Merge Interplay 1-5; Example App 1-3; Versioning and Dependencies 1-3
- Testing Strategy: example widget coverage; physical QA; repository verification
- Interview Ledger: L2, L3

## Blocked by

- [01-contract-and-capabilities.md](01-contract-and-capabilities.md)
- [02-language-application.md](02-language-application.md)

## Blocking decisions

- Operator approval is required before pushing publish tags; Android physical QA remains deferred until a device is available.

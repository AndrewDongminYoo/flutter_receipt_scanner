# Releasing

This is a federated plugin: four independently versioned packages published to pub.dev.
Publishing is automated with GitHub Actions OIDC (`.github/workflows/publish.yml`) — no stored credentials.

## Package dependency order

A package must exist on pub.dev before its dependents can resolve, so publish in this order:

1. `flutter_receipt_scanner_platform_interface`
2. `flutter_receipt_scanner_ios` and `flutter_receipt_scanner_android` (both depend on the interface)
3. `flutter_receipt_scanner` (depends on all three)

## First publication (manual, one-time per package)

pub.dev automated publishing only works for packages that already exist, so the initial version of each package is published by hand, in dependency order:

```bash
cd flutter_receipt_scanner_platform_interface && dart pub publish
cd ../flutter_receipt_scanner_ios && dart pub publish
cd ../flutter_receipt_scanner_android && dart pub publish
cd ../flutter_receipt_scanner && dart pub publish
```

Then, on pub.dev, for each package open Admin › Automated publishing, enable publishing from GitHub Actions, and set:

- Repository: `AndrewDongminYoo/flutter_receipt_scanner`
- Tag pattern: `<package_name>-v{{version}}` (e.g. `flutter_receipt_scanner_ios-v{{version}}`)

## Subsequent releases (automated)

1. Bump `version:` in the package's `pubspec.yaml` and add a `## <version>` section to its `CHANGELOG.md`.
2. Commit and merge to `main` (do not squash if you tag before merging).
3. Tag and push:

   ```bash
   git tag -a <package_name>-v<version> -m "<package_name> <version>"
   git push origin <package_name>-v<version>
   ```

4. The `publish` workflow triggers on that tag and publishes the package via OIDC.
   The tag version must equal the `pubspec.yaml` version or pub.dev rejects the publish.

A single-package release needs no coordination — bump one package, push its tag, done.

## Coordinated multi-package release

When interdependent packages bump together, push their tags in dependency order and let each publish job finish before pushing the next, so dependents can resolve the newly published versions:

```log
platform_interface  →  ios, android  →  flutter_receipt_scanner
```

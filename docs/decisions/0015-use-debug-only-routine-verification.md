# Use Debug-Only Routine Verification

## Status

Accepted on 2026-08-25.

## Context

Phase 1 feature work repeatedly ran Android Debug/Release and iOS
Debug/Release no-codesign builds even when the change was limited to Dart
application logic. The most recent matrix left about 5.1 GB of generated
content under `build/`, including duplicate Debug and Release APKs and several
iOS `Runner.app` bundles.

Those matrices were useful while establishing provider and native compatibility,
but they are not an efficient default for every frontend slice. The product
owner will perform physical-device validation later and currently needs only
evidence that routine feature work compiles in Debug.

## Decision

- Make format, analyze, and relevant/full Flutter tests the routine verification
  path.
- When native compilation evidence is needed, run
  `bin/flutter build apk --debug` once at the completed feature checkpoint, not
  after every intermediate edit.
- Keep Android Release and both iOS no-codesign commands documented as a manual
  release matrix. Do not run them unless the user explicitly requests them or
  a later decision changes this policy.
- Treat Web release, interactive `flutter run`, signing, provider runtime, and
  physical-device checks as manual-only. The product owner owns device
  validation, and every skipped runtime check remains explicitly unverified.
- Keep generated APK, AAB, IPA, `Runner.app`, and `build/` content out of Git.
  Use `bin/flutter clean` when artifact cleanup is requested.
- Encode this policy in `AGENTS.md`, `README.md`, and `harness.json`. The Harness
  must reject the old automatic `native_release_matrix` key and any routine
  native gate other than Android Debug.

## Consequences

Routine frontend iterations use less time and disk space and no longer imply
Release, iOS, signing, provider, or device evidence that was not requested.
Android Debug compilation remains available as the single native checkpoint.

Dependency, toolchain, platform, release, and store-readiness changes may need
the broader matrix later, but the agent must first receive an explicit request
or a superseding decision. This intentionally trades continuous Release/iOS
evidence for faster Phase 1 iteration; those skipped gates must never be
reported as passing.

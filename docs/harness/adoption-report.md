# Harness Adoption Report

Date: 2026-08-24

## Baseline

`loop-mobile` was already the formal Flutter product repository with a strong UI foundation: 103 catalogued surfaces, six primary destinations, a dark design system, responsive behavior, routing, and preview adapters. It lacked repository-wide agent instructions, executable drift checks, failure memory, final native identity, the verified provider dependency graph, and a compatible Privy native floor. Android used minSdk 24/AGP 9.1/Gradle 9.3.1/Kotlin 2.4.0; iOS used 15.0 and Flutter SwiftPM; both platforms still used `com.dinolabs...` identifiers.

## Adopted surfaces

- `AGENTS.md` is the repository-wide product, architecture, security, and workflow contract.
- `harness.json` is the machine-readable active profile and preserves the six-destination navigation contract.
- `bin/flutter`, `bin/dart`, and `bin/loop-sdk` reject Flutter/Dart version drift.
- `scripts/check_harness.py` and `tests/test_check_harness.py` validate exact pins, lockfiles, native identity/toolchain, records, provider shortcuts, secret paths, and Launchpad retention.
- Numbered decisions, failure memory, product constraints, compatibility/integration reports, and the dependency/license register preserve rationale and evidence.

## Rules and checks

- Direct dependencies and both package-manager lockfiles must remain exact and committed.
- Android remains API 28–36 with the Privy library compileSdk override; iOS remains 17.0 with project-local SwiftPM disabled and CocoaPods 1.16.2.
- Android/iOS IDs remain `com.cywd.loop`; iOS tests use `com.cywd.loop.RunnerTests`.
- Home / Market / Launch / Chat / Wallet / Profile remain primary destinations; the checker fails if Launch is removed from the profile.
- Harness source guards reject Privy debug/verbose logging, Stream dev tokens/guests, and premature Firebase initialization.
- Git-visible `.env`, private-key, service-account, and Firebase Admin credential paths fail validation. `.gitnexus/` and project-local SDK artifacts are ignored.

## Verification

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter pub get`: passed and regenerated `pubspec.lock` with the exact direct graph.
- `python3 -m py_compile scripts/check_harness.py tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed, 9 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed, no issues.
- Flutter tests passed 55/55. Android Debug and unsigned Release builds, plus iOS Debug and Release no-codesign builds, passed. Exact results and the sqlite3 download note are recorded in `docs/phase-1/frontend-integration-report.md`.

## Assumptions and follow-up

- Flutter 3.47.1 revision `6655482ec06e547f90abf8ae7590466f4415978d`, Xcode 26.6, CocoaPods 1.16.2, Android SDK 36, and Java 17 remain available to CI/developers.
- Provider compile success is not provider runtime proof. Real Privy, Stream, Firebase, push, call, wallet-signing, and private-trading tests remain gated by dashboard/backend/device inputs.
- Add CI execution for the Harness and Flutter tests when the repository's deployment workflow is selected.
- Re-run all four native release checks after any dependency or toolchain change.

## Failure memory

Three evidenced compatibility failures were migrated: Flutter 3.47's Gradle 8.14 floor, Privy 0.10.1's compileSdk mismatch with AndroidX Credentials, and file_picker 11's brittle SwiftPM cold-cache path. Each record names detection, prevention, and evidence; the Harness automates their durable controls.

## Effectiveness

Measure the Harness by zero repeated occurrences of the recorded native failures, zero committed privileged secrets, zero fake provider-connected states, exact lockfile/pin agreement, retention of all six primary destinations, and consistent completion of format/analyze/test plus the native matrix for structural changes. Update this report when a rule prevents a regression or creates a false positive.

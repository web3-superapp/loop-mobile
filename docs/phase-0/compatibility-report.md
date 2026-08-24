# Loop Mobile Native Compatibility Baseline

Date migrated: 2026-08-24

## Accepted matrix

| Surface | Locked value |
| --- | --- |
| Flutter / Dart | 3.47.1 / 3.13.1 |
| Android | minSdk 28, compile/target 36, AGP 8.13.2, Gradle 8.14, Kotlin 2.3.20, Java 17 |
| iOS | target 17.0, Xcode 26.6, CocoaPods 1.16.2, project-level SwiftPM disabled |
| Identity | Privy Flutter 0.10.1 |
| Communication | Stream Chat/Persistence 10.3.0; Video/Push 1.4.3 |
| Push | Firebase Core 4.13.0; Messaging 16.5.0 |
| App identity | `com.cywd.loop`; tests `com.cywd.loop.RunnerTests` |

## Evidence inherited from the compatibility spike

Before migration into the formal UI repository, the exact native dependency graph passed:

- Android Debug and Release APK builds.
- iOS Debug and Release builds with `--no-codesign`.
- Flutter analysis/tests and the repository Harness.
- Physical Pixel 7a Debug install and runtime inspection of the shell and public Hyperliquid Testnet market list.

That evidence proves coexistence of the pinned native graph, not provider-backed runtime behavior. The formal repository must repeat the matrix after UI/foundation integration; current results belong in `docs/phase-1/frontend-integration-report.md`.

## Compatibility controls

- Privy's published Android artifact requires minSdk 28.
- All Android library subprojects compile on API 36 after evaluation because Privy 0.10.1 otherwise assigns API 34 below AndroidX Credentials' API 35 floor.
- Flutter 3.47.1 requires Gradle 8.14 for AGP 8.13.2.
- CocoaPods is retained because Stream's file_picker 11 dependency made cold-cache SwiftPM resolution brittle.
- Toolchain wrappers reject any Flutter revision other than `6655482ec06e547f90abf8ae7590466f4415978d` and Dart other than 3.13.1.

## Unverified gates

- Privy Email OTP and embedded wallet behavior with the final Mobile App Client ID.
- Stream Chat/Video token minting and two-user/two-device behavior.
- Firebase delivery, APNs/VoIP, CallKit, background and terminated-state calls.
- Wallet signing, backend idempotency/reconciliation, and private Hyperliquid Testnet trading.
- Store signing, provisioning, release upload, and production environments.

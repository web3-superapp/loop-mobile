# Loop Mobile Native Compatibility Baseline

Date migrated: 2026-08-24

## Accepted matrix

| Surface | Locked value |
| --- | --- |
| Flutter / Dart | 3.47.1 / 3.13.1 |
| Android | minSdk 28, compile/target 36, AGP 8.13.2, Gradle 8.14, Kotlin 2.3.20, Java 17 |
| iOS | target 17.0, Xcode 26.6, CocoaPods 1.16.2, project-level SwiftPM disabled |
| Identity | Privy Flutter 0.10.1 |
| External credential transport | `reown_appkit` 1.8.4; lock resolves `reown_core` 1.5.0 and `reown_sign` 1.4.0; Phase 1 native compilation matrix passed on 2026-08-29 |
| Communication | Stream Chat/Persistence 10.3.0; Video/Push 1.4.3 |
| Push | Firebase Core 4.13.0; Messaging 16.5.0 |
| App identity | `com.cywd.loop`; tests `com.cywd.loop.RunnerTests` |

## Evidence inherited from the compatibility spike

Before migration into the formal UI repository, the exact native dependency graph passed:

- Android Debug and Release APK builds.
- iOS Debug and Release builds with `--no-codesign`.
- Flutter analysis/tests and the repository Harness.
- Physical Pixel 7a Debug install and runtime inspection of the shell and public Hyperliquid Testnet market list.

That evidence proves coexistence of the pinned native graph that existed at the time, not provider-backed runtime behavior. It predates `reown_appkit` 1.8.4 and was not reused as evidence for the new Reown/Core/Sign graph. The matrix was repeated after dependency integration on 2026-08-29; those current results belong to `docs/phase-1/initialization-report.md`.

Phase 1 foreground Audio Room refines, rather than invalidates, that evidence: Stream Video Push 1.4.3 remains the compatibility-tested future version but is not linked into the current application. Its native plugin auto-registers Telecom/CallKit behavior, which is outside the microphone-only foreground scope.

## Compatibility controls

- Privy's published Android artifact requires minSdk 28.
- Reown AppKit stays exactly pinned at 1.8.4; `pubspec.lock` is the authority for its currently resolved Core 1.5.0 and Sign 1.4.0 transitive versions.
- Reown is EVM `personal_sign` transport only. Its broader authentication/SIWE, Link Mode, Solana, analytics and transaction surfaces are not compatibility-approved LOOP capabilities.
- All Android library subprojects compile on API 36 after evaluation because Privy 0.10.1 otherwise assigns API 34 below AndroidX Credentials' API 35 floor.
- Flutter 3.47.1 requires Gradle 8.14 for AGP 8.13.2.
- CocoaPods is retained because Stream's file_picker 11 dependency made cold-cache SwiftPM resolution brittle.
- Toolchain wrappers reject any Flutter revision other than `6655482ec06e547f90abf8ae7590466f4415978d` and Dart other than 3.13.1.

## Current Phase 1 gates

- Android Debug/Release and iOS Debug/Release no-codesign compilation of the newly added Reown dependency graph passed on 2026-08-29. Exact commands and warnings are recorded in `docs/phase-1/initialization-report.md`; this does not retrofit the older Phase 0 matrix.
- Privy Email OTP, Google OAuth, iOS Apple OAuth, embedded wallet behavior, wallet-app return, and SIWE login/link with the configured public client identifiers.
- Privy and Reown callback routing on physical Android/iOS devices, including cancellation/rejection and Apple entitlement/provisioning behavior.
- Non-blocking post-login bootstrap against a deployed backend using a real current Privy access token.
- Stream Chat/Video token minting and two-user/two-device behavior.
- Firebase delivery, APNs/VoIP, CallKit, background and terminated-state calls.
- Wallet signing, backend idempotency/reconciliation, and private Hyperliquid Testnet trading.
- Store signing, provisioning, release upload, and production environments.

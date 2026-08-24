# Merge the Verified Mobile Foundation into the Product UI Repository

## Status

Accepted on 2026-08-24.

## Context

The formal `loop-mobile` repository already contained a substantial Flutter UI implementation: 103 catalogued product surfaces, a dark design system, routing, preview adapters, and six fixed primary destinations. A separate compatibility spike had verified the final `com.cywd.loop` identity, Flutter 3.47.1, Privy/Stream/Firebase coexistence, safe Privy Email OTP boundaries, and public Hyperliquid Testnet reads across Android and iOS builds.

The product repository still used Android minSdk 24, AGP 9.1, Gradle 9.3.1, Kotlin 2.4.0, iOS 15, `com.dinolabs...` identifiers, Flutter Swift Package Manager, and preview-only provider behavior. Directly replacing the product source would discard valuable UI work, while keeping the old native setup would fail Privy 0.10.1 and lose compatibility evidence.

## Decision

Use this repository as the formal Flutter client and merge the verified foundation into it without rebuilding the product catalog.

- Preserve Home, Market, Launch, Chat, Wallet, and Profile as six primary destinations. Launchpad remains first-class; Perp remains inside Market.
- Use final Android/iOS ID `com.cywd.loop` and iOS test ID `com.cywd.loop.RunnerTests`.
- Lock Flutter 3.47.1/Dart 3.13.1, Android API 28–36 with AGP 8.13.2/Gradle 8.14/Kotlin 2.3.20/Java 17, and iOS 17 with CocoaPods 1.16.2.
- Disable Swift Package Manager only for this project. Keep the host-level Android library compileSdk 36 override until Privy's published plugin no longer compiles below its AndroidX dependency floor.
- Keep direct Pub constraints exact, including Riverpod 3.4.2, `go_router` 17.5.0, Privy 0.10.1, Dio 5.11.0, Decimal 3.2.6, Firebase Core/Messaging 4.13.0/16.5.0, Stream Chat/Persistence 10.3.0, Stream Video/Push 1.4.3, and UUID 4.6.0.
- Keep Android Release unsigned in the repository. Approved store signing is injected by release automation; development debug keys are never a release fallback.
- Replace fake OTP and private-transaction claims with guarded production seams or visibly labelled preview states. Keep public Hyperliquid Testnet market reads direct and read-only; private actions stay backend-mediated.
- Adopt `AGENTS.md`, `harness.json`, version-guard wrappers, drift tests, failure memory, and verification reports as repository controls.

## Consequences

- Existing UI and navigation work remains the product source of truth while provider behavior is upgraded incrementally.
- Android API 27 and iOS 16 users are outside the accepted platform floor.
- Changing a dependency pin, native toolchain, application ID, six-destination navigation, persistence model, or provider security boundary requires a new decision plus both native builds.
- Native compile success does not prove provider connectivity. Privy, Stream, Firebase, push, calls, signing, and private trading remain unverified until real configuration and device evidence exist.
- The Stream package license is not a standard permissive OSS license; release owners must retain the applicable Stream agreement and notices.

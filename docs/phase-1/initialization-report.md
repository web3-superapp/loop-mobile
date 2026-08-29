# Loop Phase 1 Identity and External Credential Initialization Report

Date: 2026-08-29

Status: implementation and native compilation accepted; live provider/device behavior remains unverified.

## Scope

This checkpoint extends the existing Privy Email OTP boundary with Google OAuth,
iOS-only Apple OAuth, and external EVM-wallet authentication through Privy
SIWE. Reown is introduced only to connect an EVM wallet and transport one
`personal_sign` request for the exact Privy-generated message. Decision
[0043](../decisions/0043-use-reown-only-for-privy-external-evm-credentials.md)
owns this boundary.

This slice does not add a second identity provider, a second embedded wallet,
an external transaction wallet, Spot execution, persistent wallet connection,
or a provider-backed claim that authentication is live.

## Locked dependency graph

| Package | Relationship | Locked value | Acceptance state |
| --- | --- | ---: | --- |
| `privy_flutter` | Direct | 0.10.1 | Existing baseline; new OAuth/SIWE provider flows remain device-unverified |
| `reown_appkit` | Direct, exact | 1.8.4 | Android/iOS Debug and Release compilation passed 2026-08-29 |
| `reown_core` | Transitive lock result | 1.5.0 | Covered by the same compilation matrix |
| `reown_sign` | Transitive lock result | 1.4.0 | Covered by the same compilation matrix |

The existing Phase 0 Android/iOS build evidence predates Reown and was not used
to prove this expanded graph. The owning task repeated Android Debug/Release
and iOS Debug/Release no-codesign builds against the final source on 2026-08-29;
the exact evidence is recorded below.

## Implemented boundary

- `AppConfig` is now the only Dart environment reader. The IDE supplies the
  tracked client-visible Development values through
  `--dart-define-from-file=config/debug.json`; no provider identifier has a
  Dart default. `LOOP_BUILD_MODE` must match Debug/Profile or Release, and a
  missing/mismatched profile gates every provider-backed flow. Release remains
  an empty local template and does not change Development/Testnet policy.
- One cached `Privy.init` owner continues to provide session restoration,
  Email OTP, access-token access, embedded-wallet readiness, Google OAuth,
  iOS-only Apple OAuth, SIWE message generation, SIWE login, and SIWE link.
- Signed-out users may authenticate through Email OTP, Google, Apple on iOS,
  or an external EVM SIWE proof. A fully verified user may link an external EVM
  credential to the same Privy principal. This slice does not implement Google
  or Apple OAuth linking.
- Email send/verify, OAuth, SIWE login, and SIWE link share one application
  identity-operation lease. Duplicate taps are ignored, platform availability
  is explicit, and provider details are reduced to sanitized cancellation,
  rejection, callback, configuration, and network messages.
- A SIWE link is bound to the Privy principal that initiated it. Principal
  rotation fails closed, and LOOP never transfers, unlinks, deletes, or merges
  an external credential that belongs to another account.
- The accepted account summary distinguishes Email, Google, Apple, Privy
  Embedded Ethereum wallet identity, and external EVM credentials. Manage
  wallets labels external addresses as Privy sign-in credentials that are not
  LOOP trading wallets.

## Reown restrictions

- Only canonical CAIP-10 accounts matching
  `eip155:<positive-decimal-chain-id>:<0x40-hex-address>` are accepted.
- The only requested wallet method is `personal_sign`. The exact message from
  `privy.siwe.generateMessage` is UTF-8 encoded for the wallet request and the
  same logical message, signature, address, chain ID, domain, and URI are sent
  unchanged to Privy SIWE login or link.
- AppKit authentication, Email, Social, Embedded Wallet, AppKit SIWE,
  analytics, Link Mode, Solana namespaces, and transaction authority are
  disabled. Solana-first wallets are excluded from the initial discovery set.
- The Reown modal disconnects/disposes its session after every attempt. Its
  transitive internal secure-storage implementation is not exposed as LOOP
  identity, token, application settings, PIN, or transaction persistence.
- Reown initialization has a 30-second application timeout. A timeout releases
  the identity-operation UI lease but retains the same non-cancellable AppKit
  owner for reconnect/retry, so a partial initialization can never create a
  second competing global service graph. A terminal partial-init error remains
  fail-closed until app restart.
- An external credential never enters `PrivyWalletSummary`,
  `WalletSigningGateway`, balances, assets, canonical transaction review, or
  future backend-mediated Spot execution. The first Privy Embedded Ethereum
  wallet remains the only current mobile wallet-identity candidate for those
  future flows.

## Native callback configuration

- Privy OAuth uses `com.cywd.loop.privy`.
- Reown wallet return uses `com.cywd.loop.wallet`.
- Android assigns the Privy scheme to
  `io.privy.sdk.oAuth.PrivyRedirectActivity` and the Reown scheme to
  `MainActivity`; Flutter's competing generic deep-link handling is disabled.
- iOS registers both URL types. Apple OAuth is guarded to iOS and the Runner
  target declares the Sign in with Apple entitlement.
- Initial Android/iOS wallet discovery declarations are limited to the reviewed
  MetaMask, Trust Wallet, and Rainbow schemes/packages. These declarations do
  not prove that any wallet is installed or that return routing works.

## Post-login bootstrap

The application session boundary observes newly accepted fully verified Privy
principals. When a safe LOOP backend origin is configured, it starts the
existing principal-bound bootstrap once without awaiting it as part of login.
Missing configuration, timeout, authorization failure, or any other bootstrap
error cannot reject or roll back Privy authentication. Linking another
credential to the same principal does not trigger a second identity or widen
backend authority.

## Verification status

| Evidence | Status |
| --- | --- |
| Exact direct/transitive dependency values in `pubspec.yaml` / `pubspec.lock` | Recorded |
| Narrow OAuth, SIWE, CAIP-10, `personal_sign`, single-flight, principal-binding, callback and bootstrap tests | Flutter full suite passed: 663 tests |
| Harness/document drift checks | Harness passed; Python suite passed: 281 tests |
| Android Debug and Release builds with Reown graph | Passed on final source, exit 0 |
| iOS Debug and Release no-codesign builds with Reown graph | Passed on final source, exit 0 |
| Physical Android/iOS callback and wallet-return tests | Unverified |
| Privy Email OTP, Google OAuth, Apple OAuth and SIWE provider behavior | Unverified |
| Real post-login bootstrap with a deployed backend | Unverified |

Compilation, deterministic tests, or callback declarations alone must not be
reported as provider success. Live acceptance requires matching Privy/Reown
dashboard configuration, Apple capability/provisioning, installed wallet apps,
physical devices, observable provider responses, and a deployed safe LOOP
backend origin.

### Native compilation evidence

All commands used the repository `bin/flutter` guard and supplied only the two
public client identifiers through `--dart-define`:

```sh
bin/flutter build apk --debug --dart-define=PRIVY_APP_CLIENT_ID=<public-client-id> --dart-define=REOWN_PROJECT_ID=<public-project-id>
bin/flutter build apk --release --dart-define=PRIVY_APP_CLIENT_ID=<public-client-id> --dart-define=REOWN_PROJECT_ID=<public-project-id>
bin/flutter build ios --debug --no-codesign --dart-define=PRIVY_APP_CLIENT_ID=<public-client-id> --dart-define=REOWN_PROJECT_ID=<public-project-id>
bin/flutter build ios --release --no-codesign --dart-define=PRIVY_APP_CLIENT_ID=<public-client-id> --dart-define=REOWN_PROJECT_ID=<public-project-id>
```

Results on 2026-08-29:

- Android Debug: exit 0; APK generated. Flutter warned that locked Gradle 8.14
  and AGP 8.13.2 will require a future migration. Decision 0001 keeps the
  current baseline for this gate.
- Android Release: exit 0; APK generated. The same future Gradle/AGP warnings
  and upstream Java deprecation/unchecked warnings were non-fatal.
- iOS Debug no-codesign: exit 0; `Runner.app` generated. CocoaPods completed
  with the locked Podfile and Podfile.lock.
- iOS Release no-codesign: exit 0; 63.7 MB `Runner.app` generated.
- Both iOS builds warned that transitive `coinbase_wallet_sdk` does not support
  Swift Package Manager. This repository deliberately remains on CocoaPods
  1.16.2, so the warning is recorded rather than changing the native baseline.

Generated APK/app products are verification artifacts only and are removed
after the gate; they are not committed or presented as signed distributables.

## Inputs and release gates

1. Confirm Email, Google, and Apple provider configuration in the Privy
   Dashboard, including `com.cywd.loop.privy` as an allowed mobile callback.
2. Confirm the Reown project metadata/allowlist and
   `com.cywd.loop.wallet` return scheme.
3. Verify Apple Sign in with Apple capability and provisioning on a signed iOS
   device.
4. Exercise cancellation, rejection, wallet-not-installed, app return,
   principal rotation, another-account ownership, and network failures on the
   supported Android/iOS device matrix.
5. Keep the recorded native compilation gate green after any Reown, Privy,
   Flutter, CocoaPods, Gradle, AGP, Kotlin, or Xcode change.

Do not provide or commit a Privy App Secret, Google or Apple OAuth secret,
Apple `.p8`, wallet private key or seed phrase, Reown relay credential, Stream
Secret, Firebase service-account JSON, APNs key, Hyperliquid agent key, or any
server signing material.

# Use Reown Only for Privy External EVM Credentials

## Status

Accepted on 2026-08-29.

## Context

LOOP currently authenticates through Privy 0.10.1 Email OTP and uses the
first Privy Embedded Ethereum wallet as its only wallet identity. The product
now also requires Privy Google and Apple OAuth plus external EVM-wallet
authentication. Privy Flutter exposes OAuth and SIWE login/link operations,
but it does not provide the external wallet connection and `personal_sign`
transport needed to obtain a SIWE signature.

Reown AppKit can provide that transport. It also contains broader email,
social, embedded-wallet, network, and SIWE product surfaces that would create
a second identity system if enabled. Those surfaces are outside LOOP's
identity and transaction boundaries. External wallets are replaceable Privy
credentials; they are not LOOP trading wallets and must never enter the
canonical transaction-signing path.

The current Flutter and native baseline is Flutter 3.47.1 / Dart 3.13.1,
Android API 28-36, and iOS 17+. Reown AppKit 1.8.4 requires Dart 3.8 or newer,
Android API 23 or newer, and iOS 13 or newer. The lock for AppKit 1.8.4 resolves
`reown_core` 1.5.0 and `reown_sign` 1.4.0, whose feature graph includes Stellar
TVF. LOOP's EVM-only boundary therefore comes from the runtime namespace,
method allowlist, and excluded connectors—not from assuming the transitive
graph lacks other chains. Reown uses the Reown Community License rather than a
standard permissive open-source license, so its terms must remain visible in
the repository attribution.

## Decision

- Pin `reown_appkit` exactly at 1.8.4. Do not use a caret range. Keep Privy at
  0.10.1 and preserve every existing Flutter, Android, and iOS baseline.
- Read `PRIVY_APP_CLIENT_ID` and `REOWN_PROJECT_ID` only from
  `--dart-define`. Both are public client identifiers. Never add a Privy App
  Secret, Apple `.p8`, Google Client Secret, wallet private key, provider
  token, or refresh token to Flutter configuration, fixtures, logs, or Git.
- Keep one cached `Privy.init` owner. A narrow interactive credential facade
  reuses that owner for Google OAuth, iOS-only Apple OAuth, SIWE message
  generation, SIWE login, and SIWE link. It does not widen the existing
  backend-token or embedded-wallet facade.
- Configure Reown only as an EVM connection and `personal_sign` transport.
  Disable AppKit Email, Social, Embedded Wallet, AppKit SIWE, analytics, and
  Link Mode. Do not propose or accept a Solana namespace. Disconnect and
  dispose each Reown session after the Privy credential operation finishes.
- Parse only canonical CAIP-10 EVM accounts of the form
  `eip155:<positive decimal chain id>:<0x40-hex address>`. Generate the SIWE
  message through `privy.siwe.generateMessage`, pass its exact bytes to the
  selected wallet through `personal_sign`, and pass the unchanged message,
  signature, and parameters to `privy.siwe.login` or `privy.siwe.link`.
- A signed-out operation may call SIWE login. A fully authenticated user must
  call SIWE link and may never fall back to login. Bind link completion to the
  principal that started it and reject a changed or mismatched Privy user.
  An external wallet already owned by another account produces a clear error;
  LOOP never transfers, unlinks, deletes, or merges accounts automatically.
- Share one application identity-operation lease across Email send/verify,
  OAuth, SIWE login, and SIWE link. Ignore duplicate taps while an operation is
  active and publish only sanitized cancellation, rejection, redirect,
  configuration, and network errors.
- Bound Reown initialization to 30 seconds at the application boundary. AppKit
  1.8.4 initialization is not cancellable and registers process-global
  services before relay readiness, so a timeout releases the UI operation but
  retains that exact owner for reconnect/retry. Never construct a second owner
  over a partial initialization; a terminal partial-init error stays
  fail-closed until app restart.
- Keep external accounts separate from `PrivyWalletSummary` and
  `WalletSigningGateway`. They may be displayed as linked sign-in credentials
  in Manage wallets, explicitly labelled as not being LOOP trading wallets.
  The first Privy Embedded Ethereum wallet remains the only mobile wallet
  identity eligible for future backend-authorized trading.
- Register `com.cywd.loop.privy` for Privy OAuth and
  `com.cywd.loop.wallet` for Reown wallet callbacks. Android assigns the Privy
  scheme exclusively to `PrivyRedirectActivity` and the wallet scheme
  exclusively to `MainActivity`; iOS registers both URL types. Add only the
  declared initial wallet discovery entries and Apple sign-in entitlement.
- After every newly accepted fully verified Privy login, an app/session-level
  coordinator may eagerly request the existing LOOP backend bootstrap once
  for that principal when a safe backend origin is configured. Login success
  never depends on this request, no request occurs without a configured
  backend, and the login controller remains free of backend networking. This
  narrowly supersedes decision 0004's consumer-lazy trigger while preserving
  its principal binding, token, retry, cache, and invalidation rules.
- This also narrows decision 0020's “additional wallets unavailable” statement:
  additional transaction wallets remain unavailable, while external EVM
  addresses may appear only as non-signing Privy credentials.

## Consequences

Email, Google, Apple, and supported external EVM wallets can converge on the
same Privy identity boundary without giving Reown or an external wallet LOOP
transaction authority. Missing client IDs, unsupported platforms, rejected
wallet requests, and unavailable backend bootstrap remain fail-closed and do
not fabricate an authenticated or connected state.

The Reown dependency adds a broad native dependency graph, including its own
secure-storage implementation. LOOP does not use that storage as an identity,
token, or application settings store; the credential session is explicitly
disconnected after use. Any future persistent wallet connection, Reown Link
Mode, additional namespace, provider-auth feature, or external-wallet trading
authority requires a new security and compatibility decision.

## Verification

- Unit tests must cover exact SIWE parameter/message forwarding, canonical EVM
  parsing, login-versus-link selection, principal rotation, wallet-owned-by-
  another-account errors, user cancellation/rejection, and single-flight.
- Widget/configuration tests must cover Email retention, Google/Apple/wallet
  availability, iOS-only Apple presentation, missing-ID behavior, credential
  labelling, and post-login bootstrap triggering.
- Harness validation must lock the exact dependency, public configuration,
  EVM-only Reown features, SDK ownership boundaries, disjoint native callback
  handlers, Apple entitlement, decision/report, and license evidence.
- Android and iOS Debug and Release compilation are dependency acceptance
  gates. Email, Google, Apple, wallet-app return, SIWE provider behavior, and a
  real backend bootstrap remain unverified until exercised on physical devices
  with the corresponding provider-dashboard configuration.

## References

- [Privy Flutter setup](https://docs.privy.io/basics/flutter/setup)
- [Privy mobile app clients and URL schemes](https://docs.privy.io/basics/get-started/dashboard/app-clients)
- [Privy OAuth configuration](https://docs.privy.io/authentication/user-authentication/login-methods/oauth)
- [Reown AppKit Flutter installation](https://docs.reown.com/appkit/flutter/core/installation)
- [Reown AppKit Flutter Link Mode](https://docs.reown.com/appkit/flutter/core/link-mode)
- [`reown_appkit` 1.8.4 package record](https://pub.dev/packages/reown_appkit/versions/1.8.4)
- [Reown AppKit Community License](https://github.com/reown-com/reown_flutter/blob/develop/packages/reown_appkit/LICENSE)

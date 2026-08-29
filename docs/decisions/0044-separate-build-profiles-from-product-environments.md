# Separate Build Profiles from Product Environments

## Status

Accepted on 2026-08-29.

## Context

LOOP has several client-visible provider identifiers and one backend origin.
The IDE previously passed only the Privy Mobile Client ID and Reown Project ID
as individual launch arguments, while the App ID and Stream API key lived as
Dart defaults and the backend origin was absent. Adding Sentry, AppsFlyer, or
Firebase configuration through more unrelated constants would create multiple
configuration owners and make it easy for a Release binary to reuse Debug
values accidentally.

Debug versus Release is a distribution profile, not a product environment.
`BuildPolicy` still permits only the Development application environment and
Hyperliquid Testnet; Release compilation must not imply Production, Mainnet,
withdrawals, automated trading, or Spot execution.

## Decision

- Make `AppConfig` the only Dart owner of `String.fromEnvironment` and
  `bool.fromEnvironment` provider values. Existing Privy wallet composition
  must read the same provider instead of creating a second environment reader.
- Declare one `LOOP_BUILD_MODE` value. Debug/Profile binaries accept only
  `debug`; Release binaries accept only `release`. Missing, unknown, or
  mismatched declarations disable configured Privy, Reown, LOOP backend,
  Stream, wallet-adapter, and Firebase capabilities and expose no effective
  backend origin or Stream API key. Public Hyperliquid Testnet reads remain the
  separately locked credential-free exception.
- Keep the reviewed client-visible Development identifiers and backend origin
  in tracked `config/debug.json`. The IDE `Loop` target supplies that file via
  `--dart-define-from-file`; it never pins a device.
- Track only an empty `config/release.example.json`. A real `release.json` is
  local/automation-owned and ignored. Missing Release values therefore fail
  closed instead of falling back to Development.
- Keep the offline Preview entry independent by overriding an empty
  `AppConfig`; it performs no Privy, Reown, Stream, or LOOP backend operation.
- Add a future client SDK value, such as Sentry DSN, AppsFlyer Dev Key/iOS App
  ID, or Firebase enable marker, only when its narrow adapter exists. Add a
  typed field and capability getter at that time rather than predeclaring
  unused constants.
- Firebase platform files remain native configuration and an enable Boolean
  cannot prove they exist. Dynamic minimum-version, eligibility, maintenance,
  or kill-switch policy belongs to a verified backend policy, not a build
  constant.
- Every value in these JSON files is compiled into the app. Privy/Stream/OAuth
  secrets, Apple or APNs `.p8`, Sentry auth tokens, AppsFlyer server secrets,
  Firebase service accounts, wallet keys, and trading keys remain forbidden.
- This decision does not change the manual-only Release/iOS verification rule.

## Consequences

The toolbar starts Debug with one visible Development configuration source,
and future client SDK configuration has an explicit extension point. A wrong
profile cannot initialize Privy/Reown, construct Stream clients, create the
backend Dio client, or pass Privy inputs to the wallet adapter.

Release distribution still requires reviewed public values and a separate
manual build request. The profile name conveys no product-environment or
trading authorization.

## Verification

- AppConfig tests cover missing, matching, and cross-profile declarations plus
  provider-wide fail-closed behavior.
- Provider composition tests prove a non-empty mismatched backend/key still
  creates no backend, Chat, or Video owner; wallet composition proves it reads
  the centralized AppConfig.
- Harness validation parses both tracked JSON files, rejects secret-shaped
  keys and secondary Dart environment readers, locks the IDE file argument,
  and preserves Development/Testnet security policy.

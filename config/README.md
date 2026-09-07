# Client build configuration

`debug.json` contains only client-visible Development identifiers and
origins. The IDE `Loop` launch target passes this file with
`--dart-define-from-file`.

Release builds must copy `release.example.json` to the ignored `release.json`,
fill the reviewed public values, and build with:

```sh
bin/flutter build apk --release \
  --dart-define-from-file=config/release.json
```

The declared `LOOP_BUILD_MODE` must match the Flutter build mode. Debug and
Profile accept only `debug`; Release accepts only `release`. A
mismatch disables provider-backed capabilities instead of falling back to a
different environment.

`LOOP_CLIENT_VERSION` is the client-visible strict SemVer sent only in the
exact D1 V2 account/session request headers. It must match the application
build represented by the configuration file. A missing, malformed, or
build-profile-mismatched value disables V2 account/session composition rather
than guessing a version. It is not a force-update decision and is never used
for string-based update eligibility.

This is a distribution/configuration axis only. A Release binary does not
enable a Production backend, Hyperliquid Mainnet, withdrawals, automated
trading, or Spot execution; those product security gates remain disabled by
`BuildPolicy` until separately approved.

Future client SDK configuration such as a Sentry DSN, AppsFlyer Dev Key, or
Firebase-enabled marker belongs in these environment files only when its
narrow adapter is introduced. `AppConfig` should then expose a typed field and
a fail-closed capability getter. Never put a Privy secret, Stream secret,
OAuth client secret, Apple `.p8`, Firebase service account, APNs key, wallet
private key, or Hyperliquid signing key in this directory: every value is
compiled into the application binary.

The D1 installation UUID, opaque account/session/Stream IDs, and exact
bootstrap/logout idempotency journal are generated or returned at runtime and
belong only in the reviewed Secure Storage adapter. Configuration files never
contain that journal, a raw Privy principal, Privy access/refresh token, Stream
user token, wallet private key, PIN, or signing material.

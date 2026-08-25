# Finish App Logic Before New Transports

## Status

Accepted on 2026-08-25.

## Context

LOOP's Flutter shell, provider boundaries, public Testnet markets, guarded
identity bootstrap, official Stream SDK owners, foreground Audio Room lifecycle,
and notification classifier are already present. The backend repository also
documents future Profile, Watchlist, alert, Stream-token, private Perp, and
transfer boundaries. Most of those provider capabilities are still unavailable,
default-denied, or awaiting device evidence.

Implementing each new HTTP adapter at the same time as its screen state machine
would couple application behavior to evolving transport details and encourage
fixture success to leak into production presentation. The product can instead
finish deterministic application logic against narrow ports while backend and
provider work continues independently.

## Decision

- Complete new feature models, controllers, state transitions, and UI behavior
  against narrow application-facing ports before adding new private LOOP HTTP
  adapters.
- Keep HTTP paths, Dio, wire DTO parsing, authentication headers, retries, and
  provider error translation inside `lib/integrations/`. Feature modules do not
  import Dio or contain `/v1/` route literals.
- Production composition keeps every not-yet-connected port unavailable and
  fail-closed. Deterministic fakes may be injected only by tests or the explicit
  `lib/main_preview.dart` composition root.
- Preview data remains labelled `开发预览` or `演示数据`. A fake accepted,
  filled, connected, sent, read, signed, or delivered state is never production
  evidence.
- Model only semantics fixed by the current product and backend decisions. Do
  not invent a successful transfer DTO, Audio Room locator, Firebase payload
  mapping, background ringing flow, or fresh Token Card facts contract.
- Preserve existing connected slices. This decision does not remove the guarded
  Privy bootstrap or the public, Testnet-only Hyperliquid market adapter.
- Each providerless vertical slice receives behavior tests, Harness validation,
  and its own commit. A later transport slice implements adapters behind the
  same ports and adds contract/device evidence without rewriting feature state.

## Consequences

- Wallet, Perp, personalization, notification, and cross-feature lifecycle
  behavior can be completed and reviewed without a deployed backend.
- API contract drift is localized to future integration adapters rather than
  screen and controller code.
- Production remains honestly unavailable until real adapters, credentials,
  sandbox/Testnet responses, and device tests exist.
- End-to-end provider connectivity is deliberately deferred; fake and widget
  tests prove application behavior only.

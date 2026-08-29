# Centralize Dio Construction by Trust Boundary

## Status

Accepted on 2026-08-29.

## Context

Loop already had narrow Dio repositories for the LOOP backend and public
Hyperliquid Testnet reads, but each provider constructed its own client. The
timeouts happened to match, while redirect behavior and future credential
isolation depended on every adapter remembering the same rules. A generic
singleton would be unsafe because public provider reads and authenticated LOOP
backend requests do not share one trust boundary.

The backend is still being completed in parallel. The mobile app can establish
the construction policy now without inventing routes, tokens, retries, writes,
or persistence.

## Decision

- `lib/core/network/loop_dio_factory.dart` is the only production location that
  constructs Dio. It exposes separate credential-free-public and LOOP-backend
  profiles rather than one universal client.
- Both profiles use 10-second connect/send timeouts, a 15-second receive
  timeout, JSON response decoding, and globally disabled redirects with zero
  redirect hops. A request cannot re-enable redirects locally.
- Every request is checked against the client's exact scheme, host, and port
  before dispatch. Origins must be credential-free roots without a path,
  query, or fragment.
- The public profile accepts HTTPS only and rejects Authorization,
  Proxy-Authorization, Cookie, and `X-Api-Key` headers before dispatch. Spot market
  discovery and candle history share one exact Hyperliquid Testnet public
  client; it has no account, identity, signing, or execution capability.
- `credential-free-public` describes transport credentials, not permission to
  call arbitrary provider APIs. The current Hyperliquid repositories and
  Harness continue to admit only the reviewed Testnet `/info` queries and reject
  a direct mobile `/exchange` path; private reads and every write remain backend
  owned.
- The LOOP backend profile accepts HTTPS and Development HTTP loopback only.
  It permits a repository to attach the current Privy Bearer token to one
  exact-origin request, but never stores a credential in Dio defaults or an
  interceptor. A default Authorization value is rejected at dispatch even on
  this profile. Cookie, Proxy-Authorization, and `X-Api-Key` request headers are
  rejected on both profiles.
- The factory adds no logging, cookie persistence, automatic retry, access-token
  refresh, UUID generation, request-body transformation, or domain error
  mapping. Repositories and principal-bound session owners retain those exact
  responsibilities. In particular, timeout of a future private write remains
  an ambiguous result and cannot be generically replayed.
- The Harness intentionally treats factory imports, production consumers, and
  interceptor ownership as an architecture approval gate. Adding another
  origin, transport hook, or consumer requires an explicit review and update to
  this decision rather than silently expanding the shared boundary.
- A rejected request uses a sanitized boundary marker whose message includes no
  origin, path, header value, token, response, or request body. The surrounding
  Dio exception and its request options remain integration-owned and are mapped
  to sanitized domain failures before they can enter application state or UI.

## Consequences

New backend and provider adapters can reuse reviewed connection defaults while
remaining visibly separated by trust. Cross-origin absolute URLs, redirects,
and accidental credentials on the public client fail before network dispatch.
This changes no endpoint contract, domain failure mapping, authentication
retry, provider fact, product availability, or stored state.

No database, Secure Storage dependency, generic HTTP repository, logging
interceptor, retry package, backend call, provider call, native build, or
device verification is introduced by this decision.

## Evidence

- `test/loop_dio_factory_test.dart` exercises defaults, origin confinement,
  credential rejection, request-local backend Bearer use, redirect rejection,
  and unsafe-origin validation.
- Existing bootstrap and public-candle provider tests continue to verify their
  unchanged feature composition through the new clients.
- Repository Harness validation locks the two-profile construction boundary and
  executable behavior evidence.

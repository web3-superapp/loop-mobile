# Connect the Native Stream Chat Token Loader

## Status

Accepted on 2026-08-28.

## Context

The LOOP backend now exposes a reviewed native `POST /v1/chat/token`
interface. Mobile already owns a principal-bound official Stream Chat client
and a validated server-derived Stream identity, but its token loader is fixed
to an unavailable result. The backend's real Stream issuer remains separately
license- and credential-gated, so wiring the client contract must not imply
provider connectivity.

## Decision

- Add a strict Dio adapter for `POST /v1/chat/token`. Send one current Privy
  Bearer token, no body, no query, and never send a client-selected user ID,
  product, role, claims, or expiry.
- Require the exact success fields `api_key`, `token`, `expires_at`, and
  `user.id`, `Cache-Control: no-store`, and a canonical UUID request ID. Reject
  additional fields, malformed values, an expiry outside the bounded one-hour
  clock-skew window, an API-key mismatch, or a Stream user ID that differs from
  bootstrap.
- Keep token material only inside the Stream session source and official SDK
  token-provider call. Never cache, persist, display, or log it, and do not
  parse or reproduce Stream's JWT implementation in Flutter.
- Gate every issuance attempt on the principal-bound bootstrap identity and a
  current Privy access token. Concurrent Chat requests for the same identity
  are single-flight.
- Retire pending identity and token loads promptly when their principal-bound
  source or SDK generation is invalidated. Per-operation invalidation listeners
  detach on completion so long-lived lifecycle state does not retain returned
  bearer or provider token material.
- Retry exactly one authenticated token request after one HTTP 401 with a newly
  requested Privy token. On one `409 bootstrap_required`, invalidate and
  re-establish bootstrap once, verify the same Stream identity, and replay the
  token request once. Never loop or automatically retry 400, 429, 500, 503,
  timeout, connection, cancellation, or malformed responses.
- Keep Video on its existing unavailable loader. It remains a separate product
  boundary and will receive its own verified slice later.

## Consequences

Mobile can now consume the backend Chat token contract without weakening the
Privy, identity, or SDK ownership boundaries. With the backend's default
blocked issuer, production Chat still honestly remains unavailable. A live
connection requires recorded Stream license acceptance, one matching
Development App key/secret, a real backend issuer, and two-user/two-device
provider evidence.

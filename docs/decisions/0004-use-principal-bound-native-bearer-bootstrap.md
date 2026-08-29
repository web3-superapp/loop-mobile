# Use a Principal-Bound Native Bearer Bootstrap

## Status

Accepted on 2026-08-24. The Stream-token-unavailable statements were
superseded by decision 0045 on 2026-08-29; the bootstrap boundary remains
active.

## Context

The Loop API now implements `POST /v1/bootstrap` for the native Flutter client.
It verifies one current Privy Bearer access token, maps the verified Privy
subject to an opaque LOOP UUID, and returns that UUID with the server-derived
Stream user ID. The route accepts no body, query, client-selected identity,
wallet address, or refresh token.

Flutter already obtains a current access token from Privy without reading or
storing a refresh token. Chat and Video also have separate official SDK session
owners, but both need the same trusted backend-derived Stream identity. The
Stream token route is not implemented yet, so a successful identity bootstrap
must not be treated as permission to connect either SDK.

## Decision

- Add a strict Dio adapter for the implemented `POST /v1/bootstrap` contract.
  It sends no body or query and adds the current Privy access token only to that
  request's `Authorization` header.
- Accept HTTPS root origins and HTTP loopback roots for local Development only.
  Reject credentials, paths, queries, fragments, insecure remote HTTP, and
  automatic redirects so a Bearer credential cannot be forwarded to another
  host.
- Require the exact response fields `user.id` and `stream_user_id`, canonical
  identifier shapes, and `Cache-Control: no-store`. Reject additional fields so
  a future provider token or external identity cannot silently cross this
  boundary.
- Map HTTP and transport failures to sanitized typed failures. Never retain a
  response body, Dio exception, Authorization value, Privy token, or provider
  error in application state or logs.
- Bind each in-memory bootstrap owner to one fully verified Privy principal.
  The principal key is only a rotation key and is never sent or transformed into
  a LOOP or Stream identity.
- Revoke the local provider-backed principal synchronously when sign-out starts,
  before awaiting the Privy SDK logout. Ignore stale authenticated SDK snapshots
  until an explicit new login succeeds, so a slow or failed remote logout cannot
  keep Bootstrap, Chat, or Video authorized in the current process.
- Make authorization single-flight and cache only the validated LOOP/Stream
  identity in memory. Logout, restricted sessions, account changes, provider
  disposal, or late responses invalidate the old owner before it can publish an
  identity for another principal.
- On exactly one HTTP 401, request a current access token from Privy again and
  retry once. Do not automatically retry a second 401, 400, 500, 503, timeout,
  cancellation, connection error, or malformed response. Riverpod automatic
  retries remain disabled.
- Load bootstrap lazily when a provider-backed consumer needs the identity.
  Do not put backend networking inside the Privy login controller or make login
  success depend on backend availability.
- Let Chat and Video project the same validated `stream_user_id` into their
  feature-local identity types. Their token loaders remain explicitly
  unavailable until a separately accepted native Stream credential contract is
  implemented by the backend.

## Consequences

- Supplying `LOOP_BACKEND_BASE_URL` can establish a trusted LOOP and Stream
  identity, but cannot connect Stream Chat or Video by itself.
- Preview, signed-out, authenticated-unverified, missing URL, and unsafe URL
  configurations perform no bootstrap request.
- Account and wallet presentation remain independent: wallet changes do not
  rotate the bootstrap owner, while a different Privy principal does.
- Unit and widget tests can verify the request, parsing, retry, concurrency, and
  rotation behavior without a deployed API. Real Privy Bearer verification,
  database identity stability, TLS, and device connectivity remain unverified
  until the Development backend is deployed and tested from a physical device.

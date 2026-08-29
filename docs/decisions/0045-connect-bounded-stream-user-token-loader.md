# Connect a Bounded Stream User-Token Loader

## Status

Accepted on 2026-08-29. This supersedes only the token-unavailable statements
in decisions 0003 and 0004; their SDK lifecycle, identity, room, media, push,
and truth-source boundaries remain active.

## Context

The LOOP backend now implements authenticated `POST /v1/chat/token` and
`POST /v1/video/token` routes. Each route verifies a current Privy Bearer,
requires an existing LOOP bootstrap mapping, derives the Stream user ID on the
server, applies persistent quota, and returns one one-hour Stream user token.

Flutter already owns principal-bound official Chat and Video sessions. Chat
uses the official token provider; Video loads an initial token before client
construction and retains a refresh loader. Both validate the user ID requested
by the SDK and retire work after logout/account rotation. Their only missing
piece is a real mobile backend credential adapter.

## Decision

- Add one strict backend repository for the two fixed token routes. Requests
  are POST with no body or query and attach the current Privy access token only
  to that request through the existing LOOP backend Dio trust profile.
- Accept only HTTP 200 with `Cache-Control: no-store` and the exact
  `{api_key,token,expires_at,user:{id}}` shape. Require the returned API key to
  equal the current build's Stream key, the user ID to equal the validated
  bootstrap identity, the token to be bounded printable ASCII, and the UTC
  expiry to be future and no more than 65 minutes away.
- Treat a bad-response envelope as trusted recovery evidence only when its
  exact public error fields, UUIDv4 request ID, `X-Request-Id`, `no-store`
  header, and documented HTTP-status/public-code pairing agree. Unknown or
  mismatched codes fail as an invalid payload and cannot spend a recovery
  budget. Raw bodies, messages, headers, access tokens, provider errors, and
  Dio exceptions never enter application state or logs.
- Share one principal-bound token session between Chat and Video. It caches no
  Stream token. Every SDK request obtains a current Privy access token and
  returns the Stream token directly to the official SDK loader.
- Use two independent budgets across one token-load call: one exact HTTP 401
  may obtain a fresh Privy access token, and one exact
  `409 bootstrap_required` may invalidate, re-bootstrap, revalidate the same
  Stream user ID, and replay. The bounded loop makes at most three token POSTs
  in any order; a repeated 409 invalidates the cached bootstrap before failing.
- Never automatically retry 400, 429, 500, other 503, timeout, connection,
  cancellation, malformed payload, API-key mismatch, or user-ID mismatch.
- Keep existing Chat/Video SDK session code unchanged. Stream remains the
  truth source for messages, membership, presence, read/typing, calls, and
  media; LOOP does not add a parallel cache or state machine.
- Do not add or infer an Audio Room locator. A valid Video user token only
  authorizes an SDK user and does not identify a room or prove media readiness.
- Do not modify `loop-api` as part of this mobile slice.

## Consequences

With a matching Debug configuration, fully verified Privy session, reachable
Development backend, valid backend bootstrap, and accepted provider token, the
existing official Chat and Video clients can now attempt connection and SDK
token refresh. Missing or mismatched inputs still produce no connection claim.

Local tests and Debug compilation prove request shape, parsing, bounded
recovery, provider composition, and SDK compatibility only. Real Privy token
verification, Stream connection/refresh/reconnect, channels, two-device chat,
Video connection, and provider/device behavior remain unverified until run on
physical devices. Audio Room join remains unavailable without its separately
owned room locator.

## Verification

- Repository tests cover both routes, no body/query, request-local Bearer,
  response/error drift, no-store, key/user/expiry checks, and sanitized failure
  mapping.
- Session tests cover bootstrap-first loading, one 401, second 401, one and
  repeated 409, combined bounded budgets, wrong user, and non-retryable 429.
- Provider tests cover shared bootstrap identity, distinct Chat/Video token
  products, missing configuration, unverified sessions, profile mismatch, and
  principal rotation.
- Harness validation locks the route ownership, exact parser/recovery markers,
  behavior-test names, no token persistence/logging, and truthful Audio Room
  limitation.

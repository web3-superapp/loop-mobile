# Order Privy Cold-start Session State

## Status

Accepted on 2026-08-28.

## Context

LOOP subscribes to Privy's `authStateStream` and calls `getAuthState()` during
the same cold-start window. These asynchronous sources can resolve in either
order. A delayed restore result could previously overwrite a newer stream
state in both places that matter: the SDK adapter's token-capable
`_currentUser` and the application session controller. A delayed restore from
an earlier gateway instance could also publish after provider reconstruction.

`AuthenticatedUnverified` is a restricted offline session, not an
authentication success. It must never be promoted by an older fully
authenticated snapshot, and `NotReady` must expose no token-capable user.

## Decision

- Record every accepted Privy auth observation in one monotonic gateway
  revision. A restore captures the revision before awaiting native I/O, honors
  a newer explicit result first, then reconciles the current live SDK state.
  It may use its fallback result only when no newer observation exists, so it
  performs no stale user mutation.
- Preserve observation provenance. An explicit login or logout result wins
  until a newer SDK stream/current observation supersedes it; this accounts
  for Privy's MethodChannel result arriving before its independent auth-state
  EventChannel. Restore fallback results do not claim live-SDK provenance.
- Distinguish a brand-new SDK's initial `NotReady` from current `NotReady`
  observed after the SDK stream/current state has resolved. Only the initial
  state, with no pending explicit result, may fall back to `getAuthState()`; a
  later current `NotReady` immediately retires the current user even when its
  stream callback has not arrived.
- Clear the gateway's current token-capable user for `NotReady`,
  `Unauthenticated`, and `AuthenticatedUnverified`. Only an accepted
  `Authenticated` observation, including an explicit successful login result,
  may install a `PrivyUser`.
- Bind each controller subscription and restore to one gateway generation.
  Ignore callbacks from retired generations after provider reconstruction.
- Advance a stream revision when each event arrives. Defer only a synchronous
  pre-build replay until Riverpod has installed the initial state; later events
  apply immediately. Explicit login, Preview entry, wallet publication, and
  local logout advance the same revision and cancel older queued observations.
- Apply restore success or failure only while its gateway generation and
  stream revision are unchanged and that generation remains `restoring`.
- Keep provider-backed gates unchanged: only a fully authenticated session may
  bootstrap LOOP identity, request Stream credentials, create a wallet, or
  reach private backend data.

## Consequences

Cold-start completion is deterministic under the tested restore/stream
interleavings, and stale state cannot recover provider access for a restricted,
signed-out, Preview, or replacement-gateway session. The tests use controlled
Futures and synchronous auth streams; real SDK initialization and process
restoration still require physical-device evidence.

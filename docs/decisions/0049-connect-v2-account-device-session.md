# Connect the V2 Account and Device Session

## Status

Accepted on 2026-09-03. This supersedes only decision 0048's temporary rule
that the mobile client must not call D0/D1. The five-destination UI and every
unrelated provider, trading, Preview, and truth-source boundary remain active.

## Context

The backend handed off the committed V2 OpenAPI contract and deployed D0/D1 to
the Development origin. A current Privy access token now resolves an opaque
LOOP account, installation audit session, and server-selected Stream user ID.
The command contract requires a durable installation UUID and exact
idempotency metadata before bootstrap or logout is dispatched.

The existing mobile bootstrap is an in-memory V1 mapping. Stream Chat/Video
tokens and the implemented social routes remain frozen V1 consumers, so their
wire contracts cannot be globally converted to V2. Shared Preferences is also
intentionally limited to one non-critical display Boolean and is unsuitable
for the new command journal.

## Decision

- Add strict, separate V2 metadata and account/session adapters. V2 accepts
  only camelCase success bodies, the seven-field uppercase error envelope,
  `Cache-Control: no-store`, and one server UUID whose response header agrees
  with `correlationId` on errors. V1 response and error parsers remain intact.
- Resolve every verified Privy login with `GET /v2/account/me` first. Reuse a
  locally active projection only when its opaque `accountId` and
  `streamUserId` match that response. First registration, no local active
  projection, or `ACCOUNT_BOOTSTRAP_REQUIRED` performs one persisted
  `POST /v2/session/bootstrap` command. An explicit
  `ACCOUNT_BOOTSTRAP_REQUIRED` discards every stale active/logout projection
  that depended on the missing account. A retained unconfirmed logout is
  replayed with its original metadata and resolved before a later login may
  create a new bootstrap command.
- Keep `LoopBootstrapSession` as the compatibility facade used by existing
  Stream and V1 feature adapters. Its production repository becomes the V2
  resolver; no feature derives an account or Stream identity from Privy,
  email, Alias, wallet address, or another opaque ID.
- Pin `flutter_secure_storage` 10.3.1 directly. Store only a lowercase UUIDv4
  device ID, exact command metadata/idempotency keys, opaque `accountId`,
  `sessionId`, `streamUserId`, a pending-bootstrap retirement Boolean valid
  only beside its exact command, and an optional backend-revocation-unconfirmed
  marker. One JSON owner journal is replaced in one write after every state
  transition. Android uses a LOOP-specific storage namespace and disables the
  plugin's destructive `resetOnError`; application backup is also disabled so
  the journal is not restored onto another installation. iOS uses a dedicated
  Keychain service, disables synchronization, and selects
  `unlocked_this_device` accessibility.
- Validate the full journal again before every platform write. The accepted
  states are empty, bootstrap-pending, bootstrap-pending-with-retirement,
  active, or active-with-logout-pending; bootstrap and logout states cannot
  overlap. The retirement Boolean requires its exact pending bootstrap command,
  and an unconfirmed marker requires its exact logout command.
- Partition owner journals with a deterministic UUIDv5 computed at runtime
  from the current Privy principal. The partition is only local isolation: it
  is not sent, logged, treated as authentication, or transformed into a LOOP
  identity. The raw principal is never written by LOOP.
- Never persist a Privy access/refresh token, Stream token, email, wallet
  address, Provider response, raw Privy subject, PIN, signing material, or
  arbitrary feature state. Shared Preferences remains unchanged and the
  Reown-owned storage remains outside this journal.
- Supply client version through the matching build profile and require strict
  SemVer before composing V2 account requests. Platform is runtime-derived and
  limited to iOS or Android. Every header is request-local; account, bootstrap,
  and logout each send only their exact allowed header set.
- Logout establishes the local principal barrier synchronously, persists one
  new logout command, attempts backend revocation with its exact key/metadata,
  retires active Stream SDK owners without deleting their separately
  principal-bound offline history, and finally asks Privy to logout. Before
  reading the journal, logout synchronously retires new bootstrap work and
  waits for an already-dispatched bootstrap to record its successful session;
  this prevents a late response from writing an active session after the
  revocation pass. Success and `SESSION_NOT_FOUND` clear the active journal.
  Timeout, connection, or server ambiguity never traps the user and retains an
  unconfirmed audit marker rather than claiming backend revocation.
- Keep logout single-flight and expose a non-product `signingOut` state until
  the captured backend cleanup Future has actually terminated. Every login and
  Preview entry remains closed during that state, and the gateway used for
  Privy logout is captured before asynchronous cleanup begins. Do not wrap the
  journal-mutating backend Future in a Controller-level `Future.timeout`:
  Dart does not cancel its source, so a late old operation could otherwise use
  a new principal token or delete a newly written same-principal journal.
  Network termination remains bounded by the backend Dio profile.
- If logout finds an ambiguous pending bootstrap rather than a known active
  session, it first persists a retirement intent, replays the bootstrap with
  its original key to recover the exact session, atomically replaces that
  state with the recovered session plus a newly keyed logout command, and then
  revokes it. An ambiguous recovery remains fail-closed and durable. A later
  login must complete that recovery and revocation before it can create a new
  bootstrap key or authorize private LOOP/Stream behavior.
- D0 policy and capability projections are observational inputs in this
  slice. The application root starts one non-blocking concurrent observation
  for a valid configured origin; its error cannot block authentication or
  routing. `unavailable`, `deferred`, or evidence `pending` never grants a
  feature or constructs the stricter existing force-update, region, or
  maintenance markers. Maintenance is not part of D0.

## Consequences

Repeated launch no longer creates a new device session when the stored active
projection matches `account/me`. Lost bootstrap/logout responses can reuse the
same command metadata instead of manufacturing a second operation. Storage
failure leaves LOOP/Stream private functionality unavailable, while logout
still completes locally and through Privy. Storage corruption is surfaced as
unavailable and is never handled by silently erasing or rotating the journal.

iOS Keychain records may survive uninstall; this first slice therefore calls
the UUID a device-local installation record and does not claim uninstall
rotation evidence. A separately reviewed native installation marker is needed
before asserting that behavior. Secure Storage does not make the audit session
a credential: every protected backend request still uses a current Privy
Bearer token.

## Verification

Repository tests cover exact routes/headers, strict responses/errors,
request-correlation proof, account-first restoration, persisted same-command
retry, owner rotation, bootstrap/logout quiescence, and logout
terminal/unknown results. Existing V1 Stream and social suites remain
regression gates. Harness checks lock the dependency, profile client version,
storage allowlist and platform options, no-token rule, V1/V2 dual stack, and
physical-device claims as unverified.

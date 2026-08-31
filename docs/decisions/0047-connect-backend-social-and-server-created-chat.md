# Connect Backend Social and Server-Created Chat

## Status

Accepted on 2026-08-31.

This decision supersedes the providerless production assumptions in decision
0046. Decision 0046 continues to govern the visibly labelled Development
Preview and the feature-owned port boundary where this decision does not refine
it.

## Context

Decision 0046 intentionally stopped before inventing an authenticated social
contract. The LOOP Development backend now publishes reviewed Profile, Privacy,
Social Privacy, friend discovery, friend-request, operation-reconciliation,
group/direct-channel and group-Alias routes. Keeping the old unavailable
production composition would prevent frontend/backend integration; adapting the
new wire contract into the old viewer-scoped `profile_ref` and unique-Alias
assumptions would also discard required identity and relationship facts.

Stream remains the communication provider. The LOOP API owns public-profile
authorization, social policy, idempotency, fixed channel allocation and
reconciliation; it does not become a second message-history or presence API.

## Decision

### Authenticated session and transport

- Production social and personalization adapters use the current Privy access
  token as a request-local Bearer and complete the principal-bound LOOP
  bootstrap before an authenticated resource request. Flutter never reads,
  stores, logs or forwards the Privy refresh token.
- A request may obtain one fresh Privy access token after
  `invalid_access_token` and may perform one bounded bootstrap recovery after
  `bootstrap_required`. Other transport failures are not generically retried.
  Account rotation retires the old authenticated executor and its plaintext
  process memory. It never replays the old principal's operation under the new
  principal.
- Production Dio instances still come only from `LoopDioFactory`. Adapters
  validate the strict JSON contract, `Cache-Control: no-store` and canonical
  `X-Request-ID`, map machine-readable error codes, keep authorization out of
  Dio defaults, and never log a credential or response body.

### Public social identity

- `public_profile_id` is the stable, opaque UUID used as the only Flutter
  command target for a friend request, group member or direct-chat peer.
- `profile_code` is the immutable, globally unique 10-character Crockford
  Base32 display discriminator. Flutter displays it beside an Alias but never
  submits it as a command target or projects it into Stream/group-Alias data.
- Account `alias` is nullable for accepted friends, mutable and non-unique.
  Search rows may therefore contain duplicate Aliases and are distinguished by
  `profile_code`; duplicate Alias values no longer invalidate a response.
- Wallet addresses, Privy DIDs, LOOP internal user IDs and Stream user IDs are
  neither public-search keys nor client-selected membership identifiers.

### Profile and social policy

- Production composes authenticated adapters for Profile, public Privacy and
  Social Privacy as separate versioned resources. Their replacement writes use
  the returned version and preserve conflicts for an explicit reload rather
  than silently overwriting newer state.
- Public Privacy continues to own `discoverable` and
  `copy_trade_visibility`; it does not grant friend, chat or trading rights.
  Social Privacy separately owns `friend_requests`, `group_invites` and
  `direct_messages`, with version-zero fail-closed defaults. The supported
  positive policies are `enabled`, `friends` and `friends` respectively.

### Friend discovery and relationship lifecycle

- The friend surface uses the relationship-aware Alias-prefix search. The
  normalized prefix is 2–40 code points, the result is bounded to 20, and
  `truncated` asks the user to enter a longer prefix rather than authorizing an
  unbounded enumeration. Results distinguish `none`, `outgoing_pending`,
  `incoming_pending` and `friend`.
- Flutter bounds raw UTF-16 input, trims it, rejects the backend's complete
  Cc/Cf/Cs/Zl/Zp category set, and applies ASCII-space folding for local search
  length preflight. The backend remains authoritative for NFKC validation; the
  client does not add a second Unicode-normalization dependency or rewrite the
  submitted display value.
- Accepted friends and incoming/outgoing pending requests use separate
  cursor-paginated resources. A cursor is opaque, short-lived, owner/route/page
  bound, limited to 1024 UTF-16 code units, and never crosses an account or
  list. An invalid cursor restarts from the first page instead of being parsed
  or repaired locally.
- Sending, accepting and rejecting a request are server-confirmed operations.
  Only an accepted result followed by a refreshed friend list proves
  friendship; the client does not promote an outgoing pending request or local
  button state into an accepted relationship.

### Idempotency and outcome reconciliation

- Each new friend-request, request-decision, group-create or direct-create
  intent receives one canonical UUIDv4. That value is both the
  `Idempotency-Key` and public `operation_id`; it is never reused for another
  logical command.
- An ambiguous POST retains the exact UUID and body under the initiating
  principal for the lifetime of the current process. Flutter queries the
  matching social or Chat operation before any replay. Only the route-specific
  `404 social_operation_not_found` or `404 chat_operation_not_found` permits
  replaying the exact original request; a query authentication, rate-limit,
  transport, response-proof or parsing failure never permits a duplicate
  mutation.
- Social operations are terminal. Chat operations may return `202`; polling is
  bounded by monotonic wall-clock time and an attempt ceiling, and honors the
  greater of the response body's delay and `Retry-After`.
  `operator_required` is a terminal hold, not success or permission to
  allocate a second channel.
- A syntactically successful response that fails typed identity, CID, member,
  operation or envelope validation is still an ambiguous write response. The
  original operation is reconciled before any replay; malformed provider data
  is never treated as proof that the write did not commit.

### Backend-created channels and Stream truth

- Flutter submits only accepted friends' `public_profile_id` values. It never
  supplies another user's Stream identity, a channel ID/CID, role, member set or
  distinct key, and never creates or mutates Stream membership directly.
- A group contains 2–29 selected friends plus the current user. Successful
  creation returns both an opaque `group_id` and canonical full
  `messaging:loop_group_*` CID; member IDs are an unordered set. Direct creation
  returns a canonical `messaging:loop_direct_*` CID and repeated/concurrent
  commands for the same unordered friend pair converge on the backend's fixed
  channel.
- The existing exact-CID/current-member Stream gate remains mandatory after a
  successful backend operation. Only that online query may mount official
  channel UI. The same gate owns direct `/chat/channel/:cid/alias` deep links:
  the backend group resolver is not mounted until the current Stream principal
  has proved membership in that exact group CID. Stream's official SDK remains
  the truth source for messages,
  history, pagination, read/ACK state, typing, presence, members and realtime
  events.

### Group-scoped Alias

- A group Alias is scoped by backend `group_id`; direct channels have no group
  Alias namespace. Once a normalized Alias is reserved for the current member,
  it is immutable. An identical PUT may recover an ambiguous response, while a
  different value is rejected and a value reserved by another member is
  unavailable.
- A backend-created group receipt supplies `group_id` directly. When an
  existing official Stream group is opened after process restart, Flutter may
  submit only its validated channel ID (not the full CID) to
  `POST /v1/chat/groups/resolve` after the exact-CID/current-member Stream gate
  has succeeded. The resolver has no `Idempotency-Key`, never creates or joins
  a channel, rejects known `loop_direct_*` IDs locally, and treats the backend's
  membership check and `404 not_found` as authoritative.
- `group_alias_id` and Alias are the only peer fields exposed by group-Alias
  search. The response never supplies `public_profile_id`, `profile_code`,
  account Alias, wallet, LOOP identity or Stream identity, so Flutter cannot
  correlate a person across groups through this API.
- PostgreSQL reservation is authoritative and Stream member custom data is a
  projection. A pending projection is shown as pending, never as confirmed or
  anonymous. Group Alias is a presentation pseudonym, not a guarantee against
  provider/operator/traffic correlation.
- Group message presentation reads only the exact v1 Alias projection from the
  current channel's Stream `Member` record. Missing, duplicate, malformed or
  future projections render the neutral `群成员` label and never fall back to
  the account-level Stream `User.name`, image, custom data or stable user ID.
  This presentation boundary applies to message senders, quotes, mentions,
  reactions, thread participants and other identity-bearing official widgets;
  direct channels retain the normal Stream identity presentation.

### Explicit exclusions

This slice does not add friend deletion, block/unblock, blocklist management,
QR identity/friend discovery, wallet-address search, member invite/removal,
leave/transfer/roles, account deletion, push delivery, or a parallel message
API. The client must not expose placeholder actions for those capabilities.

## Consequences

Production friend, request, direct/group creation and social-personalization
surfaces can use one principal-bound LOOP API integration while feature code
continues to depend only on narrow ports. Preview remains process-local and
visibly labelled. The public profile discriminator and group identifier become
real backend facts instead of client-invented references.

Provider connectivity remains a separate acceptance gate. A backend operation
receipt can establish only LOOP's recorded result; official Stream channel UI
still requires the existing-member query, and group-Alias confirmation still
depends on the server projection contract.

The current UUID/body retention is deliberately process-local. App process
death, reinstall, app-data clearing and another device cannot recover an
unresolved intent from this client alone because the backend contract exposes
operation lookup by UUID but not owner-scoped pending-intent discovery. A
future encrypted, principal-bucketed command journal (or a backend discovery
contract) requires a separate persistence/security decision. Until then,
process-restart command recovery is a known limitation and must not be claimed
as verified exactly-once behavior.

## Evidence and remaining verification

The implementation includes strict transport/model/controller tests for the
authenticated session, social operations, cursor pages, duplicate Alias
handling, channel result validation, Social Privacy and immutable group Alias.
Exact command results belong in the feature-checkpoint report and must not be
inferred from this decision.

The following remain explicitly unverified until executed with real Development
providers and physical devices:

- two real Privy accounts completing request, accept/reject and friend refresh;
- group/direct creation, concurrent direct convergence and official Stream
  exact-membership channel opening;
- Stream Dashboard permission denial for client channel/member/server-field
  mutations;
- group-Alias projection, leave/rejoin restoration and member filtering;
- provider history discovery after Flutter restart.

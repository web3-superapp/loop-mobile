# Model Friends and Group Creation Before Transport

## Status

Superseded for production transport and wire identity by decision 0047 on
2026-08-31. Its visibly labelled Development Preview and feature-owned port
boundaries remain accepted.

## Context

LOOP needs a WeChat-style creation menu in Chat, Alias discovery for adding a
friend, an accepted-friend list in Profile, and a flow that selects friends to
create a group. The deployed mobile contract currently contains only bootstrap
and Stream Chat/Video token routes. It has no reviewed user-directory, friend,
friend-request, group-creation, block-policy, or idempotency-reconciliation
route. The official Stream client can list and open already authorized channels,
but Flutter must not derive another user's Stream ID or bypass backend privacy
and membership policy by creating a channel directly.

Profile Alias, group-scoped anonymous Alias, wallet address, Privy principal,
internal LOOP ID, and Stream user ID are different identities. Reusing any one
as another would break the existing privacy and provider-identity boundaries.

## Decision

- Add one fixed Chat header menu with `创建群组` and `添加好友`, plus a
  `我的好友` entry under Profile's People & communication section.
- Model the feature behind a feature-owned `FriendGateway`. Feature code contains
  no Dio, HTTP path, provider token, or Stream SDK type. Production composes an
  unavailable implementation until the authenticated backend contract is
  reviewed and implemented under `lib/integrations/`.
- Search operates only on a backend-authorized, account-level discoverable LOOP
  Alias. Group-scoped aliases and wallet addresses are neither returned nor
  searched by this slice. The current result shape has no public discriminator,
  so a directory or search response containing case-insensitive duplicate
  Aliases fails closed. If
  product Aliases remain non-unique, the backend and client must first agree on
  a user-consented public disambiguation field.
- Address people only through the typed, bounded opaque `FriendProfileRef`.
  The underlying `profileRef` is a viewer-scoped adapter reference, not a Privy
  DID, wallet address, internal LOOP ID, or Stream user ID, and it is never
  rendered or embedded in a widget key.
- Adding a person sends an idempotent friend request. Its operation response is
  valid only as `requestPending`, never an optimistic accepted friendship.
  Accepted friendship may arrive later as a separately fetched server fact.
  Only accepted friends appear in `我的好友` and the group picker.
- A group selects 2–29 accepted friends; the backend will add the current user,
  keeping the initial member set within the reviewed Stream list controller's
  30-member page bound. The client creates one UUID v4 for each logical write.
  An in-flight or ambiguous write retains its UUID and draft in memory even if
  its route is closed, and is never directly resubmitted. Retention is scoped to
  the current principal-bound gateway instance, so account rotation rebuilds
  it. A definitive rejection may release the draft for editing; the next
  submission is a new logical intent with a new UUID. Adapters must classify an
  ambiguous transport result as `outcomeUnknown`; all other typed write errors
  prove that no mutation was committed.
- A future production group adapter must revalidate the current principal,
  friendship, bilateral block/privacy rules, membership policy, and
  idempotency; derive Stream identities server-side; and return one canonical
  full `messaging:<id>` CID. A receipt carries no guessed provider-neutral
  `groupId`. Flutter first accepts the CID syntax, then performs an online
  Stream channel-list query filtered by the exact CID and current membership.
  It mounts `StreamChannel` only for that existing member result; it never calls
  `client.channel(...).watch()` for an unverified CID or submits/receives another
  user's Stream ID. The mobile Stream role must not grant client channel
  creation before production group creation is enabled.
- The explicit Development Preview root may inject `MemoryFriendGateway`.
  Preview search, pending requests, friends, and group receipts are process-local
  and remain visibly labelled `开发预览`. Preview group receipts have no Stream
  CID and cannot open an official channel.
- No backend path is invented in this decision. Production friend surfaces
  render a truthful unavailable state, and the unavailable gateway performs no
  social transport, channel-create, or membership-write call until the backend
  team provides the reviewed contract. This is narrower than the shared
  official CID route, whose exact existing-member lookup is a Stream
  read/watch query and retains normal SDK message/delivery behavior.
- Page cursors, query matching/minimum length, incoming request acceptance and
  rejection, block-policy projection, rate limits, and timeout reconciliation
  remain contract work. The current ports are deliberately not claimed to be a
  drop-in production adapter surface.
- Friend controllers are normally route-lifetime `autoDispose` state. Only an
  in-flight or outcome-unknown write keeps its controller alive in memory so its
  UUID/draft cannot disappear on navigation. A future production gateway must
  be immutable and principal-bound, and account rotation must publish a
  different gateway instance so retained state rebuilds immediately. Visible
  search/group text mirrors restored controller state and clears whenever that
  gateway instance rotates, including when both accounts use production mode.

## Consequences

The requested client interaction can be reviewed while backend work proceeds in
parallel. Production remains intentionally gated. Once the backend contract is
available, its pagination, incoming-request, privacy, block, and reconciliation
semantics may require an explicit port/UI extension rather than being hidden in
an adapter.

The Preview demonstrates layout and deterministic transitions only. It is not
evidence of a provider user, accepted relationship, remote group, Stream
membership, message delivery, presence, or persistence.

## Evidence

`test/friend_feature_test.dart` covers input bounds, pending-versus-accepted
truth, session retention for ambiguous writes, explicit definitive failures,
idempotent Preview writes, one-ID retry behavior, production unavailable
surfaces, Preview search and group creation, menu navigation, Profile entry, and
application routes. `test/stream_chat_inbox_page_test.dart` locks the exact
CID/type/current-member query filter. Harness validation keeps the memory
implementation out of production composition, forbids transport or Stream
ownership in the feature slice, and requires the existing-member route gate.

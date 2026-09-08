# 0055 · Adopt the V2 communication, chat and voice-room module

## Status

Accepted 2026-09-08. Extends decisions 0002, 0005, 0006, 0045 and 0054;
completed by decision 0056 for the merged-image export. Retires the generic
Audio Room entry of decision 0024, the V1 friend-request route, the
CID-addressed group-Alias route and the V1 Stream token paths.

## Context

Step 4 (S4) connects `loop-api` decision 0032's `communication` module and the
`chat` / `voice` sections it added to the community record, and rebuilds ten
frozen-prototype pages: `community-chat`, `dm`, `group`, `group-info`,
`chat-search`, `chat-forward`, `chat-merge-preview`, `voiceroom`,
`voiceroom-full` and `community-ai`.

Five constraints shaped the result:

- **The channel locator is server-owned.** A conversation is opened only
  through a CID the backend issued: `chat.channelCid` for a community, the
  `directGetOrCreate` operation result for a DM, the channel list or a
  notification for a group. No route, ticker or display string assembles one.
- **`chat.status` has three values, and `syncing` is not `unavailable`.** LOOP
  has already recorded the membership intent; the provider has not caught up.
  Rendering that as "unavailable" would misreport a temporary state as a
  missing feature.
- **Decision 0005's provider evidence is still pending.** The Dev Stream
  application has no `listener` call role, so the backend maps
  `listener → user` and the evidence object now asks whether `user` grants
  `create-call`. Until the export exists, the client may not connect at all.
- **Search, forwarding and merging have no backend.** They are Stream SDK
  operations; chat content never enters LOOP's `/v2/search` domain and a merged
  transcript never leaves the device.
- **The Development Preview still owns a fixture conversation** bound to an
  exact ID by decision 0025. Production and Preview must not share a widget.

## Decision

1. **One strict transport under `lib/integrations/backend/v2/communication/`.**
   `LoopV2CommunicationApi` parses with `LoopV2Contract.strictMap` against the
   frozen key set. A persistent operation accepts `200` or `202` only; a `202`
   must carry the exact `Location: /v2/chat/operations/{id}` header, a
   non-terminal answer must carry `retryAfterMs` and a terminal one must not.
   `sequence` stays a decimal string and is never parsed into a number.
2. **Two narrow ports.** `ChatV2Gateway` owns the direct-channel operation,
   its polling and the group exit; `VoiceRoomGateway` owns the room record,
   the hand-raise queue and the host commands. Both reuse the S3
   `CommunityFailureKind` taxonomy, so `lib/features/` keeps one branch set,
   and both default to `Unavailable*` in production.
3. **`operatorRequired` is a terminal unresolved outcome.** It is never retried
   automatically and never presented as a failure; the page tells the user to
   contact support instead.
4. **Stream types stay inside `lib/features/chat/`.** `LoopStreamChannelSurface`
   is the one place that proves membership with an exact channel-list query and
   then mounts the official `StreamChannel`, `StreamMessageListView` and
   `StreamMessageComposer`. Attachments and voice recording stay disabled; the
   composer placeholder promises only "发消息", because `@AI` and CA recognition
   have no runtime.
5. **A channel prefix is the only thing that picks a surface.**
   `loopChatLocationForCid` maps `loop_community_` → `community-chat`,
   `loop_direct_` → `dm`, `loop_group_` → `group`, and an unknown shape fails
   closed. Notifications, chat search and the retained `/chat/channel/:cid`
   deep link all share it.
6. **Every room is a community resource.** Decision 0024's generic inbox entry
   is removed: the lobby is reached from a community record, and while
   `voiceRooms.evidence.status` is `pending` the whole page renders an
   explanation and issues no request. The official `CallState` surface is
   mounted only after the LOOP join grant exists, inside a nested
   `ProviderScope` that supplies exactly one authorized room ID.
7. **A hand raise is never a speaker.** The room resource carries no speaker
   directory — only the viewer's own role and two aggregate counts — so the
   removal action renders unavailable rather than taking its target from the
   hand-raise queue.
8. **Host controls come only from `viewer`.** Invite, remove, mute-all and end
   render when the server says the viewer is host and grants the flag. The
   participant figure is the server's `participants.observed` with its
   `observedAt`; an unobserved count renders `—`, never `0`. The LOOP
   speaker/listener counts are labelled as role intent, not presence.
9. **Forwarding caps at 20 and merging at 50.** A deleted or empty message is
   skipped and counted, never silently dropped; a target must be a channel the
   account already belongs to. The merged transcript is anonymous by
   construction — `匿名成员`, the timestamp and the text — so no alias, LOOP ID,
   Stream user ID or address can be exported. Decision 0056 completes the
   export: the anonymous card is captured with `RepaintBoundary.toImage`,
   encoded to PNG with `dart:ui` and handed to the system share sheet through
   `share_plus`. Nothing is uploaded and nothing is kept.
10. **`community-ai` restores the layout and closes every functional area** with
   the server's `COMMUNITY_AI_RUNTIME_DEFERRED`. The prototype's sample answer,
   knowledge-base figure, daily digest count and suggested prompts have no
   source and are not reproduced.
11. **Preview and production never share a widget.** `_chatSurface` picks the
    labelled fixture page in Preview mode and the V2 page otherwise, so
    decision 0025 stays intact while production carries no fixture.
12. **Three retirements.** `/chat/friends/requests` folds into `dm-requests`,
    `/chat/channel/:cid/alias` folds into `group-info` (which resolves the LOOP
    group itself), and `/chat/channel/:cid` becomes a redirect. All three are
    recorded as informational retirements.

## Consequences

- `group-info` shows member management, the group profile and the notification
  preferences as unavailable: none has a reviewed source in this step. The
  group-Alias editor stays reachable at its supplementary route.
- `chat-merge-preview` renders the full anonymous transcript and exports it
  through the operating system's share sheet (decision 0056). The bytes are a
  pixel copy of the card the viewer can see, so the anonymisation is structural
  rather than a filter applied at export time.
- `dm` opens only after a friendship exists. Without one it offers exactly one
  next step — `POST /v2/message-requests` — and says that an unreachable target
  answers the same way as a non-existent one, so nothing about the other
  account is inferred.
- `voiceroom` and `voiceroom-full` are closed in every environment until the
  Stream Dashboard export proves the `audio_room` `user` role cannot create a
  call. The whole client path exists and is tested behind that gate.
- The Stream user token loader now uses `POST /v2/chat/token` and
  `POST /v2/video/token`. They are writes: each attempt carries the contract
  headers and its own canonical UUIDv4 `Idempotency-Key`, and errors arrive in
  the seven-field envelope. Decision 0045's recovery budget is unchanged — one
  401 refresh and one bootstrap recovery — and the session now recognises both
  the V1 `bootstrap_required` and the V2 `ACCOUNT_BOOTSTRAP_REQUIRED` code for
  the same condition. `DioLoopStreamTokenRepository` stays in the repository as
  frozen V1 history and is no longer mounted.

## Evidence

- `test/communication_api_contract_test.dart` — strict parsing, the operation
  state machine, the `202` Location header, the decimal hand-raise sequence,
  the unobserved participant count and the three `chat.status` values.
- `test/communication_pages_test.dart` — the five states for each of the ten
  pages, the forward cap and skip rule, the merge cap and anonymisation, and
  host-control visibility.
- `test/loop_notification_router_test.dart` — a chat notification lands on the
  surface its channel prefix names.
- `test/stream_chat_inbox_page_test.dart`, `test/route_manifest_test.dart`,
  `test/friend_feature_test.dart` — the deep-link redirect and the three
  retirements fail closed.

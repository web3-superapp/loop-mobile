# Centralize Notification Intents Before Provider Ingress

## Status

Accepted on 2026-08-25.

## Context

Firebase Core and Messaging are pinned for compatibility, but LOOP has no
Android or iOS Firebase application files, exact Stream push-provider names,
captured Chat payload template, APNs/VoIP policy, or production notification
category/channel configuration. The locked Stream Chat SDK exposes device
registration but no stable incoming Firebase payload parser. Stream Video's
ringing handlers can perform network work and invoke provider UI, while its iOS
PushKit path uses a different native payload shape. Treating guessed fields such
as `type`, `cid`, `message_id`, `call_cid`, title, or body as trusted navigation
would therefore cross an unverified provider and account boundary.

The application also exposed a static notification catalog under the ordinary
production route. Its risk, price, mention, badge, time, and read-state values
were local fixtures without a visible Preview boundary.

## Decision

- Introduce one provider-neutral `LoopNotificationRouter`. It performs no I/O,
  imports no Firebase, Stream, navigation, or feature SDK, and never retains or
  logs the input map.
- Accept only a LOOP-owned normalized `notification.v1` data envelope. Every
  value must be a String and every kind must have its exact key set. Common
  keys are `loop_schema`, canonical UUID v4 `event_id`,
  `recipient_stream_user_id`, `kind`, canonical millisecond UTC
  `occurred_at`, and `expires_at`. Chat alone adds `cid`.
- Support only `chat.message`, `audio_room.activity`, and `system.notice`.
  Missing, additional, wrong-typed, expired, excessive-lifetime,
  future-skewed, unknown-version, provider-shaped, or malformed data fails
  closed.
- Bind every valid interaction to the currently authenticated,
  backend-derived Stream user ID. Restoring may be retried by a future
  coordinator; signed-out, Preview, authenticated-unverified, malformed, and
  other-recipient events never navigate or cross a later account switch.
- Foreground and background delivery never navigate. Only an explicit user
  interaction may create a navigation intent.
- Resolve only three fixed destinations: a validated and URI-encoded official
  `/chat/channel/:cid` route, the `/chat/voice` lobby, or the truthful
  `/notifications` state. Payload data can never choose an arbitrary URL,
  route, call type, room ID, call CID, join action, microphone state, wallet,
  trading, or signing surface.
- Share the provider-neutral Chat CID parser between official Chat routing and
  notification classification. Stream SDK types remain inside Chat.
- Claim an interaction once in one process with a bounded receipt ledger.
  Foreground/background observation does not consume the interaction receipt.
  This ledger is not described as cross-isolate, cross-process, or exactly-once
  delivery.
- Reserve `lib/integrations/notifications/firebase_notification_ingress.dart`
  as the only future owner of Firebase global callbacks. It does not exist in
  this slice. Firebase initialization, permission prompts, device registration,
  push-provider registration, native capabilities, ringing, and provider
  payload mapping remain disabled.
- Reserve `lib/app/notifications/loop_notification_coordinator.dart` as the only
  future application consumer of the router. It must map actual session and
  verified bootstrap state into the notification context. Feature modules may
  not construct an authenticated context or a second router directly.
- Show local notification cards only in the explicit Development Preview. A
  production session shows a provider-unavailable state and no fake badge,
  read state, risk, price, or mention activity.

## Consequences

- The backend/provider configuration can proceed independently against a small
  client contract without prematurely connecting Firebase or guessing Stream
  payload fields.
- Future ingress work must supply real Android/iOS Firebase configs, exact
  Stream Chat/Video provider names, captured provider payload fixtures, and the
  server event/expiry/account-binding contract before mapping any provider
  message into `notification.v1`.
- A Chat intent still passes through the official Stream authorization and
  channel page. An Audio Room intent opens only the foreground lobby, whose
  principal-bound backend locator remains the sole room source and still
  requires an explicit Join action.
- Before background delivery or ordinary-push/VoIP ringing is enabled, LOOP
  needs a bounded persistent atomic receipt ledger that works across Firebase
  background isolates and native paths. The current in-memory ledger proves
  ordering semantics only and cannot prevent duplicate effects after restart.
- This slice does not prove delivery, notification display, badge/read state,
  device registration, Chat push, Video ringing, background execution, APNs,
  FCM, PushKit, or CallKit behavior.

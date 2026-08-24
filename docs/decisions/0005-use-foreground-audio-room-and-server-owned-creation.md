# Use a Foreground Audio Room and Server-Owned Creation

## Status

Accepted on 2026-08-24.

## Context

LOOP's first Stream Video product slice is an Audio Room, not a ringing call.
The mobile client can finish its lobby, lifecycle, permissions, official-state
UI, and backend seams before the separately owned backend provides real Stream
Video tokens and an authorized room locator.

Stream Video Flutter 1.4.3 requires special care at this boundary. Its public
`Call.join()` path sends `create: true` to the Coordinator and does not expose an
existing-only join flag. Calling `Call.get()` first would not make creation safe:
there is still a time-of-check/time-of-use gap, and this SDK version applies the
settings returned by `get()` in an unawaited task. That task can race the later
join and overwrite explicit camera or microphone choices. `getOrCreate()` is
therefore also outside the mobile contract.

The SDK publishes `CallStatusJoined` before the SFU media session is connected.
Treating that state as live, or enabling the microphone in it, can produce a
false connected claim and a `Session is null` command failure.

The Stream Video package also merges optional background media services, while
the Push package merges incoming-call, phone-call, full-screen, and notification
capabilities into Android. More importantly, Push 1.4.3 automatically registers
a Telecom phone account on Android and initializes a CallKit controller on iOS
as soon as Flutter registers the plugin. Merely removing manifest entries cannot
make that plugin dormant. None of those behaviors belongs to the first
foreground-only Audio Room release.

## Decision

- Fix the mobile call type to `audio_room`. The backend returns only a strictly
  validated room ID; a route, user input, or response cannot select another call
  type or supply a complete CID.
- Require the backend to pre-create every authorized room and assign the current
  server-derived Stream user as a member. Before a real locator is enabled,
  provider evidence must show that the mobile member role and `audio_room` call
  type do not grant `create-call`. Consequently the SDK's internal
  `create: true` cannot create a missing room and must fail closed.
- Do not call `get()` or `getOrCreate()` from this slice. `join()` itself awaits
  the Dashboard settings and then merges LOOP's explicit connect options. Those
  options disable camera, microphone, and screen share for every first join.
- Start Audio Room output on the speaker route. This is playback policy only;
  it does not publish a local track or request microphone access.
- Make join single-flight and bind every target and `Call` to the current
  verified principal and Stream client generation. A target, principal, client,
  route, or page change invalidates late work and retires the old call.
- Mount the official `CallState` projection as soon as the `Call` exists. Keep
  only command progress and sanitized command errors locally. Participants,
  participant count, connection, capabilities, microphone state, speaking, and
  reconnect state come from Stream.
- Present `Joined` as `Connecting media`; only `Connected` is `Live` and only it
  can enable the microphone. A successful `send-audio` capability is also
  required before the UI offers Speak.
- Request operating-system microphone access only when the user deliberately
  taps Speak and the SDK starts capture. Joining never starts a local media
  publishing track.
- Keep this version foreground-only. Android explicitly owns
  `RECORD_AUDIO` and `MODIFY_AUDIO_SETTINGS` while removing transitive Stream
  incoming-call, background-service, camera, notification, and Telecom entries.
  iOS adds only `NSMicrophoneUsageDescription`; it adds no camera description,
  background mode, push/VoIP entitlement, PushKit, or CallKit initialization.
- Retire the active or joining Call when Flutter reports `paused`, `hidden`, or
  `detached`. Do not retire on `inactive`, because the operating-system
  microphone prompt can transiently enter that state. Resume never rejoins or
  republishes audio automatically. The handle immediately requests native audio
  suspension, blocks microphone enable commands, starts a terminal mute and one
  single-flight Call leave immediately without letting a possibly stuck
  microphone or native suspension future delay leave, then confirms the retired
  object has disappeared from the Stream client's `activeCalls`. The lobby also
  waits for earlier microphone work and a second post-command mute. Because
  Video 1.4.3 can recreate a stopped track after disposal, each Call accepts
  only one Speak start; after Mute, leave and rejoin before speaking again. The
  lobby remains blocked on a fast resume until retirement succeeds; a completed
  failure exposes only a cleanup retry. SDK background audio/video auto-muting
  stays disabled because Video 1.4.3 remembers those tracks and automatically
  restores them on resume.
- Keep `stream_video_push_notification` 1.4.3 out of the resolved application
  and native plugin registrants. That version remains the compatibility-tested
  future pin, but it can return only with the separately approved push/ringing
  capability and device matrix. Manifest removal markers remain as defense
  against accidental transitive reintroduction.
- Keep Firebase, Stream push registration, ringing, CallKit, and background
  media disabled until their provider projects, exact push-provider names,
  native capabilities, centralized router, and device acceptance matrix are
  separately approved.

## Consequences

- Flutter can implement and test the full app-side Audio Room lifecycle without
  inventing provider state, but the default production sources remain
  unavailable until real Video token and room-locator contracts exist.
- The backend must provide an initial Video token, token refresh, a principal-
  authorized room locator, room pre-creation, membership/role assignment, and
  evidence that mobile roles cannot create calls. Provider secrets stay in the
  backend.
- Missing token, missing/invalid target, lost principal, target rotation, join
  failure, or client rotation leaves the UI offline and retires any late `Call`.
- Unit, widget, harness, and native builds prove the client structure and
  manifest shape only. Microphone prompts, audio routing, capability behavior,
  weak-network recovery, and participant media still require two physical
  devices and a configured Development backend/Stream application.

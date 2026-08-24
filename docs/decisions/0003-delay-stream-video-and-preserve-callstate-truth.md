# Delay Stream Video Construction and Preserve Official CallState Truth

## Status

Accepted on 2026-08-24.

## Context

LOOP locks Stream Video Flutter 1.4.3 and has a client-safe public API key, but
the separately owned backend does not yet provide the backend-derived Stream
user ID, initial Video token, Video-token refresh endpoint, room/callee contract, or
push-provider configuration. The native projects also do not yet declare the
reviewed microphone/camera permissions required for active media.

Stream Video 1.4.3 has a non-obvious initialization behavior: setting its token
provider immediately asks that provider for a token, even when
`autoConnect: false`. Constructing the SDK with only a loader would therefore
start backend token work during construction and make logout/account-switch
races harder to contain.

The existing LOOP voice controller is intentionally an offline-preview model.
It cannot become the production call state machine because Stream `Call` and
`CallState` are the required source of truth.

## Decision

- Keep a separate `StreamVideoSessionSource` seam for the future Loop backend.
  The backend supplies the derived Stream user ID and short-lived Video tokens;
  Flutter never derives a Stream ID from Privy data.
- Use the Privy user ID only as an opaque principal-rotation key. Only fully
  verified Privy sessions may request Video bootstrap data.
- Load and validate the backend Stream identity and initial Video token before
  constructing an official client. Missing, malformed, late, or stale values
  fail closed without SDK construction.
- Create a non-singleton `StreamVideo.create` client with both `userToken` and
  `tokenLoader`, `autoConnect: false`, and logging disabled. The initial token
  satisfies the SDK's construction-time token request; the loader is reserved
  for SDK refresh and validates the requested Stream user ID.
- Connect explicitly with `registerPushDevice: false`. Do not construct a push
  notification manager while Firebase, APNs/VoIP, and exact Stream push-provider
  names are absent.
- Bind each foreground Video owner to one principal. Authorization is
  single-flight and generation-gated; logout, account changes, route disposal,
  or a stale backend response retire the old client and active calls.
- Keep the existing preview `VoiceSessionController` unchanged. Production
  `/chat/voice` uses a separate page and never renders preview room names,
  participants, presence, ringing, or connection state.
- Keep call creation and join disabled until a backend room/callee contract and
  reviewed native media permissions exist. Do not mount `StreamCallContainer`
  or lobby widgets because they can create/join calls or media tracks.
- Provide a foreground call view that reads `CallState` through
  `PartialCallStateBuilder`. It creates no parallel call-phase state and is not
  mounted until a real backend-authorized `Call` is available.
- Generate a fresh UUID v4 for every future outgoing ringing intent. Never
  reuse an ID that has already rung.

## Consequences

- The public API key alone still cannot create an authenticated Video client or
  claim a live call.
- Entering a production voice surface is the first point that may request Video
  bootstrap data; leaving it retires the foreground owner. There is no
  background ringing or persistent Video connection in this slice.
- An authorized frontend can report only that the principal-bound SDK session
  is ready. It cannot claim a room, participant, media, ringing, or connected
  state until an official `CallState` exists.
- Native compile and unit/widget success prove lifecycle and integration shape,
  not provider connectivity, media permissions, push, CallKit, or two-device
  call behavior.

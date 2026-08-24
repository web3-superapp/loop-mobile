# Stream Video `autoConnect: false` Still Loads a Token

## Summary

Stream Video Flutter 1.4.3 consumes its token provider during client
construction even when WebSocket auto-connect is disabled. Treating
`autoConnect: false` as a completely side-effect-free constructor would start
backend token work too early and weaken logout/account-switch isolation.

## Root Cause

The `StreamVideo` constructor creates a token provider and immediately calls
`TokenManager.setTokenProvider`. In 1.4.3 that method immediately calls
`getToken`. A dynamic provider with only `tokenLoader` therefore invokes the
loader before any explicit `connect` call.

## Detection

Read the locked SDK source whenever changing Video initialization:

- `stream_video-1.4.3/lib/src/stream_video.dart`, token-provider setup around
  lines 220-245.
- `stream_video-1.4.3/lib/src/token/token_manager.dart`, immediate `getToken`
  call in `setTokenProvider` around lines 29-38.
- `stream_video-1.4.3/lib/src/token/token.dart`, dynamic provider initial-token
  handling around lines 93-126.

The LOOP lifecycle tests also assert that a pending initial token prevents SDK
construction and that logout invalidates the pending request.

## Prevention

- Obtain the backend-derived Stream user ID and initial short-lived Video token
  before SDK construction.
- Pass both `userToken: initialToken` and a user-ID-validating `tokenLoader` to
  `StreamVideo.create`.
- Keep `autoConnect: false`, then call `connect(registerPushDevice: false)` only
  after principal/generation checks.
- Re-check this behavior against official locked-version source before any
  Stream Video version change.

## Evidence

- `test/stream_video_sdk_session_test.dart` covers no-work construction,
  missing bootstrap, pending-token logout, wrong-user refresh, single-flight
  authorization, and stale-client retirement.
- `docs/decisions/0003-delay-stream-video-and-preserve-callstate-truth.md`
  records the accepted initialization order and production call boundary.

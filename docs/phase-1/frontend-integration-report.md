# Loop Mobile Frontend Foundation Integration Report

Date: 2026-08-24

## Scope

Keep the formal repository's existing UI/catalog and six primary destinations while merging the verified Harness, final native identity and compatibility matrix, guarded Privy boundary, public Hyperliquid Testnet markets, and fail-closed provider rules. Launchpad remains a primary destination.

## Integrated foundation

- Exact Flutter/provider/state/network/decimal/UUID dependencies with committed Dart lockfile.
- Flutter 3.47.1/Dart 3.13.1 version-guard wrappers.
- Final Android/iOS identity and accepted native platform/toolchain floors.
- Project-level SwiftPM opt-out and CocoaPods native integration.
- Repository Harness, product constraints, decision, failure memory, compatibility evidence, and license register.
- Six-destination product contract: Home, Market, Launch, Chat, Wallet, Profile.
- Provider shortcuts fail closed; public Hyperliquid mobile access stays Testnet read-only.
- Official Stream Chat principal-bound client/persistence ownership, backend identity/token seam, root session rotation, bounded channel list, CID route, and official message UI.
- Stream text composition is structurally enabled; attachment and voice-recording entry points remain disabled pending platform policy and device verification.
- Incoming Stream `token_card.v1` references render through official message UI with an exact identifier-only payload, malformed/unavailable states, no mutable facts or actions, and no per-message enrichment request. Compact message/draft previews use fixed safe labels for every raw Token Card. Legacy fixture conversation and token/facts routes mount only in explicit Preview mode.
- Foreground Stream Video principal-bound lifecycle, pre-construction initial-token gate, refresh loader, explicit no-push connection, UUID call-ID generator, production/preview voice-page separation, and a fail-closed Audio Room lobby/join path driven by official `CallState`.
- Native Privy Bearer bootstrap with an HTTPS-only production origin, exact no-body request, strict no-store response parsing, principal rotation, single-flight loading, and one bounded 401 refresh attempt. Chat and Video share only the validated server-derived Stream identity; neither may connect without its separate short-lived token contract.
- Provider-neutral centralized notification classification with exact `notification.v1` envelopes, authenticated recipient binding, fixed Chat/Audio Room/notification-center intents, explicit foreground/background non-navigation, and bounded process-local interaction deduplication. Production notification fixtures now fail closed outside explicit Preview; Firebase/provider ingress remains disabled.

## Verification

Completed on the integrated branch:

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter pub get`: passed; exact graph resolved and `pubspec.lock` updated.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/dart format --output=none --set-exit-if-changed lib test`: passed; 76 files, 0 changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed; no issues.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter test`: passed; 55 tests.
- Public Testnet contract probe (`POST https://api.hyperliquid-testnet.xyz/info`, `metaAndAssetCtxs`): passed; `universe` and context lists were both 210 items and sampled mark/funding fields remained JSON strings.
- `python3 -m py_compile scripts/check_harness.py tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 9 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --debug`: passed; generated `app-debug.apk`.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --release`: passed; generated an intentionally unsigned `app-release.apk`.
- Android build-tools `apksigner verify --verbose app-release.apk`: returned `DOES NOT VERIFY`, the expected evidence that repository builds do not fall back to a debug signing key.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build ios --debug --no-codesign`: passed; generated `Runner.app`.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build ios --release --no-codesign`: passed; generated a 47.8 MB `Runner.app`.
- After the supplied Privy Mobile App Client ID was wired as the Development default, the exact-identifier configuration test, all 55 Flutter tests, Android Debug build, and iOS Debug no-codesign build passed again.

The first Flutter test/native-asset attempt was interrupted by a GitHub TLS error while downloading sqlite3 3.5.2. Verification resumed with an existing binary whose SHA-256 exactly matched the hash embedded in the resolved sqlite3 package; no dependency or application setting changed. The iOS Debug build then completed CocoaPods installation, including the StreamWebRTC artifact, before compiling successfully.

These builds prove the integrated dependency and native compile matrix. They do not prove dashboard configuration, provider connectivity, store signing, or device behavior.

The official Stream Chat frontend slice was re-verified on 2026-08-24:

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/dart format --output=none --set-exit-if-changed lib test`: passed; 82 files, 0 changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed; no issues.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter test`: passed; 82 tests.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py'`: passed; 9 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --debug`: passed; generated `app-debug.apk`. Flutter repeated the already-recorded Gradle 8.14/AGP 8.13.2 future-support warnings; the accepted matrix was not changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build ios --debug --no-codesign`: passed; generated `Runner.app` for `com.cywd.loop`.

These checks include lazy SDK construction, persistence attachment, backend identity/token fail-closed behavior, token-provider refresh, principal-bound client rotation, logout/dispose races, isolation and final reaping of permanently stuck or late old-principal identity/token/SDK-connection work, root client replacement, bounded official channel-controller configuration, CID parsing/routing, disabled attachment/recording entry points, and preservation of the explicit offline preview. The authorized controller/UI path was verified structurally and at compile time only; it was not rendered against a live or synthetic connected Stream user. No live Stream token, provider channel, two-device message, presence, read/typing, background, push, or call test was run.

The foreground Stream Video foundation was re-verified on 2026-08-24:

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/dart format --output=none --set-exit-if-changed lib test`: passed; 91 files, 0 changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed; no issues.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter test`: passed; 101 tests.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 9 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --debug`: passed; generated `app-debug.apk`. Flutter repeated the accepted Gradle 8.14/AGP 8.13.2 future-support warnings; the compatibility matrix was not changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build ios --debug --no-codesign`: passed; generated `Runner.app` for `com.cywd.loop`.

These checks cover pre-construction backend identity/initial-token gating, SDK refresh-token user-ID validation, explicit push-registration disablement, single-flight authorization, logout/account-switch invalidation, stuck identity/token/connect retirement, fresh UUID v4 generation, production/preview voice separation, and truthful loading/unavailable/ready UI. The official `CallState` foreground view compiled but remains deliberately unmounted because no backend room/callee contract or native media permissions exist. No live Video token, call creation/join, media capture/playback, ringing, push, CallKit, weak-network, or two-device test was run.

The native LOOP identity bootstrap slice was re-verified on 2026-08-24:

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/dart format --output=none --set-exit-if-changed lib test`: passed; 99 files, 0 changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed; no issues.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter test`: passed; 121 tests.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py'`: passed; 9 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --debug`: passed; generated `app-debug.apk`. Flutter repeated the accepted Gradle 8.14/AGP 8.13.2 future-support warnings; the compatibility matrix was not changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build ios --debug --no-codesign`: passed; generated `Runner.app` for `com.cywd.loop`.

These checks cover safe backend-origin parsing, an exact Bearer-only `POST /v1/bootstrap`, rejection of redirects, non-200 success codes and response drift, same-UUID LOOP/Stream identity derivation, no-store enforcement, sanitized errors, one HTTP 401 refresh attempt, timeout classification, single-flight authorization, verified-principal gating, synchronous local sign-out invalidation, stale SDK snapshot rejection, account-switch invalidation, and shared Chat/Video identity projection without a token shortcut. They use fake transports and identities. No deployed endpoint, TLS/device path, live Privy token verification, database identity stability, or live Stream connection was tested.

The foreground Audio Room app-side slice was re-verified on 2026-08-25:

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/dart format --output=none --set-exit-if-changed lib test`: passed; 104 files, 0 changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed; no issues.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter test`: passed; 144 tests.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py'`: passed; 12 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --debug`: passed; generated `app-debug.apk`. Flutter repeated the accepted Gradle 8.14/AGP 8.13.2 future-support warnings; the compatibility matrix was not changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --release`: passed; generated `app-release.apk` with the same accepted toolchain warnings.
- The Debug and Release merged and packaged Android manifests contain `RECORD_AUDIO` and `MODIFY_AUDIO_SETTINGS`. They contain none of the removed camera, full-screen incoming-call, Telecom, optional Stream background service, phone-call foreground-service, media-projection, or push-notification entries. The auto-registering Stream Video Push plugin is absent from the resolved graph and generated registrant.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build ios --debug --no-codesign`: passed; generated `Runner.app` for `com.cywd.loop`.
- The built iOS application contains the reviewed microphone explanation and no `NSCameraUsageDescription` or `UIBackgroundModes` entry. Its generated registrant and Pods graph contain no Stream Video Push plugin.

The behavior checks cover a fixed `audio_room` target parser, explicit camera/microphone/screen-share-disabled join options, speaker playback policy, single-flight commands and leave, one Speak start per Call, failed/late Call cleanup, sanitized errors, `Joined` versus `Connected` status presentation, mute availability during reconnection and after a failed leave, removal of the Speak affordance after retirement starts, immediate leave despite stuck Speak/native-suspension futures, explicit old-Call removal plus post-command terminal mute before fast resume/rejoin, cleanup failure/retry, and no automatic rejoin. Source guards and compilation additionally verify the principal-bound locator/client seams and that the foreground widget reads official participant, capability, and microphone fields directly from `CallState`; those projections were not rendered against a synthetic or live connected Call. The tests use fake room targets and call handles; no production target source is installed. No deployed Video-token endpoint, Stream Dashboard role inspection, backend room pre-creation, live join, operating-system permission prompt, audio route, two-device media, weak-network recovery, or provider capability test was run.

The fail-closed Stream Token Card slice was verified on 2026-08-25:

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/dart format --output=none --set-exit-if-changed lib test`: passed; 114 files, 0 changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed; no issues.
- The focused preview-route, token-contract, attachment-builder, compact-preview and root-provider suite passed; 23 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter test`: passed; 161 tests.
- `python3 -m py_compile scripts/check_harness.py tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 20 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --debug`: passed; generated `app-debug.apk`. Flutter repeated the accepted Gradle 8.14/AGP 8.13.2 future-support warnings; the compatibility matrix was not changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build ios --debug --no-codesign`: passed; generated `Runner.app` for `com.cywd.loop`.

The behavior checks cover exact `token_card.v1` identifier parsing and round-trip encoding, rejection of missing/additional/malformed/mutable fields, interception of raw Token Cards whose computed Stream type becomes a link preview, rejection of standard top-level URL/display fields and mixed/repeated cards, sanitization of compact message and draft previews, no production price/risk/Buy/Watch claim, narrow layout and 2x Dynamic Type for both production and Preview, explicit Preview labelling, disabled prototype Chart/Watch/Buy controls, root Stream configuration, and selection of the custom builder by the official `StreamMessageItem` renderer. Production widget tests also deep-link through every legacy conversation and token/facts route and prove that fixtures cannot mount outside explicit Preview mode. The renderer performs no enrichment request and no live provider or backend facts projection was tested. Price, liquidity, ownership, attributable contract facts, risk signals, watch state and trading actions remain intentionally unavailable in production; outgoing Token Card composition also remains disabled pending server-side wire-shape enforcement.

The provider-neutral notification-routing slice was verified on 2026-08-25:

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter pub get`: passed; the existing exact dependency graph remained resolved.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/dart format --output=none --set-exit-if-changed lib test`: passed; 118 files, 0 changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed; no issues.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter test`: passed; 173 tests.
- `python3 -m py_compile scripts/check_harness.py tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 27 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build apk --debug`: passed; generated `app-debug.apk`. Flutter repeated the accepted Gradle 8.14/AGP 8.13.2 future-support warnings; the locked compatibility matrix was not changed.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter build ios --debug --no-codesign`: passed; generated `Runner.app` for `com.cywd.loop`.

The behavior checks cover exact String-only `notification.v1` key sets, canonical UUID v4 event IDs, backend-derived recipient binding, canonical UTC lifetime and expiry, unknown/provider-shaped/extra/wrong-typed rejection, fixed URI-encoded Chat CID routing, Audio Room lobby-only routing, foreground/background non-navigation, interaction-only process-local deduplication, bounded receipt capacity, and production-versus-Preview notification truth. Harness mutation tests reject competing Firebase callbacks, provider SDK imports in the router, and payload-selected routes. Firebase was not initialized, no provider callback or device was registered, no raw Stream payload was interpreted, and no FCM/APNs delivery, notification display, badge/read state, background isolate, Video ringing, PushKit, or CallKit behavior was tested.

## Provider readiness

| Capability | Current status |
| --- | --- |
| Privy App ID / API key | Client-safe identifier supplied |
| Privy Mobile App Client ID | Client-safe Development identifier supplied and wired; build-time override remains available |
| Privy Email OTP | Guarded implementation; provider/device verification pending |
| Stream API key | Client-safe identifier supplied |
| Stream Chat | Official client, persistence, lifecycle, controller and UI integrated; strict identifier-only `token_card.v1` receive rendering is wired, while the short-lived Chat token source and fresh token-facts projection are still required |
| Stream Video | Delayed foreground SDK lifecycle and Audio Room lobby/join/official-state UI integrated; backend-derived identity bootstrap and native microphone declarations are wired, while initial/refresh Video tokens, an authorized pre-created room target, no-`create-call` role evidence, and device verification are still required |
| Firebase/push | Provider-neutral intent contract and fail-closed UI verified; no mobile configs, exact Stream push-provider names, or captured payload fixtures, so initialization/handlers/device registration remain disabled and the auto-registering Stream Video Push plugin is not linked |
| Hyperliquid public markets | Direct Testnet read-only adapter available |
| Private trading | Backend-only by design; not connected |

## Follow-up inputs

Privy Email OTP still requires dashboard confirmation and physical-device evidence before it is called connected. Provide future Firebase mobile configuration only through documented client inputs. Keep Privy/Stream secrets, Firebase service-account JSON, APNs `.p8`, and Hyperliquid agent keys in backend/provider secret managers. A deployed bootstrap endpoint, Stream Chat/Video token contracts, an attributable freshness-bounded Token Card facts projection, an Audio Room locator that returns a pre-created room with a mobile role lacking `create-call`, and a two-device test setup are required before claiming communication or trading connectivity.

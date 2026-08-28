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
- Legacy Preview group/direct navigation now carries one exact registered conversation ID across Inbox, pages, group information, Home suggestions, and scoped search. Missing, repeated, unknown, or kind-mismatched targets fail closed without a message list or composer; the memory gateway cannot substitute Glyph Hunters. Production Stream continues to use the official full CID route.
- Foreground Stream Video principal-bound lifecycle, pre-construction initial-token gate, refresh loader, explicit no-push connection, UUID call-ID generator, production/preview voice-page separation, and a fail-closed Audio Room lobby/join path driven by official `CallState`.
- Native Privy Bearer bootstrap with an HTTPS-only production origin, exact no-body request, strict no-store response parsing, principal rotation, single-flight loading, and one bounded 401 refresh attempt. Chat and Video share only the validated server-derived Stream identity; neither may connect without its separate short-lived token contract.
- Provider-neutral centralized notification classification with exact `notification.v1` envelopes, authenticated recipient binding, fixed Chat/Audio Room/notification-center intents, explicit foreground/background non-navigation, and bounded process-local interaction deduplication. The root EventSource/Coordinator seam is wired with a production-disabled source; authenticated context comes only from the real LOOP session plus verified bootstrap Stream identity, and at most one time-bounded interaction may wait for restoration. Production notification fixtures now fail closed outside explicit Preview; Firebase/provider ingress remains disabled.
- Providerless Watchlist domain and application state with exact grouped/order limits, defensive immutable snapshots, draft editing, optimistic expected-version saves, one in-flight mutation, explicit discard/reload, and fail-closed conflict handling. Production uses an unavailable gateway; the labelled in-memory implementation is composed only by the explicit Preview entry point and carries asset references rather than market facts.
- Providerless Profile presentation domain and application state with exact nullable Alias/opaque avatar-reference validation, defensive immutable resources, complete optimistic replacement, draft/discard/reload, single-flight loading and saving, conflict freezing, ambiguous-retry convergence, provider rotation, and late-result isolation. H1/H2 project only committed values, production stays unavailable without claiming persistence, and the labelled Preview fake is composed only by the explicit Preview root. Bio and Privacy are not smuggled into the Profile contract, and avatar editing remains disabled.
- Providerless Privacy preference domain and application state with the exact `discoverable` Boolean and `copy_trade_visibility` enum values, version/timestamp invariants, complete optimistic replacement, draft/discard/reload, single-flight work, conflict freezing, ambiguous-retry convergence, gateway rotation, and late-result isolation. Production stays unavailable without claiming persistence; the labelled Preview fake is composed only by the explicit Preview root. Legacy H3 controls were removed, and Copy Trading remains a non-actionable placeholder because this preference neither grants authorization nor executes copying.
- Providerless Notification Preferences domain and application state with the exact four Boolean owner intents, fail-closed version-zero defaults, permanently unavailable delivery, complete optimistic replacement, draft/discard/reload, single-flight work, conflict freezing, ambiguous-retry convergence, gateway rotation, and late-result isolation. Production stays unavailable without claiming persistence or delivery; the labelled Preview fake is composed only by the explicit Preview root. Legacy H9 categories, fabricated operating-system state, the no-op device-settings action, and Quiet hours were removed. Price Alert creation/evaluation and Firebase/provider/device delivery remain separate unavailable capabilities.

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

The notification EventSource/Coordinator Harness contract was verified on 2026-08-25:

- `python3 -m py_compile scripts/check_harness.py tests/test_check_harness.py`: passed.
- The focused disabled-production-source, production-entrypoint override, forged-identity/deferred-slot, in-flight payload-retention, competing-coordinator, and repeated-navigation mutation suite passed; 6 tests.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 35 tests.

The Harness now requires both application notification seam files, keeps the production provider directly bound to `DisabledLoopNotificationEventSource`, verifies its null initial interaction and empty stream, and checks root composition against the actual session and bootstrap providers. The coordinator can construct an authenticated router context only from `bootstrap.identity.streamUserId`. It has one in-memory deferred slot with a positive default wait no longer than one minute; replacing that slot cancels the prior timer and invalidates prior identity resolution. In-flight authorization cannot retain that payload, feature code cannot construct a second coordinator, and the root may execute exactly one typed navigation. Every retried event still passes the router's time, account, recipient, kind, and route checks. This does not initialize Firebase, register a callback/device, prove delivery, or provide cross-process persistence.

The implemented notification composition was verified on 2026-08-25:

- `bin/dart format --output=none --set-exit-if-changed lib test`: passed; 122 files, 0 changed.
- `bin/flutter analyze`: passed; no issues.
- `bin/flutter test test/loop_notification_coordinator_test.dart test/app_notification_coordinator_test.dart`: passed; 13 tests.
- `bin/flutter test`: passed; 186 tests.
- `bin/flutter build apk --debug`: passed; produced `build/app/outputs/flutter-apk/app-debug.apk`. Flutter repeated the already accepted future Gradle 8.14 / AGP 8.13.2 support warnings; the locked matrix was not changed.
- `bin/flutter build ios --debug --no-codesign`: passed; produced `build/ios/iphoneos/Runner.app` for `com.cywd.loop`.

The behavior suite covers initial and live interaction routing, delivery-only non-navigation, latest-interaction restore semantics, signed-out/Preview/unverified rejection, bootstrap authorization, hung-authorization timeout, account rotation, expiry, disposal, payload-safe diagnostics, and a real `LoopApp`/GoRouter integration. These are deterministic main-isolate tests with a fake EventSource; FCM/APNs delivery and device behavior remain unverified.

The providerless Watchlist slice was verified on 2026-08-25:

- `bin/dart format --output=none --set-exit-if-changed lib test`: passed; 130 files, 0 changed.
- `bin/flutter analyze`: passed; no issues.
- `bin/flutter test test/watchlist_models_test.dart test/watchlist_controller_test.dart test/watchlist_editor_screen_test.dart`: passed; 35 tests.
- `bin/flutter test`: passed; 221 tests.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 38 tests.
- `bin/flutter build apk --debug`: passed; produced `build/app/outputs/flutter-apk/app-debug.apk`. Flutter repeated the accepted future Gradle 8.14 / AGP 8.13.2 support warnings; the locked matrix was not changed.
- `bin/flutter build ios --debug --no-codesign`: passed; produced `build/ios/iphoneos/Runner.app` for `com.cywd.loop`.

The deterministic behavior suite covers exact backend-aligned validation limits, immutable ordered copies, unavailable production composition, labelled Preview memory state, complete draft replacement, group/item editing and ordering, single-flight load/save, expected-version propagation, ambiguous-save retry convergence, fail-closed mismatched responses, explicit conflict reload, provider rotation, disposal, and sanitized unexpected/unavailable UI failures. No Dio route, Privy bearer request, backend response, provider account, or device persistence was exercised; those remain for the later authenticated adapter slice.

The providerless Profile presentation slice was verified on 2026-08-25:

- `bin/dart format --output=none --set-exit-if-changed lib test`: passed; 137 files, 0 changed.
- `bin/flutter analyze`: passed; no issues.
- `bin/flutter test test/profile_models_test.dart test/profile_controller_test.dart test/profile_presentation_screen_test.dart`: passed; 34 tests.
- `bin/flutter test`: passed; 255 tests.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 48 tests.
- `bin/flutter build apk --debug`: passed; produced `build/app/outputs/flutter-apk/app-debug.apk`. Flutter repeated the accepted future Gradle 8.14 / AGP 8.13.2 support warnings; the locked matrix was not changed.
- `bin/flutter build ios --debug --no-codesign`: passed; produced `build/ios/iphoneos/Runner.app` for `com.cywd.loop`.

The deterministic behavior suite covers the reviewed raw/normalized Alias limits, Unicode scalar and bidirectional safety, opaque avatar-reference grammar, version/timestamp biconditional, missing-row creation, stale-identical replay, complete-value replacement, invalid and non-advancing responses, single-flight work, optimistic conflicts, ambiguous save retry, gateway-owner rotation, disposal, and late-result isolation. Widget tests cover production unavailable truth, fixture-free default Home, labelled Preview editing, invalid-input retry gating, committed Home projection, conflict-only reload, pending/failed reload feedback with draft preservation, mounted gateway rotation, sanitized failure, and narrow-screen 2x Dynamic Type. No Dio route, Privy bearer request, backend response, avatar upload/reference source, Privacy persistence, provider account, or device persistence was exercised; those remain for later adapter slices.

The providerless Privacy preferences slice was verified on 2026-08-25:

- `bin/dart format --output=none --set-exit-if-changed lib test`: passed; 144 files, 0 changed.
- `bin/flutter analyze`: passed; no issues.
- `bin/flutter test test/privacy_models_test.dart test/privacy_controller_test.dart test/privacy_presentation_screen_test.dart`: passed; 26 tests.
- `bin/flutter test`: passed; 281 tests.
- `python3 -m py_compile scripts/check_harness.py tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 55 tests.
- `bin/flutter build apk --debug`: passed; produced `build/app/outputs/flutter-apk/app-debug.apk`. Flutter repeated the accepted future Gradle 8.14 / AGP 8.13.2 support warnings; the locked matrix was not changed.
- `bin/flutter build ios --debug --no-codesign`: passed; produced `build/ios/iphoneos/Runner.app` for `com.cywd.loop`.

The deterministic behavior suite covers exact field allowlists and enum wire values, rejection of unknown visibility values, defaults, version/timestamp invariants, missing-row creation, stale-identical convergence, complete expected-version replacement, invalid and non-advancing responses, single-flight work, conflicts, retryable failures, gateway rotation, disposal, and late-result isolation. Widget tests cover unavailable production truth, labelled Preview editing, committed evidence only after an advanced response, gateway rotation, conflict-preserving reload, removal of legacy H3/fake Copy permission controls, and a 390-point screen at 2x Dynamic Type. No Dio route, Privy bearer request, backend response, discovery enforcement, follower policy, Copy Trading authorization/execution, provider account, or device persistence was exercised; those remain outside this providerless slice.

The providerless Notification Preferences slice was verified on 2026-08-25:

- `bin/dart format --output=none --set-exit-if-changed lib test`: passed; 151 files, 0 changed.
- `bin/flutter analyze`: passed; no issues.
- `bin/flutter test test/notification_preferences_models_test.dart test/notification_preferences_controller_test.dart test/notification_preferences_screen_test.dart`: passed; 29 tests.
- `bin/flutter test`: passed; 310 tests.
- `python3 -m py_compile scripts/check_harness.py tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed; 64 tests.
- `bin/flutter build apk --debug`: passed; produced `build/app/outputs/flutter-apk/app-debug.apk`. Flutter repeated the accepted future Gradle 8.14 / AGP 8.13.2 support warnings; the locked matrix was not changed.
- `bin/flutter build ios --debug --no-codesign`: passed; produced `build/ios/iphoneos/Runner.app` for `com.cywd.loop`.

The deterministic behavior suite covers the exact four event wire values, unknown-value rejection, immutable complete Boolean values, fail-closed version-zero defaults, permanent `delivery=unavailable`, version bounds, identical-before-version convergence, complete expected-version replacement, single-flight load/save, ambiguous retry, invalid and non-advancing responses, conflict-preserving reload, gateway rotation, disposal, and late-result isolation. Widget tests cover unavailable production truth, retryable production load failure without a false no-request claim, visibly labelled Preview, exact four-switch editing, advanced matching commit evidence, conflict freeze/reload, gateway rotation, removal of legacy H9 categories and fake operating-system/delivery claims, and a 390-point screen at 2x Dynamic Type. No Dio route, Privy bearer request, backend response, Price Alert creation/evaluation, Firebase initialization, APNs/FCM registration, operating-system permission, provider delivery, notification display, background isolate, or device persistence was exercised; those remain outside this providerless slice.

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
| Hyperliquid public markets | Direct Testnet Spot read-only snapshot and bounded candle adapters mounted; exact Decimal discovery/OHLCV facts only, never executable quotes |
| Hyperliquid private reads | No private Spot read is connected. Retained Perp D8/D4 code is disabled, unmounted implementation history and no longer in product scope |
| Watchlist | Providerless models/controller/UI complete; production adapter unavailable and no account persistence claimed |
| Profile presentation | Providerless exact models/controller/H1-H2 UI complete; production adapter and avatar source unavailable, with no account persistence claimed |
| Privacy preferences | Providerless exact models/controller/UI complete; production adapter unavailable, and the saved preference is not discovery, follower or Copy Trading authorization/execution evidence |
| Notification preferences | Providerless exact four-intent models/controller/H9 UI complete; production adapter and delivery remain unavailable, with no Firebase/provider/device-permission claim |
| Private trading | Future Spot execution is backend-only by design and not connected; Perp is out of product scope |

## Follow-up inputs

Privy Email OTP still requires dashboard confirmation and physical-device evidence before it is called connected. Provide future Firebase mobile configuration only through documented client inputs. Keep Privy/Stream secrets, Firebase service-account JSON, APNs `.p8`, and Hyperliquid agent keys in backend/provider secret managers. A deployed bootstrap endpoint, Stream Chat/Video token contracts, an attributable freshness-bounded Token Card facts projection, an Audio Room locator that returns a pre-created room with a mobile role lacking `create-call`, and a two-device test setup are required before claiming communication or trading connectivity.

## Principal-bound Perp private reads merge

The private Perp read branch was merged into the active integration line on
2026-08-25. Production D8 now composes a lazy, verified-principal and
wallet-rotated backend session for wallet-binding, config, and account reads.
At that merge, positions, orders, fills, and funding had strict integration
transports but remained unmounted from production product pages. Order,
cancel, leverage,
transfer, withdrawal, signing, Mainnet, and automated trading remain disabled.

The merge review found and corrected one cross-principal wallet-creation race:
an old principal's single-flight Future could otherwise be reused by a new
principal. Creation now requires an expected Privy user ID, the SDK operation
is owner-keyed, its result carries the creating owner, and the session
controller independently rejects mismatched results. The deterministic A-to-B
rotation test and Harness mutation guard preserve this boundary. Android's
main manifest now declares the normal `INTERNET` permission required by the
same HTTPS adapters in Release; it does not initialize Firebase or enable
background call behavior.

Final verification after the correction:

- `bin/flutter pub get`: passed; the existing exact dependency graph remained
  resolved and no pin or lockfile changed.
- `bin/dart format --output=none --set-exit-if-changed lib test`: passed; 162
  files, 0 changed.
- `bin/flutter analyze`: passed; no issues.
- The focused session/auth/Perp account screen regression command passed 15
  tests.
- `bin/flutter test`: passed; 358 tests.
- `python3 -m py_compile scripts/check_harness.py
  tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py'`: passed; 66 tests.
- `bin/flutter build apk --debug`: passed; generated `app-debug.apk`.
- `bin/flutter build apk --release`: passed; generated the intentionally
  unsigned 135.3 MB `app-release.apk`. The accepted Gradle 8.14 / AGP 8.13.2
  future-support warnings were unchanged.
- Build-tools `aapt dump permissions` confirmed the packaged Release APK is
  `com.cywd.loop` and contains `INTERNET`, `RECORD_AUDIO`, and
  `MODIFY_AUDIO_SETTINGS`. It contains no `POST_NOTIFICATIONS`, camera,
  full-screen incoming-call, Telecom, or foreground call-service permission.
  The already-linked but uninitialized Firebase Messaging plugin still
  contributes `com.google.android.c2dm.permission.RECEIVE`; no Firebase mobile
  config, Dart initialization, provider callback, or device registration was
  added.
- `bin/flutter build ios --debug --no-codesign`: passed; generated
  `Runner.app` for `com.cywd.loop`.
- `bin/flutter build ios --release --no-codesign`: passed; generated a 56.5 MB
  `Runner.app` for `com.cywd.loop`.

These checks use deterministic gateways and native no-codesign builds. No live
Privy OTP, wallet creation, deployed backend response, wallet binding,
Hyperliquid account data, TLS tunnel, physical-device connectivity, or store
signing was exercised; those remain unverified rather than passing.

## Perp Positions production projection

Decision 0014 mounts D4 Positions through the existing principal/wallet-rotated
private Perp gateway. The first request is bounded to two Core positions and
one explicit continuation at a time uses only the opaque backend cursor. The
controller validates dataset, coverage absence, strict coin ordering, cursor
progress, and non-empty continuation progress. It takes the earliest expiry
across loaded pages, clears both non-empty and empty facts at that deadline,
checks the clock again on app resume, and retires late results after owner
rotation or expiry.

Production renders only strict `Decimal` position fields and labels the count
as loaded/fresh rather than a total. It does not synthesize mark price,
portfolio risk, or liquidation distance. Binding-required state routes to the
explicit D8 account flow and retries when that route returns, but D4 never
binds a wallet. D5 production detail now fails closed instead of falling back
to its ETH fixture; the original D4/D5 fixtures remain only in the visibly
labelled Development Preview branch. Every close, reduce, leverage, margin,
TP/SL, transfer, withdrawal, signing, and trading mutation remains unavailable.

Review found and corrected a stale single-flight edge: if a continuation stayed
physically pending beyond the projection expiry, the old Future could prevent
an immediate fresh read. Expiry now releases that retired logical operation,
while generation checks still prevent its late result from changing the fresh
projection. The UI also announces expiry/failure through a semantic live region
and avoids presenting a loaded page count as the complete live total.

Final verification on 2026-08-25:

- `bin/flutter pub get`: passed; the exact dependency graph and lockfiles did
  not change.
- `bin/dart format --output=none --set-exit-if-changed lib test`: passed; 165
  files, 0 changed.
- `bin/flutter analyze`: passed; no issues.
- `bin/flutter test test/perp_positions_controller_test.dart
  test/perp_positions_screen_test.dart`: passed; 21 tests.
- `bin/flutter test`: passed; 379 tests.
- `python3 -m py_compile scripts/check_harness.py
  tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py'`: passed; 75 tests.
- `bin/flutter build apk --debug`: passed; generated `app-debug.apk`.
- `bin/flutter build apk --release`: passed; generated the intentionally
  unsigned 135.4 MB `app-release.apk`. The accepted Gradle 8.14 / AGP 8.13.2
  future-support warnings were unchanged.
- `bin/flutter build ios --debug --no-codesign`: passed; generated
  `Runner.app` for `com.cywd.loop`.
- `bin/flutter build ios --release --no-codesign`: passed; generated a 56.6 MB
  `Runner.app` for `com.cywd.loop`.

The behavior suite uses deterministic gateways and simulated lifecycle time.
It does not prove live Privy OTP, wallet creation or binding, a deployed backend
response, non-empty Hyperliquid Testnet account data, TLS/device connectivity,
provider pagination behavior, or store signing. D5 detail, orders, fills,
funding, trading writes, Firebase, and background delivery remain separate
unverified slices.

## Spot-only public market, local settings, and communication preview

Decisions 0016 and 0017 make the mounted product Spot-only. The Market tab now
uses a separate public Hyperliquid Testnet `spotMetaAndAssetCtxs` adapter. It
indexes sparse token metadata by declared index, resolves universe token
references through that map, and joins contexts by exact provider coin instead
of array position. Wire numeric facts stay String plus Decimal; the displayed
time is explicitly the client's complete-response receipt time. Default rows
have positive exact 24-hour notional volume, are sorted descending, and are
bounded to 50. Search, refresh, loading, error, restricted-session, no-activity,
and no-match behavior are explicit. No account, balance, Buy, Sell, order,
signing, transfer, or withdrawal capability was mounted.

The explicit Development Preview root now has IDE launch configuration and an
end-to-end behavior test covering public Spot, the offline Chat cell list, a
group room, and process-local message composition. It does not supply a fixed
Stream user ID or token and never writes Preview messages into Stream
persistence. Real Chat remains unavailable until the LOOP backend validates
Privy and issues a server-derived Stream identity and short-lived token.

Provider-independent Settings work now includes a global app-run Reduce Motion
preference, local searchable Help, and Flutter's license page. Missing account
connections, sessions, blocklist, recovery, legal documents, and support
channels are truthful unavailable states instead of fixtures or no-op controls.

Verification on 2026-08-25:

- `bin/flutter pub get`: passed with the existing exact lockfile; no dependency
  version changed.
- The focused Spot/Market/Preview/Settings/navigation/Chat guard suite passed;
  the Spot repository subset passed all 4 tests, including capture of receipt
  time before response parsing.
- `bin/flutter test --no-pub`: passed all 394 tests after updating the stale
  notification Preview assertion to require the Spot alert and reject the
  removed Perp-risk card.
- `python3 -m py_compile scripts/check_harness.py
  tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed all 82
  Harness mutation tests.
- Full analyze reached application analysis and reported only two existing
  info-level lints in separately modified `lib/widgets/loop_ui.dart` and
  `test/loop_perp_providers_test.dart`; no error or warning came from this
  slice. The focused changed-file analysis had no issues.
- `bin/flutter build apk --debug --no-pub`: passed from clean generated state
  in 36.7 seconds. APK inspection found `libsqlite3.so` for arm64-v8a,
  armeabi-v7a, and x86_64.
- `bin/flutter clean` removed the 248 MB Debug APK and all generated build
  output; no APK, AAB, IPA, or Runner.app remains in the repository.

The sqlite3 system-source hook is recorded by decision 0018 and failure memory
because the default hook repeatedly failed while downloading GitHub native
artifacts before compilation. The clean Debug pass proves compilation and
packaging only. No physical-device run, live Privy OTP, real Stream Chat/Video
authorization, Stream persistence open/migration, Firebase delivery, private
Spot backend, or execution behavior was exercised; those remain unverified.

## Public Spot row-to-detail slice

On 2026-08-26, a deterministic Widget repro confirmed that every mounted Spot
row was a visual-only `LoopCard`: it had no tap callback, while the retained C2
route still resolved symbol-based Preview fixtures. The same repro failed twice
before the fix and passed afterward.

Each accepted row now opens the existing C2 surface with its exact provider
`spotIndex`. The production route parses that index, and the detail resolves the
same public `spotMetaAndAssetCtxs` snapshot rather than a symbol fixture. It
shows exact mark/mid/previous-day values, exact 24h notional/base volume,
provider and token identity, Decimal-derived change, source attribution, and
the client UTC receipt time. Missing, malformed, negative, or absent indices
fail closed without substituting ETH, Preview, or Perp data. Historical candles
remain explicitly unavailable, and no Buy, Sell, balance, order, signing, or
execution action is mounted.

Verification on 2026-08-26:

- The focused Market and real `LoopApp` Preview route suite passed all 18 tests,
  including exact row navigation, absent/invalid index behavior, no execution
  actions, and a 390 × 844 layout at 200% text scale.
- `bin/flutter test --no-pub`: passed all 399 tests.
- Changed-file Flutter analysis passed with no issues. Full analysis still
  reports only the two unrelated info-level lints in separately modified
  `lib/widgets/loop_ui.dart` and `test/loop_perp_providers_test.dart`.
- `python3 scripts/check_harness.py`: passed. The mutation suite passed all 83
  tests and now rejects removal of the Spot detail projection.
- Pixel 7a Android 16 Debug installation passed. Accessibility navigation from
  Market opened public `HYPE/USDC` Spot #1035, and the rendered page displayed
  current public Testnet facts with the expected read-only boundary.

## Public Testnet Spot candleSnapshot slice

On 2026-08-26, decision 0019 replaced the truthful unavailable-chart state on
an already resolved Spot detail with a second narrow public Testnet read. The
detail copies the exact provider coin from the market admitted by
`spotMetaAndAssetCtxs` and sends `POST /info` with `type: candleSnapshot` only
after that resolution. Invalid and absent Spot indices never mount the candle
provider and therefore issue zero candle requests.

The mounted periods map case-sensitively as `1H/1h`, `4H/4h`, `1D/1d`,
`1W/1w`, and `1M/1M`. Each request covers approximately 120 periods and the
repository sorts, deduplicates by open time, and retains at most the latest 120
rows. OHLCV remains exact wire String plus Decimal; floating point is confined
to normalized canvas coordinates. Empty and gapped history remains valid, an
overlapping first candle may open before the requested start, and the final
candle is labelled forming when client receipt time has not passed its close.
The UI provides explicit loading, empty, sanitized failure, retry, refresh, and
period states without polling, automatic retry, recursive backfill, Preview
fixtures, another asset, or Perp fallback.

This slice remains public discovery only. It adds no account, balance, Buy,
Sell, order, signing, transfer, withdrawal, or execution capability.

Verification on 2026-08-26:

- Direct official Testnet `candleSnapshot` probes for the resolved
  `HYPE/USDC` provider coin `@1035` returned real `1h` and `1M` OHLCV rows
  with the documented wire fields and fixed durations.
- The focused repository, provider, chart, Market, and Preview behavior suites
  passed, including interval switching, overlapping/gapped rows, malformed
  wire data, forming-candle state, refresh, and zero requests for invalid or
  absent Spot indices.
- `bin/flutter test --no-pub` passed all 421 Flutter tests after the
  interval-duration and chart-projection review fixes.
- Changed-file Flutter analysis passed with no issues. Full formatting and
  analysis remain blocked only by the two separately modified files
  `lib/widgets/loop_ui.dart` and `test/loop_perp_providers_test.dart`; neither
  belongs to or was changed by this slice.
- Both Harness Python files compiled, `python3 scripts/check_harness.py`
  passed, and the complete mutation suite passed all 98 tests.
- `bin/flutter build apk --debug --no-pub` passed against the final code in
  46.8 seconds. `bin/flutter clean` then removed the APK, `build/`,
  `.dart_tool`, and Flutter-generated metadata.

The live REST contract and Android Debug compilation are verified. The K-line
screen itself was not exercised on a physical device, in accordance with the
user-owned device-validation policy, so rendered provider/device behavior
remains unverified.

### Interval-duration review follow-up

A post-checkpoint review found that the first parser version verified the wire
interval identity but not each row's exact `T - t`, while its retention test
used artificial 1–2 millisecond `1h` rows. The interval model now fixes row
durations at 1h, 4h, 1d, 7d, and 30d and rejects any row whose close is not
exactly `open + duration - 1ms`. Window admission still uses time-range
intersection, so an exact-duration first row that opens before `startTime`
remains valid when it closes in the requested window.

The retention fixture now uses 121 genuine one-hour rows intersecting the
120-hour request boundary and proves that sorting/deduplication retains the
latest 120. A table-driven malformed-duration test exercises both one
millisecond short and one millisecond long rows for all five mounted intervals.

The review regressions are included in the final evidence above: all 10
repository tests and all 4 chart tests pass, the Harness now mutation-locks
exact interval durations, visible time gaps, and boundary doji rendering, and
the full Flutter suite plus final Android Debug build were rerun afterward.

## Home Discovery and Security Truth Boundary

On 2026-08-27, decision 0026 completed the providerless behavior of Home Global
Search without inventing a production index. Explicit Development Preview now
filters one fixed local set using trimmed, case-insensitive whitespace tokens,
shows a truthful no-match state, and restores suggestions through Clear. Its
group and person use the exact registered Preview identities. The ETH example
contains no price or provider index and opens only the public Spot ledger.
Authenticated production sessions show an unavailable state and no fixture.

Security Activity now fails closed in production: without an approved wallet or
account event source it shows no MFA, device, approval, count, severity, risk, or
all-clear fact. The explicit Preview keeps only a continuously labelled layout
example with no provider request or account action. Home's security activity row
now opens this bounded B9 surface rather than skipping directly to the wallet
approval fixture.

This slice added no HTTP route, provider adapter, persistence, SDK, dependency,
native capability, account action, or production event schema. Production
global group/person search and real Security Activity remain unimplemented
until their exact sources and contracts are reviewed.

Verification on 2026-08-27:

- The Home/Search/Security, application-navigation, and exact Preview identity
  focused suite passed all 32 tests.
- `bin/flutter test` passed all 496 Flutter tests.
- `python3 scripts/check_harness.py` passed, and the complete Harness mutation
  suite passed all 209 tests, including 14 Home-specific adversarial changes.
- Changed-file Flutter analysis passed with no issues. Full analysis reported
  only the two pre-existing info-level findings in separately modified
  `lib/widgets/loop_ui.dart` and `test/loop_perp_providers_test.dart`.
- The repository-wide format check identified only the separately modified
  `lib/widgets/loop_ui.dart`; every file owned by this slice was formatted.
- No HTTP/provider request, APK, application bundle, iOS build, package,
  simulator, interactive run, or physical-device validation was performed.

## Launchpad Placeholder Truth Boundary

On 2026-08-28, decision 0027 kept Launchpad in its fixed third-tab product
position while making its current delivery boundary explicit. G1 no longer
marks issuer facts complete or claims there are no live launches without a
source. Issuer facts, eligibility and participation review are all shown as not
connected, and the page exposes no amount, allocation, application, funding,
wallet, signing, claim or submission control.

G2 project discovery, G3 project details/participation and G4 applications stay
deferred. Production and Development Preview use the same non-actionable G1
placeholder and do not fabricate projects or simulated participation. This
slice adds no HTTP/provider request, persistence, wallet action, SDK,
dependency, native capability or new route.

Verification on 2026-08-28:

- The focused Launchpad, application-navigation and surface-catalog suite
  passed all 22 tests, including the 390 × 844 layout at 2× text scale.
- `bin/flutter test --no-pub` passed all 499 Flutter tests.
- Changed-file formatting and analysis passed with no issues.
- `python3 scripts/check_harness.py` passed, and the complete Harness mutation
  suite passed all 209 tests.
- Repository-wide format and analysis reached all current source. They reported
  only the two pre-existing user changes in `lib/widgets/loop_ui.dart` and
  `test/loop_perp_providers_test.dart`; no Launchpad file was reported.
- No HTTP/provider request, APK, application bundle, iOS build, simulator,
  interactive run or physical-device validation was performed.

## Connectivity Status Truth Boundary

On 2026-08-28, decision 0028 removed the implicit `fullyOffline` state from
the routed I1 system surface. A naked `/system/offline` route now says that no
connectivity source was supplied and does not infer device network loss, public
market-data failure or private LOOP service interruption. Only an explicit
scope can render one of those outage states and its retry/continue controls.

The reusable connectivity banner still requires an explicit scope and remains
unmounted in the production root. Its retry control moves below the message at
large text sizes to avoid horizontal overflow. This slice adds no connectivity
plugin, health request, polling, automatic retry, persistence, dependency or
native capability.

The I1 review also exposed a 588-pixel vertical overflow in the shared system
state scaffold at 390 × 844 and 2× text scale. The scaffold now preserves its
blocking and action semantics inside a bounded scroll layout, so explicit I1
outage states remain readable instead of overflowing.

Verification on 2026-08-28:

- All 8 I1 tests passed, including the formal `LoopApp` route, all three
  explicit scopes, the unmounted global banner assertion and both large-text
  layouts.
- The focused I1, auth, navigation and surface-catalog suite passed all 30
  tests; changed-file formatting and analysis passed with no issues.
- `bin/flutter test --no-pub` passed all 507 Flutter tests.
- `python3 scripts/check_harness.py` passed, and all 209 Harness mutation tests
  passed.
- Repository-wide format and analysis again reported only the two pre-existing
  user changes in `lib/widgets/loop_ui.dart` and
  `test/loop_perp_providers_test.dart`; no I1 file was reported.
- No connectivity provider, HTTP request, APK, application bundle, iOS build,
  simulator, interactive run or physical-device validation was performed.

## Service Error Truth Boundary

On 2026-08-28, decision 0029 removed the fabricated request outcome and fixed
`L-2048` reference from the routed I2 system surface. A naked `/system/error`
route now says that no request-error context is connected. It does not claim
that a request returned an error and exposes no retry or support action.

An owning feature may explicitly supply one `LoopServiceErrorObservation`
after its exact request returns an error or unconfirmed outcome. The copy
assumes neither success nor failure, including after a timeout. That projection
is currently an empty marker: no support-reference source or exact grammar has
been reviewed, so I2 displays no reference. Retry and support are independent
exact callbacks and remain absent when they are not connected; generic
return-to-Home navigation cannot authorize either label. Raw errors,
identifiers and provider payloads stay with their owning feature/integration,
and ambiguous writes still require reconciliation before retry.

This slice adds no error bus, HTTP/provider request, automatic retry, support
integration, persistence, SDK, dependency or native capability.

Verification on 2026-08-28:

- The focused I1/I2 suite passed all 15 tests, including the formal
  `/system/error` route, both directions of the dedicated callback boundary,
  accessibility semantics and both 390 × 844 layouts at 2× text scale.
- Changed-file formatting and analysis passed with no issues.
- `bin/flutter test` passed all 514 Flutter tests.
- `python3 scripts/check_harness.py` passed, and all 209 Harness mutation tests
  passed.
- Repository-wide format and analysis reported only the two pre-existing user
  changes in `lib/widgets/loop_ui.dart` and
  `test/loop_perp_providers_test.dart`; no I2 file was reported.
- No error provider, HTTP request, APK, application bundle, iOS build,
  simulator, interactive run or physical-device validation was performed.

# Loop Mobile Frontend Foundation Integration Report

## Device-Local Display Preferences

Decision 0042 upgrades the only implemented H12 control, Reduce motion, from
process memory to one installation-scoped, non-sensitive Boolean. Both formal
and Preview composition roots load the value before mounting `LoopApp`, so a
stored reduced-motion choice cannot be preceded by an ordinary LOOP
transition. The app still preserves a stricter operating-system accessibility
setting.

The narrow application port exposes only read/write Reduce motion operations.
The production adapter uses `SharedPreferencesAsync` and the single versioned
`loop.display.v1.reduce_motion` key. Construction, reads, and writes are bounded
to one second. Writes remain serialized across controller reconstruction so the
latest rapid selection wins even if an older operation completes late. A read
retry reads again; only a failed explicit write retries the current run-local
choice. Failures remain truthful instead of claiming persistence. Language,
Display currency, and Theme remain disabled.

The Harness locks the exact dependency, one-key adapter, both bootstrap roots,
serialized controller behavior, failure copy, system precedence, and disabled
H12 options. Shared Preferences remains outside Profile, Privacy, Notification
Preferences, wallet, identity, token, PIN, protection, and provider state. No
Secure Storage, generic database, account mirror, backend route, or provider
request is introduced.

Verification results: the focused Settings suite passed 19/19, the full Flutter
suite passed 631/631, analysis reported no issues, format checked 220 Dart files
unchanged, Harness validation passed, and the Python mutation suite passed
272/272. Native Debug compilation passed for Android (`app-debug.apk`) and iOS
without codesigning (`Runner.app`); the generated application bundles were
cleaned after verification. No simulator, interactive run, or physical-device
validation is part of this slice.

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

That final “without a token shortcut” statement records the 2026-08-24
checkpoint. Decision 0045 supersedes its token-unavailable state on
2026-08-29; the historical command results remain unchanged.

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

## Force Update Policy Truth Boundary

On 2026-08-28, decision 0030 removed the implicit blocking requirement from
the routed I3 system surface. A naked `/system/update` route now says that no
minimum-version policy is connected, remains dismissible and exposes only an
accurate return-to-LOOP action. It no longer claims that the installed build is
unsafe, unsupported or unskippable, and the route's generic placeholder action
cannot appear as `Update now`.

An explicit `LoopForceUpdateRequirement` can render the retained blocking
presentation. Its store action is independent and remains absent until an exact
reviewed callback is supplied. The reusable force-update dialog requires the
same marker. This is only a frontend presentation boundary: no production
policy source or requirement is mounted, and the current authenticated route
is not the future pre-auth whole-app gate.

The marker carries no policy reason or target version. Both retained blocking
presentations therefore request only a supported build; they do not invent an
account/trading security defect or demand an unspecified latest version.

A later authoritative gate still needs exact application/platform/channel
matching, installed integer build input, attributable and fresh policy data,
integer minimum-build comparison and an allowlisted App Store/Play Store
destination. This slice adds no version/package plugin, HTTP request, polling,
persistence, store launch, SDK, dependency or native capability.

Verification on 2026-08-28:

- All 8 I3 tests passed, including the formal `/system/update` route,
  dismissible and blocking states, dedicated action isolation, the retained
  nondismissible dialog, accessibility semantics and both 390 × 844 layouts at
  2× text scale.
- The focused I1-I3, application-navigation and surface-catalog suite passed
  all 42 tests; changed-file formatting and analysis passed with no issues.
- `bin/flutter test` passed all 522 Flutter tests.
- `python3 scripts/check_harness.py` passed, and all 209 Harness mutation tests
  passed.
- Repository-wide format and analysis reported only the two pre-existing user
  changes in `lib/widgets/loop_ui.dart` and
  `test/loop_perp_providers_test.dart`; no I3 file was reported.
- No minimum-version policy/provider, package metadata read, integer build
  comparison, store launch, APK, application bundle, iOS build, simulator,
  interactive run or physical-device validation was performed.

## Maintenance Notice Truth Boundary

On 2026-08-28, decision 0031 removed the fabricated active notice and fixed
`01:00–01:30 UTC` window from the routed I4 system surface. A naked
`/system/maintenance` route now says that no maintenance notice is connected.
It does not claim that maintenance is planned or active, does not disable a
feature and exposes neither recheck nor service-status actions.

An app-level composition may explicitly supply one `LoopMaintenanceNotice`
only while an approved current notice is active. The current marker carries no
window, countdown or affected-service list, so the presentation claims none;
each feature continues to own its current availability state. Recheck and
service status are independent exact callbacks, and generic return-to-Home
navigation cannot authorize either label.

A richer future projection still needs a bounded notice identity/revision,
attributable source, issue/observation time, UTC start/end, expiry, explicit
affected-service vocabulary and an allowlisted status destination. This slice
adds no notice/health request, timer, countdown, polling, automatic retry,
persistence, status URL, SDK, dependency or native capability.

Verification on 2026-08-28:

- All 7 I4 tests passed, covering the formal `/system/maintenance` route,
  unknown and explicit-notice states, generic/dedicated action isolation,
  accessibility semantics, truthful copy and both 390 × 844 layouts at 2×
  text scale with their rendered actions scrolled to and invoked.
- The focused I1-I4, application-navigation and surface-catalog suite passed
  all 49 tests. Changed-file formatting reported 0 changes, and changed-file
  analysis passed with no issues.
- `bin/flutter test` passed all 529 Flutter tests.
- `python3 scripts/check_harness.py` passed, and all 209 Harness mutation tests
  passed.
- Repository-wide formatting reported only the pre-existing user change in
  `lib/widgets/loop_ui.dart`. Repository-wide analysis reported only its
  pre-existing `use_null_aware_elements` info and the pre-existing
  `prefer_initializing_formals` info in
  `test/loop_perp_providers_test.dart`; no I4 file was reported.
- No production maintenance notice/provider, health endpoint, timer, polling,
  status destination, APK, application bundle, iOS build, simulator,
  interactive run, physical-device validation or package artifact was added or
  exercised.

## Feature Availability Truth Boundary

On 2026-08-28, decision 0032 removed the fabricated regional conclusion from
the routed I5 system surface. A naked `/system/region` route now says that no
current eligibility decision is connected. It does not claim that LOOP
observed a location, evaluated account information or region-blocked Spot order
execution, deposits or withdrawals.

An app-level composition may explicitly supply one
`LoopFeatureAvailabilityRestriction` only while an approved current decision
limits some feature access. The marker carries no location, reason, policy
identity or affected-capability list, so the presentation claims none. It also
does not invent a list of Market, Wallet or Chat capabilities that remain
available. Continue and policy navigation are independent exact callbacks;
generic route actions cannot authorize either label.

The backend OpenAPI currently exposes no eligibility-policy route, and the
integration catalog marks `regional_gate` as `PENDING`. A richer future
projection still needs exact subject/application/environment binding, bounded
decision identity/revision, attributable source, observation time, expiry and
a closed capability vocabulary. This slice adds no eligibility request, IP or
device-location lookup, polling, persistence, policy URL, SDK, dependency or
native capability.

Verification on 2026-08-28:

- All 8 I5 tests passed, covering the formal `/system/region` route, unknown
  and explicit-restriction states, independent dedicated actions, generic
  action isolation, removal of every former fabricated claim, semantics and
  both 390 × 844 layouts at 2× text scale with their rendered actions invoked.
- The focused I1-I5, application-navigation and surface-catalog suite passed
  all 57 tests. Changed-file formatting reported 0 changes, and changed-file
  analysis passed with no issues.
- `bin/flutter test` passed all 537 Flutter tests.
- `python3 scripts/check_harness.py` passed, and all 209 Harness mutation tests
  passed.
- Repository-wide formatting reported only the pre-existing user change in
  `lib/widgets/loop_ui.dart`. Repository-wide analysis reported only its
  pre-existing `use_null_aware_elements` info and the pre-existing
  `prefer_initializing_formals` info in
  `test/loop_perp_providers_test.dart`; no I5 file was reported.
- No production eligibility source/provider, policy decision endpoint, IP or
  device-location lookup, policy destination, native build, simulator,
  interactive run, physical-device validation or package artifact was added or
  exercised.

## Permission Prompt Truth Boundary

On 2026-08-28, decision 0033 removed the fabricated default Camera request from
the routed I6 system surface. A naked `/system/permission` route now says that
no permission context is available. It does not claim that access is needed,
requestable, denied or recoverable through settings, and its only action is an
accurate return to LOOP.

An originating feature may explicitly supply one `LoopPermissionPrompt` for
Camera, Notifications or Microphone. Education and settings recovery remain
separate modes. Request, open-settings and not-now are independent exact
callbacks; generic route actions and a callback for the wrong mode cannot
authorize their labels. Camera copy does not start a scanner, Notification copy
does not claim category enablement or delivery, and Microphone copy remains
bounded to Audio Room's deliberate Speak action and muted first join.

This slice adds no platform adapter or direct permission dependency. Camera and
Notifications have no production composition or complete native/provider
configuration. Audio Room keeps its existing Stream-owned microphone capture
path; no second permission manager or call-lifecycle change was introduced. No
system prompt, settings launch/return, OS-state mapping or device behavior is
implemented by I6.

Verification on 2026-08-28:

- All 10 I6 tests passed, covering the formal `/system/permission` route,
  unknown, education and settings-recovery states for Camera, Notifications and
  Microphone, exact mode-specific actions, generic and wrong-mode action
  isolation, removal of the former fabricated claims, accessibility semantics
  and all three 390 × 844 layouts at 2× text scale.
- The focused I1-I6, application-navigation and surface-catalog suite passed
  all 67 tests. Changed-file formatting reported 0 changes, and changed-file
  analysis passed with no issues.
- `bin/flutter test` passed all 547 Flutter tests.
- `python3 scripts/check_harness.py` passed, and all 209 Harness mutation tests
  passed.
- Repository-wide formatting reported only the pre-existing user change in
  `lib/widgets/loop_ui.dart`. Repository-wide analysis reported only its
  pre-existing `use_null_aware_elements` info and the pre-existing
  `prefer_initializing_formals` info in
  `test/loop_perp_providers_test.dart`; no I6 file was reported.
- No platform adapter, permission dependency, system prompt, settings launch,
  OS-state mapping, Firebase or Camera configuration, native build, simulator,
  interactive run, physical-device validation or package artifact was added or
  exercised.

## Global Feedback Truth Boundary

On 2026-08-28, decision 0034 removed the three fabricated result examples from
the routed I7 component surface. A naked `/preview/toast` route now says that no
current feedback context is connected. Opening the route no longer claims that
Notification Preferences were saved, Market prices are delayed or a Spot order
has an unconfirmed status.

An exact owning feature may explicitly supply one presentation-safe
`LoopGlobalFeedback` with success, warning or error semantics, reviewed display
copy and an optional action label. Empty and whitespace-only messages fail
closed at runtime; empty or whitespace-only action labels never create a
button. The action also requires its dedicated callback, Dismiss requires a
separate callback, and generic route actions cannot authorize either behavior.
The renderer announces exact kind and copy as a live region, uses icon plus
text, and stacks controls at large text sizes.

The owning feature remains the state authority and retains raw errors,
identifiers, sensitive values and retry semantics. A confirmed committed
outcome is required before success; timeout and ambiguous writes remain
outcome-neutral under I2. This slice adds no event bus, queue, automatic
timeout, persistence, analytics or root overlay host, and it does not replace
the independently sourced I1 connectivity banner. Existing feature SnackBars
were not migrated.

Verification on 2026-08-28:

- All 11 I7 tests passed, covering the formal `/preview/toast` route, unknown
  and three explicit semantic states, runtime empty/whitespace failure closure,
  exact action pairing, independent Dismiss, generic action isolation,
  live-region and button semantics, removal of every former fabricated claim,
  and both unknown and long active 390 × 844 layouts at 2× text scale with all
  rendered actions invoked.
- The focused I1-I7, application-navigation and surface-catalog suite passed
  all 78 tests. Changed-file formatting reported 0 changes, and changed-file
  analysis passed with no issues.
- `bin/flutter test` passed all 558 Flutter tests.
- `python3 scripts/check_harness.py` passed, and all 209 Harness mutation tests
  passed.
- Repository-wide formatting reported only the pre-existing user change in
  `lib/widgets/loop_ui.dart`. Repository-wide analysis reported only its
  pre-existing `use_null_aware_elements` info and the pre-existing
  `prefer_initializing_formals` info in
  `test/loop_perp_providers_test.dart`; no I7 file was reported.
- No production feedback source, host, event bus, queue, timer, persistence,
  backend route, SDK, dependency, native build, simulator, interactive run,
  physical-device validation or package artifact was added or exercised.

## Loading Presentation Truth Boundary

On 2026-08-28, decision 0035 removed the unconditional list, detail and chart
gallery from the routed I8 component surface. A naked `/preview/loading` route
now says that no loading context is connected. Opening it no longer claims
that content is being requested, exists, will arrive or is “on the way”, and
it emits no false loading announcement.

An exact owning feature may explicitly supply one `LoopLoadingPresentation`
only for its current pending state. It selects exactly one static list, detail
or chart skeleton and one kind-specific live region. List placeholder count is
compile-time non-null and runtime-bounded to 1–8; it controls visual density
only and predicts neither a provider result count nor an outcome. Missing or
invalid presentations fail closed, while decorative geometry remains excluded
from accessibility semantics. Generic system actions cannot make an active
loading presentation interactive.

The owning feature remains responsible for request identity, cancellation,
success, empty, stale, offline and error transitions. This slice deliberately
does not compose I8 into Market, Chat, Profile, Watchlist, Privy, Wallet or
Audio Room and adds no production loading source/controller, shimmer,
animation, timer, polling, event bus, persistence or global overlay host.

Verification on 2026-08-28:

- All 9 I8 tests passed, covering the formal `/preview/loading` route, unknown
  and all three explicit skeleton kinds, compile-time non-null construction,
  runtime list-density bounds, direct-render failure closure, kind-specific
  live-region semantics, decorative exclusion, generic action isolation and
  every 390 × 844 layout at 2× text scale.
- The focused I1-I8, application-navigation and surface-catalog suite passed
  all 87 tests. Changed-file formatting reported 0 changes, and changed-file
  analysis passed with no issues.
- `bin/flutter test` passed all 567 Flutter tests.
- `python3 scripts/check_harness.py` passed, and all 209 Harness mutation tests
  passed.
- Repository-wide formatting reported only the pre-existing user change in
  `lib/widgets/loop_ui.dart`. Repository-wide analysis reported only its
  pre-existing `use_null_aware_elements` info and the pre-existing
  `prefer_initializing_formals` info in
  `test/loop_perp_providers_test.dart`; no I8 file was reported.
- No backend/provider request, SDK, dependency, native build, simulator,
  interactive run, physical-device validation or package artifact was added or
  exercised.

## Public Spot Full Chart

On 2026-08-28, decision 0036 replaced C3's simulated chart with the existing
bounded public Testnet Spot candle projection. C2 now constructs
`/market/chart` from its admitted market's exact `spotIndex`. C3 accepts only
one canonical non-negative index, re-resolves it from the current
`spotMetaAndAssetCtxs` snapshot, and mounts `candleSnapshot` only with that
market's exact provider coin. Missing, repeated, extra, malformed, negative,
overflowing, or stale identities issue zero candle requests and never recover
ETH, another market, Preview fixtures, or Perp data.

The full chart exposes only the reviewed 1H / 4H / 1D / 1W / 1M families and
the same exact String-plus-Decimal OHLCV projection. The old 15M period,
simulated candles, and label-only MA/MACD/RSI controls are removed. Loading uses
one explicit I8 chart presentation; empty, sanitized error, forming-candle,
client-receipt-time, retry and refresh states remain truthful. The surface is
scrollable in portrait and landscape and contains no balance, Buy, Sell,
order, signing, transfer, withdrawal, or execution action.

The focused route, Market, and application-navigation files passed all 50
tests, including exact C2-to-C3 identity, zero-request closure, exact provider
family, all five periods, I8 loading, Preview/execution absence, both
orientations at 200% text, real root routing without the Shell, and direct-link
Close fallback to Market. The full Flutter suite passed all 579 tests, Harness
validation passed, and the Python mutation suite passed all 214 tests. No
native build, simulator, interactive run, physical-device validation or package
artifact was produced.

## Home Portfolio and Net Worth Truth Boundary

On 2026-08-28, decision 0037 separated B1 Home and B2 Net Worth from their
static portfolio and cross-product activity fixtures. Production now treats
portfolio, balance, allocation, net worth, and aggregate activity as
unavailable because no reviewed owner-scoped source exists. A fully verified
Privy session may confirm only whether a valid current-session Embedded
Ethereum wallet identity is available. Wallet identity is not balance evidence
and does not authorize an amount, gain, chart, allocation, alert, approval,
count, activity time, freshness, or all-clear state.

The existing totals, gains, charts, allocation rows, Watchlist movement, unread
counts, alerts, approvals, activity times, and named Preview communication
targets remain available only in exact Development Preview and stay visibly
labelled `开发预览` / `演示数据`. B2 independently applies the boundary when
opened directly rather than relying on navigation through B1. Production keeps
only neutral navigation and provider-availability copy.

This slice adds no portfolio, balance, allocation, or cross-product activity
interface, provider request, backend route, SDK, dependency, refresh, retry,
polling, persistence, or inferred loading/empty/error state. A future real
portfolio flow still requires its own authenticated contract, freshness model,
decimal-safe values, and state policy.

Focused Home, Net Worth, navigation, notification, security, and catalog tests
passed, followed by all 590 Flutter tests. Harness validation passed and all
221 Python mutation tests passed. Analyze passed for the Dart files changed by
this slice. Repository-wide analyze and format checks remained unclaimed
because two pre-existing out-of-scope user edits were intentionally preserved;
neither file is part of this change. No native build, simulator, interactive
run, physical-device validation, or package artifact was produced.

## New Pairs Exact-Preview Truth Boundary

On 2026-08-28, decision 0038 separated C10 New Pairs from the public Spot
discovery source. `spotMetaAndAssetCtxs` does not expose listing time, and the
client receipt instant, first local observation, volume, or canonical flag are
not reinterpreted as evidence that a pair is new. Authenticated and
authenticated-unverified sessions now render one neutral source-unavailable
state, with no inferred empty/loading/offline/region status and no Market or
Candle request.

BTC, ETH, SOL, fixture ages, and the folded-candidate example remain only in the
exact Development Preview session and are labelled `开发预览`, `演示数据`, and
`PREVIEW`. Their cards return to bare `/market` without inventing a Spot index.
The C1 Preview shortcut rail is also exact-session gated, so its still-fixture
C11 destination is no longer reachable from the production Market path. C5,
C6, C9, and C11 remain separately unimplemented.

The five-file focused C10, Market, Preview, navigation, and catalog suite passed
60/60, including verified/unverified truth boundaries, mounted session rotation,
zero-request evidence, exact Preview entry, bare-Market navigation,
portrait/landscape layout, and 200% text. The full Flutter suite passed 598/598;
Harness validation passed and the full Python mutation suite passed 228/228.
Changed-file analysis was clean.
Repository-wide analysis reported only the two pre-existing info-level findings
in the preserved user edits `lib/widgets/loop_ui.dart` and
`test/loop_perp_providers_test.dart`; the repository-wide format check likewise
reported only `loop_ui.dart`. No backend/provider request, SDK, dependency,
native build, simulator, interactive run, physical-device validation, or
package artifact was added or exercised.

## Security Capability and Enrollment Truth Boundary

Decision 0040 closes the A11/H5 providerless security-state gap. A11 now
reports method availability only, exposes no enrollment Switch or Save action,
and explicitly states that Secure Storage and app-PIN verification are not
connected. Continuing advances the catalog journey without claiming a change.

H5 no longer treats Privy capability availability as enrollment or protection
status. It shows no score, ready state, recovery-set conclusion, or providerless
sign-in activity. Wallet MFA and App lock are disabled until exact setup
adapters exist; Devices and recovery destinations continue to use their
existing fail-closed information surfaces. This slice adds no storage package,
PIN, provider request, backend route, or native capability.

Harness validation passed, the Python mutation suite passed 246/246, and the
complete Flutter suite passed 609/609. Repository-wide format and analysis were
clean. No native build, simulator, interactive run, physical-device validation,
or package artifact was produced.

## Dio Trust-Boundary Foundation

Decision 0041 establishes the mobile network construction seam without waiting
for additional backend routes. `LoopDioFactory` now creates separate
exact-origin public and backend profiles. Public Hyperliquid Testnet traffic is
HTTPS-only and cannot carry Authorization; both profiles reject Cookie,
Proxy-Authorization, and `X-Api-Key`, disable every redirect, and use bounded
10/10/15-second connection defaults. Backend Bearer injection remains local to
the exact repository request.

Spot discovery and candle history share one public Testnet client. LOOP
bootstrap and the retained private adapter continue through the distinct
backend client; the unmounted legacy perpetual public adapter keeps an isolated
public lifecycle. Request shapes, 401 refresh, strict response parsing, domain
failures, idempotency, ambiguous-write reconciliation, and product availability
remain with their existing owners.

Focused behavior covers defaults, exact-origin confinement, credentials,
request-local Bearer use, redirects, unsafe origins, and loopback Development.
Harness mutations cover construction bypass, profile drift, retry/logger
insertion, default drift, and hollow tests. Harness validation passed, the
Python mutation suite passed 259/259, the focused network suite passed 39/39,
and the complete Flutter suite passed 616/616. Repository-wide format checked
all 218 Dart files without changes, analysis reported no issues, and
`git diff --check` was clean. This slice adds no route, provider call, backend
call, persistence layer, Secure Storage, native build, simulator, interactive
run, device validation, or package artifact.

## Build-Profile Configuration and Stream Token Loading

Decisions 0044 and 0045 centralize client-visible build configuration and
replace the Chat/Video token placeholder with the implemented LOOP backend
contracts. The toolbar `Loop` target now loads `config/debug.json` as one
reviewable public configuration bundle. Release has only an empty ignored-file
template, and a declared mode mismatch gates Privy, Reown, backend Dio, Stream,
wallet adapter inputs, and future Firebase initialization. This does not alter
the locked Development/Testnet product environment.

The mobile backend layer now owns exact Chat and Video token requests through
the existing authenticated Dio profile. It validates no-store, exact response
shape, matching Stream API key and server-derived user ID, bounded printable
token, and near-one-hour UTC expiry. Strict public error envelopes can spend at
most one 401 refresh and one transparent bootstrap recovery across a maximum
of three token requests. Tokens remain only in the official SDK loader and are
never cached, persisted, decoded, or logged by LOOP.

Focused Flutter behavior tests cover configuration/profile gates, both wire
routes, success/error drift, recovery budgets, shared bootstrap, distinct
Chat/Video products, and account rotation. Live Privy Bearer acceptance,
Stream connect/refresh/reconnect, channels, two-device Chat, and Video remain
provider/physical-device unverified. Audio Room remains unavailable because no
production room locator was added.

Repository-wide format checked all 235 Dart files without changes, analysis
reported no issues, and the complete Flutter suite passed 683/683. Harness
validation passed and its Python mutation suite passed 287/287. The single
requested Android Debug checkpoint compiled successfully with
`config/debug.json`; only the locked Gradle 8.14 / AGP 8.13.2 future-support
warnings were emitted. No Release/iOS build, interactive run, simulator, or
physical-device/provider validation was performed. `flutter clean` removed the
generated APK and build metadata after the evidence was recorded.
## Friend Directory and Group-Creation Frontend Slice

- Added the Chat `+` menu with `创建群组` and `添加好友`, plus the Profile
  `我的好友` entry and dedicated application routes.
- Added a providerless friend-domain seam and deterministic, normally route-lifetime
  controllers for Alias search, pending outgoing friend requests,
  accepted-friend loading, group drafts, single-flight writes, late-result
  isolation, typed viewer-scoped references, and UUID-v4 intent ownership.
- In-flight or outcome-unknown writes retain only their UUID/draft in the
  current principal-bound gateway session, so leaving and reopening a route
  cannot submit a second logical intent. Definitive rejection and success
  release that retention; account/gateway rotation rebuilds it and clears the
  visible search/group text even when both accounts have the same mode. A newly
  mounted route restores visible text from a retained unresolved state.
- Duplicate Alias results fail closed until a public disambiguator exists.
  A friend-request response is valid only as `requestPending`. Ambiguous writes
  freeze without resubmission; definitive rejection can reopen the draft as a
  new intent. Production group success requires a canonical Chat CID. The
  official route then queries Stream online by exact CID and current membership
  before mounting channel UI; it never calls `channel(...).watch()` on an
  unverified string.
- The production friend port stays unavailable with zero social backend
  requests and no channel/member creation call. The shared official CID route
  does make an exact Stream read/watch query when navigated and retains normal
  SDK message/delivery behavior. The labelled Development Preview can exercise
  the complete UI in memory, but a created Preview group has no Stream CID and
  cannot claim provider membership.
- Kept account Alias, future group-scoped Alias, wallet address, Privy/LOOP
  identity, and Stream identity separate through opaque viewer-scoped profile
  references. No social API route was invented while the backend contract is in
  progress.
- Pagination, incoming friend-request acceptance/rejection, exact query
  semantics, and timeout reconciliation remain pending backend-contract work;
  this slice does not hide them behind an invented adapter.

## Backend Social, Server-Created Chat, and Group Alias Integration

On 2026-08-31, decision 0047 superseded the preceding providerless production
assumptions after the reviewed Development API and OpenAPI contract became
available. Production now composes principal-bound authenticated adapters for
Profile, public Privacy, Social Privacy, relationship-aware friend discovery,
accepted-friend and pending-request pagination, request decisions,
server-created group/direct channels, operation reconciliation, group
resolution, and immutable group Alias reservation/search. Preview continues to
use visibly labelled process-local memory adapters.

Every social or Chat command owns one UUIDv4 as both `Idempotency-Key` and
`operation_id`. Lost or malformed success responses retain the exact UUID/body
and query the matching operation; only the exact route-specific operation-not-
found code permits an identical replay. Authentication, rate-limit, transport,
response-proof, parsing and polling failures cannot authorize a second write.
Chat polling uses monotonic wall-clock and attempt bounds, while
`operator_required` freezes the original intent for manual reconciliation.
This retention is deliberately process-local; killed-process recovery remains
unimplemented and is not represented as exactly-once evidence.

The backend remains the only channel allocator. Flutter submits public profile
UUIDs, validates the returned group/direct CID and result set, then queries
Stream online by the exact CID plus current membership before mounting official
channel UI. Direct group-Alias deep links use that same Stream-owned gate, so
the LOOP resolver is not mounted before the current principal proves exact
group membership. Stream continues to own messages, history, pagination, delivery,
read state and realtime events. Group identity presentation accepts only the
current member's exact immutable v1 Alias projection. Message senders, quotes,
mentions, reactions, thread participants, channel previews, headers, avatars
and typing surfaces fail closed to `群成员`/neutral group chrome rather than
falling back to global Stream names, images, custom fields or visible IDs;
known direct channels retain normal Stream identity behavior.

OpenAPI alignment covers exact paths, methods, Bearer and JSON headers,
idempotency headers, request/response shapes, success status codes, endpoint-
specific public errors, canonical UUID/CID forms, the 1024-code-unit cursor
limit, and complete Cc/Cf/Cs/Zl/Zp text rejection. Search preflight folds ASCII
spaces for its local code-point check. NFKC validation remains authoritative to
the backend instead of adding another client normalization dependency or
rewriting a user's submitted display value.

Repository-wide formatting checked 281 Dart files without changes, analysis
reported no issues, and the complete Flutter suite passed 852/852 tests.
Harness validation passed and all 304 Python mutation tests passed. The public
Development `/health/ready` endpoint returned HTTP 200 with database `up`.
One Android Debug build using `config/debug.json` compiled successfully; only
the already-recorded locked Gradle 8.14 / AGP 8.13.2 future-support warnings
and dependency deprecation notes were emitted. `flutter clean` then removed the
APK and generated build metadata.

No Release/iOS build, interactive run, simulator, physical-device flow, Privy
test-account command, or live Stream conversation was exercised. Two-account
request/accept/reject refresh, backend group/direct creation and convergence,
Stream membership/permission behavior, group Alias projection and leave/rejoin
restoration, and restart history remain explicitly unverified until performed
against real Development provider accounts and devices.

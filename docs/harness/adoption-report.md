# Harness Adoption Report

Date: 2026-08-24

## Baseline

`loop-mobile` was already the formal Flutter product repository with a strong UI foundation: 103 catalogued surfaces, six primary destinations, a dark design system, responsive behavior, routing, and preview adapters. It lacked repository-wide agent instructions, executable drift checks, failure memory, final native identity, the verified provider dependency graph, and a compatible Privy native floor. Android used minSdk 24/AGP 9.1/Gradle 9.3.1/Kotlin 2.4.0; iOS used 15.0 and Flutter SwiftPM; both platforms still used `com.dinolabs...` identifiers.

## Adopted surfaces

- `AGENTS.md` is the repository-wide product, architecture, security, and workflow contract.
- `harness.json` is the machine-readable active profile and preserves the six-destination navigation contract.
- `bin/flutter`, `bin/dart`, and `bin/loop-sdk` reject Flutter/Dart version drift.
- `scripts/check_harness.py` and `tests/test_check_harness.py` validate exact pins, lockfiles, native identity/toolchain, records, provider shortcuts, centralized notification ingress, provider-neutral notification routing, secret paths, and Launchpad retention.
- Numbered decisions, failure memory, product constraints, compatibility/integration reports, and the dependency/license register preserve rationale and evidence.

## Rules and checks

- Direct dependencies and both package-manager lockfiles must remain exact and committed.
- Android remains API 28–36 with the Privy library compileSdk override; iOS remains 17.0 with project-local SwiftPM disabled and CocoaPods 1.16.2.
- Android/iOS IDs remain `com.cywd.loop`; iOS tests use `com.cywd.loop.RunnerTests`.
- Home / Market / Launch / Chat / Wallet / Profile remain primary destinations; the checker fails if Launch is removed from the profile.
- Harness source guards reject Privy debug/verbose logging, Stream dev tokens/guests, and premature Firebase initialization.
- Notification guards reserve one future Firebase callback owner, reject competing Chat/Video handlers, and prevent the pure router from importing provider SDKs, logging payloads, accepting payload-selected routes, or carrying Audio Room locators.
- The same guard requires the root application coordinator as the sole router/identity consumer, keeps its production EventSource disabled, binds authenticated context to the real session plus bootstrap Stream identity, and bounds restoration to one in-memory interaction.
- Providerless application guards keep Dio and `/v1/` transport literals out of feature modules and reject known Preview fixture composition from `lib/main.dart`; controllers must depend on ports while fakes remain test/Preview-only.
- Profile guards require its exact domain/controller/UI tests, keep production directly unavailable, enforce the `ProfileValues` and `ProfileResource` field allowlists, confine every `MemoryProfileGateway` reference to its implementation and `lib/main_preview.dart`, and reject ad-hoc notifications or positive Profile-save language.
- Privacy guards require the exact two-field preference contract and its domain/controller/UI tests, keep production directly unavailable, confine `MemoryPrivacyGateway` to its implementation and `lib/main_preview.dart`, reject legacy H3 controls and actionable Copy Trading permission claims, and preserve the distinction between a saved visibility preference and authorization or execution.
- Notification Preferences guards require the exact four-event Boolean contract and its domain/controller/UI tests, keep delivery permanently unavailable and production directly fail-closed, confine `MemoryNotificationPreferencesGateway` to its implementation and `lib/main_preview.dart`, and reject legacy H9 categories, fabricated operating-system state, Quiet hours, or positive delivery/save claims.
- Git-visible `.env`, private-key, service-account, and Firebase Admin credential paths fail validation. `.gitnexus/` and project-local SDK artifacts are ignored.

## Verification

- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter pub get`: passed and regenerated `pubspec.lock` with the exact direct graph.
- `python3 -m py_compile scripts/check_harness.py tests/test_check_harness.py`: passed.
- `python3 scripts/check_harness.py`: passed.
- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: passed, 9 tests.
- `LOOP_FLUTTER_ROOT=/Users/mac/Documents/ChatGPT/LOOP/.tooling/flutter bin/flutter analyze`: passed, no issues.
- Flutter tests passed 55/55. Android Debug and unsigned Release builds, plus iOS Debug and Release no-codesign builds, passed. Exact results and the sqlite3 download note are recorded in `docs/phase-1/frontend-integration-report.md`.

## Assumptions and follow-up

- Flutter 3.47.1 revision `6655482ec06e547f90abf8ae7590466f4415978d`, Xcode 26.6, CocoaPods 1.16.2, Android SDK 36, and Java 17 remain available to CI/developers.
- Provider compile success is not provider runtime proof. Real Privy, Stream, Firebase, push, call, wallet-signing, and private-trading tests remain gated by dashboard/backend/device inputs.
- Add CI execution for the Harness and Flutter tests when the repository's deployment workflow is selected.
- Dependency, toolchain, platform, signing, or release changes may require the
  manual native matrix, but the agent must obtain an explicit user request
  before running it under decision 0015.

## Failure memory

The Harness preserves the migrated native compatibility failures and the later production-truth failures, including preview Chat route leakage and providerless notification fixtures. Each record names detection, prevention, and evidence; executable checks and behavior tests automate their durable controls.

## Effectiveness

Measure the Harness by zero repeated occurrences of the recorded native failures, zero committed privileged secrets, zero fake provider-connected states, exact lockfile/pin agreement, retention of all six primary destinations, consistent format/analyze/test evidence, and Android Debug compilation at requested feature checkpoints. The manual Release/iOS matrix and device validation count only when explicitly requested. Update this report when a rule prevents a regression or creates a false positive.

## Providerless Application-Logic Update

On 2026-08-25, decision 0008 made the next frontend phase explicit: feature
models, controllers, ports, and deterministic tests are completed before new
private HTTP transports. The Harness now rejects Dio imports and `/v1/` route
literals under `lib/features/`, and rejects the existing Preview fixture
implementations when composed from `lib/main.dart`.

`python3 scripts/check_harness.py` passed. `python3 -m unittest discover -s
tests -p 'test_*.py' -v` passed all 29 Harness mutation tests, including the two
new providerless-layer checks. No failure-memory record was added because this
change codifies a planned delivery policy rather than a reproduced failure.

## Notification Coordinator Update

On 2026-08-25, the provider-neutral EventSource/Coordinator seam was connected
at the application root without enabling Firebase or any provider callback. The
Harness requires the disabled production source, actual session/bootstrap
binding, one bounded deferred slot, and both coordinator behavior-test files.

`python3 scripts/check_harness.py` passed. `python3 -m unittest discover -s
tests -p 'test_*.py' -v` passed all 35 Harness tests before the final Flutter and
native verification recorded in the Phase 1 integration report. No
failure-memory record was added because no provider delivery failure was
reproduced.

## Providerless Watchlist Update

On 2026-08-25, decision 0009 fixed the Watchlist application boundary before
its authenticated HTTP adapter. The Harness requires the feature models,
gateway, controller and behavior tests; keeps production directly bound to an
unavailable gateway; confines `MemoryWatchlistGateway` composition to the
explicit Preview root; and rejects volatile market-fact fields in the
Watchlist model.

The providerless slice models only versioned, grouped and ordered asset
references. Successful Preview saves are development evidence, not proof of
account persistence or market availability. `python3 scripts/check_harness.py`
passed, and the complete mutation suite passed 38 tests. Flutter format,
analyze, 35 focused Watchlist tests, 221 full tests, Android Debug, and iOS
Debug no-codesign also passed; exact commands are recorded in the Phase 1
integration report.

## Providerless Profile Presentation Update

On 2026-08-25, decision 0010 fixed the exact Profile presentation boundary
before its authenticated HTTP adapter. The Harness requires the Profile
models, gateway, controller, UI behavior tests and explicit Preview memory
implementation; production must remain directly unavailable. It enforces the
exact values/resource field allowlists, rejects feature-owned references to the
memory fake, and rejects ad-hoc notifications or positive Profile-save UI.

The slice models only nullable Alias, opaque avatar reference, version and
update time. Preview saves demonstrate application behavior rather than
account persistence. `python3 scripts/check_harness.py` passed, and the
complete mutation suite passed 48 tests. Flutter format, analyze, 34 focused
Profile tests, 255 full tests, Android Debug, and iOS Debug no-codesign also
passed; exact commands are recorded in the Phase 1 integration report.

## Providerless Privacy Preferences Update

On 2026-08-25, decision 0011 fixed the exact Privacy preference boundary before
its authenticated HTTP adapter. The Harness requires the Privacy models,
gateway, controller and UI behavior tests; production stays directly bound to
an unavailable gateway, while the memory implementation is confined to the
explicit Preview root. Exact model-field allowlists keep the contract at
`discoverable` and `copyTradeVisibility`; a separate enum guard locks the
reviewed `private`, `followers`, and `public` wire values in both directions.
The UI must not present those preferences as follower, discovery, Copy Trading
authorization or execution enforcement.

The complete Harness mutation suite passed 55 tests. Flutter format covered
144 files, the focused Privacy suite passed 26 tests, the full Flutter suite
passed 281 tests, and analyze, Android Debug and iOS Debug no-codesign passed.
No failure-memory record was added because this is a planned boundary and no
production incident was reproduced. Exact commands and remaining provider
inputs are recorded in the Phase 1 integration report.

## Providerless Notification Preferences Update

On 2026-08-25, decision 0012 fixed the exact Notification Preferences boundary
before its authenticated HTTP adapter. The Harness requires the models,
gateway, controller and UI behavior tests; locks the four reviewed event wire
values and complete Boolean snapshot; keeps `delivery` limited to
`unavailable`; and keeps production directly bound to an unavailable gateway.
The memory implementation is confined to the explicit Preview root.

The UI guard rejects the inherited six-category local state, fabricated
operating-system permission, no-op device-settings action, Quiet hours, and
positive save or delivery claims. The complete Harness mutation suite passed
64 tests. Flutter format covered 151 files, the focused Notification
Preferences suite passed 29 tests, the full Flutter suite passed 310 tests, and
analyze, Android Debug and iOS Debug no-codesign passed. No failure-memory
record was added because this is a planned boundary and no production incident
was reproduced. Exact commands and remaining provider inputs are recorded in
the Phase 1 integration report.

## Principal-Bound Perp Private Reads Update

On 2026-08-25, decision 0013 connected the first backend-mediated private Perp
read slice without enabling trading mutations. The Harness now requires the
Perp gateway, Decimal-safe models, session, strict repository, provider,
controller, behavior tests, decision record, and associated failure memory.
It also parses the Android main manifest and requires exactly one active
`INTERNET` permission so production HTTPS adapters cannot silently work only
in Debug/Profile builds.

The merge review exposed a cross-principal wallet single-flight risk. Harness
fragments now require an explicit expected Privy principal, an owner-keyed SDK
operation, an owner-tagged result, and the controller's independent owner
check. Named behavior evidence proves an old principal's wallet Future cannot
attach to the current principal, while a Python mutation test proves removing
the owner comparison fails the Harness.

`python3 scripts/check_harness.py` passed and the complete Harness mutation
suite passed 66 tests. Flutter format covered 162 files with no changes,
analyze reported no issues, the full Flutter suite passed 358 tests, and
Android Debug/Release plus iOS Debug/Release no-codesign builds passed. Exact
commands, packaged Android permission evidence, and remaining provider/device
gaps are recorded in the Phase 1 integration report.

## Perp Positions Projection Update

On 2026-08-25, decision 0014 mounted D4 through the existing backend-mediated
private gateway without enabling a trading mutation. The Harness now requires
the Positions controller, production/Preview surface, behavior tests, and
decision record. It locks the bounded initial call, cursor-only continuation,
logical single-flight release on expiry, dataset/coverage/order/cursor
validation, Decimal-only live rendering, explicit binding route, D5
fail-closed boundary, and semantic expiry announcement.

The guard parses the executable D4 and D5 selectors so reversing the
Development Preview condition fails validation. Each named behavior test has a
one-to-one domain-specific executable evidence map; marker constants and dummy
`expect(true, isTrue)` bodies fail. Mutation tests independently remove the
empty-page cursor case, repeated-cursor case, cursor-only request, expired
single-flight release, selector boundary, wallet-binding boundary, and live
fixture isolation to prove that these regressions are detected.

The complete Harness mutation suite passed 75 tests. Flutter format covered
165 files with no changes, the focused Positions suite passed 21 tests, the
full Flutter suite passed 379 tests, and analyze, Android Debug/Release, and
iOS Debug/Release no-codesign builds passed. Exact commands and the remaining
provider/device gaps are recorded in the Phase 1 integration report. No failure
memory was added because the stale-operation edge and Harness false-confidence
gaps were caught and fixed during pre-commit review rather than reproduced in a
released production path.

## Debug-Only Routine Verification Update

On 2026-08-25, decision 0015 changed the agent verification policy at the
product owner's request. Routine feature work now stops at format, analyze, and
relevant/full tests. When native compilation evidence is needed, the only
routine gate is one Android Debug build at the completed feature checkpoint.
Android Release, iOS no-codesign, Web release, interactive run, signing,
provider runtime, and physical-device checks are manual-only and require an
explicit user request. Device validation remains user-owned and skipped checks
remain unverified.

`harness.json` now separates the Debug gate from a clearly named
`manual_release_matrix` and records that build artifacts are not retained. The
Harness rejects the legacy automatic `native_release_matrix` key, a non-Debug
routine gate, policy-field drift, or a missing decision record. The complete
Harness mutation suite passed 77 tests, `scripts/check_harness.py` passed, and
both Python files compiled successfully.

`bin/flutter clean` removed the approximately 5.1 GB generated `build/` tree,
`.dart_tool`, Flutter plugin metadata, and native ephemeral configuration. A
follow-up scan found no APK, AAB, IPA, or `Runner.app` in the repository, and
Git remained free of generated-file changes. No Flutter build was run after
cleanup because this update changes only the agent verification policy and the
user explicitly requested that no new package be produced. No failure-memory
record was added because this is a deliberate workflow/cost policy rather than
a runtime or released-product failure.

## Spot-Only Frontend and Offline Communication Preview Update

On 2026-08-25, decisions 0016 and 0017 removed Perp from mounted product
navigation and connected the Market tab to the separate public Hyperliquid
Testnet Spot discovery contract. The Harness now requires both decisions, the
Decimal-safe Spot model/repository/provider, the primary Market and Preview
behavior tests, disabled perpetual and spot-execution policy flags, and the
absence of `/perp` navigation from primary Home, Wallet, Profile, and the
mounted portion of Market.

The explicit `main_preview.dart` root remains the only place that composes the
memory communication gateway. It allows Chat cells, group/direct rooms, and
process-local message composition to be inspected without a Stream connection;
production still requires a backend-derived Stream user ID and short-lived
token. The Preview Market exception is public and identity-free, so it may read
live Testnet Spot facts while authenticated provider work stays offline.

Settings now includes an app-run Reduce Motion preference, a local searchable
Help catalog, and the real Flutter license page. Missing account, legal,
connection, recovery, and support capabilities render unavailable rather than
fabricating records or accepting no-op actions. The complete Flutter suite
passed 394 tests. A stale notification fixture assertion was corrected to
require the Spot price-alert card and reject the removed Perp-risk card.

## SQLite Cold-Build Reliability Update

On 2026-08-25, repeated cold tests and Android Debug builds exposed that the
sqlite3 v3 default hook downloaded a native artifact from GitHub before Dart
compilation. Decision 0018 selects the supported `source: system` hook for the
current exact Stream persistence graph, whose transitional
`sqlite3_flutter_libs` dependency already packages Android libraries. The new
failure-memory record separates hook/download failure from application test
failure, and the Harness rejects source drift.

The complete Harness mutation suite passed 82 tests. A clean Android Debug
build passed in 36.7 seconds without the GitHub native download. APK inspection
confirmed `libsqlite3.so` for arm64-v8a, armeabi-v7a, and x86_64. The 248 MB
Debug APK and all generated `build/` output were then removed. Compilation is
not Stream persistence runtime proof; device database open, offline history,
account rotation, and iOS/Android provider behavior remain unverified.

## Spot Detail Navigation Guard

On 2026-08-26, a widget repro proved that mounted Spot rows were visual cards
without a tap callback. The implementation now routes the accepted row by
exact `spotIndex` into the existing C2 token-detail surface and resolves that
same public snapshot. The Harness requires the row-to-index projection, the
production route parser, the dedicated read-only Spot detail screen, and tests
covering exact navigation, exact public facts, and an absent index that must
not fall back to another asset or Preview data. Private execution remains off.
The complete Flutter suite passed 399 tests, the Harness mutation suite passed
83 tests, and a Pixel 7a Debug checkpoint opened HYPE/USDC Spot #1035 through
the mounted interaction path.

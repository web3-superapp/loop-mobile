# Repository Agent Instructions

Repository phase: `active`.

Build Loop, a Flutter iOS/Android app with five primary destinations—Community, Mining, Launch, Market, and Wallet—using Privy identity/wallets, Reown only for external EVM credential proofs, Stream Chat/Video inside Community, and reviewed backend-mediated V2 capabilities.

These instructions apply to the entire repository. Preserve the approved five-destination V2 shell while migrating the legacy UI catalog through narrow, verified vertical slices. Community is the post-login home; Chat and Profile remain child domains outside bottom navigation. The mounted market slice is the V2 BSC read surface (decision 0057): registry assets addressed by canonical CAIP `assetId`, every figure rendered with its source and observation time, and no execution path. The retained Perp routes and adapters and the retained Hyperliquid Spot adapters are disabled implementation history and must not return to product navigation. Never imply that Privy, Stream, Firebase push, account Watchlist persistence, wallet signing, or private spot execution is connected when its required dashboard, backend, or device inputs are absent.

Read `docs/product/implementation-constraints.md` and `docs/product-decisions.md` before planning or implementing product behavior. The former owns security and truth-source constraints; the latter owns the five primary destinations, the 93-route manifest (`docs/product/routes-manifest.json`, mirrored by `lib/core/navigation/route_manifest.dart`), and current delivery decisions. `lib/core/navigation/surface_catalog.dart` is read-only history and is not a routing source. Material below `reference/legacy-prototype/` is frozen history and must not override current Flutter product decisions.

## Ownership boundaries

- `lib/main.dart` and `lib/app.dart` own composition, application bootstrap, routing, and the five-destination shell
- `lib/core/` owns cross-cutting navigation, theme, signing intent, errors, logging, and security primitives
- `lib/integrations/` owns narrow Privy, Reown, Stream, Firebase, backend, and public Hyperliquid adapters
- `lib/features/` owns product-facing feature modules; Stream types stay inside chat/calls
- `lib/widgets/` owns shared product UI primitives
- `android/` and `ios/` own platform configuration and generated plugin integration
- `reference/legacy-prototype/` is frozen history, not an implementation source
- The Loop backend owns provider secrets, Stream token minting, Hyperliquid agent keys, signing, risk controls, idempotency, and reconciliation

Stream SDK types may stay inside chat and calls to preserve official controllers, pagination, UI, and call state. Expose small facades at feature boundaries; do not wrap the entire SDK or let its types spread into identity, wallet, profile, markets, or trading.

## Locked stack

- Flutter 3.47.1 / Dart 3.13.1
- Android: API 28-36, AGP 8.13.2, Gradle 8.14, Kotlin 2.3.20, Java 17
- iOS 17+, Xcode 26.6, CocoaPods 1.16.2
- Privy Flutter 0.10.1
- Reown AppKit 1.8.4; the lockfile currently resolves Reown Core 1.5.0 and Reown Sign 1.4.0
- Stream Chat/Persistence 10.3.0
- Stream Video 1.4.3; Stream Video Push 1.4.3 is compatibility-approved but not linked in foreground Audio Room v1
- Firebase Core 4.13.0 / Messaging 16.5.0
- Riverpod 3.4.2 / go_router 17.5.0 / Dio 5.11.0
- Decimal 3.2.6 / UUID 4.6.0 / Shared Preferences 2.5.5
- flutter_svg 2.3.0 (prototype SVG sprite, token/network/brand assets; decision 0051)

Dependency managers are Flutter pub with repository `pubspec.lock`, Gradle Wrapper 8.14, and CocoaPods 1.16.2 with repository `ios/Podfile.lock`. Direct dependency constraints stay exact. Change a pin only with official-source research, both native builds, and a numbered decision/report update.

## Registered paths

- Manifests: `pubspec.yaml`, `ios/Podfile`
- Lockfiles: `pubspec.lock`, `ios/Podfile.lock`
- Source roots: `lib`, `test`
- Generated paths: `.metadata`, `.dart_tool`, `.flutter-plugins-dependencies`, `.tooling`, `.gitnexus`, `build`, `android/local.properties`, `ios/Flutter/Generated.xcconfig`, `ios/Flutter/ephemeral`, `ios/Flutter/flutter_export_environment.sh`, `ios/Runner/GeneratedPluginRegistrant.h`, `ios/Runner/GeneratedPluginRegistrant.m`
- Repository profile: `harness.json`
- Client build profiles: `config/debug.json`, `config/release.example.json`
- Toolchain guards: `bin/flutter`, `bin/dart`, and `bin/loop-sdk`
- Architecture decisions: `docs/decisions/`
- Compatibility evidence: `docs/phase-0/compatibility-report.md`
- Integration evidence: `docs/phase-1/frontend-integration-report.md`
- Current identity/Reown initialization evidence: `docs/phase-1/initialization-report.md`
- Product constraints: `docs/product/implementation-constraints.md`
- Open-source register: `docs/open-source-attribution.md`

Never edit generated paths as application source. `.tooling` may hold an ignored project-local Flutter SDK or compatibility artifacts; `.gitnexus` may hold a local code index. Neither may be committed.

## Required workflow

1. Read `README.md`, `harness.json`, relevant decisions, this file, `docs/product/implementation-constraints.md`, and every file being changed.
2. Preserve Community / Mining / Launch / Market / Wallet as the five primary destinations in that order. Community is the post-login home; Chat and Profile stay reachable as child domains, `/home` and `/launchpad` remain compatibility redirects, Market stays Spot-only, and retained Perp history must not be mounted.
3. Keep Development and Hyperliquid Testnet as the only enabled environments. Mainnet, withdrawals, and automated trading remain false until an explicit security decision changes them.
4. Keep provider secrets, Stream server tokens, Firebase service-account credentials, APNs private keys, and Hyperliquid agent private keys out of Flutter, fixtures, logs, and Git.
5. Use Privy as the only identity source. Email OTP, Google OAuth, iOS-only Apple OAuth, and external-EVM SIWE login/link reuse the same cached Privy owner. Reown is only an ephemeral EVM connection and `personal_sign` transport; AppKit auth, Email, Social, Embedded Wallet, SIWE, analytics, Link Mode, Solana, and transaction authority remain disabled. Read client-visible provider values only through `AppConfig` and the matching `--dart-define-from-file` build profile; neither is authority to embed a provider secret. Flutter may request a current Privy access token but never reads, stores, refreshes, or forwards a Privy refresh token.
6. Mint Stream Chat and Video user tokens only in the backend after validating the Privy access token and deriving the Stream user ID server-side. Mobile token loaders remain request-local and non-persisting, validate the exact backend contract, and may spend at most one 401 refresh plus one bounded bootstrap recovery per load.
7. Keep Hyperliquid L1 signing, agent keys, nonce allocation, risk checks, idempotency, relay, and reconciliation in the backend. Mobile may sign only allowlisted user actions after displaying a canonical intent.
8. Preserve one centralized Firebase Messaging foreground/background router. Chat and Video must not register competing global background handlers.
9. Add behavior tests with behavior code. Report exact command results; skipped device or provider tests remain unverified, never passing.
10. Keep preview fixtures visibly labeled `演示数据` or `开发预览`. They must not enter Stream persistence or claim sent, read, presence, typing, ringing, or connected state.
11. Keep `lib/integrations/hyperliquid/**` unmounted. Decision 0057 retired its product mounting; the source stays as history and receives no feature work. No file under `lib/features/`, `lib/app.dart` or `lib/main.dart` may import it. Any account, position, order, cancellation, leverage, transfer, or withdrawal path uses the Loop backend.
12. Generate a new UUID for every outgoing call and idempotent request; never reuse an identifier that has already rung or been submitted.
13. Keep production Stream `token_card.v1` attachments identifier-only and render them through the official message attachment builder. Never persist mutable facts or actions in the message, fetch once per historical card, or mount fixture conversation routes outside explicit Preview mode.
14. During the providerless application-logic phase, keep Dio and `/v1/` route literals out of `lib/features/`. New controllers depend on narrow ports; production defaults stay unavailable, and deterministic fakes enter only tests or `lib/main_preview.dart`.
15. Keep Watchlist models limited to versioned, grouped, ordered canonical CAIP `assetId` references under a whole-resource version CAS. The Watchlist is not a market fact: it never carries a price, a change, freshness, tradability or alert state. Its Preview adapter was retired with decision 0057; the surface is unavailable outside the authenticated V2 adapter.
16. Keep Profile presentation models limited to nullable Alias and opaque `avatar:` reference values with the reviewed version contract. Bio and Privacy are separate resources; production Profile persistence stays unavailable until an authenticated, owner-scoped adapter exists, and UI must never announce a save without an advanced matching resource.
17. Keep Privacy models limited to `discoverable` and the `private` / `followers` / `public` copy-trade visibility preference. This resource never proves discovery, follower membership, portfolio sharing, copy authorization, or execution; production remains unavailable until its authenticated adapter exists.
18. Keep Notification Preferences limited to the contract's exact ten categories under a version CAS. `security.event` is locked on and every write submits `true`, because the server rejects `false` rather than ignoring it. Delivery stays `PUSH_RUNTIME_DEFERRED` regardless of saved values, and the UI must not infer Firebase/provider/device permission or delivery from a stored intent.
19. Keep Home Search and Security Activity source-scoped. Production Search must not expose local Preview assets, groups, or people, and production Security must not infer all-clear, MFA, device, approval, severity, count, or risk facts while its verified sources are absent. Preview filtering and security layouts remain visibly labelled and non-provider-backed.
20. Keep Home Portfolio and Net Worth source-scoped. Production must not render Preview totals, gains, charts, allocations, Watchlist movement, unread counts, alerts, approvals, activity times, or freshness while reviewed owner-scoped portfolio and activity sources are absent. A verified Privy wallet proves current-session wallet identity only, never balance or net worth. Preview fixtures require the exact Preview session and visible truth labels; do not add refresh, retry, loading, empty, or error semantics without a real request source.
21. Keep `new-pairs` and `smart-money` source-scoped. Both are whole-page unavailable with the server's own `reasonCode` until their providers are enabled. Client receipt time, first local observation, volume and canonical status never prove listing time or newness, and no other field may be used to derive a risk conclusion while `riskScreening` is unavailable.
22. Capability availability never proves enrollment, configuration, enforcement, or secure persistence. A11 exposes no protection Switch or Save action without a reviewed setup adapter; H5 exposes no enabled score or recovery conclusion without a dedicated status source. Wallet MFA and App lock remain disabled until their exact setup callbacks exist. Do not add an application-owned Secure Storage or persist a PIN before an account-bound credential-lifecycle decision; raw PIN storage is forbidden. Reown's transitive internal secure-storage dependency does not become a LOOP identity, token, settings, or PIN store.
23. Keep device-local display persistence limited to the non-sensitive `reduceMotion` Boolean and the exact `loop.display.v1.reduce_motion` key through `SharedPreferencesAsync`. It is installation-scoped, not an account resource; never clear the shared store or place identities, Profile/Privacy/Notification resources, wallet data, tokens, PINs, protection state, or provider facts in it. Construction, reads, and writes fail open after one second; read retry must not overwrite unknown stored state, and timed-out writes remain ordered. Failure stays visibly run-local, while a stricter system Reduce Motion setting always wins.
24. Construct production Dio clients only through `LoopDioFactory` and keep public Hyperliquid Testnet reads separate from authenticated LOOP backend requests. Both profiles stay exact-origin with redirects disabled and no automatic retry or logging; the public client rejects Authorization, both reject Cookie, Proxy-Authorization, and `X-Api-Key`, while backend Bearer values remain request-local and are forbidden in Dio defaults. A credential-free profile grants no provider permission: the retained Hyperliquid clients stay Testnet `/info`-only, never call `/exchange`, and are no longer constructed by any product path.
25. Keep every S5 chain, market and wallet figure sourced. A market value is the fixed `{value, source, fetchedAt, ttlSeconds, quality, reasonCode}` object and is rendered with its source and observation time; `stale`, `derived` and `proxied` carry a visible marker; an `unavailable` value renders the server's `reasonCode`, never `0` and never an em dash. A balance row's discriminated union keeps "the chain read failed" apart from "this wallet holds none of it". The five balance meanings are shown separately and never derived from one another, the gas reserve comes from `gasReservePolicy`, and net worth carries `isSpendable: false` so it can never be presented as a spendable total. Only the canonical CAIP `assetId` addresses an asset and only the opaque `walletId` addresses a wallet; the Swap entry point is gated on `capability.swappable` alone. Amounts and prices are `Decimal`; `double` appears only after normalisation into chart pixel space.
26. Routine feature work uses format, analyze, and relevant/full tests. When native compilation evidence is needed, run Android Debug once at the feature checkpoint with `bin/flutter build apk --debug`; do not build after every intermediate edit.
27. Release, iOS no-codesign, Web release, interactive `flutter run`, signing, provider, and physical-device checks are manual-only. Run them only when the user explicitly requests them or a later decision supersedes this policy. The user owns physical-device validation; skipped checks remain unverified.
28. `build/` and native application bundles are generated evidence, not retained deliverables. Remove them with `bin/flutter clean` when cleanup is requested; never commit them.

## Commands

The routine application command contract is:

```sh
bin/flutter pub get
bin/dart format --output=none --set-exit-if-changed lib test
bin/flutter analyze
bin/flutter test
```

At a feature checkpoint, use only this native compilation gate when needed:

```sh
bin/flutter build apk --debug
```

The following matrix is manual-only and must not run without an explicit user
request:

```sh
bin/flutter build apk --release
bin/flutter build ios --debug --no-codesign
bin/flutter build ios --release --no-codesign
```

Interactive `bin/flutter run` and physical-device validation are also
user-requested activities, not routine agent verification.

Harness validation is:

```sh
python3 scripts/check_harness.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

## Platform gates

- Android `minSdk` is 28 because the published Privy 0.10.1 plugin declares 28 even though its installation page says 27. Do not lower it without a fixed upstream artifact and a clean native matrix.
- Android stays on compile/target SDK 36, AGP 8.13.2, Gradle 8.14, Kotlin 2.3.20, and Java 17. Flutter warns that AGP 8 will be retired; do not migrate to AGP 9 until every plugin is proven compatible.
- iOS deployment target is 17.0 in every build configuration. Swift Package Manager is disabled per project and CocoaPods 1.16.2 owns native plugin resolution. Never change the user's global Flutter setting.
- The application ID is `com.cywd.loop` on Android and iOS; the iOS test bundle is `com.cywd.loop.RunnerTests`. Change them only with provider dashboard updates, both native builds, and a numbered decision.
- Push, VoIP, CallKit, camera, microphone, associated domains, and signing capabilities are not inferred or fabricated. Configure them only with final provider projects.
- Android Release remains unsigned until approved store credentials are injected by release automation; never fall back to the development debug key.
- Privy 0.10.1 requires both App ID and Mobile App Client ID. Initialize through `Privy.init`, keep `PrivyLogLevel.none`, and treat `AuthenticatedUnverified` as a restricted offline session rather than logout.
- Privy OAuth uses `com.cywd.loop.privy`, Reown wallet return uses `com.cywd.loop.wallet`, and the two native callback owners remain disjoint. Apple OAuth is iOS-only and requires the Sign in with Apple entitlement. Reown accepts only canonical `eip155` accounts and `personal_sign`; every external address remains a replaceable Privy sign-in credential, never a `PrivyWalletSummary`, `WalletSigningGateway`, balance source, or LOOP trading wallet.
- A newly accepted verified Privy login may start one principal-bound LOOP bootstrap when a safe backend origin exists. It is eager but non-blocking: backend absence or failure cannot reject or roll back login, and linking another credential to the same principal does not create a second identity.
- The Reown native graph passed Android/iOS Debug and Release no-codesign compilation on 2026-08-29, as recorded in `docs/phase-1/initialization-report.md`. Email/Google/Apple/SIWE provider behavior, wallet-app return, signing, and backend bootstrap remain unverified on physical devices; compilation is not provider acceptance.
- A Stream API key alone is not an authenticated connection. Do not construct Video or connect Chat until a validated backend bootstrap returns the server-derived Stream user ID and the strict backend token loader succeeds. The Chat/Video token clients are implemented, but live provider/device behavior remains unverified and Audio Room still has no production room locator. Firebase stays uninitialized until real mobile configs and exact push-provider names exist.
- Keep the top-level `hooks.user_defines.sqlite3.source: system` manifest override while the pinned Stream persistence graph still packages `libsqlite3` on Android. It prevents cold Debug builds and tests from depending on a GitHub native-artifact download. Revisit it only with a dependency decision, clean Debug build, and runtime database evidence on supported Android/iOS devices.
- The current `notification.v1` router is a provider-neutral classifier only. It accepts exact LOOP-owned String envelopes, binds interactions to the backend-derived Stream user ID, and produces only official Chat CID, Audio Room lobby, notification-center, or price-alert token intents. The price-alert kind (decision 0057) validates its `asset_id` against the canonical CAIP pattern before it can become a location. The router is not a raw Firebase/Stream payload parser and does not prove delivery.
- Foreground/background notification delivery never navigates. Only an explicit interaction may resolve a fixed intent; Preview, signed-out, authenticated-unverified, wrong-recipient, expired, unknown, or provider-shaped data fails closed.
- `lib/integrations/notifications/firebase_notification_ingress.dart` is the only future location allowed to own Firebase global callbacks. Do not create it or initialize Firebase until real mobile configs, exact provider names, captured payload fixtures, and the ordinary-push/VoIP routing decision exist.
- `lib/app/notifications/loop_notification_coordinator.dart` is the only application consumer of the normalized router. It derives authenticated notification context from the real LOOP session and verified bootstrap identity, retains at most one interaction for a bounded restore window, and revalidates before typed root navigation. Feature modules must not construct a matching Stream user, router, or competing coordinator directly.
- Production `loopNotificationEventSourceProvider` remains `DisabledLoopNotificationEventSource`: no initial interaction, event stream, Firebase initialization, or provider request. Replace it only after the real mobile configs, exact provider names, captured payload fixtures, and ordinary-push/VoIP routing decision are reviewed together.

## Decisions and failure memory

Record changes to runtime, dependency manager, primary navigation, architecture, persistence, security boundaries, or verification strategy under `docs/decisions/NNNN-short-title.md`. Create `docs/failures/short-title.md` only for an evidenced high-risk or recurring failure, retaining `Summary`, `Root Cause`, `Detection`, `Prevention`, and `Evidence` sections.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **loop-mobile** (22882 symbols, 83329 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/loop-mobile/context` | Codebase overview, check index freshness |
| `gitnexus://repo/loop-mobile/clusters` | All functional areas |
| `gitnexus://repo/loop-mobile/processes` | All execution flows |
| `gitnexus://repo/loop-mobile/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

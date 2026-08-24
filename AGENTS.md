# Repository Agent Instructions

Repository phase: `active`.

Build Loop, a Flutter iOS/Android app with six primary destinations—Home, Market, Launch, Chat, Wallet, and Profile—using Privy identity/wallets, Stream Chat/Video, and backend-mediated Hyperliquid Testnet trading.

These instructions apply to the entire repository. Preserve the accepted UI catalog and six-destination shell while replacing preview-only provider seams through narrow, verified vertical slices. Never imply that Privy, Stream, Firebase push, wallet signing, or private trading is connected when its required dashboard, backend, or device inputs are absent.

Read `docs/product/implementation-constraints.md` and `docs/product-decisions.md` before planning or implementing product behavior. The former owns security and truth-source constraints; the latter owns the current 103-surface catalog, six primary destinations, and delivery decisions. Material below `reference/legacy-prototype/` is frozen history and must not override current Flutter product decisions.

## Ownership boundaries

- `lib/main.dart` and `lib/app.dart` own composition, application bootstrap, routing, and the six-destination shell
- `lib/core/` owns cross-cutting navigation, theme, signing intent, errors, logging, and security primitives
- `lib/integrations/` owns narrow Privy, Stream, Firebase, backend, and public Hyperliquid adapters
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
- Stream Chat/Persistence 10.3.0
- Stream Video 1.4.3; Stream Video Push 1.4.3 is compatibility-approved but not linked in foreground Audio Room v1
- Firebase Core 4.13.0 / Messaging 16.5.0
- Riverpod 3.4.2 / go_router 17.5.0 / Dio 5.11.0
- Decimal 3.2.6 / UUID 4.6.0

Dependency managers are Flutter pub with repository `pubspec.lock`, Gradle Wrapper 8.14, and CocoaPods 1.16.2 with repository `ios/Podfile.lock`. Direct dependency constraints stay exact. Change a pin only with official-source research, both native builds, and a numbered decision/report update.

## Registered paths

- Manifests: `pubspec.yaml`, `ios/Podfile`
- Lockfiles: `pubspec.lock`, `ios/Podfile.lock`
- Source roots: `lib`, `test`
- Generated paths: `.metadata`, `.dart_tool`, `.flutter-plugins-dependencies`, `.tooling`, `.gitnexus`, `build`, `android/local.properties`, `ios/Flutter/Generated.xcconfig`, `ios/Flutter/ephemeral`, `ios/Flutter/flutter_export_environment.sh`, `ios/Runner/GeneratedPluginRegistrant.h`, `ios/Runner/GeneratedPluginRegistrant.m`
- Repository profile: `harness.json`
- Toolchain guards: `bin/flutter`, `bin/dart`, and `bin/loop-sdk`
- Architecture decisions: `docs/decisions/`
- Compatibility evidence: `docs/phase-0/compatibility-report.md`
- Integration evidence: `docs/phase-1/frontend-integration-report.md`
- Product constraints: `docs/product/implementation-constraints.md`
- Open-source register: `docs/open-source-attribution.md`

Never edit generated paths as application source. `.tooling` may hold an ignored project-local Flutter SDK or compatibility artifacts; `.gitnexus` may hold a local code index. Neither may be committed.

## Required workflow

1. Read `README.md`, `harness.json`, relevant decisions, this file, `docs/product/implementation-constraints.md`, and every file being changed.
2. Preserve Home / Market / Launch / Chat / Wallet / Profile as the six primary destinations. Perp stays within Market; Launchpad remains a first-class destination.
3. Keep Development and Hyperliquid Testnet as the only enabled environments. Mainnet, withdrawals, and automated trading remain false until an explicit security decision changes them.
4. Keep provider secrets, Stream server tokens, Firebase service-account credentials, APNs private keys, and Hyperliquid agent private keys out of Flutter, fixtures, logs, and Git.
5. Use Privy as the identity source. Flutter may request a current access token from the SDK but never reads, stores, refreshes, or forwards a Privy refresh token.
6. Mint Stream Chat and Video user tokens only in the backend after validating the Privy access token and deriving the Stream user ID server-side.
7. Keep Hyperliquid L1 signing, agent keys, nonce allocation, risk checks, idempotency, relay, and reconciliation in the backend. Mobile may sign only allowlisted user actions after displaying a canonical intent.
8. Preserve one centralized Firebase Messaging foreground/background router. Chat and Video must not register competing global background handlers.
9. Add behavior tests with behavior code. Report exact command results; skipped device or provider tests remain unverified, never passing.
10. Keep preview fixtures visibly labeled `演示数据` or `开发预览`. They must not enter Stream persistence or claim sent, read, presence, typing, ringing, or connected state.
11. Keep the direct Hyperliquid mobile adapter public and Testnet read-only. Any account, position, order, cancellation, leverage, transfer, or withdrawal path uses the Loop backend.
12. Generate a new UUID for every outgoing call and idempotent request; never reuse an identifier that has already rung or been submitted.

## Commands

The application command contract is:

```sh
bin/flutter pub get
bin/dart format --output=none --set-exit-if-changed lib test
bin/flutter analyze
bin/flutter test
bin/flutter build apk --debug
bin/flutter run
```

The native release matrix is:

```sh
bin/flutter build apk --release
bin/flutter build ios --debug --no-codesign
bin/flutter build ios --release --no-codesign
```

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
- A Stream API key alone is not an authenticated connection. Do not construct Video or connect Chat until a validated backend bootstrap returns the server-derived Stream user ID and token providers. Firebase stays uninitialized until real mobile configs and exact push-provider names exist.

## Decisions and failure memory

Record changes to runtime, dependency manager, primary navigation, architecture, persistence, security boundaries, or verification strategy under `docs/decisions/NNNN-short-title.md`. Create `docs/failures/short-title.md` only for an evidenced high-risk or recurring failure, retaining `Summary`, `Root Cause`, `Detection`, `Prevention`, and `Evidence` sections.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **loop-mobile** (19844 symbols, 87509 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

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

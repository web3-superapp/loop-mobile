# LOOP UI preview validation — 2026-10-02

Base: integration/v2 ebf5f4967603ef5afb7930438504de5619438569. Branch: codex/loop-v2-ui-edits-20261002.

## Delivered

Six peer destinations: 社区、聊天、挖矿、Launch、行情、钱包. All original 93 routes retained and native Chat added as route 94. Chat keeps provider-backed request counts and exact conversation identity, with friends and search entry points. Anonymous-mode controls retired; explicit Privacy Save normalizes legacy anonymousMode=false under existing CAS while preserving other preferences. Public profiles offer the existing V2 friend-request flow.

Market adopts stacked price/change, functional local asset filters and direct community discussion. The offline preview entry supplies eight market assets and matching charts, mining power/assets/rankings, Launch project/detail data, wallet balance/activity and referral data. Global preview label remains on every preview route. No transaction, receive address, reward claim or provider authorization is fabricated.

## Evidence

- `dart analyze lib`: no issues.
- Navigation/shell/manifest/application suite: 31 passed.
- Chat request, exact identity and primary navigation suite: 18 passed; after final padding, primary navigation 2 passed again.
- Market regression: 205 distinct tests passed across the scoped runs.
- Social/profile/privacy regression: 134 passed, plus one 360-pixel Add Friend check.
- Final integration run: 39 passed (preview catalog 10, market reference 5, market density 22, primary navigation 2), including ground probes.
- Full repository harness passed. Python harness tests: 402 passed.
- GitNexus impact and detect-changes reviewed; no high/critical result. Unresolved fixture symbols were checked by source references.
- Flutter WASM preview compiled and served on 127.0.0.1:8766. Browser inspected at 390×844: six tabs, chat margins, mining values, Launch listing, wallet balance, market list and candle detail. Widget tests additionally cover 360 widths.
- Independent review found an unresolvable market community fixture and duplicate mining rank identities. Both fixed with regression tests.

## Remaining boundaries

This is a local UI preview, not native-device or production-provider acceptance. Backend legacy anonymous projections and real friendship acceptance/Stream admission still need integration verification. Preview transaction actions remain disabled. Smart-money/new-pairs, real receive addresses, staking and reward claims remain unavailable. WASM is used because the inherited cache hash contains a 64-bit integer unsupported by Dart-to-JavaScript. No hash algorithm change was made.

Browser refresh returns to login; choose 进入开发预览 to reload the memory catalog. Development data resets between sessions.

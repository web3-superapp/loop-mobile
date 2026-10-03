# Community / Chat and product-copy cleanup

## Changes

- Five bottom destinations: Community, Mining, Launch, Market, Wallet. Community and the existing Chat inbox share an in-page segment in the existing title area. `/chat` keeps bottom navigation and the minimized voice banner clears it correctly. Friends and conversation detail routes retain existing identity, membership and Stream controllers.
- Removed the global developer banner and repetitive community/chain/profile/friend notices and headings. Their compatibility widgets return zero size. The explicit Preview entry and isolated providers remain.
- Chat removes repeated inbox headings, technical authorization prose, fixture timestamps and simulated member metadata. Private-chat display also removes the route ribbon, connection subtitle, redundant security explanation and local-send toast; its composer reads “输入消息”. Missing/invalid conversation identities still fail closed. Operator-required DM state still offers no unsafe retry.
- Community removes the extra recommendation explanation and unavailable-activity caption. Its bell retains distinct requests, search and live-room shortcuts. Market removes the generic data-policy notice and unavailable smart-money promotion; watchlist management remains and asset discovery uses the concise “浏览代币” action.
- Login and account, security, mining, system and wallet pages use concise unavailable/recovery wording. Send/Swap implementation-explanation notices are removed while canonical signing facts, acknowledgement, expiry and confirmation gates remain.
- Updated the current five-tab manifest/docs/harness contracts. Kept all 94 routes. Added magic-verified AppleDouble handling for scanners on the exFAT workspace; arbitrary dot-prefixed source and malformed binary source are not silently ignored.

## Verification

- `bin/dart analyze lib test`: passed with no issues after the equivalent-copy and metadata-scanner edits.
- Flutter targeted navigation/identity suite: 42 passed (five tabs, 360/390 layouts, friends/back, 94-route coverage, preview catalog and exact conversation identity).
- Flutter combined chat/auth/community suite: 132 passed, including production Stream unavailability and request identity behavior.
- Flutter final identity pages: 18 passed; unavailable wallet creation stays blocked with one actionable message.
- Latest targeted Chat navigation checks include `/chat` voice-banner bottom-bar clearance; passed.
- Profile, chain, watchlist and density tests were updated only for intentionally removed labels. The remaining market expansion assertions are handled in the chart review report.
- Four Python regressions verify AppleDouble magic filtering, real dot-prefixed source retention, malformed source errors and record inventory handling.
- Full harness passed; all 406 Python tests passed. Earlier runs identified stale presentation assertions and AppleDouble inventory errors; these were repaired rather than suppressed generically.
- `git diff --check`: passed.

`flutter analyze` hit a toolchain LSP initialization JSON truncation at the Chinese workspace URI; direct `dart analyze` completed successfully. This is UI and automated-test evidence, not physical-device/provider acceptance. No production release or transaction capability was enabled. This audit covered the shared presentation seams and the concrete flows above; it does not claim all 94 flows were redesigned.

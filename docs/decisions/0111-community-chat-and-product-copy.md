# 0111 · Community and Chat share a tab; concise product copy

Date: 2026-10-02

## Status

Accepted by the user's latest UI instruction; supersedes 0109 navigation and repeated Preview-label presentation requirements.

## Context

The user requested one Community/Chat tab and app-wide removal of redundant developer-oriented presentation.

## Decision

The five bottom destinations are Community, Mining, Launch, Market and Wallet. `/community` and `/chat` remain mounted in the same shell; both select Community and expose one Community / Chat segment. Existing private chats were inspected first: the Preview inbox uses exact registered conversation identities; production uses the official Stream inbox, exact CID/current membership checks and DirectMessageScreen. These are reused, not replaced. Friends, requests, group creation, conversation filters, deep links and back navigation remain available.

Remove the global development banner and repeated shared community, chain, profile and friends preview notices/kickers. The explicit Preview entry remains isolated. Simplify the inbox's repeated headings and provider-oriented connection errors. Private-message errors retain actionable recovery and unresolved-operation holds. Security and signing confirmations, transaction state, source/time/quality facts and provider authorization gates remain unchanged.

The shared segment replaces the existing page title rather than adding a second header. Previously a user switched bottom destinations to reach Chat; now Community / Chat switches in place, and opening a friend or exact conversation uses the existing route directly. The Community bell retains distinct requests, search and live-room shortcuts. Market retains watchlist management and makes the discovery action a concise “浏览代币”; unavailable smart-money promotion and the general data-policy card are removed. Community removes recommendation-rule and unavailable-activity paragraphs while preserving sourced counts. Login exposes concise unavailable messages instead of SDK configuration names. Send and Swap retain canonical confirmation facts but remove implementation-explanation cards. Preview inbox metadata hides simulated member labels and preview timestamps without inventing presence.

The user's follow-up makes candle data the dominant surface: remove the chart card and its nested padding, use a nearly full-width plot, consolidate indicator readouts and retain a compact unit/source disclosure. This changes presentation density, not market data or execution authority. Horizontal pan/zoom and current real-history bounds remain.

## Consequences

### Audit scope

Reviewed the shared presentation seams used by account, chain, chat, community, launch, market, mining, notifications, profile, security, social, system and wallet. The shared community notice has 32 direct callers and chain notice 45; suppressing those zero-size widgets removes repeated cards across the feature pages without changing feature state. Profile and friend notices use the same zero-size result. Explicit preview login, data isolation, unavailable capability states and irreversible-action disclosures remain. Retained unmounted Perp history is outside product navigation and receives no changes.

No new chat transport, identity mapping, backend call, token storage, signing path or capability is introduced. This is a UI cleanup, not proof of provider/device acceptance. Existing 94 routes are retained; Chat changes its tab flag only.

## Impact and verification

GitNexus index was two commits behind and available via cached CLI. LoopShell, LoopApp, inboxes, DirectMessageScreen and manifest impacts were LOW. CommunityPreviewNotice and LoopChainPreviewNotice were CRITICAL because of their many presentation callers; communityPreviewKicker was HIGH. The broad effect was disclosed before the shared cleanup. Targeted tests cover five-tab order, 360/390 layout, Chat/friends/back behavior, unchanged manifest route coverage, and exact conversation identities. Full analyzer/harness and additional regression results are reported with the delivery rather than inferred from source edits.

# Perp Semantics Survived in the Chat Preview

## Summary

After LOOP became Spot-only, the E9 Chat asset fixture still rendered a long
position with entry, size, return and a fake `Save setup` action. A separate
fixture message also claimed that an address and transfer alert had been saved.

## Root Cause

The original Spot-only guard covered primary route mounting and Market, Home,
Wallet and Profile entry points, but treated Preview conversation content as
cosmetic. E9 therefore escaped the product-semantic boundary even though the
normal Development Preview made it directly reachable.

## Detection

Product review found `ETH position snapshot`, `LONG`, `Entry`, `Return when
shared`, `Save setup`, and `Setup saved for review` in the Chat component and
page. A source audit then found the unsupported saved-address and active-alert
claim plus the catalog description `shared trade snapshot`.

## Prevention

The E9 component and page now have an executable Spot-only Harness contract.
Visible fixture facts require Preview attribution and an explicit fact
allowlist, the component tree is closed over reviewed non-interactive widgets,
and normalized fingerprints close the card, page, fixture content and evidence
source against cross-file substitution. The only enabled navigation is exactly
`/market`, and Watch must remain disabled. Mutation tests restore the old and
alternate position language, fake save and localized or imported alerts, no-op
or drifting navigation, direct and helper-hidden interactions, missing Preview
labels, enabled Watch, skipped or shadowed tests, and unreachable evidence to
prove the guard detects each regression.

## Evidence

`test/chat_spot_snapshot_test.dart` verifies the rendered language, disabled
control, exact navigation and 390-point 2x Dynamic Type layout. The existing
`test/chat_preview_route_guard_test.dart` continues to prove that production
cannot mount `/preview/asset-message`.

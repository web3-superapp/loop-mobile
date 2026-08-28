# Providerless Wallet Controls Without Effects

## Summary

A Wallet audit found controls that looked functional while changing no
observable product state, plus a Bridge progress deep link that supplied its
own route facts. A later F3 audit found the same failure in Send: its enabled
asset search accepted text but never filtered ETH, USDC, SOL, or the unavailable
ARB example. The pages were labelled Preview, but these interactions could still
mislead users and future agents about what application logic existed.

## Root Cause

Prototype controls retained local selection booleans without deriving the
rendered content from them. The revocation button used an enabled snackbar as
an unavailable placeholder, and Bridge route facts lived as literals on both
screens instead of travelling through typed route state.

F3 also duplicated wallet asset fixtures directly inside its rows and mounted a
controllerless TextField. The visible results therefore had neither one
canonical source nor any dependency on the entered query.

## Detection

`test/wallet_providerless_controls_test.dart` proves that History and Networks
change only their matching Preview rows, that revocation is disabled, and that
Transaction Result never claims submission. `test/app_navigation_test.dart`
proves that Bridge progress requires typed state. Model tests bind History and
Bridge variants to their closed Preview fixtures.

`scripts/check_harness.py` also validates these source and route boundaries;
mutation tests in `tests/test_check_harness.py` remove each guard and must fail.
`test/send_asset_search_test.dart` proves that normalized local search changes
only labelled Preview rows, Clear restores canonical order, a filtered
selection carries the exact asset and network, ARB remains unavailable, and a
no-match state does not claim that a provider returned an empty wallet.

## Prevention

Every mounted providerless control must either derive a visible, accurately
labelled local state or be disabled. Continuation screens that display wallet,
route, quote, intent, or transaction facts require typed process-local origin
state and fail closed when that state is absent. An enabled snackbar is not a
replacement for an unavailable capability.

A providerless search must filter one bounded fixture source, label every
result as Preview evidence, and describe no-match as a local filter result. It
must never reinterpret a local no-match as a zero balance, empty wallet, or
provider response. Any selected route state must come from the matching object,
not from a repeated default asset.

## Evidence

- `docs/decisions/0023-close-providerless-wallet-controls.md`
- `lib/features/wallet/bridge_preview_snapshot.dart`
- `lib/features/wallet/wallet_preview_activity.dart`
- `lib/features/wallet/wallet_preview_asset.dart`
- `lib/features/wallet/send_screens.dart`
- `test/wallet_providerless_controls_test.dart`
- `test/send_asset_search_test.dart`
- `test/app_navigation_test.dart`
- `tests/test_check_harness.py`

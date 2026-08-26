# Swap Preview Draft Divergence

## Summary

Changing the Swap input could leave the receive amount, quote details, and
Signing Review describing the original `0.50 ETH` fixture. The Reset action
changed only a Boolean and did not restore the edited text controller.

## Root Cause

Quote validity, user input, output facts, route facts, and review facts had
separate sources of truth. A `quoteCurrent` Boolean represented validity while
three UI locations independently hard-coded amounts. Nothing bound those
literals to the controller or invalidated all derived projections together.

## Detection

`test/swap_preview_flow_test.dart` edits the amount, proves that every derived
fact and route entry disappears, proves that manually typing the old value does
not resurrect a snapshot, and verifies atomic restore plus review
single-flight. `test/swap_preview_snapshot_test.dart` proves that every review
field comes from one immutable snapshot. Navigation and signing-boundary tests
cover wrong route state and zero wallet handoff.

## Prevention

Use nullable `SwapPreviewSnapshot` as the only quote-validity state. Route and
review consumers require that exact typed object. Any input edit sets it to
null; one state transition restores both controller and snapshot. Harness
mutation guards reject the old Boolean, direct Swap intent construction in the
screen, untyped route state, missing invalidation/reset assignments, literals
outside the snapshot, removed review single-flight, or canonical/signing
capability in providerless Wallet code.

## Evidence

- `docs/decisions/0022-bind-wallet-local-drafts-to-exact-snapshots.md`
- `lib/features/wallet/swap_preview_snapshot.dart`
- `lib/features/wallet/trade_screens.dart`
- `test/swap_preview_flow_test.dart`
- `test/swap_preview_snapshot_test.dart`
- `test/app_navigation_test.dart`
- `test/signing_review_boundary_test.dart`

# Providerless Notification Fixtures in Production

## Summary

The ordinary `/notifications` route displayed hard-coded position-risk, price,
mention, timestamp, and unread-style content during an authenticated production
session. A no-op `Mark all read` control further implied provider-backed state
that did not exist.

## Root Cause

The notification surface was inherited from the broad prototype catalog and
was not placed behind the same explicit Preview boundary used by communication
fixtures. Routing protection alone could not distinguish those local cards
from a future Firebase/Stream notification inbox.

## Detection

A pre-integration push audit opened the route from the production shell and
traced every card and action to constants in `home_screens.dart`. Repository
search confirmed there was no Firebase initialization, message callback,
provider token registration, notification repository, read-state owner, or
backend source capable of producing those values.

## Prevention

- Production renders one honest provider-unavailable state until a verified
  centralized ingress and provider-backed inbox exist.
- Local notification examples render only when `LoopSessionState.isPreview` is
  true and the page continuously labels them `开发预览` and `演示数据`.
- Do not expose read, unread, badge, delivery, timestamp, account-risk, price,
  or mention claims without the provider that owns the fact.
- Keep widget tests for both production and Preview states, and keep the
  centralized notification contract in the Harness required-file set.

## Evidence

- `test/notifications_screen_test.dart` proves that a production session
  contains no fixture activity or fake read action and that explicit Preview
  remains visibly labelled.
- `lib/features/home/home_screens.dart` now selects the notification state from
  the explicit session mode before constructing fixture cards.
- `scripts/check_harness.py` rejects competing Firebase callbacks and
  provider/arbitrary-route imports in the normalized notification router.

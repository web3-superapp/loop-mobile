# Production Chat Preview Route Leak

## Summary

Authenticated production navigation could open legacy group, direct-message,
member, request, search, and token/facts pages backed by local fixtures. The
pages did not write to Stream, but their named messages and facts could be
mistaken for production provider state.

## Root Cause

The application correctly separated its production and Preview communication
gateways, but several catalog routes mounted legacy widgets directly. The
fixture widgets therefore bypassed the gateway boundary whenever their route
was opened by a deep link or catalog entry.

## Detection

A route audit compared every chat and preview `GoRoute` against the production
Stream inbox/CID path and the explicit Preview gateway. Widget tests then
opened all affected paths under an authenticated production session and found
that fixture labels such as the legacy group, user, and token name must never be
present.

## Prevention

- Wrap every legacy conversation and token/facts preview route in
  `ChatPreviewRouteGuard`.
- Mount the guarded child only when `communicationGatewayProvider` is explicitly
  in Preview mode; otherwise render a truthful unavailable state.
- Keep a Harness route-list check and production widget test so a future route
  cannot silently bypass the guard.
- Move a surface to production only by replacing its fixture source with the
  authorized official Stream controller/UI path and adding behavior evidence.

## Evidence

- `test/chat_preview_route_guard_test.dart` opens all guarded routes in
  production and verifies that fixture conversation/token content is absent.
- `scripts/check_harness.py` requires every registered preview-only route to be
  wrapped by `ChatPreviewRouteGuard`.
- The explicit Preview gateway test proves that the same child remains
  available for offline product review without weakening production truth.

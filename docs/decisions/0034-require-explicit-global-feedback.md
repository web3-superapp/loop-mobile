# 0034 Require Explicit Global Feedback

## Status

Accepted on 2026-08-28.

## Context

I7 previously rendered three result claims whenever its catalog route opened:
Notification Preferences were saved, Market prices might be delayed and an
order status could not be confirmed. No preference write, market-freshness
observation or Spot order existed on that route. The subtitle nevertheless
claimed that every notice stated exactly what happened.

The reusable renderer accepted a bare kind and arbitrary message, while its
optional action was not separated from generic system-route placeholders. The
repository also has no global feedback event bus, queue, timeout policy or root
overlay host. I1 connectivity banners and persistent feature-status banners
remain separate state presentations, not ephemeral I7 feedback.

## Decision

- `SystemSurfaceScreen.fromId('toast')` requires one explicit
  `LoopGlobalFeedback` before rendering active I7 content. Without it, the route
  reports feedback context as unavailable and may only return to LOOP.
- The projection contains one success, warning or error kind, reviewed display
  copy and an optional exact action label. It carries no destination, raw
  exception, request/provider payload, token, internal identity, wallet
  address, support reference or request/call/order/idempotency identifier.
- The exact owning feature remains the state and evidence authority. Success is
  used only after a confirmed committed outcome. Timeout, ambiguous writes and
  unconfirmed results remain outcome-neutral under I2 and are never converted
  to definite success or failure by I7.
- An action appears only when the projection contains its non-empty label and
  the composition supplies the dedicated feedback-action callback. Dismiss
  appears only with its independent callback. Generic retry, primary and
  secondary system actions cannot authorize active I7 behavior.
- `LoopGlobalNotice` consumes the complete typed projection, announces the
  exact kind and message as a live region, preserves icon-plus-text meaning and
  stacks its actions at large text sizes. It remains a presentation primitive,
  not a second feature state source.
- This slice preserves I7, `/preview/toast` and the 103-surface catalog. It adds
  no event bus, queue, automatic disappearance timer, persistence, analytics,
  overlay host, backend route, SDK, dependency or native capability. Existing
  feature SnackBars migrate only through separately reviewed feature slices.

## Consequences

Catalog navigation and direct deep links no longer fabricate a product result.
A feature can opt into the bounded renderer after it has exact evidence and
safe copy, without exposing provider internals or allowing placeholder
navigation to masquerade as a retry, review or dismiss action.

## Evidence

- `test/system_global_feedback_truthfulness_test.dart`

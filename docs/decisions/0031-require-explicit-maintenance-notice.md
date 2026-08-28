# 0031 Require Explicit Maintenance Notice

## Status

Accepted on 2026-08-28.

## Context

I4 previously rendered active scheduled maintenance from its route ID alone,
invented a fixed `01:00–01:30 UTC` window and declared Account, Wallet, Trading
and Chat unavailable. Its `Check again` and `View service status` actions both
navigated to Home, so neither performed the action named by its label.

The repository has no maintenance notice source, health feed, status-page
destination, expiry observation or affected-service policy. A route name is
not evidence for any of those facts.

## Decision

- `SystemSurfaceScreen.fromId('maintenance')` requires one explicit
  `LoopMaintenanceNotice` before rendering active I4 content.
- Without that marker, I4 reports maintenance status as unavailable and may
  only return to LOOP. It does not claim that maintenance is planned, active or
  affecting a service.
- The current marker proves only that an approved current notice is active. It
  contains no window, countdown or affected-service list, so the presentation
  claims none. Each feature continues to own its actual availability state.
- `Check again` and `View service status` use independent dedicated callbacks
  and appear only when their exact behavior is connected. Generic system-route
  actions cannot authorize either label.
- A future authoritative notice projection must validate a bounded notice
  identity/revision, attributable source, issued/observed time, UTC start/end,
  expiry and an explicit affected-service vocabulary before those facts can be
  displayed. A status destination also requires its own allowlist.
- This slice adds no notice or health endpoint, timer, countdown, polling,
  automatic retry, persistence, status URL, SDK, dependency or native
  capability.

## Consequences

Catalog navigation and direct deep links no longer fabricate maintenance,
timing or a whole-product outage. A later app-level source can explicitly mount
the narrow active marker while richer facts remain unavailable until their
contract is reviewed.

## Evidence

- `test/system_maintenance_truthfulness_test.dart`

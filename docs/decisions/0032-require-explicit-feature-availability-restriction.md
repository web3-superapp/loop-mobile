# 0032 Require Explicit Feature Availability Restriction

## Status

Accepted on 2026-08-28.

## Context

I5 previously rendered a regional restriction from its route ID alone. It
claimed that LOOP had evaluated location and account information, listed Spot
order execution and deposits/withdrawals as region-blocked, and asserted that
Market, Wallet and Chat capabilities still worked. Those capabilities are not
currently enabled or verified as one regional-policy projection, so the page
misattributed global product state to a location decision.

The backend OpenAPI has no eligibility-policy route. Its integration catalog
marks `regional_gate` as `PENDING` until a legal opinion, country matrix,
provider eligibility and unknown-location handling are approved. A route name
is not evidence that a location was observed or a restriction was decided.

## Decision

- `SystemSurfaceScreen.fromId('region-restricted')` requires one explicit
  `LoopFeatureAvailabilityRestriction` before rendering active I5 content.
- Without that marker, I5 reports availability status as unavailable and may
  only return to LOOP. It does not claim that an account or location is
  restricted.
- The current marker proves only that an approved current decision limits some
  feature access. It contains no location, reason, policy identity or affected
  capability list, so the presentation claims none and does not assert which
  other features remain available.
- `Continue to LOOP` and `View eligibility policy` use independent dedicated
  callbacks and appear only when their exact behavior is connected. Generic
  system-route actions cannot authorize either label. A policy destination must
  be reviewed and allowlisted before its callback is mounted.
- Flutter does not infer jurisdiction from GPS, IP, SIM, locale, timezone,
  Privy profile attributes or wallet addresses. Missing, stale, malformed,
  mismatched or unknown policy input must not be presented as a regional
  denial. Independently guarded feature actions may still remain unavailable
  until their own current authorization is proven.
- A future authoritative projection must validate a bounded decision identity
  and revision, attributable source, subject/application/environment binding,
  observation time, expiry and a closed capability vocabulary before showing
  those facts.
- This slice adds no eligibility endpoint, IP or device-location lookup,
  persistence, polling, policy URL, SDK, dependency or native capability.

## Consequences

Catalog navigation and direct deep links no longer fabricate location
collection, regional conclusions or affected/available feature lists. A later
app-level authority can mount the narrow active marker, while richer policy
facts remain unavailable until their contract and legal ownership are
reviewed.

## Evidence

- `test/system_region_truthfulness_test.dart`

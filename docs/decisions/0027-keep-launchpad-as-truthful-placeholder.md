# 0027 Keep Launchpad as a Truthful Placeholder

## Status

Accepted on 2026-08-28.

## Context

Launchpad is one of LOOP's six primary destinations, but the current catalog
deliberately defers project discovery, project details and launch applications.
The existing G1 placeholder correctly exposed no participation controls, yet it
marked issuer and contract facts as complete and said there were no live
launches. Without a reviewed project source, those presentations could be read
as provider-backed audit and availability facts.

The current frontend phase may complete deterministic application behavior, but
it cannot invent a launch feed, eligibility result, allocation, funding path or
canonical participation intent while their authorities and policies are absent.

## Decision

- Keep `/launchpad` as the first-class G1 destination in the six-tab shell.
- Keep G2 project discovery, G3 project details/participation and G4 project
  applications deferred. Do not mount a local substitute for those routes.
- Present every issuer, eligibility and participation prerequisite as not
  connected until its reviewed authority, freshness and failure policy exists.
- Do not state that launches are live, absent, approved, eligible or complete
  when no launch source was queried.
- Production and Development Preview share the same non-actionable placeholder;
  Preview does not introduce fixture projects or simulated applications.
- Expose no amount, allocation, wallet, fund, signing, claim or submission
  control on G1. Future participation must use a backend-mediated canonical
  intent and the shared wallet review boundary.

## Consequences

Launchpad remains visible in its planned product position without implying that
project facts or financial participation are available. This slice adds no
provider request, private route, persistence, wallet action, SDK, dependency or
native capability. Product work on G2-G4 requires an explicit scope decision
and reviewed backend/compliance contracts.

## Evidence

- `test/launchpad_truthfulness_test.dart`
- `test/app_navigation_test.dart`
- `test/surface_catalog_test.dart`
- `scripts/check_harness.py`
- `tests/test_check_harness.py`

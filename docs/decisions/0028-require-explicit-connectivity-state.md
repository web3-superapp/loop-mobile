# 0028 Require Explicit Connectivity State

## Status

Accepted on 2026-08-28.

## Context

I1 distinguishes complete device network loss from public market-data failure
and private LOOP service interruption. The reusable screen and banner already
had separate presentations for those states, but the routed screen defaulted to
`fullyOffline`. Opening `/system/offline` therefore claimed the device was
offline even though the application root had no connectivity source and had
observed no network or provider failure.

The current phase must keep absent runtime inputs unknown. A route name is not a
device observation, provider response or backend health signal.

## Decision

- `SystemSurfaceScreen.fromId('offline')` accepts an optional explicit
  `LoopConnectivityScope`; it never defaults to an outage type.
- When no scope is supplied, I1 presents connectivity as unknown and says that
  the route itself proves neither device network loss nor service failure.
- Retry and offline/available-feature actions appear only after an explicit
  scope is supplied. The unknown state may only return to LOOP.
- `LoopConnectivityBanner` continues to require an explicit scope and is not
  mounted by the production root until an approved source exists.
- The banner stacks its retry control at large text sizes so status content
  remains readable without horizontal overflow.
- This slice adds no connectivity plugin, polling, HTTP health check, automatic
  retry, persistence or provider claim. A future adapter must translate an
  observed source into one exact scope at the composition boundary.

## Consequences

Naked system routes and Preview no longer fabricate offline or provider-health
facts. Existing feature-owned network errors remain local to their real request
state. The reusable I1 views are ready for a later observed source without
committing the app to a native connectivity package or a health endpoint now.

## Evidence

- `test/system_connectivity_truthfulness_test.dart`

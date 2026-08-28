# 0030 Require Explicit Force Update Policy

## Status

Accepted on 2026-08-28.

## Context

I3 is the product's blocking minimum-version surface. The routed screen
previously declared every build unsafe and unskippable without reading an
installed build or a release policy. It also blocked system back while its
`Update now` callback only displayed a placeholder Snackbar. The separate
force-update dialog could make the same claim without any policy input.

The current route is behind authentication and therefore cannot implement a
real whole-app version gate. A route name and callback are not minimum-version
evidence.

## Decision

- `SystemSurfaceScreen.fromId('force-update')` requires one explicit
  `LoopForceUpdateRequirement` before rendering or blocking on I3.
- Without that marker, the surface reports update status as unavailable,
  remains dismissible and may only return to LOOP. It does not claim that the
  build is unsupported, unsafe or unskippable.
- With the marker, I3 remains blocking. `Update now` appears only when the
  composition also supplies its dedicated reviewed callback; the generic
  system primary action cannot authorize it.
- The marker contains neither a policy reason nor a target version. Required
  copy therefore says only that an approved policy requires a supported build;
  it does not claim a security defect or demand the unspecified latest version.
- `showLoopForceUpdateDialog` requires the same explicit marker and a dedicated
  update callback.
- This marker is frontend presentation evidence only. A future authoritative
  gate must match the exact application ID, platform and release channel; read
  the installed integer build; verify policy version, source, issue time and
  expiry; compare integer minimum builds; and allowlist the exact store target.
- The real gate belongs in `lib/app/` before authentication. Missing, stale,
  malformed or mismatched policy evidence remains unknown. Whether policy
  verification failure itself blocks access requires a separate safety and
  availability decision.
- This slice adds no version/package plugin, HTTP policy adapter, polling,
  persistence, store launch, SDK, dependency or native capability.

## Consequences

Catalog navigation and direct deep links no longer fabricate a forced update
or trap the user behind a nonfunctional action. The reusable blocking screen
and dialog remain available for a later verified app-level policy boundary
without pretending that boundary exists today.

## Evidence

- `test/system_force_update_truthfulness_test.dart`

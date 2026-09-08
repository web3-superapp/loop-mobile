# Consolidate the system-surface truthfulness suites around their invariants

## Status

Accepted on 2026-09-08 (workspace step 1, batch C item 4). This records how
the eight `test/system_*_truthfulness_test.dart` suites were rewritten during
batch B and which invariants they must keep asserting. It does not relax any
truth-source rule from decisions 0028–0035.

## Context

Batch B replaced the English catalog pages with the frozen prototype's zh-CN
system pages (`offline`, `server-error`, `force-update`, `maintenance`,
`region-blocked`, `permission-notice`, `toast-states`, `skeleton-states`). The
old suites were written per page around the retired `I1…I8` identifiers, with
one `testWidgets` per assertion group and a private `_pump` helper duplicated
in each file. Rewriting them against the new copy would have duplicated the
same helper eight more times, so the assertions were merged into
`test/support/system_surface_harness.dart` plus four to six cases per file:
production route, naked surface, explicit observation, large text.

The merge dropped the isolation family that the earlier suites carried, and
the batch B review found the loss. The maintenance page had also started
consuming the generic `onSecondaryAction` for its "查看只读内容" action, which
was what made the old isolation assertion impossible to restore verbatim.

## Decision

- `test/support/system_surface_harness.dart` owns the shared mechanics:
  `pumpSystemSurface` (390×844, optional 2× text, toast host),
  `pumpProductionApp`, `expectProductionUnavailable` and `scrollPageTo`. No
  suite re-implements them.
- Every system suite keeps these invariants, and a reviewer may reject a
  suite that drops one:
  1. **Production route is unknown.** Opening the route in the real app shows
     the page's `*-source-unavailable` notice, renders none of its factual
     claims, and its 返回 LOOP action lands on `/community`.
  2. **Naked surface infers nothing.** Passing no observation never renders a
     heading, figure, window, trace ID, version or per-chain claim.
  3. **Explicit state never accepts generic system actions.** With an
     observation supplied, `onRetry`, `onPrimaryAction` and `onSecondaryAction`
     must not be reachable; each suite asserts this with `fail(...)` callbacks
     plus the absence of every action label.
  4. **An action requires its exact label and its dedicated callback.** Half
     the evidence (a label with no callback, or a callback with no label)
     renders no button; dismissal is a separate callback from the action.
  5. **Skeletons expose no facts.** `LoopSkeletonView` carries one live-region
     label, no `Text`, no counts, no identities and no buttons.
  6. **Every state stays usable at 2× text** without an exception.
- `onMaintenanceReadOnly` is the maintenance page's dedicated "查看只读内容"
  callback. The generic `onSecondaryAction` now reaches only the
  source-unavailable states, where it is the shared 返回 LOOP action.
- One documented exception: `offline` deliberately consumes the generic
  `onRetry` and `onSecondaryAction` in its explicit state, because retry and
  "continue with what still works" are exactly the generic pair and the page
  has no narrower owner action. Its suite therefore asserts invariant 3 only
  for `onPrimaryAction`, which no surface consumes at all.
- The retired `I1…I8` identifiers are not reintroduced. Test names use the
  manifest slug or the page's Chinese heading.

## Consequences

The suites are shorter and share one harness, so a copy change touches one
helper instead of eight files. The isolation family is explicit and named, so
its removal is visible in review rather than silent. A new system page must
add its dedicated callbacks instead of reusing the generic trio.

## Verification

`bin/flutter test` covers all eight suites plus `loop_sign_sheet_test.dart`
and `system_sign_sheet_states_test.dart`. Full command output is recorded in
`LOOP/docs/modules/D0-baseline.md` with the batch C completion note.

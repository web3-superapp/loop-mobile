# Client-Derived Governance Visibility

## Summary

`community-members` offered an Admin viewer 「禁言」 and 「封禁」 on another
Admin's row. The server answered every such command with
`403 PERMISSION_DENIED` and changed nothing, so the page could only report
「上一次操作没有完成 / 当前账号没有执行这个操作的权限」. The authorization
boundary held; the client published an entry point that could never succeed,
on the most sensitive permission surface in the app.

## Root Cause

The server's governance rules are one `actor × action × target` matrix, in
which `admin` may mute and ban `member` targets only. The member directory
projected that matrix as three observer-level booleans —
`canInviteAdmin` / `canMute` / `canBan` — which state whether the viewer holds
a right *somewhere* in the community and **carry no target**. An admin
therefore received `canMute: true, canBan: true`.

The client derived each row's commands from those booleans. It could not have
been right: the fact it was given had one fewer dimension than the decision it
had to make. Owner targets and banned rows had their own client-side guards,
which is why only the admin→admin cell was visibly wrong; the same mechanism
also offered an ownership transfer against a muted member, which the server
refuses with `409 DATA_STALE`.

Decision 0054 had already recorded that "a second client-side matrix could
only drift". The drift arrived through the projection, not through the rule.

## Detection

A 2026-09-14 device session: signed in as a community Admin, opened another
Admin's row, pressed 禁言, and received the failure notice with no state
change. Reproduced twice before the fix — server side, `viewerPermissions`
returns `canMute: true` for an admin while `canPerformTargetAction` denies
`admin → mute → admin`; client side,
`communityGovernanceActions(adminViewer, adminRow)` returned `[mute, ban]`.

## Prevention

A client-facing projection of a permission rule must carry every dimension the
rule uses, or it must be computed server-side and published as a result. The
member directory now publishes `items[].actions` per row, computed from the
same matrix **and** the same stored-state precondition the write path
evaluates, in the same order. The client renders that list verbatim and holds
no governance rule of its own.

Guards: `check_harness.py` forbids `canMute`, `canInviteAdmin`, `canGovern`,
`isActionable`, and any locally built `List<CommunityGovernanceAction>` in
`community_members_screen.dart`, allows `canBan` only once (the banned
segment), and requires the sheet's action list to be an unfiltered
`for (final action in entry.actions)`. Three Python unit tests fail the build
if any of those is relaxed. On the server, the matrix test asserts every
`actor × action × target` cell and the row-action test asserts every
`actor × target × status` cell against a hand-written table, plus a
cross-check that the published list equals what the write path would
authorize.

## Evidence

- Server before the fix: `viewerPermissions({role: "admin", status: "active"})`
  → `{canInviteAdmin: false, canMute: true, canBan: true}`, while
  `canPerformTargetAction({actor: admin, action: "mute", targetRole: "admin"})`
  → `false`.
- Client before the fix: `communityGovernanceActions` returned
  `[mute, ban]` for an admin viewer on an admin row.
- After the fix: the published `actions` for that row is `[]`, in the policy
  unit tests, the route contract tests, and the member-screen widget test.

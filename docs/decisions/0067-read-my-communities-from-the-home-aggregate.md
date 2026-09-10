# 0067 · 我的社区 reads the membership LOOP already has

## Status

Accepted 2026-09-10. Extends decision 0051 (V2 `community` module). It changes
no backend contract: `GET /v2/community/home` and
`GET /v2/communities?membership=joined` are used exactly as
`loop-api/docs/frontend-v2-community-api.md` §4.1 and §4.2 define them.

## Context

The 2026-09-10 simulator acceptance run found `profile` and `community`
disagreeing about the same account. The Community tab listed one joined
community — Builders Guild, role `owner` — read from the `joined` block of
`GET /v2/community/home`. The 我的社区 row on 我的, three taps away, said
「社区成员关系尚未接入」 with the trailing value 「未接入」.

That copy was written before S3 connected the module and was never revisited.
It was not a missing source: the source existed, was already being read on
another page in the same session, and the row simply did not consult it. A
truthfulness rule that exists to stop LOOP inventing facts was, here, stating
a falsehood in the opposite direction — claiming nothing is known when the
server had already answered.

## Contract facts this rests on

| Fact | Value |
| ---- | ----- |
| Where membership comes from | `GET /v2/community/home` → `joined.items[]` |
| What each item carries | `community` summary + `membership.{role,status,joinedAt}` |
| When the list is complete | `joined.truncated === false` |
| Where the full list lives | `GET /v2/communities?membership=joined` (cursor) |
| What may be shown | `joined.items.length` and `memberCount`; no number when unread |

`membership=joined` is also the filter `community`'s own 「查看全部已加入的社区」
button already uses, so the profile row reaches an existing page rather than a
new one.

## Decision

`我的社区` is now a projection of the community home aggregate, not a profile
fact.

- `ProfileCommunitiesRow` (`lib/features/profile/profile_v2_screens.dart`)
  watches the existing `communityHomeControllerProvider`. No gateway, model,
  controller or transport is added: the row consumes the same single-flight
  read the Community tab consumes, and shares its result whenever both are
  alive.
- It reads the `community` capability through `communityCapabilityBlocks`
  exactly as `CommunityScreen` does, so a module the server has declared
  unavailable produces **no request at all** and the row says so.
- Ready: the trailing value is `N 个已加入` from `joined.items.length`, and
  `N+ 个已加入` when `joined.truncated` is true, because a truncated aggregate
  makes the count a floor rather than a total. The subtitle names at most two
  communities with the role the server confirmed —
  `Builders Guild（Owner） · Frog Holders（成员）`.
- A `muted` or `banned` membership reads as 已禁言/已封禁 rather than as its
  role. The account still holds `member`/`admin`, but printing the role would
  read as an entitlement the server has suspended. The mapping is now one
  function, `communityMembershipLabel`, shared with the community home rows
  that already did this.
- Not ready: the trailing value is the em dash `communityMissingFigure`, never
  `0`, and the subtitle states which of the reviewed phases the aggregate is
  in — loading, offline, unavailable, permission, error — from the same
  `CommunityViewPhase` vocabulary every other S3 surface uses. 「未接入」 is
  gone.
- Zero joined communities is a *server answer*, not a missing one: the row
  shows `0 个已加入` and 「还没有加入社区，从发现社区开始」.
- The row stays a navigation entry in every phase, so a failed read never
  removes the way out. With memberships it opens the paginated directory
  narrowed to them (`community-joined` →
  `/community/discover?membership=joined`); with none, or with nothing read,
  it opens the public directory, which owns the full five-state block and the
  retry. The row does not carry a second retry of its own.

`community-joined` is a profile *destination id*, resolved by `_profilePath`
in `lib/app.dart` to the existing `community-discover` manifest path plus its
`membership=joined` query. The 93-route manifest is unchanged; no route is
added.

## Consequences

- Opening 我的 now issues one `GET /v2/community/home` it did not issue before.
  It is the aggregate the account already reads on login's landing tab, it is
  single-flight, and it is skipped entirely when the capability document says
  the module is closed.
- `profile` now depends on `lib/features/community/`. That direction already
  exists (`chat`, `social`), the import is of the feature's own port-backed
  controller and models, and no transport type or route literal crosses with
  it.
- The Launch rows on the same page keep 「未接入」, which remains true for them:
  `launch-history` and `launch-tier` have no connected source.
- Membership status is not a mining, balance or reputation fact and nothing on
  the page derives one from it.

## Evidence

`test/s14_profile_communities_test.dart` covers one membership (count, name,
role, and the `community-joined` destination), the two-name cap, `truncated`,
a suspended membership, the empty answer and its discovery destination,
loading, offline, a refused read, and a closed capability.
`test/profile_v2_pages_test.dart` locks that the retired copy is gone and that
only the two Launch rows still read 「未接入」.

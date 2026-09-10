# 0072 · 成员搜索接上，占位删除

## Status

Accepted 2026-09-10. S16 stream D, client half. It rests on the new optional
`q` parameter of `GET /v2/communities/{communityId}/members`
(`loop-api` decision 0040, `loop-api/docs/frontend-v2-community-api.md` §4.6).
No route is added; the 93-route manifest is unchanged.

## Context

`community-members` shipped with a search control in the topbar, exactly where
the frozen prototype draws it. Tapping it opened a sheet that said 「成员搜索
暂不可用 · 成员目录没有搜索接口」 and sent the user to global search instead.
The 2026-09-10 simulator run put it plainly: "why can't member search be used?
if there's no endpoint, why wasn't one added?"

The placeholder was honest about the client, but the answer was to build the
missing half, not to keep explaining its absence. The backend now takes an
alias prefix on the same read the page already performs.

## Contract facts this rests on

| Fact | Value |
| ---- | ----- |
| Parameter | `q` on `GET /v2/communities/{id}/members`, optional |
| Bound | 1–40 Unicode code points after trim + NFKC + lower-case + space fold |
| Match | Literal **prefix** of the member alias; never a substring, never `loopId` |
| No alias | A member without an alias is never a hit |
| Counts | `counts.all/owner/admin` describe the whole non-banned directory and do **not** move with `q` |
| Cursor | Bound to the normalized query; changing, adding, or removing `q` makes an old cursor `400 INVALID_REQUEST` |
| Quota | A `q` request spends the shared public alias search budget (30/min per account); `429 RATE_LIMITED` when exhausted |
| Fail closed | An unconfigured server quota answers `503 CAPABILITY_UNAVAILABLE` for `q` only |

## Decision

| Topic | Ruling |
| ----- | ------ |
| Where the field lives | The prototype's topbar control now toggles an inline field above the role segments instead of opening a sheet. Closed is the default, so the directory still opens as the whole directory. |
| Placeholder | `member-search-unavailable-sheet` and its copy are deleted, not hidden. Nothing in `lib/` claims member search is unavailable any more. |
| Debounce | 300 ms, in the controller rather than the widget, so the rule survives a rebuild. `CommunityMembersController.searchDebounce` is the single source and the tests read it rather than repeating the number. |
| Single flight | The existing `CommunitySingleFlight` guard still allows one read at a time. A keystroke that lands while a read is in the air does not start a second one; when the read returns, the drain loop issues exactly one more for the latest text. A read never answers for text the caller has moved past without a follow-up. |
| Clear | The field carries a clear control and the topbar toggle also clears. Both drop `q` and read the whole directory again immediately, without waiting out the debounce. |
| Loading | A search re-read is a narrowing of the directory already on screen, so decision 0071's rule applies: the rows stay and wear the 更新中 mark rather than being replaced by a skeleton per settled keystroke. `CommunityMembersState.refreshing` carries it and the page renders 0071's own `LoopUpdatingBadge` under the same `community-state-updating` key every other community surface uses. A first open and a role switch are different directories with nothing comparable to keep, and still load as a skeleton. The stale cursor is dropped either way, so 载入更多 is withdrawn while a re-read is in the air. |
| Empty result | 「没有匹配的成员」 with 「别名要从开头对上才算匹配，换个开头再试。」. It is the ordinary `empty` phase, not a new state: the segment counts stay the server's directory counts, and the field survives its own empty answer so the query can be edited. |
| Five states | Unchanged. A refused search is the same `error` / `offline` / `permission` / `unavailable` block the directory already renders, with the field still on screen; `429` reaches it as `rateLimited` through the existing catalogue mapping. |
| Transport | `q` is trimmed by the transport, dropped when blank, and refused before dispatch when it carries a control, format, surrogate or line/paragraph separator code point or exceeds the contract's 256-character raw bound — the client never spends a quota slot on a request the contract already rejects. Normalization and the code-point bound stay the server's. |
| Error catalogue | The member read now allows `403 PERMISSION_DENIED` (the `banned` governance view, which the handler could always answer) and `429 RATE_LIMITED`, through a new `LoopV2ModuleRequest.memberListErrors`. `readErrors` is untouched for every other read. |
| Cursor | 「载入更多」 keeps working under a query because the controller never carries a cursor across a query change: a new query always restarts at the first page, which is what the server's cursor binding requires. |
| Preview | The in-memory preview gateway applies the same prefix rule, lower-cased, so 开发预览 does not show a search that silently ignores what was typed. It stays labelled preview data. |
| Design tokens | No new colour, size, or weight. The field is the same `TextField` the global search page uses; member rows keep `LoopRecordRow`. |

## Consequences

The topbar control now does what its icon promises, and the sheet that
explained why it could not is gone from the code rather than hidden behind a
flag. The page spends the shared public alias search quota, so the debounce
and the single-flight guard are not polish: without them a fast typist would
exhaust 30 requests a minute and the page would answer `429` to its own user.

A cursor is bound to the query it was issued for, so changing the text always
restarts at the first page — 「载入更多」 keeps working under a query, and a
mixed page of two different searches is not reachable.

Because the rows survive a re-read, the page no longer blanks itself once per
settled keystroke — which is the same complaint decision 0071 answered for
every other block, applied to the one interaction that did not exist when 0071
landed.

Refused, and still refused: fuzzy or substring matching, searching by `loopId`
or wallet address, sorting results by relevance, and any client-side filtering
of an already-loaded page. A search the server did not perform is not a
search.

## Evidence

- `test/community_pages_test.dart` → group `community-members · alias search`:
  the placeholder sheet is gone, 300 ms debounce (three keystrokes, one
  request), the trimmed query reaching the gateway as `q`, an empty result
  that keeps the server's counts and the field, the clear control and the
  topbar toggle both dropping `q`, a keystroke during a read producing exactly
  one follow-up, a re-read keeping its rows under the 更新中 mark with
  载入更多 withdrawn until the answer lands, a first open and a role switch
  still loading as a skeleton, and a refusal keeping the five-state block.
- `test/community_api_contract_test.dart`: `q` trimmed onto the wire beside
  `role` and `cursor` with no `Idempotency-Key`, a blank or absent query
  sending no `q` at all, an unsafe or over-long prefix never dispatched, and
  `429`/`403` mapping onto `rateLimited` / `permissionDenied`.

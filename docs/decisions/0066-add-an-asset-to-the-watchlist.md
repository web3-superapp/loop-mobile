# 0066 · Add an asset to the Watchlist: the star writes, the editor creates groups

## Status

Accepted 2026-09-10. Extends decision 0057 (V2 `watchlist` module). It changes
no backend contract: `GET /v2/watchlist` and `PUT /v2/watchlist` are used
exactly as `loop-api` decision 0033 defines them.

## Context

The 2026-09-10 simulator acceptance run found that LOOP had no way to put an
asset into the Watchlist at all — a closed loop with no entrance:

- `token`'s star (`lib/features/market/token_screen.dart`) was labelled
  「管理自选」 and only pushed `/market/watchlist`.
- `watchlist-edit` can reorder and remove, and nothing else. With no groups it
  said 「还没有分组 · 自选分组来自服务端资源，本页只编辑已存在的分组」, which is
  false — the server generates no group and takes whatever the client sends —
  and with no assets it said 「在行情页打开一个资产后加入自选」, which pointed
  back at the star that had just sent the owner here.
- `market`'s Watchlist block therefore stayed empty forever, and its empty
  state repeated the same 「在自选管理里加入资产」 loop.

## Contract facts this rests on

Read from `loop-api/src/features/watchlist/watchlist-v2-service.ts`,
`src/database/watchlist-v2-repository.ts` and `src/routes/v2/watchlist.ts`:

| Fact | Value |
| ---- | ----- |
| Who generates a group `key` | **The client.** The server only validates it. |
| `key` shape | `^[a-z0-9][a-z0-9_-]{0,31}$`, unique within the document |
| `name` | trimmed, 1–40 code points, no `\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}` |
| Groups per document | ≤ 20 |
| Items per document | ≤ 100, unique `assetId` within a group |
| Concurrency | whole-document CAS on `expectedVersion`; stale → `VERSION_CONFLICT` |
| `Idempotency-Key` | **rejected** — `400 INVALID_REQUEST` when present |
| Asset admission | every `assetId` must be a readable registry row on the chain, else `VALIDATION_FAILED` |

So a client *can* create a group, and it must: there is no other way for the
first group to exist. And no idempotency key is issued for this write — the
version is what makes it safe to repeat — so `LoopV2CommandKeyring` is
deliberately not involved.

## Decision

### 1. The star on `token` is the write

`WatchlistMembershipController` (`watchlist_membership_controller.dart`) is a
per-`assetId` autoDispose family that reads the document and owns one
operation:

- **State is three answers, not two** — watched, not watched, and *not read
  yet*. `isKnown` is false until a `GET` succeeds, and the star never renders
  「not read yet」 as 「not watched」 in anything but its default label.
- **Adding** appends the asset to the group whose key is `default`. When no
  such group exists it is created in the same replacement, named 「自选」. Both
  server limits are checked *before* any request, and each has its own outcome
  (`itemLimitReached`, `groupLimitReached`) with its own sentence — 「自选已达
  100 项」 / 「分组已达 20 个」. The server answers both with `VALIDATION_FAILED`,
  whose copy says the asset is not registered; showing that here would be a
  lie, so a limit refusal is never routed through a chain failure kind and
  never touches the page's read state.
- **Removing** drops the `assetId` from *every* group, because the Watchlist is
  one list to the owner even though the resource groups it. An emptied group is
  kept: the owner named it, and this press was about one asset.
- **A `VERSION_CONFLICT` is retried exactly once.** The owner's intent — add or
  remove — is re-applied to the freshly read document against its new version.
  If that read already shows the intent satisfied (another device did it), the
  reload *is* the outcome and no second write is sent. A second conflict is
  reported; a list that keeps moving is not one this press can safely rewrite.
- A committed write invalidates `marketOverviewControllerProvider`, because the
  overview projects the same resource and a list read before this write is
  stale.

The star's accessible name is the action, not the state: 「加入自选」 /
「移出自选」, and `LoopIconButton` gains an optional `toggled` so a screen reader
also hears the on/off state. `toggled` is `null` — no claim at all — while the
list is unread or the module is closed, because `false` would say the asset is
not watched.
Watched is `LoopColors.lime`, unwatched is the default chalk — an existing
token, no new colour and no new type size. The star is disabled and reads
「自选当前不可用」 on **either** closed answer: the capability document
(`loopChainCapabilityBlocks`) *or* the controller's own `unavailable` phase,
which is what a production build with no transport produces —
`loopChainCapabilityBlocks` only exempts Preview and would otherwise leave the
star pressable against `UnavailableWatchlistGateway`. It reads its *own*
capability, so a Market outage cannot claim an asset is unwatched and a
Watchlist outage cannot hide a price.

Every outcome is a toast: 「已加入自选」, 「已移出自选」, or the server's own
reason. The failure toast never says a write may have landed — an offline or
refused `PUT` changed nothing on either side, and the star stays where the last
committed document put it.

### 2. `watchlist-edit` creates groups

「新建分组」 opens a sheet with one name field validated live against the write
bounds above (`watchlistGroupNameIssue`, shared by the field and the
controller, so what the field explains is what the write would refuse). The key
is generated as the first free `g<n>`; the name is what the owner typed. The
new group joins the **draft**, so it travels in the next compare-and-set and
放弃修改 undoes it — the page keeps exactly one write.

### 3. The copy stops pointing in a circle

| Surface | Was | Is |
| ------- | --- | -- |
| `watchlist-edit`, no groups | 「自选分组来自服务端资源，本页只编辑已存在的分组」 | names both entrances: the star, and 新建分组 (offered right there) |
| `watchlist-edit`, empty group / empty list | 「在行情页打开一个资产后加入自选」 | 「打开代币页，点右上角星标即可加入自选。」 |
| `market`, empty Watchlist | 「在自选管理里加入资产后…」 | 「在代币页点星标加入自选…」, keeping the 管理自选 button |

## Consequences

- `token` no longer navigates to `/market/watchlist`. The editor stays reachable
  from `market`'s app bar and from its empty state; nothing in the 93-route
  manifest changes.
- The five reviewed states are untouched. The star is a control, not a block:
  its unavailable case is a disabled control with a stated reason, and every
  refusal is reported without moving what is on screen.
- `FakeWatchlistGateway` gains a scripted `replaceFailures` queue and a
  `reloadSnapshot`, which is what lets a test assert that the conflict retry is
  composed against the version that was actually read back.

## Known boundaries

Accepted for this slice, recorded so they are not rediscovered as bugs:

- **The star writes into `default` only.** There is no way to choose a group
  from `token`, and no way to move an asset between groups except by removing
  and re-adding. Group membership beyond the default is `watchlist-edit`'s job,
  and it cannot add.
- **The membership read is per-asset and per-page.** Each `token` page issues
  its own `GET /v2/watchlist`; two token pages in a stack read the document
  twice, and a write on one does not update a sibling that is already built.
  The document is small and `no-store`, so this is a cost, not a correctness
  problem — but a shared cached read would remove it.
- **`market`'s Watchlist rows have no star.** Removing from the overview still
  means opening the token page or the editor.
- **A group can be created but never renamed or deleted** from the editor. The
  contract allows both; neither is in this slice.

## Alternatives rejected

- **Add to the first existing group.** Silent and unpredictable: an owner with a
  「Mining」 group would find unrelated assets in it. A named default group is
  visible in the editor and can be renamed or emptied there.
- **Rename an existing `default` group to 「自选」.** The star would then rewrite
  a name the owner chose. The key is matched; the name is left alone.
- **Retry a conflict until it lands.** An unbounded retry is an unbounded
  overwrite of whatever the other device is doing. One retry covers the ordinary
  race; the second answer is reported.
- **Carry an `Idempotency-Key`.** The server rejects it with
  `400 INVALID_REQUEST`.
- **Let the editor add assets through a search field.** There is no
  registry-search contract to back it, and the star is where the owner already
  is when they decide.

## Verification

`bin/dart format --set-exit-if-changed`, `bin/flutter analyze` (no issues),
`bin/flutter test --concurrency=2`, `python3 scripts/check_harness.py`, and
`python3 -m unittest discover -s tests` (307 passing).

`test/s13_watchlist_add_test.dart` holds 23 cases: default-group creation,
append to an existing default group, removal, the conflict retry against the
version that was read back, a conflict whose reload already satisfies the
intent (one `PUT`, not two), a second conflict, offline, a refused write, both
limit refusals (no request, and the limit named rather than the asset), the
unread third state (no colour claim, no `toggled` claim, still pressable), a
failed read answered by the press, a closed gateway, a closed capability, the
market-overview invalidation, 放弃修改 undoing a new group, the disabled
新建分组 at 20 groups, both editor name refusals, the saved new group with its
client-generated key, the empty-state copy, and the contract bounds.

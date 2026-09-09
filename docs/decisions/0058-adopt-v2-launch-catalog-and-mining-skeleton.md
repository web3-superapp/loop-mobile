# 0058 — Adopt the V2 Launch catalogue, Mining skeleton and Referral graph

## Status

Accepted 2026-09-09. Retires decision 0027 (`keep-launchpad-as-truthful-placeholder`):
the Launch destination is no longer a static placeholder, and
`lib/features/launchpad/launchpad_screen.dart` is deleted with it. Extends
decision 0057 with three more fail-closed V2 ports.

## Context

Step 7 delivers the seventeen Launch and Mining pages plus `referral`. The
backend (loop-api decision 0036, migration 000023) is merged and answers
twenty-two endpoints, but **the 02 contract document was never provided**.

That single absence decides the whole step. Without an ABI, an address and an
audit there is no sale state, no entitlement, no liquidity, no purchase, no
refund, no vesting, no pool and no staking position that the client can prove.
Without an approved mining formula version there is no power, no daily output,
no accumulation, no claimable reward, no rank and no referral boost. The server
says so explicitly: every one of those fields arrives as
`{status: "unavailable", reasonCode}`, and the two reason codes that dominate
the step are `LAUNCH_CONTRACT_BASELINE_PENDING` and
`MINING_FORMULA_BASELINE_PENDING`.

The frozen prototype states the opposite. It shows a uniform one-billion
supply, a permanent 1% ecosystem tax, a `…LOOP` contract-address suffix, a
0.5% per-wallet cap, three rounds at 10%/5%/configured fees, a $300,000
graduation line, 1.0× and 0.1×–1.0× mining weights and a 2,840-hash referral
boost over 182 valid relationships. None of those numbers has a source. A page
that rendered them would be indistinguishable from a page backed by a real
contract, which is exactly the failure this project exists to avoid.

## Decision

**One taxonomy for the three modules.** `lib/features/launch/launch_contract.dart`
owns `LaunchFailureKind`, `LaunchException`, `LaunchGatewayMode`,
`LaunchUnavailable`, `LaunchViewPhase` and `LaunchResourceState`, and `mining`
and `referral` import it — the same arrangement decision 0057 used for
`chain_contract.dart`. It adds four kinds the S5 taxonomy has no use for:
`stale` (`409 DATA_STALE`), `policyBlocked` (`403 POLICY_BLOCKED`),
`activationRequired` (`409 PROFILE_ACTIVATION_REQUIRED`) and `versionConflict`,
because the application state machine and the referral claim each need a
different next step for each of them.

**Three fail-closed ports.** `LaunchGateway`, `MiningGateway` and
`ReferralGateway` default to their `Unavailable…` implementations;
`lib/main.dart` overrides them with the authenticated V2 adapters, which stay
unavailable while the Dio client, the client metadata or the session is absent.
There is no Preview mode for step 7: a Launch or Mining fixture cannot be
labelled truthfully, so none exists.

**Absence is rendered in two different ways, and they are not interchangeable.**
A server field shaped `{status: "unavailable", reasonCode}` renders the
server's own explanation through `LaunchUnavailableCard`. A *metric* whose
figure the contract cannot carry renders `LaunchEmptyMetric`: the em dash plus
that same explanation. Neither ever renders `0`. Where a configuration slot has
no confirmed version the page adds "待确认（configVersion）" naming the version,
or "待确认（版本未指派）" when the server has not assigned one.

**Nothing about the chain is inferred from the schedule.** The catalogue
segments come only from `scheduleStatus`, and `awaitingSchedule` is its own
segment rather than a variant of "即将开始". "已毕业" is a liquidity-axis
projection and stays unavailable; the graduation page says in as many words
that "已结束" is not graduation. The four on-chain axes are rendered as four
separate rows so no page can later imply one from another.

**Refusals stay the server's.** `launch-trade` keeps its amount field and its
round list visible and disables only the main action, with the server's own
`503 CAPABILITY_UNAVAILABLE` as the stated reason; there is no sell side,
because an ungraduated launch is buy-only. `loop-stake` is non-executable as a
whole page: no amount field, no tab pair, no signing entry. `mining-rewards`
disables its claim control on the server's `claimExecutable: false`, and the
transport refuses a `true` value outright.

**`launch-apply` is a real resource, not a gesture.** It creates a draft
(`POST`, one idempotency key per logical operation), edits it under the exact
server version (`PUT` with `expectedVersion` and deliberately no idempotency
key), submits it, and renders the six review states with the next step each one
allows. A returned application is editable and re-submittable; an approved or
rejected one is read-only. Attachments and KYB have no provider and are shown
as pending with no upload control. A non-owner projection carries a `null`
version and a `null` review trail, and the page renders that as "审核轨迹与版本
只属于申请人" rather than as "never submitted".

**`referral` reads `GET /v2/referral`.** It shows the account's single invite
code (copied to the system clipboard), the per-level counts grouped by the
server's `validationStatus`, and the boost as unavailable. Only `valid` edges
count as effective relationships; everything else is "待验证". The claim entry
appears only while the account is unbound and the server reports an open
window, an obviously malformed code is refused locally so it cannot spend the
account's one binding attempt, and each of the five documented refusal codes
gets its own next step. The inviter's identity is never part of the
projection — only depth, validation state and rule version.

**Route identity is opaque.** `lib/core/navigation/launch_route.dart` adds
`LaunchRoute` (`launchId`) and `MiningRoute` (`communityId`) with the same
exact-match parser `MarketAssetRoute` uses. A ticker, a name or an address is
never a route identity; a missing or malformed parameter fails closed into the
page's own unavailable state.

**The capability enum tracks the frozen contract, not this step's needs.** It
grows to the 31 ids the contract carries, adding `security`, `settings` and
`support` alongside `referral`, because the parser requires the exact set.
`launch` and `mining` read `available` with **pending evidence**: the catalogue
and the application flow work while the baselines do not, and it is the
evidence reason code that each page renders.

**`LoopTokenCard.graduated` loses its ecosystem-tax metric.** There is no tax
rate to show. The state keeps its Lime border and its owner-supplied metrics.

## Consequences

Fifteen manifest routes move from `pending` to `implemented`; only `key-export`
remains pending. `/launchpad` stays a compatibility redirect. `referral` keeps
its `/profile/referral` path but its screen moves to `lib/features/mining/`,
because it is a Mining Power page backed by the `referral` capability.

Seventeen pages ship whose headline figure is an em dash. That is the honest
result of the missing contract document, and it is what makes the eventual
delivery verifiable: when 02 arrives, every `unavailable` block has a named
reason code that must stop appearing, and no page has to be un-lied to first.

The three transports parse strictly. `contractAddress`, `stateTupleDigest`,
`snapshotBlockNumber`, `snapshotBlockHash`, the eligibility `tier` and the
eligibility `snapshotBlock` are pinned to `null`; `executable`,
`claimExecutable` and `dependsOnStaking` are pinned to `false`; the history,
asset and ledger collections are pinned to empty. A server that started
answering otherwise would be an invalid payload rather than a silently
half-trusted page — which is the intended alarm, since it would mean the
baseline landed without a client update.

The `mining-snapshot` and formula-approval paths are exercised only in the
transport tests: no runtime path can reach them until
`pnpm mining:approve-formula` is run, which this step does not do.

## Evidence

- Contracts: `loop-api/docs/frontend-v2-launch-api.md`,
  `loop-api/docs/frontend-v2-mining-api.md`,
  `loop-api/openapi/loop-api.v2.json` at `integration/v2` `64e1cf5`.
- Rulings: `docs/modules/S7-launch-mining.md`「主代理裁决」(2026-09-08).
- Tests: `test/s7_api_contract_test.dart`, `test/s7_launch_pages_test.dart`,
  `test/s7_mining_pages_test.dart`, `test/s7_referral_test.dart`,
  `test/support/s7_fixtures.dart`, `test/support/s7_page_harness.dart`.
- Gates: `bin/flutter pub get --enforce-lockfile`, `bin/dart format`,
  `bin/flutter analyze`, `bin/flutter test`, `python3 scripts/check_harness.py`,
  `python3 -m unittest discover -s tests -p 'test_*.py'`.

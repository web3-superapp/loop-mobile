# 0070 · Screens speak to the user, not to the backlog

## Status

Accepted 2026-09-10. Ruling B of the S16 UX pass
(`docs/modules/S16-ux-polish.md`). Copy only: no route, contract, request,
state machine, component or token moves.

## Context

A user walking the 93 surfaces reported that the product sounds like its own
issue tracker. The audit found it in the source rather than in impressions:

- 18 literals rendered a backend step id — `社区算力排序需要挖矿口径（D19）确定后才有来源。`
  on Discover, `D8 · Margin account` as a Perp eyebrow.
- `rule:verified-members-v1` was printed verbatim in the Community
  recommendation notice.
- 21 capability gates rendered `服务端原因：${capability.reasonCode}。`, and two
  more sign-sheet sentences appended `（${outcome.reasonCode}）`, so
  `SEARCH_RUNTIME_UNAVAILABLE` and `ASSET_NOT_IN_CANARY_ALLOWLIST` reached the
  screen as-is. Two tests asserted that they did.
- 29 literals used 口径 / 观测 / 投影 / 聚合, and roughly 400 more used
  服务端 / 来源 / 接入 / 证据 / 契约 / 槽位 / 本步 / 组装 / 交付 / 预执行 /
  registry / payload — vocabulary that exists so the team can talk about the
  system, not so a person can use it.
- Most unavailable and empty states were two or three clauses long and
  explained the implementation: which module was not assembled, which indexer
  had not started, which key was not configured.

None of this was accidental. The product's rule is that a surface never invents
a fact, so every closed surface says exactly *why* it is closed — and the
nearest available "why" was the engineering one. The rule is right; the
vocabulary was wrong.

## Decision

A user-visible string states what cannot be done now, in the user's words, and
optionally when or how it will work. Implementation detail moves into the
`LoopDisclosure`-style details block or the timestamp fine print, or it is
dropped.

- `docs/copy-glossary.md` is the source of truth: the banned list (step ids,
  rule ids, reason codes, capability ids, 口径 / 观测 / 投影 / 聚合), the
  discouraged list with its replacements, the six rewriting principles, the
  sentence patterns, and the review checklist.
- One sentence is the target and two is the ceiling. `message` states the
  fact; `reason` states the timing or the consequence. They may not be the same
  sentence twice.
- Provenance stays. `来源 DexScreener · 观察于 3 分钟前`, `区块高度 …`,
  `规则版本 … · 生效于 …` are the product's promise that every figure is
  attributable; they remain, as fine print beside the figure, never inside the
  headline.
- A `reasonCode` is never rendered. Where a gate previously printed one, the
  page now carries a single plain sentence; where a code carried real
  information, it is mapped to a sentence first — `loopReasonCodeText`,
  `communityUnavailableReason`, `launchReasonCodeText`,
  `communicationUnavailableReason`, and the new `launchReviewReasonText` for a
  returned Launch application. Every map keeps a neutral fallback rather than
  inventing a cause.
- Truthfulness is unchanged. "Cannot read" still never becomes zero, safe, or
  "no records"; the prototype's flat, unpromising register is kept.

`check_user_visible_copy` in `scripts/check_harness.py` enforces the machine-
checkable half. It parses every Dart string literal in `lib/` (skipping
comments), refuses `（D\d+）` / `(D\d+)` / `D\d+ ·` in any literal, and refuses
`rule:`, `_PENDING`, `_UNAVAILABLE`, 口径, 观测, 投影 and 聚合 inside a literal
that carries a CJK ideograph. The CJK test is the allowlist: wire constants,
`reasonCode` keys and env-var names have no Chinese in them, so the transport
layer and the code→sentence maps are untouched. Literals on a `debugPrint`,
`developer.log` or `assert` line are diagnostics and are skipped. The rest of
the glossary is a review obligation, not a regex.

## Consequences

- 528 literals across 79 `lib/` files were rewritten; 63 assertions in 22 test
  files were updated to the new strings without weakening what they assert.
  Two assertions that required a reason code on screen were inverted: the code
  must now be absent and the sentence present.
- Two harness contracts that had pinned old copy were repointed at the new
  sentence: the Mining page's locked fragment (`D19` → 挖矿公式还没有批准的版本)
  and the Swap confirmation's evidence sentence (真机证据未取得 → 兑换还在验证中).
- Perp eyebrows lost their `D…·` prefix. Those screens stay out of navigation
  under the 93-route manifest; the prefix is removed so the guard holds for the
  whole of `lib/`.
- 快照 survives in the Launch eligibility surfaces, where it is the product's
  own noun, and was replaced by 结算 everywhere it meant an internal settlement
  snapshot. This is the one deliberate exception in the glossary.
- Anyone adding a surface now writes the sentence before the reason code, and
  the harness fails the commit if the code leaks.

## Evidence

`tests/test_check_harness.py` covers the guard in three ways: a synthetic file
with a step id, an eyebrow prefix, a rule id, a reason code and 观测 produces
six errors; a file of wire constants, an env-var name, an `L1 ·` referral label
and a `debugPrint` of 投影 produces none; and the current repository produces
none. `flutter test` keeps every five-state, capability-gate and refusal test
that already covered these surfaces, now reading the new copy.

# 0094 · Launch device-round findings: round lock, open-round wording, history row

## Status

Accepted 2026-09-27. Follows the first device purchase on the Launch testnet
(sale 5, `docs/acceptance/2026-09-25-launch-testnet-device-plan.md`, IMG_8312).
Extends 0088, 0089 and 0091.

## Context

On the device the review and the chain both said Round 1 while the round list
highlighted Round 2 as 「已选择」. The selector stayed tappable while the intent
was being prepared (and while an approval was polling), and the highlight was
the page's own selection, not the prepared intent's round. The detail page's
「我的资格」 and 「我的参与记录」 rows were fixed sentences that never read their
resources.

## Decision

1. `launch-trade`: the round selector is locked while the purchase intent is
   being prepared, while one is prepared, signed or broadcast, and while an
   approval is preparing or polling. The highlight is the prepared intent's
   `roundId`, and a line 「本次认购：Round N」 names it. Only 「重新报价」
   (discard) unlocks it; a broadcast attempt is never discarded.
2. `launch-trade`: once the wallet has broadcast (or its outcome is unknown) a
   line at the top of the page says 「已广播，等待链上索引」 while the server's
   intent is `submitted`, and 「已广播 · <state label>」 once it moves.
3. Open round: only the OpenAPI open branch counts — eligibility `result` with
   `status: available` and an all-zero `allowlistRoot`. `launch-detail` then
   says 「公开轮 · 无需资格」 and `launch-tier` says 「公开轮」 /
   「本轮公开，任何钱包都可参与。」. A pending result keeps 「待确认」; nothing is
   inferred from the mode or from the detail's round list.
4. `launch-detail` 「我的参与记录」 reads `GET /v2/launch/{id}/history` through
   the same controller as `launch-history`: indexed with purchases →
   「N 笔认购 · 最近 <time>」; indexed and empty → 「暂无记录（已索引到区块 X）」;
   unavailable, loading or failed → the existing reminder.

## Consequences

- The page can no longer show one round while the intent, the signing sheet
  and the chain use another; the lock is enforced by the row having no tap
  handler, not by a check after the tap.
- The detail page makes two more reads (eligibility, history). Each fails on
  its own and falls back to its existing sentence; neither blanks the record.
- Tests: `test/s83c4_launch_device_findings_test.dart`.

## Open

When `tierModeV1` is not confirmed the server answers `TIER_MODE_PENDING`
without evaluating the round, even when its on-chain root is zero, so an open
round under an unconfigured mode still reads 「待确认」. Evaluating open roots
regardless of mode is a loop-api decision.

# Providerless Security Activity Facts

## Summary

The ordinary `/home/security` route reported a positive account-security
summary and weekly event counts in every post-login session even though LOOP
had no wallet-policy or account-event source for that page. Users could be told
that MFA was active, no new device signed in, an approval was blocked, and no
urgent action existed without any supporting evidence.

## Root Cause

The broad UI prototype treated security examples as final copy. The route was
guarded by login but did not distinguish Development Preview from production,
and it had no domain state for unavailable evidence. A logged-in session was
therefore mistaken for authority over unrelated MFA, device, approval, and risk
facts.

## Detection

A Home surface audit traced every displayed security value to constants in
`home_screens.dart`. Repository search found no approved B9 event DTO, wallet
policy adapter, account-event gateway, source timestamp, freshness rule, or
provider capable of producing the claims.

## Prevention

- Production Security Activity renders only a provider-unavailable state until
  a reviewed source and contract are connected.
- Missing production evidence never becomes zero, safe, MFA-enabled, blocked, or
  `No urgent action`.
- Layout examples are restricted to explicit Preview and remain visibly marked
  `开发预览` / `演示数据`; they have no provider action or risk score.
- Dedicated widget tests cover both session modes. Harness source/evidence
  fingerprints and mutations reject fixture leakage, lost labels, fake actions,
  and hollow tests.

## Evidence

- `test/home_discovery_and_security_test.dart`
- `docs/decisions/0026-bound-home-discovery-and-security-facts.md`
- `scripts/check_harness.py`
- `tests/test_check_harness.py`

# Providerless Home Portfolio Facts

## Summary

Production Home and Net Worth displayed static totals, gains, charts,
allocations, unread counts, alerts, approvals, and activity times without an
account portfolio or activity source. Preview labels described the values as
fixtures, but the fixtures still appeared in ordinary authenticated sessions
and could be mistaken for the signed-in user's account.

## Root Cause

The broad UI prototype was mounted as one unconditional post-login layout.
Authentication was treated as evidence for unrelated portfolio and activity
facts, while the valid Privy wallet-identity projection was not separated from
balance, asset, allocation, and net-worth authority. Net Worth also relied on
Home navigation rather than enforcing its own session boundary.

## Detection

A source audit traced every B1/B2 monetary and activity value to local
constants. Repository search found no production portfolio, balance,
allocation, or cross-product activity port capable of producing them. The only
reusable account projection was `WalletReadiness`, whose contract explicitly
states that a complete wallet address proves identity only and does not prove a
balance or asset set.

## Prevention

- Production B1 and B2 render unavailable states until reviewed owner-scoped
  portfolio and activity sources exist.
- Wallet identity is not balance evidence. Wallet readiness must never enable a
  total, allocation, gain, chart, alert, approval, count, or freshness claim.
- Static portfolio and activity examples remain inside exact Development
  Preview and are visibly labelled before their facts are rendered.
- B2 enforces the same boundary on a direct route instead of trusting that the
  user arrived through B1.
- No refresh, retry, loading, empty, or failure state is inferred when no
  request source exists.
- Dedicated widget evidence and Harness mutations reject Production fixture
  leakage, a broadened Preview gate, wallet-identity escalation, and hollow
  tests.

## Evidence

- `docs/decisions/0037-bound-home-portfolio-and-net-worth-facts.md`
- `test/home_portfolio_truthfulness_test.dart`
- `test/app_navigation_test.dart`
- `scripts/check_harness.py`
- `tests/test_check_harness.py`

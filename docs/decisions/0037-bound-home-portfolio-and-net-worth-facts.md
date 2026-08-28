# 0037 Bound Home Portfolio and Net Worth Facts

## Status

Accepted on 2026-08-28.

## Context

B1 `/home` and B2 `/home/net-worth` rendered the same static portfolio
examples in every post-login session. A production user could therefore see an
invented total, daily change, chart, wallet/stablecoin allocation, Watchlist
movement, unread count, approval, alert, and activity time even though LOOP had
no portfolio, balance, allocation, or cross-product activity source for either
surface.

Privy can confirm the current session and, for a fully verified session, the
identity of one Embedded Ethereum wallet. That identity does not report an
asset balance or authorize LOOP to calculate net worth. Public Spot prices,
Wallet Preview assets, retained Perp code, and other feature fixtures cannot
fill the missing account source.

## Decision

- B1 and B2 read the explicit LOOP session mode. Production renders portfolio,
  net-worth, allocation, and cross-product activity as unavailable while their
  reviewed sources are absent. Missing evidence is not zero balance, an empty
  portfolio, a request failure, or an all-clear activity state.
- A fully verified current-session Privy wallet may project wallet-identity
  availability only. Restricted, walletless, and invalid-address sessions stay
  distinguishable and fail closed. Wallet identity is not balance evidence.
- Static totals, gains, charts, allocations, Watchlist movement, unread counts,
  alerts, approvals, activity times, named Preview groups, and named Preview
  rooms remain inside exact Development Preview only. The Preview boundary is
  visibly labelled `开发预览` / `演示数据` before those facts appear.
- Existing neutral navigation may continue to open its owning destination, but
  Home does not summarize that destination with an invented account fact. A
  production Audio Room entry remains generic because room selection is
  backend-owned.
- No portfolio, balance, allocation, or cross-product activity request is
  added. This slice adds no gateway, backend route, SDK, dependency, refresh,
  retry, polling, loading state, persistence, or private provider read.

## Consequences

Production Home remains useful as a truthful availability and navigation
surface without presenting the Preview portfolio as the signed-in user's
account. Net Worth can be opened directly and still fails closed independently
of Home. Development Preview keeps the visual examples needed for UI review,
but its values cannot cross the exact Preview session boundary.

A later portfolio integration requires a separately reviewed owner-scoped
contract, freshness model, decimal-safe values, loading/empty/error semantics,
and refresh policy. This decision does not pre-authorize any of them.

## Evidence

- `lib/features/home/home_screens.dart`
- `lib/features/wallet/wallet_readiness.dart`
- `test/home_portfolio_truthfulness_test.dart`
- `test/app_navigation_test.dart`
- `scripts/check_harness.py`
- `tests/test_check_harness.py`
- `docs/failures/providerless-home-portfolio-facts.md`

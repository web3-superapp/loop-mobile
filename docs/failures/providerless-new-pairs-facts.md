# Providerless New Pairs Facts

## Summary

authenticated production sessions could open C10 and see static BTC, ETH, and
SOL pairs described as recently observed, including fixture ages and a hidden
candidate count. No approved listing-time source supplied those facts.

## Root Cause

`NewPairsScreen` defaulted its public constructor to
`MarketSnapshotState.preview`. The application route constructed that default
screen directly, so route availability and a visible Preview banner were
mistaken for an adequate fixture boundary. The page did not derive fixture
authority from the exact current session.

The nearby public Spot source made the failure easier to overlook, but its
response contains price and volume discovery facts, not listing time. Client
receipt time and first local observation were also unsuitable substitutes.

## Detection

A real authenticated `LoopApp` navigation test previously required the BTC
fixture to appear under `/market/new`. Source inspection confirmed that both
authenticated and authenticated-unverified modes took the constructor's
Preview default. Focused widget tests now fail if either production mode renders
fixture identity, age, count, Preview labels, inferred empty/loading state, or
performs a Market/Candle request.

## Prevention

- Make the exact Preview session the sole fixture selector inside C10 itself.
- Do not accept caller-provided Preview state or route-derived fixture identity.
- Treat absence of a listing-time source as unavailable, never as empty,
  offline, stale, safe, or no-new-pairs evidence.
- Keep the C1 fixture shortcut rail inside the same exact Preview boundary.
- Let Preview cards return only to bare `/market`; only an admitted public Spot
  row may construct a concrete `spotIndex` route.
- Retain source/test fingerprints and mutation checks for selector broadening,
  route injection, production fixture restoration, lost labels, false empty
  state, invented Spot identity, and hollowed behavior evidence.

## Evidence

`test/new_pairs_truthfulness_test.dart`, the corrected authenticated navigation
test, decision 0038, and `check_new_pairs_preview_truth_contract` jointly prove
the exact Preview session boundary and the zero-request production behavior.

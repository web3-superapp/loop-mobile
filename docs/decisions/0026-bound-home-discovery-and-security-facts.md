# 0026 Bound Home Discovery and Security Facts

## Status

Accepted on 2026-08-27.

## Context

Home Global Search accepted text input but always rendered the same ETH and
group suggestions. Those fixtures also appeared in authenticated production
sessions, including a static price with no market identity or source. Home
Security Activity was more serious: without any wallet/account event source it
unconditionally claimed that MFA was active, no new device had signed in, an
unlimited approval had been blocked, and no urgent action was needed.

The current frontend phase is allowed to finish deterministic local behavior,
but it is not allowed to invent a production search index or security-event
contract. Existing public Hyperliquid discovery admits exact provider markets
only from its own snapshot, while Preview Chat navigation already requires an
exact registered conversation ID.

## Decision

- Global Search reads the explicit LOOP session mode. Authenticated and
  authenticated-unverified production sessions render one source-unavailable
  state and no Preview result.
- Explicit Development Preview filters one fixed, bounded process-local set:
  an ETH example, the exact registered group, and the exact registered direct
  person. Queries are trimmed, case-folded, split on whitespace, and require
  every non-empty token to match one target's local search text.
- Empty input shows the bounded suggestions, no-match input shows an explicit
  empty state, and Clear restores the initial set. No provider request, search
  history, analytics, persistence, Stream message mirror, or private index is
  created.
- The ETH example opens the public Spot ledger at `/market`; it does not guess
  a `spotIndex` or present a price. Preview group/person navigation uses the
  exact registered conversation locations.
- Security Activity also reads explicit session mode. Production renders one
  unavailable state until a reviewed wallet/account event authority, schema,
  freshness rule, and detail contract exist.
- Preview may retain a facts-layout example only while the page, section, and
  fixture boundary remain visibly labelled `开发预览` / `演示数据`. It performs
  no provider request, computes no risk score or all-clear, and exposes no
  Revoke, Block, or other account action.
- The Home approval example opens the bounded Security Activity surface so B9
  remains reachable without implying that its Preview row is provider truth.

## Consequences

B4 now has complete providerless Preview interaction but not production global
search. B9 now has a truthful production boundary and a Preview layout, but not
production security activity. A future public Spot search may reuse an already
accepted snapshot and exact `spotIndex`; a future group/person or security
source requires its own reviewed adapter and decision.

The Home discovery/security Harness owns the bounded Home entry, Search,
Security, and application-route source slices plus their dedicated behavior
evidence. The Chat exact-conversation Harness continues to own the registry,
Preview message routes, and production Stream CID path rather than
fingerprinting the whole Home Search implementation.

## Evidence

- `test/home_discovery_and_security_test.dart`
- `test/chat_preview_conversation_identity_test.dart`
- `test/app_navigation_test.dart`
- `scripts/check_harness.py`
- `tests/test_check_harness.py`

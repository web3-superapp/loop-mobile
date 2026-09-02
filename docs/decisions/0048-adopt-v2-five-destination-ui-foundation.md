# Adopt the V2 Five-Destination UI Foundation

## Status

Accepted on 2026-09-02.

## Context

The approved V2 product handoff and backend module roadmap replace the former
six-destination information architecture. The backend will deliver D0 and D1
first through a frozen `/v1` boundary and a new `/v2` contract, while the
Flutter client can advance presentation work that does not depend on those new
responses.

The existing Flutter application already contains useful Privy, Stream,
social, Profile, Wallet-identity and public Hyperliquid Testnet Spot slices.
Those implementations must not be discarded or relabelled as V2 backend
capabilities. Community discovery, Mining and the future BSC Market remain
without reviewed V2 facts.

## Decision

- Replace the primary navigation with Community, Mining, Launch, Market and Wallet,
  in that order. Community is the post-authentication and unknown-route
  home. Profile remains a major product domain but is opened as a child surface
  from Community rather than occupying a bottom-navigation slot.
- Keep official Stream Chat and the existing social routes as Community child
  flows. `/chat` remains a supported deep link but is not a primary
  destination. It must retain the existing Stream and backend truth-source
  gates.
- Mount Launch at `/launch`. Preserve `/home` and `/launchpad` only as
  compatibility redirects to `/community` and `/launch`; do not maintain two
  primary destinations for either concept.
- Add Community and Mining UI-first entry screens without fixture facts.
  Community may route to already implemented Chat, friend, group, Audio Room
  and Profile surfaces, while Community feeds, discovery and recommendations
  remain explicitly unavailable pending D3 and later modules. Mining remains
  explicitly unavailable pending backend D19 and its reviewed prerequisites.
- Adopt the V2 Lime Ledger color foundation: Ink `#050604`, Lime `#B8FF20`,
  Chalk `#F3F5EF` and Graphite `#171A16`. Keep temporary semantic aliases for
  existing widgets so the visual migration can proceed in bounded slices.
  Font assets are not fabricated; Sora, Noto Sans SC and IBM Plex Mono require
  separately licensed repository assets before they can be claimed as shipped.
- Keep the current public Hyperliquid Testnet Spot ledger mounted temporarily
  as a truthful Development read-only source. It is not BSC Market, does not
  implement D10/D11, is not reused for Swap, and receives no new product work.
  Its eventual replacement requires a separate backend-contract migration.
- Keep the existing 103-surface catalog as legacy migration inventory during
  this first UI-foundation slice. It is not evidence that the V2 93-route
  catalog is complete. Catalog replacement proceeds module by module after
  route ownership and acceptance evidence are available.
- Keep Pay as a truthful unavailable child of Wallet. The reviewed backend V2
  roadmap maps Pay to D21; this slice adds no scanner, camera request, payment
  details, quote, signing, or transaction behavior.
- Do not call, mock or pre-empt the backend D0/D1 `/v2` contract in this slice.
  Existing authenticated adapters remain on their reviewed `/v1` contracts
  until the backend handoff includes OpenAPI, error matrix, deployment URL,
  test data and device checklist.
- Preserve every existing security, identity, Stream truth-source, decimal,
  idempotency, Preview-labelling and provider-device verification boundary.

This decision supersedes only the six-primary-destination and `/launchpad`
placement statements in decisions 0001, 0016 and 0027, plus the
six-destination Shell wording in decision 0036. Their native, Spot-only,
Launch truthfulness, chart isolation and provider-boundary decisions remain
active.

## Consequences

The client can look and navigate like the approved V2 product before D0/D1 are
ready, while unavailable modules remain honest. Existing Chat and Profile
functionality stays reachable without presenting either as a sixth tab.

Old `/home` and `/launchpad` links remain safe, but tests and Harness rules now
target the five-destination contract. The full 93-route migration, Community
facts, Mining facts, BSC Market and D0/D1 integration remain later delivery
packages rather than implied completion.

## Verification

- Widget tests cover all five destinations, Community child actions, Mining's
  unavailable state, Profile's child-route placement and compatibility
  redirects.
- Theme tests lock the four canonical V2 colors and navigation contrast.
- Harness checks lock destination order, required UI files and this decision.
- Routine verification is format, analyze, Flutter tests and both Harness
  commands. Android Debug compilation remains a feature-checkpoint gate; no
  provider or physical-device result is inferred from compilation.

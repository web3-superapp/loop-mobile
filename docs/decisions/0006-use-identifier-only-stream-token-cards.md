# Use Identifier-Only Stream Token Cards

## Status

Accepted on 2026-08-25.

## Context

The product prototype includes token cards inside chat messages. A Stream
message is durable history, while price, liquidity, ownership, contract facts,
risk signals, provider URLs, watch state, and trading eligibility all change
after that message is sent. Persisting those values in Stream would make stale
facts look authoritative and would tempt historical-message rendering to run an
unbounded request for every card.

The legacy prototype already supplies a small versioned reference shape:
attachment type `token_card`, schema `token_card.v1`, and the asset, chain,
contract, and snapshot identifiers. Stream Chat's official Flutter UI supports
custom attachment builders without replacing its controller, pagination,
message list, persistence, ACK, or read-state ownership.

Several legacy conversation and preview routes also remained reachable from
the production router. They rendered named fixture users, messages, members,
search results, and token facts even though the production Stream session was
not their source of truth.

## Decision

- Register one `LoopStreamTokenCardAttachmentBuilder` and one
  `LoopStreamTokenCardMessagePreviewFormatter` in the root
  `StreamChatConfigurationData`. Official `StreamMessageItem` rendering remains
  the full-message path, compact message/draft previews use fixed safe labels,
  and Stream remains the sole message/history source.
- Accept only attachment type `token_card`, schema `token_card.v1`, and exactly
  five `extraData` keys: `loop_schema`, `asset_id`, `chain_id`, `contract_id`,
  and canonical millisecond UTC `snapshot_at`.
- Intercept any message containing a raw `token_card`, even when Stream's
  computed type would classify it as a link preview. Missing, additional,
  malformed, mixed, repeated, unknown-version, or standard top-level
  title/text/media/URL/action fields fail closed as unsupported and reveal none
  of their supplied values.
- Define the compliant producer/server wire contract as identifier-only.
  Mutable facts, URLs, risk claims, watch state, and executable actions are
  forbidden in that contract; receive validation hides violations but cannot
  prove what Stream already stored.
- Keep attachment rendering synchronous and side-effect free. It performs no
  per-message request and owns no message mirror, pagination, cache, or second
  persistence layer.
- Until a separately designed backend facts projection provides attributable,
  freshness-bounded data, a valid production reference displays `Current facts
  unavailable` and exposes no Buy or Watch control.
- Preview facts remain local fixtures labelled `开发预览` and explicitly state
  that they are not provider responses. They cannot mutate watch state or
  initiate trading.
- Guard legacy group, direct-message, group-information, request, search, and
  token/facts preview routes with `ChatPreviewRouteGuard`. Only the explicit
  Preview composition root may mount them; production chat uses the
  server-authorized Stream inbox and CID route.
- Keep outgoing Token Card composition disabled until a backend or Stream
  before-send policy enforces this complete wire shape. Receiver-side rejection
  protects rendering but cannot prove that malformed fields were never stored.

## Consequences

- The app can finish and verify Token Card layout, malformed/unavailable states,
  narrow-screen behavior, Dynamic Type, and official Stream builder wiring
  while the backend proceeds independently.
- Historical scrolling remains bounded by the official Stream controller and
  does not become an N-request enrichment workload.
- Production cards deliberately show less information until the backend facts
  contract exists. The next enrichment slice needs source attribution,
  freshness/expiry semantics, bounded caching and error clearing before it may
  display any fact.
- Enabling production sending requires a separately reviewed producer contract
  and server-side validation; the current app only renders received references.
- A future Buy entry must hand off to the existing canonical review and
  backend-mediated intent flow. Stream attachment data can never authorize or
  execute a trade.

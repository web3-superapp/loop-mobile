# Bind Wallet Local Drafts to Exact Snapshots

## Status

Accepted on 2026-08-26.

## Context

The transfer backend remains default-closed and publishes no successful
review, signing, submission, or reconciliation DTO. Its only stable amount
rule is an exact positive decimal String with a 128-character bound. Flutter
previously used `Decimal.tryParse` alone, which also admitted leading zeros,
signs, exponent notation, and other strings outside that rule.

The providerless Swap layout also kept validity in one Boolean while the input,
output card, route details, and Signing Review each held separate literals.
Editing `0.50` to `0.75` invalidated the Boolean but Reset did not restore the
controller, and a review could still describe the old amount. This was a local
truthfulness defect, not authorization to invent a provider quote.

## Decision

- Model the one known transfer amount lexical rule as `TransferAmount`:
  `String`, 1 through 128 characters, and exact pattern
  `^(?:[1-9][0-9]*(?:\.[0-9]+)?|0\.[0-9]*[1-9][0-9]*)$`. Parse the accepted
  String once more with `Decimal` and require a positive value, but retain only
  the original wire String. Never normalize it through `double`,
  `Decimal.toString()`, trimming, or exponent conversion; `1.2500` remains
  `1.2500`. Require the regular-expression match to consume the complete source
  String so trailing line separators cannot exploit end-anchor behavior.
- Do not let the input widget enforce the 128-character limit by truncation.
  Preserve the complete pasted value in the controller and let the model reject
  it, so an invalid 129-character source cannot silently become a different
  valid 128-character amount.
- Treat that check as local syntax only. It does not establish balance, asset
  precision, minimums, fees, recipient validity, name resolution, network
  support, screening, or a backend canonical intent. Do not invent per-network
  recipient regular expressions while those contracts are absent.
- Open each local transfer review through a synchronous single-flight gate.
  One tap burst creates one local Preview revision and one route entry. That
  revision is not a transfer idempotency key and is never sent to a backend.
- Replace the Swap validity Boolean and distributed literals with the
  closed-set immutable `SwapPreviewSnapshot.demo`. The input, receive card,
  quote card, typed quote-details route, and local Signing Review all consume
  that same object.
- Any Swap input edit drops the snapshot and hides every derived output and
  route entry, even when the user manually types the original value again.
  Explicit restore updates the text controller and snapshot in one state
  transition. The quote route fails closed without the exact typed snapshot.
- Swap review navigation is also single-flight. The snapshot may derive only a
  local Preview `SigningIntent`; `IntentOrigin.backendCanonical`, wallet
  handoff, provider requests, signing, and submission remain unavailable.

## Consequences

Wallet can exercise exact draft editing and review navigation without claiming
that a provider validated or accepted anything. A later transfer adapter can
reuse `TransferAmount.wire` for the known field, but it must still implement the
future backend DTO and every missing policy behind an integration boundary.

No HTTP route, transfer DTO, quote provider, balance read, wallet action,
successful transaction state, or reconciliation behavior is added by this
decision. Preview amounts remain visibly labelled `演示数据` or `开发预览`.

# Close Providerless Wallet Controls

## Status

Accepted on 2026-08-26.

## Context

Several B-priority Wallet Preview surfaces were visibly labelled but did not
preserve their own local truth. Transaction History chips changed selection
without filtering any rows, the Networks testnet switch changed no content,
and App Permissions exposed an enabled revocation-review button even though it
could only show a snackbar. A naked Bridge progress route also manufactured a
particular route and two completed steps without carrying the Preview route
that supplied those facts.

These are application-behavior defects, not permission to infer provider
capabilities. There is still no wallet-history, allowance, revocation, bridge,
network-health, transaction-result, signing, or reconciliation adapter.

## Decision

- Keep Transaction History as labelled `演示数据`, but model its closed-set
  activities and filter categories explicitly. A selected filter renders only
  its matching rows and removes empty date sections.
- Make the Networks testnet switch a display-only filter. It may reveal the
  labelled Hyperliquid Testnet environment row, but that row states that public
  Market reads are not Wallet network support. The switch never changes build
  policy, RPC configuration, portfolio value, or transaction capability.
- Keep the allowance examples visible, but disable revocation. The page does
  not claim that an allowance or balance was read and has no enabled action
  until a provider-backed review and canonical signing path exist.
- Put every Bridge route and progress fact in the closed immutable
  `BridgePreviewSnapshot.demo`. The status route requires that exact typed
  process-local object. A naked, restored, or wrong-type route returns to the
  Bridge start and invents no provider reference or progress.
- Bridge progress variants are local layout demonstrations derived from the
  same snapshot. They never become provider state, enable claim, refresh a
  route, sign, submit, or report a receipt.
- Keep Transaction Result as an explicit state-layout Preview. Even its
  success example continues to state that no transfer occurred, the
  transaction was not submitted, and there is nothing to inspect.

## Consequences

Mounted providerless controls now either cause the exact labelled local UI
change they promise or are disabled. Critical Bridge continuation state cannot
be restored from a URL alone, and no control is presented as evidence of a
provider request.

This change adds no HTTP request, wallet action, chain query, bridge provider,
RPC configuration, transaction DTO, signing handoff, success result, or
reconciliation behavior.

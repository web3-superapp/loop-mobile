# Mount Privy Wallet Readiness Without Enabling Funds

## Status

Accepted on 2026-08-26.

## Context

The official Privy 0.10.1 integration already restores the first Embedded
Ethereum wallet and can create it for a fully verified account. Creation is
bound to the expected Privy principal, single-flight inside the SDK adapter,
reconciled after an ambiguous provider result, and rejected if the account,
gateway, or wallet state changes while the request is pending. The mounted
Wallet tab did not consume that state: it showed only labelled fixtures, the
Receive page exposed no address, and Manage wallets showed two sample wallet
identities.

Wallet existence is narrower than transaction readiness. The app still has no
provider-backed balance read, supported funding policy, canonical transfer or
swap intent, simulation, final Privy authorization, broadcast result, or
reconciliation. In particular, wallet identity is not deposit or signing authority.

## Decision

- Derive a Wallet feature projection from `LoopSessionState`. It exposes only
  Preview, restricted, needs-wallet, ready, or invalid-address presentation
  state plus a complete Embedded Ethereum wallet address. It never exposes a
  Privy DID, access token, refresh token, SDK object, or wallet secret.
- Permit wallet creation only from a fully verified current session and reuse
  the existing principal-bound `LoopSessionController.createWallet()` path.
  Local UI state prevents duplicate taps and shows only sanitized provider
  errors. Preview and authenticated-unverified sessions perform zero creation
  calls.
- Accept an address for display and clipboard use only when it is exactly
  `0x` followed by forty hexadecimal characters. Preserve the provider value
  without shortening it. A malformed value stays hidden and cannot be copied.
- Make clipboard success truthful: render the address as non-selectable text,
  copy only through the guarded button, and show a success message only after
  the platform write succeeds. Revalidate the session around the write and
  warn if the wallet changes; native selection menus must not bypass that
  current-session check.
- Remove fixture identities from Manage wallets. It may show only the first
  current Privy Embedded Ethereum wallet; additional wallets, signing policy,
  and recovery remain unavailable.
- Keep Receive identity-only. No QR code, network selector, supported-asset
  claim, funding instruction, or deposit-success claim is inferred from an
  address. The page explicitly states that receiving is not enabled.
- Keep balances, assets, activity, and approvals visibly labelled `演示数据`
  or `开发预览`. Rename local Send and Swap entries as previews. Wallet
  creation does not change `WalletSigningGateway`, which stays unavailable for
  production canonical review.
- Redirect incomplete `/wallet/send/to` and `/wallet/send/confirm` deep links
  to asset selection instead of silently constructing a default ETH draft.
  Local transfer and swap drafts remain blocked even if a test injects an
  available signing gateway.

## Consequences

The App can now prove whether the current verified Privy account has its first
Embedded Ethereum wallet and can copy that exact public address without a LOOP
backend. It still cannot prove a balance, deposit route, supported network,
quote, simulation, transaction, or signature. Real Privy creation and
clipboard behavior remain device-verification items; deterministic tests are
application evidence only.

No new failure-memory record is needed. The existing
`principal-agnostic-wallet-single-flight` record covers the recurring
cross-principal risk, while this decision and the Harness add executable UI,
clipboard, SDK-ownership, QR, deep-link, and signing-boundary guards.

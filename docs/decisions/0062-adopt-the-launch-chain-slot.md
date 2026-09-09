# 0062 · Adopt the Launch chain slot: two named chains, one of them a testnet

## Status

Accepted 2026-09-09. Extends decisions 0057 (chain / market / wallet read),
0058 (Launch catalogue) and 0059 (money actions). Consumes loop-api decision
0038 and the contracts in `docs/frontend-v2-chain-api.md`,
`docs/frontend-v2-wallet-api.md` and `docs/frontend-v2-launch-api.md`.

## Context

The Launch contract will live on the BSC testnet (`eip155:97`) for a while
before it moves to the main chain. Everything else — the wallet, the asset
registry, market data, Swap, Send, approvals, the indexer and the watchlist —
stays on `eip155:56` and does not move at all.

Before S9 the client treated `eip155:56` as a constant. `chain_contract.dart`
told the owner that "本步只支持 eip155:56"; the Launch transport parsed
`chainId` as an enum of exactly one value; the wallet balances projection had
no place for a second chain; and `SigningIntent` carried no chain at all, so
the payload's own `chainId` was the only thing that decided where a signature
would land.

The backend publishes the slot in three places and **omits all three while the
Launch slot equals the primary chain**: `GET /v2/chain/status.launchChain`,
`GET /v2/wallets/{id}/balances.launchChain` and the `launch` capability's
`evidence.launchChainId`. Absence is therefore a meaning, not a null.

## Decision

1. **Exactly two named chain slots, declared once.**
   `lib/core/chain/loop_chain_ids.dart` owns `loopPrimaryChainId`,
   `loopLaunchTestnetChainId`, `loopKnownChainIds`, `loopChainName` and
   `loopChainReference`. There is no chain list and no generic multi-chain
   support: a third chain id is an invalid payload everywhere it can appear.
   The identity is `core/` because signing, Launch and the wallet all read it;
   `features/chain/chain_models.dart` re-exports it for its existing callers.

2. **The three new fields are optional, and absent means "unchanged".**
   `LoopV2Contract.strictMapWithOptional` is the new strict decoder: every
   required key must be present, an optional key may be absent, and any other
   key is still an invalid payload. `LoopChainStatus.launchChain`,
   `LoopWalletBalances.launchChain` and
   `LoopV2CapabilityEvidence.launchChainId` are `null` exactly when the server
   omitted the key, so a build whose Launch slot is `eip155:56` parses byte for
   byte as it did in S5/S7.

3. **Each fact is checked against its own halves.** `launchChain.chainReference`
   must agree with its `chainId`; a `head` may only accompany `verified`; the
   `nativeBalance.assetId` must belong to the slot it was read on; an
   `unavailable` slot carries a reason and no figure, and an `available` one
   carries a figure and no reason. `evidence.launchChainId` may appear on the
   `launch` capability and nowhere else.

4. **The chain of a launch is the launch's own.** `LaunchSummary.chainId` is a
   closed enum of the two slots. A surface that has a launch record reads that
   record; the catalogue and `loop-stake`, which have none, read the chain the
   server published on the `launch` capability. Neither is inferred from the
   other.

5. **The badge is a statement of fact and never a blocker.** `LoopTestnetBadge`
   ("BSC 测试网") names the chain. On the Launch surfaces and the wallet's Launch
   block it is accompanied by one dismissible explanation, shared through
   `loopTestnetNoticeDismissedProvider` so it appears once per run rather than
   once per page; closing it changes nothing, because the badge stays, every
   action stays exactly as it was, and the five reviewed states are untouched.
   **The sign sheet carries the badge only.** A confirmation is not the place
   to read an explanation for the first time, and it must not grow a control
   whose only effect is to change the sheet while a signature is pending, so
   `LoopSignSheet` takes a `networkBadge` string and nothing else. Market,
   Watchlist, Swap, Send and approvals can never render any of it —
   `scripts/check_harness.py` fails if they reference the slot at all.

6. **The wallet's Launch block is one native balance, not a portfolio.** It
   exists only when the server published `launchChain`. It holds exactly one
   `eth_getBalance` result with its own snapshot; it is never added to the
   asset rows or to the net worth; a failed read renders the server's reason
   and never a `0`. The `networks` page gains one Launch row for the same
   reason, with no endpoint reference and no URL, because testnet endpoint
   health is not part of the contract.

7. **The signing intent carries its chain, and only a Launch intent may leave
   the primary chain.** `SigningIntent.backendCanonical` now requires
   `chainId`, carried verbatim from the server; `IntentKind.launchPurchase` is
   the one kind `chainIsPermitted` admits off the primary chain. Send, approve,
   revoke and swap are locked to `eip155:56` at three layers: the transport
   rejects any other `chainId` (and any `unsignedTransaction.chainId` but 56),
   `MoneyActionSigner.sign` refuses with `INTENT_CHAIN_NOT_PERMITTED` before
   the wallet opens, and `allowsWalletHandoff` is false so the boundary itself
   refuses.

8. **Privy cannot switch chains, so the device signer fails closed.**
   `privy_flutter` 0.10.1 routes every Ethereum call through
   `EmbeddedEthereumWalletProvider.request`, whose implementation
   (`real_embedded_ethereum_wallet_provider.dart`) accepts exactly six methods —
   `eth_sign`, `personal_sign`, `secp256k1_sign`, `eth_signTypedData_v4`,
   `eth_signTransaction`, `eth_sendTransaction` — and returns
   `Failure(PrivyException("Unsupported method: …"))` for anything else.
   `wallet_switchEthereumChain` and `wallet_addEthereumChain` are therefore
   unavailable, and no API on `PrivyUser`, `EmbeddedEthereumWallet` or the SDK
   root selects a chain. There is consequently no device evidence that the
   native side honours a transaction's own `chainId`.
   `PrivyDeviceSigner.sendTransaction` now takes the intent's `chainId`,
   refuses `privy_chain_mismatch` when the payload disagrees with it, and
   refuses `privy_chain_switch_unsupported` for any non-primary chain — before
   it looks at the session, so the refusal does not depend on being signed in.
   This is why S9 ships **no** executable Launch intent: the server answers
   `503 LAUNCH_CONTRACT_BASELINE_PENDING` and the device would refuse anyway.

## Consequences

- A backend that has not set `LAUNCH_CHAIN_ID` produces exactly the S7/S5
  client behaviour: no badge, no notice, no Launch block, no networks row.
- Launch can point at the testnet without any other module noticing: the
  primary chain block of `GET /v2/chain/status` is still validated as
  `eip155:56`, and a testnet failure never turns a main-chain read into a 503.
- A Launch signature is not possible in this build. When the 02 contract
  document lands, the missing piece is device evidence for chain selection —
  either a Privy SDK version that exposes it, or a signed, verified
  chain-specific path — plus the Launch intent projection itself. Until then
  `privy_chain_switch_unsupported` is the honest answer.
- Adding a third chain would mean editing `loopKnownChainIds`, which the
  harness guard makes deliberate rather than incidental.

## Alternatives rejected

- **A generic chain list.** The product has one chain plus one temporary
  Launch slot. A list would have to be rendered, ordered, and defaulted, and
  every one of those decisions would be invented rather than published.
- **Publishing `launchChain: null` when the slots match.** The backend chose
  absence so existing responses stay byte-identical; the client mirrors that
  rather than normalising it into a null, so "no Launch block" and "a Launch
  block that failed" cannot be confused.
- **Sending the transaction anyway and trusting its `chainId`.** Without a
  chain-selection call and without device evidence, a broadcast could land on
  whichever chain the wallet was already on. Nothing in the payload can prove
  otherwise, so the client refuses instead.

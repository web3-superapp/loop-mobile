# 0059 · Adopt the V2 money actions and make the signing exit real

## Status

Accepted 2026-09-09. Retires `/preview/signing-review`, the Preview transfer
draft, the `SwapPreviewSnapshot` quote projection, the Preview send-asset
search, the Preview approvals screen and the Preview transaction-result
layout. Moves `approval-guard` from `/preview/approval` to
`/wallet/approval-guard`.

## Context

Step 6 (S6) connects `loop-api` decision 0035 — the `sendApprovals` and `swap`
module gates — and rebuilds eight frozen-prototype pages (`send`, `send-to`,
`send-confirm`, `swap`, `swap-route`, `approval-guard`, `approvals`,
`tx-result`) plus the real `sign-sheet-states` layer on the step-1 component
library.

Until this step the signing exit was a shape. Every wallet page assembled its
own draft, handed it to a review surface, and the wallet adapter refused it —
which was honest, but it meant the one rule that matters for money had never
been enforced by anything but a comment: *the fields the owner reads and the
payload the wallet signs must be the same object.*

Five constraints shaped the result:

- **A client may not build a transaction.** The server owns the call data, the
  fee, the nonce and the pre-execution. The client's whole job is to show what
  the server built, hand it to the wallet unchanged, and report back what the
  wallet produced.
- **Two halves, one digest.** The intent resource carries `review` and
  `unsignedTransaction` (or `authorizationPayload`) as two projections of one
  canonical payload, bound by `reviewSha256`. A page that rendered one and
  signed the other would be the exact failure the sign sheet exists to
  prevent.
- **A wallet result is not an outcome.** `eth_sendTransaction` returning a
  hash means the device broadcast something. Whether it landed, reverted or
  vanished is the server's reconciliation to report — so the client never
  turns a wallet success into a completion.
- **Some outcomes are unknown, and unknown is not retryable.** A provider
  timeout, an unreadable wallet response and a lost report all leave a
  submission that may already exist on chain. The only safe action is to poll.
- **There is no simulator.** `simulation` is an RPC pre-execution of the exact
  payload, nothing more. Swap has no provider simulation at all this step, so
  every swap intent stops at `prepared` and cannot be signed.

## Decision

1. **Three strict transports under `lib/integrations/backend/v2/`.**
   `wallet_intents/`, `swap/` and `approvals/` parse with
   `LoopV2Contract.strictMap` against the frozen key set;
   `LoopV2IntentCodec` holds the shared decoders. An amount is kept in both of
   its exact forms — the raw minor-unit string the call data encodes and the
   display string — and `unlimited` stays a meaning, never a parsed number.
   The authorization payload and the unsigned transaction are validated and
   then rebuilt verbatim, key for key.

2. **`SigningIntent.backendCanonical` is the only wallet-bound constructor.**
   It requires a payload and the server's `reviewSha256`; the four local
   factories keep `IntentOrigin.localPreview` and therefore cannot satisfy
   `allowsWalletHandoff`. A preview object is refused at the wallet boundary
   itself, not merely hidden by a disabled button.

3. **`MoneyActionSigner` is the single path from intent to signature.** It
   checks the server's own permission (`canSignAt`), then cross-checks that
   the call data encodes the reviewed recipient/spender and amount
   (`payloadMatchesReview`), then hands the payload to the wallet, then hands
   what the wallet produced straight back to the server —
   `broadcast-report` for a device broadcast, `execute` for a provider swap.
   The state it returns is the server's. An unresolved report locks the intent
   rather than offering a second signature.

4. **Two signing modes, one exit.** Send, approve and revoke broadcast from the
   device through the Privy embedded wallet whose address matches the payload's
   `from`; swap signs the server's canonical wallet-API payload with
   `generateAuthorizationSignature`. `PrivyDeviceSigner` is deliberately
   separate from the auth gateway so an identity test double cannot gain the
   ability to broadcast.

5. **Every confirmation is gated on the server, plus the clock.** `signing.allowed`
   is never derived locally; expiry is the one thing the client evaluates, and
   it disables the button and offers a fresh prepare. Preparing a second intent
   for the same wallet expires the first, so an existing unsigned intent is
   surfaced and must be reported or cancelled first.

6. **The Swap confirmation waits on device evidence.** `privySwap.available`
   only means the backend is configured; `evidence.status = pending` keeps the
   confirmation closed and says so. The page still quotes, still counts down
   and still shows every figure.

7. **Unlimited approval is reachable, and expensive to reach.** The default is
   the exact amount this operation needs. Unlimited requires the guard's own
   warning sheet and a second confirmation, which travels as the server's
   `acknowledgeUnlimited` field; the canary ceiling is then enforced on the
   real exposure, `min(allowance, balance)`.

8. **`tx-result` is the only place a success may be announced.** It polls
   `GET /v2/wallet-intents/{intentId}` through all five states and fires a
   toast only on `confirmed`. `unknown` renders as a locked state that is
   polled and never resubmitted.

## Consequences

- `/preview/signing-review` is retired from the router and from
  `supplementaryPaths`; the retained Perp overview keeps its unmounted history
  but no longer points at it.
- `approval-guard` moves to `/wallet/approval-guard` with `/preview/approval`
  recorded as its legacy path.
- The capability enum tracks the contract's 31 ids; `security`, `settings` and
  `support` are listed for the parser even though no step consumes them yet.
- The shared failure taxonomy gains `insufficientBalance`, `simulationFailed`,
  `quoteExpired` and `submissionUnknown`; the last is an unresolved outcome, so
  its idempotency key is replayed rather than replaced.
- Recipient screening, approval risk facts, the platform fee, the slippage and
  price-impact policy, and the Privy BSC swap device evidence all remain
  explicit gaps with the server's own reason codes.
- `pay`, `bridge`, `bridge-status` and `dapp` stay unavailable for step 8.

## Verification

`bin/dart format`, `bin/flutter analyze`, `bin/flutter test`,
`python3 scripts/check_harness.py` and
`python3 -m unittest discover -s tests -p 'test_*.py'`. Device broadcast,
Privy swap quoting and the authorization signature remain unverified: they
require the canary wallet and a physical device.

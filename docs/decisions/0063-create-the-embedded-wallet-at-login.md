# 0063 · Create the embedded wallet at login, and tell "no wallet" from "not read"

## Status

Accepted 2026-09-10. Extends decisions 0057 (chain / market / wallet read) and
0062 (Launch chain slot). Consumes `GET /v2/wallets` from
`docs/frontend-v2-wallet-api.md` and the Privy embedded-wallet gateway in
`lib/integrations/privy/privy_auth_gateway.dart`.

## Context

The login page promises "登录后自动创建钱包，持仓即产生算力"
(`lib/features/account/privy_login_screen.dart`). The client did not keep that
promise. After a verified Privy login and a successful
`POST /v2/session/bootstrap`, nothing asked Privy for an embedded wallet. The
only creation call in the product was on the retired Perp account page
(`lib/features/perp/perp_account_screens.dart`), which decision 0016 unmounted
from navigation, so in practice no product path created a wallet at all.

The consequence was visible on the 2026-09-09 simulator pass. LOOP's backend
projects `GET /v2/wallets` from Privy, so an account with no Privy wallet gets
`200` with an empty list and `activeWalletId: null`. The wallet tab then read
`activeWalletId == null` and rendered
"钱包清单尚未读取成功，本页不展示任何余额." — which says the read failed. The
read had succeeded. It had answered "you own no wallet", and the page could not
tell the two apart, so it reported a failure that had not happened and offered
no way out of a state the owner could not leave.

`LoopChainResourceState` made the confusion structural: a successful read of an
empty directory is `phase: ready`, and `LoopChainStateBlock` renders
`SizedBox.shrink()` for `ready`. The section was therefore blank, and the only
sentence on the page was the folio's wrong one.

## Decision

1. **One creation path, called automatically once per verified principal.**
   `LoopWalletProvisioningController`
   (`lib/app/session/wallet_provisioning_controller.dart`) owns both entry
   points and funnels both into the existing
   `LoopSessionController.createWallet`, which calls the idempotent
   single-flight `PrivyAuthGateway.createFirstEthereumWallet`. No second
   creation path is added, and the Perp page's call is left exactly as it was
   because that page is unmounted.

2. **The automatic attempt is chained to a successful LOOP session, not to
   authentication.** `PostAuthBootstrapCoordinator` already runs one
   non-blocking bootstrap per newly accepted verified login; `lib/app.dart`
   now calls `ensureWallet()` after that bootstrap returns
   `LoopBootstrapAuthorization.authorized`. So the LOOP ID exists before the
   wallet does, and a backend outage produces no wallet request at all rather
   than a wallet the account cannot be told about.

3. **A wallet is never created for a session that may not own one.**
   `ensureWallet()` returns without touching Privy when the session is a
   development preview, is `authenticatedUnverified`, has no account, or
   already reports `account.wallet`. Preview must never reach a provider, a
   restricted session must never open a real wallet, and an account that
   already has one must never be asked for a second.

4. **A failed creation is a wallet fact, never a login one.** `ensureWallet()`
   cannot throw. A failure is recorded as
   `LoopWalletProvisioningStage.failed` with the provider's own sentence and
   changes nothing about the session: the owner stays signed in, lands on
   `community`, and finds the reason on the wallet page. Authentication has
   already succeeded and may not be undone by a wallet that did not open.

5. **A created wallet invalidates the directory it was missing from.**
   `GET /v2/wallets` is the server's projection of Privy, so a list read before
   the wallet existed is stale. On success the controller invalidates
   `walletDirectoryControllerProvider`, and the next wallet surface re-reads
   the list. `GET /v2/account/me` is deliberately **not** re-read: its
   projection carries only `accountId` and `streamUserId`, it holds no wallet
   fact, and the only way to re-issue it is to drop the cached bootstrap
   authorization — which would risk a working session to refresh two fields
   that cannot have changed.

6. **Three answers, three blocks.** `LoopWalletDirectory.isEmpty` states the
   third one. A wallet surface now distinguishes:
   - **the list was not read** — loading, error, offline, unavailable or
     permission, rendered by `LoopChainStateBlock` as before, and now saying
     "钱包清单还没有读到 · 这不是'没有钱包'，只是这次没有读到清单。";
   - **the list was read and holds no wallet** — the new `WalletCreationBlock`,
     which explains what LOOP will create and offers one 创建钱包 button;
   - **a wallet is active** — unchanged.

   The empty state is reachable only from `phase: ready` with a non-null
   directory, so a failed or unfinished read can never render it. A read list
   that names no active wallet is a fourth answer and gets its own sentence
   pointing at 我的钱包; it is not "no wallet" either.

7. **The button shares the automatic attempt's single flight.** It is disabled
   while any creation is in flight — including the one made at login — so one
   session can never open two wallets, and a failure renders the provider's
   sentence beside a button that stays available.

## Consequences

- A new account that completes login now owns an embedded wallet without
  having to find a button, and the login page's promise is kept.
- An account whose automatic attempt failed is not stuck: the wallet tab and
  我的钱包 both state why and offer the same call again.
- `GET /v2/wallets` returning `[]` can no longer be reported as a failed read
  anywhere in the product.
- The wallet tab's five reviewed states are unchanged; the empty state is a
  sixth block beside them, not a replacement for any of them.
- `WalletReadiness` (`lib/features/wallet/wallet_readiness.dart`) remains
  unmounted. It projects the same fact from the session alone, but the pages
  read the server's directory, which is the only thing that can distinguish an
  empty list from an unread one.

## Alternatives rejected

- **Creating the wallet inside the login flow, before bootstrap.** A wallet
  that exists while the LOOP account does not is a wallet the product cannot
  show, and a Privy failure would then sit between the owner and a session
  that was already valid.
- **Blocking login until the wallet exists.** Authentication succeeded. Making
  it conditional on a second provider call would turn one provider's outage
  into a sign-in outage.
- **Reusing the empty branch of `LoopChainStateBlock`.** That branch is
  unreachable for the directory — `failed()` is only ever called with a
  failure kind — and it carries no action. The empty answer needs a button,
  which is a different block, not different copy.
- **Rendering the two per-class empty lists on 我的钱包 for a fully empty
  directory.** "没有嵌入式钱包" plus "没有已连接的外部钱包" is two true
  sentences that together say nothing the owner can act on. They stay for the
  case they were written for: one class empty while the other is not.

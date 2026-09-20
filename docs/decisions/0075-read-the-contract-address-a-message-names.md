# Read the Contract Address a Message Names

## Status

Accepted on 2026-09-20.

## Context

The frozen prototype's `community-chat` shows a Token Card under a message
that pastes a contract address: identity, quote, a fixed 1H line, market cap /
liquidity / holders, the LOOP community, the contract facts, and four actions.
S4 could not build it — there was no facts projection and no way for the
client to say anything true about an address — so decision 0006 rendered every
chat Token Card as `unavailable` and the composer promised only 发消息.

Two things changed. `GET /v2/market/assets/{assetId}` is delivered, with per
fact source and observation time. And the backend now answers an address the
registry does not carry from a market provider
(`frontend-v2-market-api.md` §4a): the same document, `asset.status:
"unregistered"`, identity from a `provider_lookup` source, `swappable: false`
with `ASSET_NOT_REGISTERED`, and a ticker, a name and a precision that may all
be `null`.

Decision 0006's reasoning still holds for the *message*: a Stream message is
durable history, and a price stored in it would be authoritative and wrong a
minute later. What it ruled out was storing facts, not reading them.

## Decision

- Detect a BSC contract address in the message text at render time:
  `0x` + 40 hex, bounded on both sides so the first 40 characters of a 32-byte
  hash are not read as somebody's contract, lower-cased, de-duplicated, at
  most three per message. A `$TICKER` is never detected: two contracts can
  share a ticker, so a card opened from one would carry another asset's facts.
  The message is not rewritten and stores nothing.
- Read each address through the existing market port as
  `eip155:56:<address>`. The conversation holds one answer per address for 60
  seconds, so a scrolling history is not a request per frame, and the card
  states when the quote was observed.
- Render the prototype's card: symbol (or the address, when no provider
  reported a ticker), the short address or the chain, quote and 24h change,
  the 1H line through the shared Token Card sparkline, the three metric cells,
  the LOOP community or 暂无 LOOP 社区, the contract facts that state a
  mechanism — each with source and observation time, no verdict — and small
  print naming the registry status, the identity's provider and the quote's
  provenance.
- 买入 and 卖出 stay on the card and stay unpressable, gated by the same
  `privySwap` capability the wallet's funds row reads, with the reason in the
  card's own small print. 图表 opens the token route; 社区 opens the bound
  community or is shut. No chat card opens a signing entry.
- Every read state has a card: 识别中, the read card, 未收录的代币 for a 404,
  the prototype's 数据缺失 card carrying the server's reason for an outage or
  a closed capability, and an offline strip with a retry. A `429` states the
  wait and offers no retry to spend it on.
- Accept the unregistered shape in the codec rather than dropping it: a
  `provider_lookup` source with its own provider, freshness and quality; a
  null symbol, name and precision; a pool protocol that is the source's own
  dex id rather than LOOP's constant. A null precision means no raw quantity
  is formatted anywhere.
- The composer says 发消息 · 贴合约地址自动识别代币 in every conversation. It
  does not promise an assistant.
- Decision 0006 keeps the `token_card` attachment contract: a message still
  carries identifiers only, and a received attachment still renders no fact.
  Only the client's own read may put a figure on screen.

## Consequences

- A conversation can answer "what is this contract" without leaving it, and
  every figure on the card names where it came from and when it was seen.
- A card can now issue a request. It is bounded by the 60-second hold, by
  three cards per message, and by the conversation's own lifetime; the answers
  are dropped when the conversation is left.
- An unregistered address is shown with its facts and its status side by side.
  The card never reads as a listing, and it never offers a trade.
- Unregistered lookups count against a per-user quota. The client does not
  retry automatically and states the wait when the server asks for one.
- `LoopChainAsset.symbol`, `name` and `decimals` are nullable everywhere. The
  surfaces that printed them now print the address, or say the figure is not
  available, instead of an invented one.

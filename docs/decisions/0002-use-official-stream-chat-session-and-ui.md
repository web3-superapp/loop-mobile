# Use Official Stream Chat Session, Persistence, and UI

## Status

Accepted on 2026-08-24.

## Context

LOOP already locked Stream Chat/Persistence 10.3.0 and had a client-safe API key, but production communication still stopped at an unconfigured custom gateway. The explicit preview entry point used LOOP DTOs and memory fixtures, while the production app had no official client lifecycle, token refresh seam, persistence owner, channel controller, or message page.

The Loop backend is being implemented separately and does not yet provide the required backend-derived Stream user ID or short-lived token. Flutter must therefore become SDK-ready without deriving an identity, minting a token, using development credentials, or claiming a live connection.

## Decision

- Construct one active official `StreamChatClient` and `StreamChatPersistenceClient` pair per principal-bound provider value when the public API key exists. Rotate the entire pair when the opaque Privy principal changes, but perform no identity, token, or network work at construction time.
- Obtain the Stream identity and token only through a narrow `StreamChatSessionSource` supplied by the future Loop backend adapter. The default source returns no identity and fails closed.
- Use `connectUserWithProvider` so SDK token refresh stays behind the source boundary. Flutter widgets never receive or persist the token.
- Treat the Privy user ID only as an opaque principal-change key. The backend remains the sole owner of the Stream user ID mapping.
- Keep authorization, logout, and disposal generation-gated. An account switch or logout synchronously invalidates in-flight identity, token, and SDK connection waits and disconnects with `flushChatPersistence: false`.
- Bind each authorizer to one non-null principal and one backend Stream user ID. A different principal retires the instance; a changed Stream user ID for the same principal fails closed.
- Keep the principal-selected session provider active at the app root even when Chat is closed. Key the `StreamChat` scope by client identity so a rebuilt provider replaces the retired client.
- Use the official `StreamChannelListController`, `StreamChannelListView`, `StreamChannel`, and `StreamChannelPage` directly in production Chat. Do not project SDK channels or messages into LOOP preview DTOs.
- Query only `messaging` channels containing the current backend-derived Stream user. Use a bounded channel page (`limit: 20`, `messageLimit: 25`, `memberLimit: 30`) and the SDK's `last_updated` ordering and pagination.
- Carry only an encoded CID through global routing. Parse and resolve it to SDK types inside the Chat feature.
- Disable attachments and voice recording in the official composer until platform permissions and product/provider policy are configured. Text composition remains official Stream UI.
- Preserve the explicit memory-backed Chat experience only in Development Preview. Live Stream Video calls, Firebase push, background ringing, and secondary production communication surfaces remain unconnected.

## Consequences

- Stream is now the only production source of truth for channel/message state, pagination, delivery/read state, presence, typing, and offline synchronization.
- Supplying the API key alone creates no authenticated Stream connection. Until the backend session source exists, production Chat honestly renders an unavailable state.
- Per-user cached history survives logout/account switching. Because Stream 10.3.0 initialization is not fully cancellable, a late old operation may touch only its retired client/persistence pair; a completion reaper disconnects that pair again, and it cannot mutate the next principal's pair or complete as authorized.
- Native compile and unit/widget success prove integration shape, not provider connectivity. Real Chat still requires backend and two-user/two-device evidence.

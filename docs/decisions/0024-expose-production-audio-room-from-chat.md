# Expose Production Audio Room From Chat

## Status

> **Superseded in part by decision 0055 (2026-09-08).** Step 4 made every
> Audio Room a community resource with a server-owned locator, so the clause
> requiring one always-visible Audio Room entry in the generic Chat inbox no
> longer applies: an inbox has no community and therefore no room to open. The
> lobby is now reached from a community record, and decision 0005's provider
> evidence closes the page entirely while it is pending. Everything else in
> this decision — that the entry performs no provider operation, never selects
> or fabricates a room, and never renders preview room state — still holds.

Accepted on 2026-08-26.

## Context

The foreground Stream Audio Room lifecycle and `/chat/voice` production route
already existed, but the production Chat inbox exposed only authorization state
or Stream channels. Its Audio Room was reachable from notification routing and
Preview fixtures, not from the normal production Chat interface. This made an
implemented first-release capability appear absent and left its truthful lobby
hard to inspect while backend credentials were still unavailable.

Adding an entry must not turn a public Stream API key into an authenticated
session, select a room in Flutter, or fall back to the named Preview room and
members.

## Decision

- Keep exactly one visible `Audio Room` action in the production Chat app bar,
  across loading, unavailable, empty, and connected channel-list states.
- The entry performs no provider operation. It opens only `/chat/voice`, whose
  existing production composition selects `StreamVoiceRoomPage`.
- Stream Video authorization and the backend-owned room target remain separate
  gates. Without them, the lobby continues to show `Stream session unavailable`
  or `No authorized room assigned` and keeps Join disabled.
- The production path never falls back to `ETH Macro Room`, Preview members,
  simulated presence, or a client-selected call type or room ID.

## Consequences

Users can now discover and inspect the first-release Audio Room from the Chat
tab before provider integration is complete, while every join/media claim
remains fail-closed. The change adds no token source, room locator, Stream
request, member fixture, push behavior, background media, or new native
capability.


# Expose Production Audio Room From Chat

## Status

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


# 0025 Require exact Preview conversation identity

## Status

Accepted on 2026-08-27.

## Context

The legacy Development Preview already carried a conversation ID in every
summary and message-search result, but its navigation ignored that identity.
Inbox rows and search results selected a fixed group or direct-message page
from `ConversationKind`, while the memory gateway treated every non-direct ID
as the Glyph Hunters group. A missing, unknown, duplicated, or mismatched ID
could therefore display or mutate a different fixture conversation.

Production Stream Chat does not have this defect: it opens the official
channel route from the complete Stream CID. The fix must not replace, wrap, or
weaken that production path.

## Decision

- Keep the registered Preview paths `/chat/group`, `/chat/dm`,
  `/chat/group-info`, and `/chat/search`.
- Carry the exact local conversation ID in one URI-encoded
  `conversationId` query value. Missing, empty, repeated, control-containing,
  overlong, unknown, or kind-mismatched values fail closed.
- Resolve Preview message targets through one bounded allowlist. Page title,
  message provider, composer, group information, and conversation-local search
  all consume the same admitted identity.
- Global Preview message search remains available without a scope. A scoped
  search accepts only a registered message conversation; unknown and
  non-message targets fail rather than returning another conversation.
- Inbox and search result navigation consume the ID carried by their model.
  Unknown or mismatched results are non-navigable and never fall back by kind.
- The memory gateway returns `preview_conversation_not_found` for unknown
  message reads, sends, and scoped searches. A rejected send changes neither
  registered message list.
- The official production Stream inbox, `/chat/channel/:cid`, CID parser,
  persistence, and backend-authorized Audio Room target remain unchanged.

## Consequences

Preview links are slightly more explicit, and a bare legacy group or direct
deep link now shows an unavailable state instead of a fixture. This is an
intentional compatibility break for unbound Preview URLs. The paths remain in
the surface catalog and production Preview guard, so the product information
architecture and Stream route contract do not change.

Any future local Preview conversation must be deliberately registered and
tested. Adding another row without that registration produces an unavailable
interaction rather than silently aliasing an existing fixture.

## Evidence

`test/chat_preview_conversation_identity_test.dart` covers exact target
resolution, malformed query rejection, unknown gateway operations without
mutation, missing/unknown/mismatched deep links, conversation-scoped search,
non-navigable search results, same-kind Inbox decoys, and the truthful Home
global-search target. Harness source and mutation checks preserve the exact-ID
resolver, router propagation, gateway rejection, Inbox/search navigation, and
executable behavior evidence.

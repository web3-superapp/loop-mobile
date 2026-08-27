# Preview conversation ID fallback

## Summary

The Development Preview ignored conversation IDs when opening group and direct
message fixtures. An unknown ID could read or mutate Glyph Hunters because the
memory gateway used the group as its default branch.

## Root Cause

The first Preview contained one group and one direct conversation, so
`ConversationKind` appeared sufficient for navigation. The same shortcut was
used in the memory gateway: direct selected the direct list and every other ID
selected the group list. Search-this-conversation also opened a global search
because the route and gateway call dropped the current ID.

## Detection

Source review found that `ConversationSummary.id` and
`MessageSearchResult.conversationId` were never used by the old navigation,
and that `loadMessages` and `sendText` had a non-direct group fallback. An
adversarial same-kind conversation, an ID/kind mismatch, and an unknown send
made the substitution observable.

## Prevention

Preview message navigation now uses one exact allowlist and one URI-encoded
query value. Invalid route identities mount no messages or composer. The
memory gateway has explicit group/direct cases and an unknown failure branch;
scoped search carries the same admitted ID. Search results and Inbox rows that
cannot be resolved are non-navigable. Production Stream continues to use its
official full CID route.

Harness fingerprints close the resolver and reviewed behavior sources, while
mutations restore kind-only routing, gateway fallback, default route IDs,
dropped search scope, and hollow evidence to prove that each regression is
detected.

## Evidence

- `test/chat_preview_conversation_identity_test.dart`
- `test/chat_preview_route_guard_test.dart`
- `scripts/check_harness.py`
- `tests/test_check_harness.py`
- Decision `0025-require-exact-preview-conversation-identity.md`

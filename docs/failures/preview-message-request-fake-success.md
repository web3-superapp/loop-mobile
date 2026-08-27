# Preview Message Requests Claimed Provider Success

## Summary

The Development Preview Message Requests page said that Accept started a
conversation and that Report submitted moderation, although its memory gateway
only removed a fixture from a local list. The Chat Inbox also kept a fixed
request count after local resolution.

## Root Cause

The original Preview UI treated a successful in-memory mutation as evidence of
the provider-side effect that a future Stream or moderation adapter might
perform. Request IDs were not modeled as one-way pending state, so unknown and
already resolved IDs also returned success.

## Detection

A truth-source audit compared the page copy with
`MemoryCommunicationGateway`. It found no conversation creation, navigation,
sender interaction, moderation submission, or report transport. It also found
two hard-coded request counts in the Chat Inbox.

## Prevention

The memory gateway now transitions each exact fixture once from pending to a
local terminal resolution and fails unknown or repeated requests. The page
states that all effects are process-local `开发预览`, disables every action on a
request while it resolves, never navigates after Accept, and never claims that
a report was submitted. Inbox badges and labels derive from the pending
projection. Normalized source fingerprints close the reviewed page, memory
gateway, Inbox projection and executable evidence against equivalent cross-file
substitution; behavior tests and Harness mutations preserve those boundaries.

## Evidence

`test/chat_preview_message_requests_test.dart` covers gateway transitions,
unchanged conversations and messages, truthful Accept/Ignore/Report copy,
single-flight controls, dynamic counts, and the zero-request state. The
existing production Preview-route guard continues to prove that
`/chat/requests` cannot mount memory fixtures in production.

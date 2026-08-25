# Model Profile Presentation Before Its HTTP Adapter

## Status

Accepted on 2026-08-25.

## Context

The Profile edit surface currently changes local text fields and then always
announces `Profile changes saved.` without a persistence owner or provider
response. It also groups Bio and visibility with Alias even though the reviewed
backend Profile contract contains only a nullable Alias and nullable opaque
avatar reference. Privacy is a separate versioned resource, and no Bio contract
exists.

Decision 0008 requires providerless application behavior to precede private
HTTP adapters. The backend already fixes optimistic version semantics and exact
validation, so Flutter can model truthful drafts and conflicts now without
inventing transport or unsupported fields.

## Decision

- Model one immutable Profile presentation resource containing only nullable
  canonical Alias and nullable `avatar:` reference, plus version and update
  time. Match the reviewed length, Unicode safety, reference, and version
  invariants.
- Add a feature-owned Profile gateway and controller for load, Alias draft,
  discard, one in-flight save, sanitized failure, explicit reload, optimistic
  version conflict, provider rotation, and late-result isolation.
- Require a future production gateway to be owner-scoped. Replacing the owner
  replaces the gateway, clears the old resource/draft before publication, and
  causes an already mounted Profile surface to load only the new owner.
- A save replaces the complete presentation values using the committed
  `expectedVersion`. A conflict keeps the local draft visible but frozen until
  explicit reload; no state announces success before a matching advanced
  resource is returned.
- Keep avatar selection disabled until a reviewed upload or built-in reference
  source exists. Do not accept arbitrary URLs or fabricate a successful avatar
  change.
- Bio and visibility are not saved from Profile edit. Visibility remains owned
  by the separate Privacy resource; Bio remains unavailable until a contract is
  selected.
- Production defaults directly to an unavailable gateway. Tests and
  `lib/main_preview.dart` may inject a visibly labelled memory implementation.
  This slice adds no Dio, route literal, bearer handling, or wire DTO parser.

## Consequences

Profile edit no longer claims an account write without evidence. Preview can
exercise Alias edits, retries, conflicts, and projection back to Profile Home,
while production remains honestly unavailable.

A later authenticated adapter can implement the existing Profile endpoint
behind the same port. Privacy, Bio, avatar-source selection, public discovery,
and social relationships remain separate decisions and slices rather than
being smuggled into the presentation record.

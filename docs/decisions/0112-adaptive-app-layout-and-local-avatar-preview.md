# 0112 — Adapt app density to existing flows and simplify profile setup

Date: 2026-10-02

## Status

Accepted for the current development feature branch under the user-requested UI and Preview scope.

## Context

The user requested frontend-design across the entire app, compact data-first layouts, no preset-avatar selection, optional own-image selection, and editable usernames. They explicitly clarified that reference screenshots must be adapted to LOOP's existing code logic, not copied as product capabilities.

## Decision

- Audit all 94 current manifest routes. Change structure where it hides actual content; retain purpose-built conversation, chart, confirmation and recovery flows.
- Keep the five destinations, Community/Chat in-page segment, original social admission, financial confirmations, typed sources and canonical identity.
- Replace redundant community/profile heroes, shorten other context headers and group wallet actions. Keep chart full-width and interactive. Fix shared value-column wrapping while keeping short amounts at the right edge.
- Setup and profile edit expose one default avatar and one optional image action. Username remains the existing Alias resource with unchanged validation/CAS/activation semantics and immutable LOOP ID.
- The current backend only accepts reviewed preset avatar references and has no authenticated custom-upload adapter. Do not expand that wire contract, forge references, or claim remote upload. Explicit Preview may select a local image using the installed Stream gallery handler through a bytes-only port; only Preview overrides the picker. No Stream image-upload method is called.
- Selected bytes are memory-only, reset with the owning session, reject late results after session changes, and are visible only in explicit owner avatar instances. Other people never read those bytes. Limit file size to 5 MB, native source dimensions to 8192 per axis, and validation decode to at most 256 per axis without upscaling. Invalid/cancelled selection preserves the previous avatar and does not block username editing.

## Verification and limits

See `docs/superpowers/reports/2026-10-02-frontend-design-coverage.md` and module reports. Widget tests cover narrow viewports, keyboard, original controller gates, local image lifecycle and public identity isolation. Preview browser checks do not establish native gallery behavior, provider message delivery or remote avatar persistence. Production custom upload remains a separate backend integration gap.

Browser QA identified that the pinned Stream handler uses `dart.library.html`, so WASM selects its unimplemented fallback; even its HTML handler does not implement gallery `pickImage`. The preview image adapter therefore conditionally uses a small `dart:js_interop` local file input on web (`dart.library.js_interop`), with change/cancel cleanup and size validation before reading. Native still uses the existing installed gallery handler. This introduces no package dependency and no upload/network path.

## Consequences

The existing production avatar wire contract and provider authorization remain unchanged. Local image choice is useful for UI review but intentionally disappears when its preview session ends. Native photo-library behavior and real remote avatar storage still require their own integration acceptance. Shared density changes are covered by narrow-screen and controller regression tests, not a claim of all-route device acceptance.

Web image validation uses `instantiateImageCodec` with both target axes bounded and upscaling disabled because Flutter Web cannot read encoded `ImageDescriptor.width/height`. It decodes a first frame and rejects invalid data; native retains its source-dimension check.

# 0053 · Adopt the V2 profile module for identity, resources and privacy

## Status

Accepted 2026-09-08. Supersedes the V1 privacy client and the mnemonic account
pages.

## Context

Step 2 (S2) connects `loop-api` decision 0030's `profile` module: a
server-generated LOOP ID, a one-time public-profile activation, and a V2
privacy resource. The frozen prototype's eleven identity pages had to be
restored on the step-1 component library at the same time.

Three constraints shaped the result:

- The V2 privacy resource is not a superset of V1. It replaces
  `copy_trade_visibility` with `anonymousMode` and four independent
  `self | everyone` visibility facets. Copytrade is retired and must not
  return, so no field maps onto the old one.
- The LOOP ID is generated, unique and immutable. It is never user-chosen, so
  `loop-id-setup` is an activation, not a name picker.
- Activation is a write command with an `Idempotency-Key`. A timed-out retry
  must replay the original key and the original bytes or the backend answers
  `IDEMPOTENCY_CONFLICT`.

## Decision

1. **`ProfileValues` / `ProfileResource` carry the V2 shape.** `bio`,
   `interests`, `loopId`, `profileStatus` and `activatedAt` are added with
   defaults, so the frozen V1 profile adapter still compiles. `loopId` is
   nullable only because the V1 transport does not carry one.
2. **`PrivacyValues` drops `copyTradeVisibility`** and gains `anonymousMode`
   plus a `PrivacyVisibility` record of the four facets. All defaults are
   fail-closed.
3. **The V1 privacy adapter is deleted, not mounted-and-ignored.** Keeping
   `DioLoopPrivacyGateway` would have required inventing a mapping between a
   retired copy-trade preference and the V2 facets. `DioLoopProfileGateway`
   stays as frozen history because V1 and V2 genuinely share the alias and
   avatar columns.
4. **`lib/integrations/backend/v2/profile/` owns the transport.**
   `DioLoopV2ProfileApi` parses with `LoopV2Contract.strictMap`; an unknown
   field, a wrong `contractVersion`, a missing `Cache-Control: no-store`, or a
   `correlationId` that differs from `X-Request-ID` is an invalid payload.
   Reads and CAS writes never send an `Idempotency-Key`.
5. **Activation keeps a durable journal.** The idempotency key and the exact
   body — interest order included — are written before dispatch, mirroring the
   bootstrap journal. An identical retry replays them; a changed body is a new
   logical activation with a new key, which can never collide with the
   recorded one. A rejected body (`VALIDATION_FAILED`, `ALIAS_RESERVED`,
   `ALIAS_BLOCKED`) clears the record so the correction is not replayed under
   the old key.
6. **The post-login profile check never blocks login.** A new
   `PostAuthProfileRedirectCoordinator` in `lib/app/session/` reads
   `GET /v2/profile` once per newly verified principal: `pending` lands on
   `/auth/loop-id`, `active` on `/community`, and every failure lands on
   `/community` with a visible banner and a re-check on the next start. The
   coordinator only lifts an owner off `/auth`, `/auth/otp` or `/community`, so
   a deliberate deep link is never interrupted.
7. **Recovery, MFA, app lock, private-key export and social recovery read
   fail-closed capabilities and state their reason.** Nothing is simulated
   locally. LOOP has no recovery phrase: the seed reveal, verify and import
   pages and every tile pointing at them were deleted.
8. **`/profile/social-privacy` retires** into `informationalRetiredPaths`;
   `auth-otp` and `loop-id-setup` become implemented manifest routes.
9. **The alias suggestion is local and labelled.** Aliases may repeat, so
   "换一个" performs no availability check and the copy says so.
10. **The `loop-id-setup` notification switch is a local preference.** It is
    not sent to the backend and never claims a granted OS permission; delivery
    stays unavailable until D14.

## Consequences

- The mobile capability enum tracks the frozen contract exactly (21 entries
  after loop-api decision 0031), because the parser requires the exact set. It
  lists module IDs this step does not consume.
- Avatar upload has no storage provider. Only the 13 preset references are
  submittable, and an unreadable catalog keeps the picker unavailable rather
  than inventing references the backend would reject.
- A non-preset avatar value written by V1 renders as the monogram and is never
  resubmitted.

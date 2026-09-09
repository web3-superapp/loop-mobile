# 0060 · Adopt the V2 security, settings, support and about modules

## Status

Accepted 2026-09-09. Retires the providerless H5 Security Center, the H12
General Settings slice, the local Help article catalog, the About legal-tile
slice, the Preview DApp browser and the Bridge Preview snapshot.

## Context

Step 8 (S8) connects `loop-api` decision 0037 — the `security`, `settings` and
`support` module gates plus the public `GET /v2/meta/about` — and rebuilds the
seven D20 pages (`security`, `devices`, `key-export`, `social-recovery`,
`settings`, `about`, `support`) and the four D21 surfaces (`pay`, `bridge`,
`bridge-status`, `dapp`) on the step-1 component library. `notif-settings`,
`privacy` and `profile-edit` were re-checked against the frozen prototype and
left as delivered in steps 2 and 5.

Five constraints shaped the result:

- **A revoke is an audit projection, not a sign-out.** The server answers
  `effect: "auditOnly"` and `providerAccessTerminated: false`: LOOP refuses
  later requests carrying the revoked `X-Loop-Session-ID`, and the other
  device's Privy access token keeps working. Saying "已下线" would claim a
  provider action that did not happen, so the sheet states the real effect
  before the command and the page repeats it after — "已记录撤销，对方访问未终止".
- **Availability is not enrollment, and there is no score.** The six Privy
  security methods are permanently `unavailable` with a
  `PRIVY_<X>_EVIDENCE_PENDING` reason. The prototype's "3 项保护已开启"
  heading, `GOOD` stamp, per-method "已开启" badges, masked exported key and
  guardian samples all describe state no source reports, so none is rendered.
- **A device has no name and no place.** The wire carries `platform`,
  `clientVersion` and a bootstrap-observation `lastSeenAt` (decision 0027).
  The prototype's "iPhone 15 Pro · 上海 · 今天 09:41" is three facts the
  backend never states; the row shows the two it does plus the observation
  time.
- **A missing figure is a sentence, not a zero.** The account settings are
  fixed constants the server publishes with a `policy`, so the page renders
  them read-only rather than offering an editor that would always be refused.
  The prototype's "数据用量 本月 142MB" has no backend and no platform source,
  so the row is absent rather than invented. `reduceMotion` and `theme` stay
  device-local exactly as `policy.localOnly` names them.
- **Reviewing a URL must not visit it.** The `dapp` review is a pure function
  in `lib/core/security/loop_url_review.dart`: it never opens a socket,
  resolves DNS or fetches the address, so a redirect can never be followed and
  the reviewed host is always the typed host. HTTPS is enforced, credentials
  and unsafe code points are refused, and an IDN homograph is blocked with the
  Latin string it imitates named out loud.

## Decision

1. **Three strict transports plus one public repository.**
   `lib/integrations/backend/v2/{security,settings,support}/` and
   `meta/loop_v2_about_api.dart` decode through `LoopV2Contract.strictMap` and
   `LoopV2ChainCodec`; an unknown or missing field is an invalid payload. The
   revoke decoder refuses any response that changes `effect` or claims
   `providerAccessTerminated: true`, and refuses a session id it did not ask
   about. The four feature ports (`SecurityGateway`, `AccountSettingsGateway`,
   `SupportGateway`, `AboutGateway`) default to their fail-closed
   `Unavailable…Gateway`; only `lib/main.dart` mounts the adapters.
2. **The session id is read, never minted.** `LoopV2SessionIdSource` reads the
   active session out of the session module's own owner journal. It is not a
   credential: `GET /v2/devices` sends it only so the server can mark the
   current row, and a device command sends it to name the caller's own
   session. It is deliberately uncached, because a re-bootstrap replaces the
   session for the same principal and a stale id would mark the wrong device.
   A missing journal degrades the list (nothing is marked current) instead of
   failing it, and makes the revoke command impossible rather than unsafe.
3. **Step-up is its own failure kind.** `AUTH_STEP_UP_REQUIRED` maps to
   `LoopChainFailureKind.stepUpRequired`, which renders the permission state
   and a sentence that says the command is refused, not that it can be retried.
   Revoking the current session is never dispatched: local sign-out is
   `POST /v2/session/logout`, reached from the `settings` page.
4. **The client build is local.** `about` pairs the public server record —
   contract version, every published rule snapshot, the terms version slot and
   the open-source register — with the version and build mode read from
   `AppConfig`. The register publishes no dependency version, so none is shown;
   the four legal document links have no URL on the wire, so they render as one
   version slot with the server's `TERMS_POLICY_UNAVAILABLE`.
5. **D21 surfaces are entry points that state their reason.** `pay`, `bridge`
   and `bridge-status` render the server's own deferred `reasonCode` and hold
   no amount, route, fee, ETA or progress source; the three bridge steps stay
   pending because nothing is reporting them. `dapp` reviews locally and keeps
   connect and sign disabled; domain reputation is unavailable because no
   provider is configured. `smart-money` and `community-ai` were already
   whole-page unavailable and were re-checked, not changed.

## Consequences

- The capability enum reaches 31 ids; the parser still requires the exact set
  in contract order, so a contract change fails loudly.
- `bridge-status` no longer requires a typed `extra`, because there is nothing
  to carry into it. `BridgePreviewSnapshot`, `DappBrowserScreen` and the tests
  that guarded them are retired; `WalletReadiness` survives as unmounted
  history with its own unit test.
- `key-export` remains permanently reachable as a product promise while being
  permanently inert as a capability. It shows no verification steps, because a
  verification that cannot lead to an export is theatre.
- The harness locks the new truth rules and drops the retired ones: the six
  method rows must render the server's reason, the three bridge steps must
  stay pending, the DApp review may not import a transport or render an
  address, and the two fixed settings rows must stay read-only.

## Evidence

- Contract: `loop-api/docs/frontend-v2-security-settings-api.md`,
  `loop-api/openapi/loop-api.v2.json` (31 capabilities).
- Gates: `bin/flutter pub get --enforce-lockfile`, `bin/dart format`,
  `bin/flutter analyze`, `bin/flutter test`, `python3 scripts/check_harness.py`,
  `python3 -m unittest discover -s tests -p 'test_*.py'`.
- Tests: `test/s8_security_pages_test.dart`,
  `test/s8_settings_about_support_test.dart`,
  `test/s8_deferred_pages_test.dart`, `test/loop_url_review_test.dart`,
  `test/security_capability_truthfulness_test.dart`,
  `test/local_settings_and_help_test.dart`.
- Unverified: every Privy security method (plan, platform, SDK and
  physical-device evidence), real device revocation against a live Privy
  session, push delivery, and the bridge, pay and DApp providers.

# 0064 · Recover a cold start that lost the network: a three-state session and a re-armed D0 observation

## Status

Accepted 2026-09-10. Extends decision 0049 (V2 account/device session) and
decision 0050's D0 observation boundary; it changes neither the backend
contract nor the D0 request shape.

## Context

The 2026-09-10 simulator acceptance run dropped the emulator from WiFi to a
throttled 3G link for about three minutes and cold-started the app. Two
distinct failures appeared (recorded in `LOOP/docs/acceptance/93-pages.md`,
「模拟器验收记录」).

**(a) A restore that could not complete was presented as a sign-out.**
`LoopSessionController._restore` had exactly two outcomes: a snapshot, or
`LoopSessionState.signedOut(errorMessage: …)`. Every failure of
`PrivySdkAuthGateway.restoreSession` — including "the device has no network" —
therefore landed on `PrivyLoginScreen`'s credential form. The owner reads that
as "LOOP signed me out". When the network came back, Privy's
`authStateStream` emitted `Authenticated` and the app silently jumped back
into the product, which reads as a second unexplained event.

**(b) The capability document never arrived, and nothing ever asked again.**
`loopV2MetaSnapshotProvider` is read exactly once, from `LoopApp`'s root
lifecycle, with `retry: (retryCount, error) => null`. When both public D0 reads
failed on the dead link, the `AsyncError` stayed forever: `/v2/account/me` and
`/v2/profile` succeeded minutes later, but every module gate still projected
`LoopCapabilityDecision.unknown` and Community still said 「尚未读取到能力清单」
until the app was killed and restarted.

## Decision

### 1. Session restore is a three-state answer

`LoopSessionMode` gains `restoreUnavailable`. The three outcomes of a cold
start are now:

| Outcome | Mode | Surface |
| --- | --- | --- |
| Privy answered `Authenticated` / `AuthenticatedUnverified` | `authenticated` / `authenticatedUnverified` | routed into the product |
| Privy answered `Unauthenticated` | `signedOut` | the credential form |
| Privy could not be reached, or failed unexplained | `restoreUnavailable` | the branded launch frame + an offline notice + 重试 |

`LoopSessionState.isRestoring` covers `restoring` and `restoreUnavailable`
together; both are "undecided", neither is a sign-out. `canEnterProduct` stays
false for both, so routing is unchanged: the owner sits on `/auth`, which now
renders `PrivySessionRestoreScreen` rather than the form.

`LoopSessionController.retryRestore()` is the retry, and it is single-flight
with the cold-start restore (`_restoreOperation`): only `restoreUnavailable`
may call it, and it asks Privy exactly once per press. A `notReady` event
arriving from `authStateStream` while the state is `restoreUnavailable` keeps
the explanation and the retry instead of collapsing back to a bare spinner.
An explicit `Unauthenticated` event still signs the owner out immediately —
the rule is "no credential form until Privy says so", not "never".

### 2. Privy 0.10.1 failure mapping

privy_flutter 0.10.1 carries **no error code across the platform channel**.
`PrivyException` (`lib/src/errors/privy_exception.dart`) has one field,
`message`; `ExceptionConversion.convertToPrivyException` reads
`PlatformException.code` only to pick the four MFA subclasses
(`MFA_MISSING_OR_INVALID`, `MFA_CHALLENGE_EXPIRED`,
`MFA_MAX_ATTEMPTS_REACHED`, `MFA_SDK_TIMEOUT`) and discards it otherwise.
`Privy.getAuthState()` wraps everything it catches in
`e.convertToPrivyException("Error in getAuthState")`. There is therefore no
structured signal, and classification is a message mapping:

| Kind | Markers matched in the lowercased message (in order) | Session result |
| --- | --- | --- |
| `network` | `network`, `internet`, `offline`, `connection`, `connect`, `timed out`, `timeout`, `unreachable`, `unavailable`, `socket`, `hostname`, `dns`, `ssl`, `tls`, `certificate` | `restoreUnavailable` |
| `authentication` | `unauthenticated`, `not authenticated`, `unauthorized`, `no user`, `no authenticated user`, `no active session`, `not logged in`, `logged out`, `session expired`, `token expired`, `expired token`, `invalid token`, `invalid credential`, `invalid refresh`, `401`, `403` | `signedOut` |
| `unknown` | anything else, e.g. `Error in getAuthState: Auth state data is null` | `restoreUnavailable` |

Network markers are tested **first**: when a message mentions both a transport
and a credential, the transport explains it. `unknown` is treated exactly like
`network`, because an unclassified failure is not Privy answering that the
credential is gone. A non-`PrivyGatewayException` thrown anywhere in the
restore path is also `unknown`.

The mapping lives in `PrivyFailureClassifier` next to the gateway, and
`PrivyGatewayException` now carries `kind` (default `PrivyFailureKind.unknown`,
so every existing call site keeps its meaning).

### 3. The D0 observation is re-armed, not re-scoped

`LoopV2MetaObserver` owns the observation lifecycle. The request itself is
untouched: still `GET /v2/meta/client-policy` and `GET /v2/meta/capabilities`
read concurrently, still no Bearer, body, query, `X-Loop-*` or idempotency
header, still non-blocking, still unable to gate login or routing (decision
0050 / README D0). What changes is only that a **failed** read is asked again:

- cold start once, exactly as before;
- on failure, at most **5** retries at **1s → 2s → 4s → 8s → 16s**;
- one attempt when the radio comes back (`connectivity_plus`), one when the app
  returns to the foreground (`AppLifecycleListener.onResume`), and one on every
  navigation — which is how "a module page opened without a capability
  document" is implemented, since GoRouter's top-level `redirect` is the one
  place every page opening passes through. The callback never decides that
  redirect.

Every trigger is single-flight: it is ignored while a read is in flight and
while a backoff retry is already scheduled. A trigger that does start a read
resets the ladder, so a genuinely restored network gets a fresh five-step
budget. A **completed** observation is never re-read — including the "no
backend endpoint is configured" answer, which resolves to `null` data rather
than an error. Only `AsyncError` is re-armed. Success clears the ladder, the
module gates open by themselves, and no restart is needed.

`connectivity_plus` 7.3.1 was already resolved in `pubspec.lock` as a
transitive package; it is now a direct dependency pinned to the same version,
so the resolution is byte-identical. It is read through
`LoopConnectivitySignal`, which exposes one thing — "the device went from no
transport to some transport" — and is explicitly **not** evidence that a
service is reachable or that LOOP is offline. No product surface may derive an
outage from it.

## Consequences

- The owner never sees the credential form because of a bad link. They see the
  LOOP mark, 「暂时无法确认登录状态」, the reason, 「未收到 Privy 的"未登录"答复，
  因此不会要求你重新登录。」 and a 重试 button.
- The silent jump from the login form back into the product is gone, because
  the app never left the undecided state to begin with.
- After a 3-minute outage the backoff ladder (31s) is spent, so the recovery
  path is the connectivity / foreground / navigation trigger — exactly the
  case the acceptance run hit.
- Worst case per outage episode: 6 request pairs from the ladder, plus one pair
  per external trigger. Two identical triggers arriving together cost one pair.
- No new colour, type size or component: the third state reuses `LoopNotice`
  with the five-state Offline icon and the `danger` tone, `LoopButton`, and the
  existing brand frame.

## Alternatives rejected

- **Treat `Unauthenticated` as undecided when the radio reports no transport.**
  It would also cover the case where Privy answers "unauthenticated" without
  throwing. It was rejected because it overrides an explicit Privy answer with
  a radio reading, and the ruling is that only Privy decides. The residual risk
  is recorded below.
- **`LoopOfflineState` on the launch frame.** Its copy asserts 「离线 · 显示缓存」
  and names paused funding actions. Nothing is cached at that moment and no
  action is paused, so it would state something untrue; the shared `LoopNotice`
  with the same `offline` icon and tokens says only what is known.
- **Retrying inside `loopV2MetaSnapshotProvider` (`retry:`).** That would make
  the retry policy invisible to the D0 boundary and impossible to drive from
  connectivity or lifecycle. The provider keeps `retry: … => null`; the ladder
  is owned by a named observer that tests can inspect.
- **Triggering from `loopCapabilityProvider`.** The projection rebuilds on every
  observation change, so a trigger there re-arms itself after the ladder is
  exhausted and loops forever. The router redirect fires once per navigation
  and cannot.
- **Blocking the launch on the capability document.** Rejected by decision 0050
  and unchanged here: the observation still cannot gate login or routing.

### 4. A restore that never answers is also an answer

`Privy.getAuthState()` can fail to complete rather than fail. The two native
sides do not behave the same way:

- **iOS.** The native SDK awaits readiness before resolving the auth state and
  surfaces no transport failure of its own. With a dead link the platform-channel
  call simply stays pending: no `PrivyException`, no `Unauthenticated`, nothing
  for the message mapping in §2 to classify. The Future may never complete.
- **Android.** The native side does report a distinct `getAuthStateError`, which
  arrives as a `PrivyException` and is classified by §2.

The classification in §2 is therefore an Android-shaped answer, and on iOS the
**only** available signal is elapsed time. `LoopSessionController` gives a
restore a bounded window — `defaultRestoreWindow`, 12 seconds, injectable
through `loopSessionRestoreWindowProvider` — after which the session moves to
`restoreUnavailable` carrying `loopUndecidedSessionMessage`
(「暂时无法确认登录状态，请稍后重试。」, which asserts no cause because none was
observed).

The deadline does **not** cancel the call in flight. Privy may still answer
minutes later, and `_restore` publishes that answer because `isRestoring`
covers the undecided state as well: a late `Authenticated` lands and the owner
is routed without touching anything. What the deadline does drop is the
*operation identity*, so `retryRestore()` issues a genuinely new `getAuthState`
instead of handing back the Future that never answered. A failure arriving from
a superseded attempt is ignored by generation, because — unlike a snapshot — it
carries no new fact about the credential.

## Open risk

Privy may report `Unauthenticated` — rather than throwing or hanging — when it
cannot reach its backend to validate a cached session. In that case this
decision does not change the behaviour: the credential form still appears. The
mapping above is the honest limit of what privy_flutter 0.10.1 exposes, and the
12-second window only covers the case where nothing is reported at all.
Confirming the native behaviour on both platforms needs a device run with the
network cut at cold start; until then the acceptance record should keep
冷启动网络抖动 as device-unverified.

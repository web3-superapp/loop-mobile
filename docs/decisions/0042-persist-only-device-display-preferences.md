# Persist Only Device-Local Display Preferences

## Status

Accepted on 2026-08-29.

## Context

H12 General Settings has one implemented control: Reduce motion. It changes
LOOP's global `MediaQuery.disableAnimations` projection while preserving a
stricter operating-system accessibility choice. The value previously existed
only for the current app run, so it reset on every launch.

Language has no localization resources, Display currency has no trusted
conversion contract, and Theme has only the current dark design system.
Profile, Privacy, and Notification Preferences are versioned owner resources
whose production adapters remain backend-owned. App lock and PIN storage have
a separate account-bound security lifecycle. None of those values can be
folded into an installation preference merely because their pages appear near
H12.

## Decision

- Pin the Flutter-owned `shared_preferences` package at 2.5.5 and use its
  non-caching `SharedPreferencesAsync` API. The package is suitable only for
  simple, non-critical preferences; it is not Secure Storage or a database.
- Persist exactly one Boolean under `loop.display.v1.reduce_motion`. The store
  exposes only read/write Reduce motion operations and never calls `clear`.
- Both `main.dart` and `main_preview.dart` read the value before mounting the
  first `LoopApp` frame. A missing value defaults to false. A read failure uses
  the same false run-local fallback while exposing persistence as unavailable.
  Store construction and reads fail open after one second so this non-critical
  preference cannot hold the application on its native launch screen.
- The controller applies a user change immediately and serializes device
  writes. A delayed older write cannot become the final stored value after a
  newer selection, including across controller reconstruction. A write that
  has not completed after one second reports unavailable instead of leaving
  the UI in `saving`; its underlying operation remains ordered ahead of later
  writes. Failure keeps the current app-run choice and never claims it was
  saved for the next launch.
- Retry after an initial read failure reads again, preserving an unknown stored
  value rather than overwriting it with the false fallback. Retry after a
  failed or timed-out user write writes the current explicit run-local choice.
- Reduce motion is installation-scoped. Logout and account rotation do not
  clear it. A stricter system accessibility setting always wins.
- The store contains no LOOP/Privy/Stream identity, Profile, Privacy,
  Notification Preferences, wallet data, token, PIN, enrollment/protection
  state, provider fact, or arbitrary feature setting. Shared Preferences is
  never treated as a credential or authoritative backend resource.
- Language, Display currency, and Theme remain disabled until their actual
  resources, UI behavior, and product contracts exist. Secure Storage remains
  deferred to the account-bound credential-lifecycle decision in decision
  0040, and raw PIN storage remains forbidden.

## Consequences

Reduce motion can survive ordinary relaunches without a backend or account and
is restored before LOOP can present a non-reduced transition. Storage failure
does not block the app or fabricate durable success. The integration adds the
official federated Android/iOS preference plugin and therefore requires both
native Debug compilation gates at this dependency checkpoint.

This decision creates no generic database, Secure Storage adapter, account
preference mirror, localization system, currency conversion, theme selection,
provider request, or backend route. The package documentation also warns that
preference writes are asynchronous and unsuitable for critical data, which is
why this boundary remains limited to a recoverable display choice.

## Evidence

- `test/loop_display_preferences_test.dart` covers the one-key adapter,
  missing/read-failure/timeout behavior, constructor fallback, read-versus-write
  retry, reconstruction, serialized rapid changes, late writes, write timeout,
  and duplicate-write suppression.
- `test/local_settings_and_help_test.dart` covers global restoration,
  an actual read-retry action, run-local failure copy, the stricter system
  setting, and disabled H12 options.
- Repository Harness validation locks the exact dependency, key, adapter,
  composition roots, forbidden data boundary, and executable behavior evidence.

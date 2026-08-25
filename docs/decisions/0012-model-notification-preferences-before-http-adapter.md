# Model Notification Preferences Before Its HTTP Adapter

## Status

Accepted on 2026-08-25.

## Context

The backend owns an authenticated, owner-scoped Notification Preferences
resource, while this Flutter phase intentionally completes application logic
before adding another private HTTP adapter. The existing H9 screen held six
widget-local switches for prices, orders, liquidation, community, security,
and system messages. It also asserted an operating-system notification state,
offered a no-op device-settings button, and displayed local quiet hours. None
of those controls represented the reviewed backend resource or verified a
Firebase/APNs/FCM/device capability.

The reviewed resource instead stores four owner intents and permanently reports
delivery as `unavailable`. Enabling an intent cannot be treated as evidence
that an alert exists, a provider accepted a message, the operating system
granted permission, or a device received anything.

## Decision

- Model exactly four Boolean preferences with these event wire values:
  `price_alert_triggered`, `provider_activity_projected`, `security_notice`,
  and `support_update`.
- Preserve the backend's version-zero default: all four values are false,
  delivery is `unavailable`, and versions stay within `0..2147483647`.
  No other delivery value is accepted or synthesized.
- Replace the complete four-value snapshot using the committed expected
  version. An identical replay converges before stale-version comparison; a
  divergent stale write freezes and preserves the draft until explicit reload.
  Load and apply operations are single-flight, and gateway rotation retires
  late work from the previous owner.
- Accept a committed draft only from a matching resource whose version
  advances. An ambiguous retry reuses the same expected version and complete
  candidate so it may converge on the already-advanced resource. Do not use a
  SnackBar or positive delivery/save copy as evidence.
- Keep `notificationPreferencesGatewayProvider` directly bound to
  `UnavailableNotificationPreferencesGateway` in production. Only tests and
  `lib/main_preview.dart` may compose
  `MemoryNotificationPreferencesGateway`, and Preview remains visibly labelled
  `开发预览`.
- Do not add Dio, the `/v1/notification-preferences` route, bearer handling,
  owner IDs, or HTTP error parsing to `lib/features/`. A later authenticated
  adapter may implement the narrow gateway without changing the models,
  controller, or UI state.
- Replace the unsupported H9 categories, fake operating-system state,
  device-settings action, and quiet-hours row with the exact four-preference
  editor plus a persistent `DELIVERY UNAVAILABLE` explanation.
- Keep Price Alert creation/evaluation separate. This slice stores only the
  `price_alert_triggered` delivery intent and does not implement C9 alerts,
  market thresholds, provider events, or delivery.

## Consequences

The frontend can verify deterministic preference editing, complete
replacement, conflict recovery, account/gateway rotation, and accessible
responsive UI while the backend transport and push work continue in parallel.
Production remains honestly unavailable and makes no request. Preview proves
only in-process application behavior.

This decision does not initialize Firebase, request operating-system
notification permission, register a device, parse provider payloads, configure
APNs/FCM, deliver or display a notification, implement quiet hours, create a
Price Alert, or add an authenticated transport. No failure memory is added
because the removed UI was an inherited prototype fixture rather than a
reproduced production incident; executable Harness mutations prevent its
return.

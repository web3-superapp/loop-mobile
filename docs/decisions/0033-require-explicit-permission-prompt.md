# 0033 Require Explicit Permission Prompt

## Status

Accepted on 2026-08-28.

## Context

I6 previously defaulted every route visit to a requestable Camera permission.
It claimed a QR scanner was ready, mapped an unverified Boolean to denied state,
and labelled generic placeholder navigation as `Continue` or `Open settings`.
Its Notifications copy invented alert categories and background delivery, while
its Biometrics copy invented app lock, recovery and protected account actions.

The app has no general platform-permission adapter. Camera has no complete
native declaration or originating feature, Notifications has no Firebase/APNs
configuration or Android permission, and `permission_handler` is only a
transitive dependency. Audio Room has reviewed microphone declarations, but its
deliberate Speak action and Stream capture path remain the request authority.

## Decision

- `SystemSurfaceScreen.fromId('permission')` requires one explicit
  `LoopPermissionPrompt` before rendering active I6 content. Without it, the
  route reports permission status as unavailable and may only return to LOOP.
- The typed prompt contains one current catalog kind—Camera, Notifications or
  Microphone—and one presentation mode: `education` or `settingsRecovery`.
  Legacy generic Biometrics copy is removed; any future biometric account/MFA
  capability needs its own reviewed source, native integration and decision.
- `education` means only that the exact originating feature is ready to explain
  a deliberate next request. It does not claim that the OS status is unknown,
  denied, requestable or granted.
- `settingsRecovery` may be constructed only after a reviewed platform adapter
  observes that opening settings is the correct next action. Returning to LOOP
  does not prove that the permission changed.
- Request, open-settings and not-now use three independent dedicated callbacks.
  Education cannot consume the settings callback, settings recovery cannot
  consume the request callback, and generic system-route actions cannot
  authorize any active I6 label. Missing callbacks hide their labels.
- Camera copy states only the bounded QR-scanning purpose and does not start a
  scanner. Notification copy separates OS permission from in-app preferences
  and never claims category enablement or delivery. Microphone copy states that
  Audio Room begins muted and access follows the deliberate Speak action.
- Audio Room keeps Stream capture as microphone authority; I6 does not create a
  second permission manager or alter call lifecycle. Camera and Notifications
  prompts remain unavailable in production until their feature and native
  decisions are approved.
- A future platform adapter must preserve exact OS states and lifecycle refresh
  behavior. Unknown, not-determined, denied, permanently denied/restricted,
  granted and unsupported states must not collapse into an unverified Boolean.
- This slice adds no permission request, settings launch, plugin import, direct
  dependency, native declaration, Firebase initialization or device behavior.

## Consequences

Catalog navigation and direct deep links no longer open a fake Camera flow or
offer nonfunctional system actions. The presentation contract is ready for
exact feature-owned composition without claiming that any platform prompt,
settings return or physical-device behavior has been verified.

## Evidence

- `test/system_permission_truthfulness_test.dart`

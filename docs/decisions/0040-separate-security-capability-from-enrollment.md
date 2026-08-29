# 0040 Separate security capability from enrollment

## Status

Accepted on 2026-08-29.

## Context

The A11 account-protection catalog page exposed local Passkey, Biometrics, and
PIN switches even though no enrollment controller, verification adapter, or
LOOP-owned secure storage existed. Its PIN started enabled, and `Save
protection` only navigated forward while copy claimed that the PIN was stored.

H5 made the inverse mistake: it counted Privy capability-availability flags as
enabled protection, produced a three-part protection score, and inferred that
recovery was either ready or not set. Availability says that a method may be
supported; it does not prove enrollment, configuration, enforcement, or stored
state. Production currently supplies no Profile security-capability mapping or
protection-status source.

## Decision

- A11 is a truthful unavailable setup surface. It may report Passkey and device
  biometric capability availability, but exposes no switch, enrollment, save,
  or PIN behavior. `Continue without changes` advances the catalog journey
  while explicitly leaving protection unchanged.
- A11 states that Secure Storage is not connected and that no app PIN is stored
  or checked. This slice adds no storage dependency or speculative gateway.
- H5 reports capability availability separately from status. It exposes no
  protection score and makes no enabled, configured, ready, recovery-set, or
  sign-in-activity claim without a dedicated source.
- Wallet MFA is labelled as wallet protection, not generic login MFA. Wallet
  MFA and App lock remain disabled until separate typed setup callbacks and
  reviewed adapters exist.
- Devices, recovery phrase, and social recovery continue to open their existing
  bounded information surfaces. Those surfaces already fail closed when their
  provider evidence is absent.
- A future local PIN or App lock slice requires a separate security decision
  covering the actual route, account binding, enrollment, verifier design,
  retry and lockout policy, migration, logout/account-switch cleanup, and
  operating-system-backed storage. A raw PIN must never be persisted.

## Consequences

The app no longer turns local widget state or method support into a security
claim. Users can inspect what may be available and continue the unfinished
catalog journey without being told that protection changed. Secure Storage
remains a considered future adapter rather than an unused dependency or a
fictional implementation.

This decision does not enroll MFA, configure Passkeys or Biometrics, store a
PIN, read sessions, reveal recovery material, or connect a Privy security
status source.

## Evidence

- `test/security_capability_truthfulness_test.dart`
- `scripts/check_harness.py`
- `tests/test_check_harness.py`
- `docs/failures/providerless-protection-status-and-setup.md`


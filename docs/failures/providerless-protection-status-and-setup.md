# Providerless Protection Status and Setup

## Summary

A11 displayed functional protection switches and claimed Secure Storage-backed
PIN persistence without an adapter. H5 converted capability-availability flags
into an enabled-protection score and recovery conclusions without an enrollment
or account-status source.

## Root Cause

Prototype presentation state was treated as committed security state. The
implementation did not distinguish four separate facts: platform or provider
capability, user enrollment, current enforcement, and durable credential
storage. Navigation success was also mistaken for proof that a protection
setting had been saved.

## Detection

A storage and capability audit found no direct Secure Storage dependency, no
local-protection port, and no Passkey, biometric, or PIN enrollment operation.
The production composition supplies neither `PrivyWalletCapabilities` nor
`PrivyProfileCapabilities`, so the UI had no source for the positive claims.
Widget-state tracing showed that A11 changed only local Booleans and H5 counted
availability flags.

## Prevention

- Capability availability never becomes enabled, configured, enforced, or
  stored state.
- A providerless security setup exposes no Switch or Save action. Continuing
  must explicitly say that it makes no change.
- Missing protection status stays unknown; it never becomes a score, ready
  state, recovery-set conclusion, or sign-in fact.
- Wallet MFA and App lock remain disabled until their exact setup adapters are
  connected.
- Secure Storage is introduced only with an account-bound credential lifecycle
  decision; raw PIN storage is forbidden.
- Flutter behavior tests and Harness mutations protect the A11/H5 slices,
  information routes, catalog copy, and executable evidence.

## Evidence

- `docs/decisions/0040-separate-security-capability-from-enrollment.md`
- `test/security_capability_truthfulness_test.dart`
- `scripts/check_harness.py`
- `tests/test_check_harness.py`


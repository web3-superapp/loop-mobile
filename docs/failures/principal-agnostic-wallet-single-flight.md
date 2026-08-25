# Principal-Agnostic Wallet Single-Flight

## Summary

A pre-merge review on 2026-08-25 found that one in-flight Privy wallet
creation Future could be reused after the authenticated principal changed. No
production incident or provider call was observed, but the old result could
have been attached to the new local session.

## Root Cause

`PrivySdkAuthGateway` stored one `_walletCreation` Future without its owner.
`LoopSessionController` rejected a result only when the principal changed
during that individual call, so a second call started by the new principal
could await the old principal's Future and pass the existing post-call check.

## Detection

The two-axis merge review traced the new D8 wallet-creation entry through the
session controller into the SDK gateway. A deterministic controller test then
reproduced two principals awaiting the same old-owner result.

## Prevention

Wallet creation now requires the expected Privy user ID, keys the SDK
single-flight to that owner, captures the original SDK user, and returns an
owner-tagged result. The controller independently verifies the returned owner
before attaching the wallet. Harness evidence locks both code fragments and
the cross-principal behavior test.

## Evidence

`bin/flutter test test/loop_session_controller_test.dart
test/email_auth_controller_test.dart test/perp_account_screen_test.dart`
passed 15 tests after the correction. The full command matrix is recorded in
the Phase 1 frontend integration report.

# Open an Account in Five Steps

## Status

Accepted on 2026-09-20.

## Context

The frozen prototype opens an account in five numbered steps: `auth-otp` is
01 验证邮箱, `wallet-create` is 02 创建钱包, `wallet-recovery` is 03 设置恢复方式,
`security-setup` is 04 安全设置 and `loop-id-setup` is 05 创建 LOOP ID. Every one
of those pages prints its own `0N / 05` counter.

Step 2 built all five pages, but only one of them was ever reached.
`PostAuthProfileRedirectCoordinator` sent a `profileStatus == pending` owner
straight to `/auth/loop-id`. A device report on 2026-09-20, from a new account
on a real phone, confirmed it: splash → login → OTP → 生成 LOOP ID. Three pages
the product promised were never shown, and nothing told the owner that a
wallet was being made for them.

The same report showed why 02 mattered. Privy creates the embedded wallet on
the device, and the server's `account_wallets` row for that account first
appeared about ninety seconds after activation. So there really is a wait, and
a page whose job is to describe it had been skipped.

Step 2 had also decided that `wallet-create` would show no progress ring at
all, because no capability proved a wallet was being created. That was the
right call against a capability. It is the wrong call against a fact: the
wallet directory can be read, and Privy reports its own wallet on this device.

## Decision

- An account whose profile the server calls `pending` walks 02 → 03 → 04 → 05
  and then lands in Community. An account the server calls `active` never
  enters the sequence. The only thing that puts an owner into it is a
  `GET /v2/profile` read that answered `pending`.
- 02 has no back action: the credential behind it has already been accepted,
  so there is no login page to return to. 03, 04 and 05 step back exactly one
  page. Activation replaces the whole stack with Community, so no back gesture
  can re-enter a finished opening.
- The position is kept device-locally, partitioned by the opaque
  `LoopV2OwnerPartition` value, under `loop.onboarding.v1.step.<partition>`.
  Killing the process and reopening resumes on the same step. Signing out
  keeps it; activation deletes it. The stored value is a step name and nothing
  else — no principal, no credential, no account resource, and no claim that
  anything was enrolled.
- 02 reports observations, not hopes. 生成密钥对 and 写入安全区 are ticked only
  when an embedded wallet is actually observed — in the server's wallet
  directory, or reported by Privy for this device. 设置恢复方式 is ticked only
  when step 03 recorded a method the owner really chose, and 绑定 LOOP ID only
  when the profile is active, which inside the sequence it never is. Every
  unticked row names the step that will produce it.
- 02 polls the wallet directory every 2 seconds for at most 60 seconds. A
  refused read is not "you have no wallet"; it keeps the unseen state and asks
  again. Running out of time says 钱包还在创建中，可以先继续 and is not a failure.
  The step's action stays available throughout: login has already succeeded
  and a wallet that has not appeared yet may not hold the owner here.
- 03 and 04 keep step 2's rule unchanged. Every recovery method, MFA option
  and application lock states an availability from the capability document
  with the reason it is unavailable. A local application lock, biometric gate
  or PIN is not implemented in this round and says so. Nothing is enrolled,
  configured or stored, and 稍后设置 is never recorded as an enrolment.

## Consequences

- The recovery decision is kept for the run only and never written to the
  store. A method cannot be proven enrolled after a restart, so a resumed run
  claims nothing about it.
- A device that refuses the write falls back to the in-process default: the
  sequence still runs, it simply restarts at 02 after a cold start. The
  fallback is silent because it costs the owner one step, not a fact.
- `shared_preferences` now has a second reviewed adapter. It is pinned as
  narrowly as the display store: one key prefix, three operations, one
  `SharedPreferencesAsync`, and no other file in `lib/` may import the package.
- Step 2's deliberate deviation "`wallet-create` shows no progress ring
  without a capability" is superseded. The page now plays what it can observe
  and stays silent about what it cannot.

## Evidence

- `lib/app/session/onboarding_sequence.dart`
- `lib/integrations/personalization/shared_preferences_onboarding_store.dart`
- `lib/features/account/wallet_creation_facts.dart`
- `lib/features/account/wallet_create_step_screen.dart`
- `lib/app.dart` (`_enterOnboardingSequence`, `_onboardingStepScreen`)
- `test/s53_onboarding_sequence_test.dart`
- `scripts/check_harness.py` (`check_onboarding_sequence_contract`)

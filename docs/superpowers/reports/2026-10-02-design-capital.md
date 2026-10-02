# CAPITAL design audit · 2026-10-02

Applied frontend-design to LOOP's existing Ink/Lime/Chalk identity and existing business contracts. The distinctive object is the wallet ledger: real figures and holdings precede secondary mining information. No new provider capability, signing authority or transaction shortcut was introduced.

## Concrete changes

- Wallet: five existing actions share one compact row; asset rows and snapshot provenance precede the mining hint; decorative ledger ring removed. Existing unavailable actions still state their reason, and available actions keep their exact routes.
- Login: brand reduced from 104 to 72, heading margins normalized to 24/12, bringing authentication methods upward.
- Registration: one avatar, optional image selection, editable username, immutable ID demoted to metadata after the input. Removed all preset choices. Optional avatar selection does not affect activation eligibility or Alias validation.
- Avatar: shared editor used by account and profile; image selection works in explicit Preview using the already installed gallery handler. Validated bytes stay only in memory and reset on session mode/principal changes; stale selection results are ignored. Production states the unavailable upload capability on action. There is no backend upload endpoint, new avatar reference, fake upload success or new dependency. Limits: 5 MB and 8192 px per dimension, decoded image required. Cancellation or invalid selection preserves the prior local image.
- Send recipient, swap and Pay: compact folios leave more room for fields. Existing keyboard collapse/accessory and canonical confirmation steps retained.
- Offline/server-error state cards: padding reduced from 34 vertical to 16; recovery controls remain beside their explanation.

## Per-route audit

`Changed` means a direct change in this domain; `Reviewed` means the page's current purpose/guards justify retaining its composition, with shared primitives updated by the root implementation.

| Slug | Treatment | Evidence / retained constraint |
|---|---|---|
| splash | Reviewed | Indeterminate branded restoration, no invented progress/success. |
| auth | Changed | Compact brand/header; all Privy/platform/provider guards retained. |
| auth-otp | Reviewed | Existing keyboard-safe OTP focus and retries; no extra step introduced. |
| auth-wallet | Reviewed | External credentials stay ephemeral and gated. |
| wallet-create | Reviewed | Creation outcome remains provider-sourced; no fabricated wallet. |
| wallet-recovery | Reviewed | Necessary recovery choices/confirmations retained. |
| security-setup | Reviewed | Unavailable protection controls remain unavailable. |
| loop-id-setup | Changed | Single optional avatar + username; ID metadata; one primary activation. |
| force-update | Reviewed | Blocking policy and allowed exits unchanged. |
| region-blocked | Reviewed | Unknown eligibility never infers a region restriction. |
| wallet | Changed | One action strip, assets before mining, no ornamental ring. |
| networth | Reviewed | Non-spendable valuation, source markers, missing history not fabricated. |
| pay | Changed | Compact header; scanning unavailable and no camera/payment authority. |
| asset | Reviewed | Canonical asset identity and five separate balance meanings retained. |
| send | Reviewed | Asset selection and closed-gate state unchanged. |
| send-to | Changed | Compact field header; address preflight, amount rules and keyboard accessory retained. |
| send-confirm | Reviewed | Canonical recipient/network/amount confirmation retained. |
| receive | Reviewed | Actual wallet QR/address and network warnings remain primary. |
| swap | Changed | Compact header; source/destination, slippage and quote gates retained. |
| swap-route | Reviewed | Quote provenance and expiry remain visible; no executable substitute. |
| bridge | Reviewed | Provider absence remains explicit; no fee or route invented. |
| bridge-status | Reviewed | No fake pending/completed stages without transfer source. |
| tx-result | Reviewed | Server result and reconciliation/polling remain authoritative. |
| tx-history | Reviewed | Direction, source and transaction identifiers preserved. |
| wallets | Reviewed | Existing active-wallet selection stays an identity operation. |
| dapp | Reviewed | URL review does not grant signing or wallet connection. |
| approval-guard | Reviewed | Necessary spender/risk review and signing confirmation retained. |
| approvals | Reviewed | Current allowance facts and revoke semantics unchanged. |
| networks | Reviewed | Network rows first, detailed RPC evidence in disclosure. |
| offline | Changed | Compact recovery card, factual scope and retry retained. |
| server-error | Changed | Compact failure card; exact observed error/source retained. |
| maintenance | Reviewed | Time claims only from supplied maintenance notice. |
| permission-notice | Reviewed | Supplied permission prompt only; no invented OS grant. |
| toast-states | Reviewed | Specimens remain explicitly separate from actual feedback. |
| skeleton-states | Reviewed | Loading display never implies a request occurred. |
| token-card-states | Reviewed | Identifier/source contract unchanged. |
| sign-sheet-states | Reviewed | Canonical signing intent and safety checks unchanged. |

## Verification

GitNexus pre-edit impacts: WalletScreen, PrivyLoginScreen, SystemSurfaceScreen, LoopIdSetupScreen, SwapScreen, PayScreen LOW; SendRecipientScreen MEDIUM. main_preview.dart main UNKNOWN with no indexed callers, verified explicit entry point. Index was 3 commits behind HEAD. No HIGH/CRITICAL target changed.

New tests cover 360/390 wallet action geometry (all five >=44 touch targets), assets above secondary mining information, Receive route, and registration input/primary action above a simulated keyboard. Avatar tests cover valid selection, cancel, invalid bytes, oversized bytes, session reset and pending result rejection.

Initial affected suite: 24 passed; new 360-width test exposed shared LoopRecordRow overflow, reported to root and fixed there. Broad wallet/system/account regression: 152 passed, one pre-existing region-copy expectation mismatch (expected developer explanation removed before this change). Domain analyze initially passed. Final rerun results follow below.

Final focused rerun: `bin/flutter test --no-pub test/avatar_upload_test.dart test/loop_id_setup_screen_test.dart test/design_capital_layout_test.dart test/system_region_truthfulness_test.dart` — **23 passed**. This includes both 360/390 keyboard layouts and resolves the stale region-copy expectation while retaining all unknown-policy/no-restriction assertions. Final avatar validation decodes the first frame as well as checking dimensions. No provider upload/device gallery end-to-end validation or native/server build was run by this domain agent.

Review P2 follow-up: first-frame decode now computes both target dimensions, preserving the aspect ratio within whole-pixel limits, with no upscale and at most 256×256 decoded pixels. Regression includes 1×8192 and 8192×1 images, square/portrait/landscape and already-small images. `test/avatar_upload_test.dart`: **3 passed** after the correction.

Browser QA follow-up: the locked Stream gallery handler does not implement `pickImage` on its web/WASM branch. Added a conditional `dart.library.js_interop` browser picker with a local `input[type=file]`, image-only accept hint, change/cancel handling, pre-read file-size check, and removal of both listeners and the input on completion. Native gallery behavior is unchanged. The helper successfully compiled with `dart compile wasm`; actual chooser/selected-image rendering is being revalidated by root browser QA. No dependencies or remote upload were added.

Browser decode follow-up: the locked Flutter web ImageDescriptor width/height getters are unsupported. Web now validates using `ui.instantiateImageCodec` with both target axes 256 and `allowUpscaling: false`, reads the first frame and disposes frame/codec. Native retains the 8192 source-dimension cap and proportional thumbnail; web enforces the 5 MB byte cap and bounded decode request, without claiming source-dimension inspection. Invalid images still fail; there is no acceptance fallback.

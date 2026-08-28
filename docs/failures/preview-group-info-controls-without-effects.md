# Preview Group Information Exposed Controls Without Effects

## Summary

The Development Preview group-information page exposed enabled member-option
buttons that did nothing and a Leave confirmation whose final action only
closed the dialog. Its notification switches also looked provider-backed even
though they changed widget state only.

## Root Cause

The page was treated as a visual catalog after its exact conversation identity
was fixed. That protected fixture selection but did not verify whether each
enabled control owned the provider mutation implied by its label. Local state,
dialog completion, and Stream account state were therefore conflated.

## Detection

A providerless-control audit traced every enabled callback in the mounted
Preview group-information slice. `_MemberRow` contained `onPressed: () {}`;
the Leave confirmation popped its dialog without changing any gateway or
membership state; and no notification-settings port existed behind the two
switches.

## Prevention

Preview preference controls are now visibly process-local and their dependent
state is deterministic. Unsupported member and membership actions are absent
or disabled. The Harness keeps the group-information page, its separately
defined member-list sheet, and executable evidence fingerprinted; rejects
restored empty callbacks or enabled Leave; and requires the no-Stream-write
labels. A local acknowledgement is never accepted as evidence of a provider
mutation.

## Evidence

`test/chat_preview_conversation_identity_test.dart` proves the labelled local
switch transition, member-list behavior, disabled Leave action, and continued
exact Preview conversation scope. `tests/test_check_harness.py` mutates each
boundary and requires the Harness to reject the regression.

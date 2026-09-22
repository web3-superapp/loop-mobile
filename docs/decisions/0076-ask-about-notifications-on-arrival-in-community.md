# Ask About Notifications on Arrival in Community

## Status

Accepted on 2026-09-22, by the product owner.

## Context

Until 2026-09-22 no device had ever been asked. The registration required an
account the backend had accepted, and the only callers that told it to look
again ran before that account existed, so it stopped at "no account" for the
rest of every run: no prompt, no token, no `POST /v2/devices/push-token`, and
no row on the server for a phone that had been signed in for days (S73).

Fixing that left a second question the code could not answer by itself: *when*
to ask. The first repair asked at the moment `POST /v2/session/bootstrap`
succeeded, which is in the middle of the five-step opening — the system dialog
landed on top of 创建钱包, before the owner had seen anything LOOP could
notify them about.

Decision 0067 already fixed the boundary at "never before there is an
account": a permission prompt on first launch asks somebody who has not yet
decided to use LOOP to decide about notifications. That rule was right and is
not weakened here; it was simply not specific enough about the moment.

Apple's own guidance is the same shape: ask in context, where the value of the
answer is visible, and never on launch. Community is where LOOP opens, where
the things a notification is about actually are, and — for a new account — the
first page that is not a step.

## Decision

- The notification permission is requested, and the device registered, on the
  account's **first arrival in Community** in a run. Not before, not on any
  other page, and not a second time.
- The arrival is the landing `GET /v2/profile` published becoming
  `community` — not a route location. An account whose answer is Community
  has arrived whether the router put it on the tab or on a conversation deep
  under it, and a location string would never match the second one.
- Both paths that produce that answer mark it: the landing the profile read
  publishes, and the end of the five-step opening. Either order works. A
  restored session that reaches Community before `bootstrap` answers, and one
  whose `bootstrap` answers first, both end up registering, because the
  arrival and the backend identity each re-evaluate the registration.
- The provider's own token refresh waits for the same arrival. On Android the
  first registration token exists before anybody has been asked anything, and
  registering it would put the device on the server's list at a moment nobody
  chose.
- Leaving the account drops the arrival. The next account on this device has
  not been anywhere yet and is asked on its own arrival.
- The step the registration stopped at is recorded on the device — an enum
  member and a time, never a token, an address, a session id or a
  configuration — and the notification-preferences page turns it into one
  sentence about this device. While the arrival is what is being waited for,
  that sentence is 「还没有向这台设备请求通知权限 / 进入社区后会请求一次。」

## Invariants

1. **Nothing is asked during the opening.** No page of the five-step sequence
   can produce a permission dialog, and neither can the launch page.
2. **A refusal is read, never repeated.** The device is asked at most once per
   account. Afterwards the answer is re-read with `getNotificationSettings`,
   which draws nothing, so a permission the owner turned on in the system
   settings is picked up the next time LOOP comes to the foreground.
3. **A registered device asks the provider for nothing.** Re-evaluation is
   idempotent and happens on the arrival, on the backend accepting the
   account, on the capability document changing its answer, and on returning
   to the foreground.
4. **A build with no push provider says so first.** A Firebase that could not
   be brought up is reported as "this device has no push channel", never as
   an account that is not ready yet.

## Consequences

- A new account sees the system dialog once, on the first Community frame
  after 05, with the rest of the product already on screen behind it.
- A returning account is registered on the first Community frame of the run,
  without being asked anything.
- An owner who refuses gets one honest sentence and one next step, and LOOP
  notices by itself when that step is taken.
- The arrival is application state and not persisted: a cold start asks the
  same question of the platform again, which answers from its own stored
  decision without drawing anything.

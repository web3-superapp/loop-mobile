# 0029 Require Explicit Service Error Observation

## Status

Accepted on 2026-08-28.

## Context

I2 is a reusable global presentation for a request error or unconfirmed
outcome. The routed screen previously created a fixed `L-2048` support code
without an observed request error and asserted that an operation had not
completed. Its `Try again` and
`Contact support` actions both navigated to Home, so neither performed the
action named by its label.

A route name is not a response, exception or support-system reference. A
generic retry is also unsafe for an ambiguous wallet or trading write that
must be reconciled before another submission.

## Decision

- I2 renders the service-error state only after the owning feature supplies one
  explicit `LoopServiceErrorObservation` for an exact request that returned an
  error or unconfirmed outcome. The copy assumes neither success nor failure.
- A naked `/system/error` route reports that no error context is connected.
  It creates no error, support reference, retry or support claim.
- The observation is currently an empty marker. No support-reference source or
  grammar has been reviewed, so the view displays none; raw exceptions,
  identifiers, response bodies, headers and provider messages stay outside the
  projection.
- Retry and support use independent I2 callbacks and appear only when their
  exact behavior is connected. The generic system-route callbacks do not
  authorize either action.
- Feature-owned local errors remain local. This slice adds no error bus,
  backend route, support integration, automatic retry, persistence, SDK,
  dependency or native capability.

## Consequences

Opening the catalog or a deep link no longer fabricates a service incident or
tracking code. A later feature may reuse I2 after mapping its own known error or
unconfirmed outcome to the narrow projection, but it remains responsible for
safe retry and for reconciling ambiguous writes.

## Evidence

- `test/system_server_error_truthfulness_test.dart`

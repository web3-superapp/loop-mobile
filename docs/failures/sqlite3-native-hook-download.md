# SQLite3 Native Hook Download Blocks Cold Builds

## Summary

Clean Flutter tests and Android Debug builds repeatedly stopped before Dart
compilation because sqlite3's default native hook could not download its
platform artifact from GitHub. Warm outputs could conceal the problem, so an
old APK was not valid evidence that the current source compiled.

## Root Cause

The pinned persistence dependency graph resolves sqlite3 3.5.2. Its default
hook downloads a precompiled native SQLite library from GitHub on a cold build.
The development network intermittently timed out, reset TLS, or closed port
443. The same graph also resolves `sqlite3_flutter_libs` 0.5.42, which already
packages Android `libsqlite3.so`, but the sqlite3 v3 hook still attempted its
own download unless explicitly configured.

## Detection

- Always distinguish a hook/download failure from a Dart test or compile
  failure; the former occurs before test execution and produces no behavior
  result.
- Run the requested feature checkpoint from a clean generated state.
- Inspect the resulting Debug APK rather than accepting a stale file left by a
  previous build.
- `scripts/check_harness.py` requires the exact sqlite3 system-source hook, and
  its mutation test proves changing the source is rejected.

## Prevention

- Keep `hooks.user_defines.sqlite3.source: system` in `pubspec.yaml` while the
  locked Stream persistence graph supplies Android SQLite libraries.
- Keep exact dependency and lockfile pins; re-review this workaround whenever
  the persistence graph or platform ABI matrix changes.
- Run only the routine Android Debug gate at an explicit feature checkpoint,
  then clean generated packages as required by decision 0015.
- Preserve device database-open and offline-history validation as unverified
  until it is actually exercised; compilation alone is not runtime proof.

## Evidence

- Multiple focused Flutter test attempts and one Android Debug attempt failed
  while fetching sqlite3 native artifacts from GitHub, before application code
  ran.
- The same focused suite passed after selecting `source: system`.
- Decision 0018 records the accepted compatibility boundary and required clean
  Android Debug/APK inspection evidence.

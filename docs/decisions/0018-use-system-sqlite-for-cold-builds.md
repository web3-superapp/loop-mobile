# Use the Available System SQLite for Cold Builds

## Status

Accepted on 2026-08-25.

## Context

The pinned Stream Chat persistence graph resolves Drift with `sqlite3` 3.5.2
and the transitional `sqlite3_flutter_libs` package. By default, sqlite3 v3
runs a native build hook that downloads a platform binary from a GitHub
release. Repeated clean tests and Android Debug builds failed before Dart
compilation when that host timed out or closed TLS connections. The failure
made toolbar Run depend on an unrelated cold-build network request even though
the locked Android graph already packages `libsqlite3.so` for arm64-v8a,
armeabi-v7a, and x86_64.

The sqlite3 package officially supports selecting the operating-system library
with `hooks.user_defines.sqlite3.source: system`. Apple platforms provide
SQLite, and Android resolves the packaged Stream persistence libraries under
the current exact dependency graph.

## Decision

- Keep a top-level `hooks.user_defines.sqlite3.source: system` entry in
  `pubspec.yaml` for the current exact dependency graph.
- Treat the entry as a native compatibility boundary. The Harness fails if it
  is removed or changed to the default downloadable binary source.
- Preserve the exact Stream, Drift, sqlite3, and sqlite3_flutter_libs resolution
  in `pubspec.lock`; this decision does not upgrade or add a Dart dependency.
- Verify a clean Android Debug build and inspect the APK for the supported
  Android ABI libraries. Do not retain the generated package afterward.
- Do not call compilation proof a Stream persistence runtime pass. Database
  open, offline history, account rotation, migration, and supported iOS/Android
  device behavior remain explicit provider/device checks.
- Revisit this override whenever Stream persistence removes
  `sqlite3_flutter_libs`, sqlite3 changes its hook contract, the supported ABIs
  change, or LOOP adopts a custom encrypted SQLite build. Such a change needs
  a new decision, cold native verification, and device database evidence.

## Consequences

Cold tests and Android Debug builds no longer depend on downloading a sqlite3
native artifact from GitHub. This makes IDE Run deterministic in the current
environment and retains the libraries already shipped by the pinned Stream
persistence graph.

The selected SQLite binary may have different compile-time options from the
sqlite3 package's bundled release. LOOP currently uses Stream's ordinary
persistence path and does not claim SQLCipher or custom SQLite extensions. A
later dependency or persistence change must re-evaluate those capabilities
instead of silently relying on this override.

# GitNexus Generated Source Pollution

## Summary

The repository graph indexed vendored CocoaPods and the frozen web prototype as
if they were Loop Mobile application source. Impact analysis then resolved Dart
symbols to unrelated C functions and reported false critical blast radii. A
subsequent rebuild also exposed an inconsistent Ladybug full-text index.

## Root Cause

GitNexus reads ignore rules from the repository root. CocoaPods is ignored by
an iOS-local ignore file, while the frozen prototype remains tracked for
reference, so neither tree was excluded from graph analysis. Reusing the
polluted index amplified ambiguous symbol resolution and eventually left its
full-text index inconsistent.

## Detection

Run `python3 scripts/check_harness.py` to require the root `.gitnexusignore`
rules. After a graph rebuild, `gitnexus list` or the repository context must not
count `ios/Pods/` or `reference/legacy-prototype/` as indexed application files.
Impact results that resolve a requested Dart file to another path are invalid
evidence and require an index refresh before editing.

## Prevention

Keep `ios/Pods/` and `reference/legacy-prototype/` in the root
`.gitnexusignore`. When the index is corrupt, delete only the current
repository index with `gitnexus clean --force`, then run
`gitnexus analyze --index-only`; pure index mode must be used so user-owned
`AGENTS.md`, `CLAUDE.md`, and `.claude/` content is not injected or rewritten.

## Evidence

On 2026-08-28, the polluted metadata contained 1,467 CocoaPods files and 107
frozen-prototype files. `FullChartScreen` impact included unrelated Pods and
prototype flows, and the analyzer reported an inconsistent `file_fts` index.
A clean `--index-only` rebuild completed successfully; the Harness mutation
test now detects removal of either root exclusion.

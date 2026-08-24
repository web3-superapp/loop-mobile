# Privy 0.10.1 Compiles Below Its AndroidX Dependency Floor

## Summary

The Android compatibility build reached AAR validation but failed because `privy_flutter` 0.10.1 compiles its library with API 34 while resolved AndroidX Credentials 1.5.0 requires API 35 or newer.

## Root Cause

An application's compileSdk 36 does not overwrite a library subproject's explicit compileSdk 34. A callback that runs too early is also overwritten by the Privy Gradle script.

## Detection

The Android build identified Privy's API 34 library surface against the AndroidX Credentials minimum. The Harness checks the root `afterEvaluate` library-extension override and API 36 value.

## Prevention

Compile every Android library subproject at API 36 after evaluation. Remove this workaround only after a published Privy release is compatible and both Android build modes pass.

## Evidence

- `privy_flutter` 0.10.1 publishes `compileSdk = 34`.
- Its resolved AndroidX Credentials 1.5.0 AAR declares `minCompileSdk=35`.
- API 36 plus the post-evaluation host override passed Debug and Release in the compatibility spike.

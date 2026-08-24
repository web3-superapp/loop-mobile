# Flutter 3.47 Rejects Gradle 8.13

## Summary

The first Android compatibility build failed before compiling the application because Flutter 3.47.1 rejects Gradle 8.13. The repository baseline is Gradle 8.14 with AGP 8.13.2.

## Root Cause

The candidate matrix combined a current Flutter patch release with an older Gradle floor. Flutter 3.47.1 maps AGP 8.13.x to a minimum Gradle version of 8.14.

## Detection

`flutter build apk --debug` failed while applying the Flutter Gradle plugin with a version-floor message. `scripts/check_harness.py` now checks the exact wrapper distribution.

## Prevention

Do not bypass Flutter dependency validation. Any Flutter, AGP, or Gradle change must run Android Debug and Release builds and update the decision and compatibility report.

## Evidence

- Failed baseline: Flutter 3.47.1 with Gradle 8.13.
- Corrected wrapper: `https://services.gradle.org/distributions/gradle-8.14-all.zip`.
- Corrected Android Debug and Release builds passed in the compatibility spike.

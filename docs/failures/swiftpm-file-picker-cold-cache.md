# File Picker 11 Makes SwiftPM Cold-Cache Resolution Brittle

## Summary

An iOS Debug compatibility build stalled during Swift Package Manager resolution. Loop uses the project-level SwiftPM opt-out and CocoaPods 1.16.2 instead.

## Root Cause

Stream Chat 10.3.0 constrains file_picker to 11.0.3, whose iOS package manifest requests DKImagePickerController `4.3.9` as a branch even though upstream publishes that reference as a tag. A cold cache also requires large remote repository mirrors.

## Detection

`flutter build ios --debug --no-codesign` remained in `xcodebuild -resolvePackageDependencies` while the active Git mirror stopped growing. CocoaPods subsequently completed the pinned native graph.

## Prevention

Keep `flutter.config.enable-swift-package-manager` false in this repository, use iOS 17/CocoaPods 1.16.2, and retain `ios/Podfile.lock`. Never change a developer's global Flutter setting.

## Evidence

- file_picker 11.0.3 declares DKImagePickerController using `branch: "4.3.9"`.
- The compatibility spike passed iOS Debug and Release no-codesign with CocoaPods.
- The Harness rejects regenerated Flutter SwiftPM references in the Xcode project.

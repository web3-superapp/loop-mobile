# 0074 — Take the photo in the composer

## Status

Accepted on 2026-09-19 (S46), on the user's ruling of the same day.

## Context

S45 gave a chat message its picture, but only one that already existed: the
composer opens the platform's own photo chooser, which costs no permission and
never sees the rest of the library. A camera does cost one. LOOP does not
declare a permission because an SDK offers a feature, so S45 shipped without a
camera row and said so in its commit.

The ruling of 2026-09-19 answers that question: chat may take a photo, and
`android.permission.CAMERA` may be declared for it. Multi-select was refused in
the same breath — the photo chooser stays one picture at a time.

Two facts shaped the implementation:

* Stream's *system* attachment picker — the one LOOP uses, precisely because it
  needs no permission — ships no camera option at all. The camera lives in the
  tabbed picker, whose gallery grid draws from `photo_manager` and would pull in
  `READ_MEDIA_IMAGES` on Android 13+. LOOP wants one permission, not two.
* `ImageSource` belongs to `image_picker`, a transitive package. Adding it as a
  direct dependency is a lockfile decision, which this step does not have.

## Decision

* Declare exactly one new Android permission, `android.permission.CAMERA`, and
  one iOS purpose string, `NSCameraUsageDescription` = 用于在聊天中拍照发送图片.
  No camera *hardware feature* is declared, and Audio Room's configuration is
  untouched — it still asks for the microphone alone.
* Add one `SystemAttachmentPickerOption` beside the gallery row, titled with the
  translation the tabbed picker already used (拍照), applied through
  `loopChatImageComposerProps` so every LOOP composer — room, direct message,
  thread — gets it or none does.
* Drive the capture with `StreamAttachmentHandler.instance.pickImage(source:
  .camera)`. The dot shorthand names the `image_picker` enum value from the
  context type without importing the library, so no new import and no new
  dependency appear.
* Judge the captured photo with S45's own `loopChatReviewImages`: images only,
  four formats, 10 MB each, nine per message. A refused photo is never cached,
  compressed or uploaded.
* Say one thing per outcome. A denied permission reads 「没有相机权限，去系统设置
  里允许 LOOP 使用相机后再试」 — the one action that changes the result, and not
  "retry", because LOOP owns no way to open that settings page. A cancelled
  capture says nothing and adds nothing: the member already knows what they did.
* Replace the harness's blanket camera ban with `check_chat_camera_contract`,
  which is two-sided: the declaration must exist, and the code and the tests
  that justify it must exist too.

## Consequences

* The app's permission list grows by one line, and a store review can be
  answered with one sentence: the chat composer takes photos.
* An Android device without a camera is filtered by Play's implied
  `android.hardware.camera` requirement. LOOP declares no `uses-feature`, so the
  requirement stays implicit; if that filtering ever matters, the answer is an
  explicit `required="false"`, which is a separate decision.
* The refusal copy is LOOP's, not Stream's, and is not covered by
  `stream_chat_localizations_zh.dart`: no Stream widget renders it.
* Multi-select remains out of scope, by the same ruling.
* Nothing here was verified on a device. The capture, the permission prompt and
  the denial path are compile-and-test evidence only, and the first real-device
  run is the acceptance step.

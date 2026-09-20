// Taking the picture instead of finding it (S46).
//
// S45 shipped the picture as a message but left the camera out on purpose: a
// photo taken inside the app needs `android.permission.CAMERA`, and LOOP does
// not declare a permission without a ruling. The ruling came on 2026-09-19 —
// the composer gets a camera row, and the manifest gets that one line.
//
// Three things are LOOP's here, and only these three:
//
//  * the row. Stream's system attachment picker ships gallery, video, file and
//    poll options; none of them opens a camera. The camera lives in the tabbed
//    picker, which LOOP does not use (its gallery grid needs READ_MEDIA_IMAGES
//    on Android 13+). So LOOP adds one `SystemAttachmentPickerOption` beside
//    the gallery row and drives the capture itself;
//  * the same gate. A photo taken here is judged by `loopChatReviewImages`,
//    the S45 rule, before it is added — so the ceiling a member is told about
//    (images only, four formats, 10 MB, nine per message) is the one that
//    holds no matter which way the picture came in. A refused photo is never
//    cached, compressed or uploaded;
//  * what LOOP says. A denied camera permission is not an error the member
//    can retry into success — it is a setting they have to change — and a
//    cancelled capture is not a failure at all, so it says nothing.
//
// `ImageSource.camera` is written `.camera`: the enum lives in `image_picker`,
// a transitive package LOOP does not depend on, and the dot shorthand names
// the value from the context type without importing its library.
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_policy.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Captures one photo, or returns null when the member backed out.
///
/// The seam exists so the rule, the copy and the refusals can be tested
/// without a camera; production always uses [loopChatCaptureFromCamera].
typedef LoopChatCameraCapture = Future<Attachment?> Function();

/// The key of LOOP's camera row in the attachment picker.
const String loopChatCameraOptionKey = 'loop-camera';

/// What LOOP says when the system refused the camera.
///
/// It names the one thing that will change the outcome. LOOP cannot open the
/// system settings page itself — no permission plugin is in the lockfile — so
/// it does not offer a button that would have to fake the trip.
const String loopChatCameraPermissionMessage = '没有相机权限，去系统设置里允许 LOOP 使用相机后再试';

/// What LOOP says when the capture itself failed.
///
/// Not "sent", not "saved": nothing was added to the message.
const String loopChatCameraUnavailableMessage = '相机没有拍成照片，这次没有加进来。';

/// Opens the device camera through Stream's own attachment handler.
///
/// The handler is the same one the SDK's picker uses, so the returned
/// [Attachment] carries the file, name and MIME type the rest of the composer
/// already knows how to read.
Future<Attachment?> loopChatCaptureFromCamera() =>
    StreamAttachmentHandler.instance.pickImage(source: .camera);

/// Whether [error] is the platform saying the member has not granted the
/// camera.
///
/// `image_picker` reports this as a `PlatformException` on both platforms;
/// everything else is a failure of the capture, not of a permission.
bool loopChatCameraPermissionDenied(Object error) =>
    error is PlatformException &&
    const <String>{
      'camera_access_denied',
      'photo_access_denied',
    }.contains(error.code);

/// The sentence for a capture that ended in [error].
String loopChatCameraProblemMessage(Object error) =>
    loopChatCameraPermissionDenied(error)
    ? loopChatCameraPermissionMessage
    : loopChatCameraUnavailableMessage;

/// Why LOOP will not add [photo] to a draft that already holds [current], or
/// null when it will.
///
/// This is S45's rule, called on S45's function: the photo is appended to what
/// the composer is holding and the whole draft is reviewed, so the count, the
/// format and the size all come from one place.
LoopChatImageRefusal? loopChatRefuseCameraPhoto({
  required List<Attachment> current,
  required Attachment photo,
}) {
  final review = loopChatReviewImages(<Attachment>[...current, photo]);
  // Identity, not equality: the refusal being reported is the one that kept
  // *this* photo out, not one an already-held attachment caused.
  if (review.kept.any((it) => identical(it, photo))) return null;
  return review.refusal;
}

/// Takes one photo and puts it in the draft the picker is filling.
///
/// Reports through [onProblem] exactly once, and only when there is something
/// to report: a cancelled capture adds nothing and says nothing, because the
/// member already knows what they did.
Future<void> loopChatTakePhoto({
  required StreamAttachmentPickerController controller,
  required LoopChatCameraCapture capture,
  required void Function(String message) onProblem,
}) async {
  final Attachment? photo;
  try {
    photo = await capture();
  } on Object catch (error) {
    onProblem(loopChatCameraProblemMessage(error));
    return;
  }

  // Cancelled. Nothing was taken, so nothing is said.
  if (photo == null) return;

  final refusal = loopChatRefuseCameraPhoto(
    current: controller.value.attachments,
    photo: photo,
  );
  if (refusal != null) return onProblem(loopChatImageRefusalMessage(refusal));

  try {
    await controller.addAttachment(photo);
  } on Object catch (error) {
    onProblem(loopChatCameraProblemMessage(error));
  }
}

/// LOOP's camera row, beside the picker's gallery row.
///
/// The title is the translation the tabbed picker already used for its camera
/// tab (`拍照`), so the two surfaces cannot drift apart, and the icon is the
/// theme's, so the row matches the one above it.
SystemAttachmentPickerOption loopChatCameraPickerOption(
  BuildContext context, {
  required LoopChatCameraCapture capture,
  required void Function(String message) onProblem,
}) => SystemAttachmentPickerOption(
  key: loopChatCameraOptionKey,
  // Images: the row must survive the composer's `allowedAttachmentPickerTypes`
  // filter, which LOOP pins to images alone.
  supportedTypes: const <AttachmentPickerType>[AttachmentPickerType.images],
  icon: context.streamIcons.camera,
  title: context.translations.photoFromCameraLabel,
  onTap: (context, controller) => loopChatTakePhoto(
    controller: controller,
    capture: capture,
    onProblem: onProblem,
  ),
);

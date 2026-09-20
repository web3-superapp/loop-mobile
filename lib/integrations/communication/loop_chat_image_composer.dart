// The composer, once it can send a picture.
//
// Stream's composer already owns picking, previewing, uploading, progress and
// retry. LOOP adds three things it cannot get from the SDK:
//
//  * a narrower gate — images only, four formats, 10 MB, nine per message
//    (`loop_chat_image_policy.dart`). Stream's own validator reads the
//    server's `imageUploadConfig`, which LOOP does not set and which is far
//    more permissive than a phone on a mobile network should be asked to
//    honour;
//  * the refusal in LOOP's voice, on the surface the member is looking at,
//    instead of Stream's English alert dialog;
//  * the Chinese word. The panel says 图片, never 附件: "attachment" is a
//    provider's word for a wire field, not something a member sends.
//
// S46 adds a fourth: the camera row. The system attachment picker ships no
// camera option at all, so LOOP builds one (`loop_chat_camera.dart`) and puts
// what it captures through the same gate as a picked picture.
//
// The gate is a listener on the composer's own controller rather than a
// subclass: `StreamMessageComposerController` has a private constructor, and
// every add path in the SDK — the picker, the drag target, the paste handler —
// ends at its `attachments` setter, so one listener sees them all.
import 'package:flutter/widgets.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_camera.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_policy.dart';
import 'package:loop_mobile/integrations/communication/stream_failure.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Applies LOOP's composer policy to [props].
///
/// Every LOOP composer — room, direct message, thread — goes through this, so
/// the gate cannot be half-applied on one surface.
///
/// `useSystemAttachmentPicker` is on deliberately. The tabbed picker draws its
/// own gallery grid from `photo_manager`, which needs `READ_MEDIA_IMAGES` on
/// Android 13+; the system picker hands the choice to the platform's own photo
/// chooser, which needs no permission at all and never sees the rest of the
/// library.
///
/// S46 adds one row to that picker: 拍照. It is LOOP's own option because the
/// system picker ships none, and it is the only reason the manifest declares
/// `android.permission.CAMERA` (ruling of 2026-09-19). [onProblem] is what the
/// member reads when the capture is refused or fails; the composer passes its
/// own toast.
MessageComposerProps loopChatImageComposerProps(
  MessageComposerProps props, {
  LoopChatCameraCapture capture = loopChatCaptureFromCamera,
  void Function(String message)? onProblem,
}) => props.copyWith(
  disableAttachments: false,
  enableVoiceRecording: false,
  useSystemAttachmentPicker: true,
  allowedAttachmentPickerTypes: loopChatImagePickerTypes,
  attachmentLimit: loopChatImageMaxCount,
  attachmentPickerOptionsBuilder: (context, defaults) =>
      <AttachmentPickerOption>[
        ...defaults,
        loopChatCameraPickerOption(
          context,
          capture: capture,
          // A composer mounted without a reporter still takes the photo; it
          // simply has nowhere to say why one was refused. Every LOOP surface
          // passes one.
          onProblem: onProblem ?? (_) {},
        ),
      ],
);

/// Holds one composer controller to LOOP's image rule.
///
/// Attach it to the controller a surface owns, before the composer mounts. It
/// puts back the list the member is allowed to send and reports the first rule
/// that was broken; it never uploads, compresses or queues what it dropped.
class LoopChatImageAttachmentGate {
  LoopChatImageAttachmentGate({
    required StreamMessageComposerController controller,
    required void Function(LoopChatImageRefusal refusal) onRefused,
  }) // The fields are private, so an initializing formal would leak the
    // underscore into the constructor's public parameter name.
    // ignore: prefer_initializing_formals
    : _controller = controller,
       // ignore: prefer_initializing_formals
       _onRefused = onRefused;

  final StreamMessageComposerController _controller;
  final void Function(LoopChatImageRefusal refusal) _onRefused;

  bool _attached = false;
  bool _writing = false;

  /// Starts watching. Safe to call twice.
  void attach() {
    if (_attached) return;
    _attached = true;
    _controller.addListener(_review);
    _review();
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    _controller.removeListener(_review);
  }

  void _review() {
    // The write below notifies this same listener; without the guard the
    // second pass would report the same refusal again.
    if (_writing) return;
    final review = loopChatReviewImages(_controller.attachments);
    if (!review.refused) return;
    _writing = true;
    try {
      _controller.attachments = review.kept;
    } finally {
      _writing = false;
    }
    _onRefused(review.refusal!);
  }
}

/// What LOOP says when an upload or a send did not go through.
///
/// Stream reports four shapes here, and they mean four different things to the
/// member. A validator refusal is LOOP's own rule restated; a 403 is the
/// server refusing this account's upload; a transport failure means the
/// picture never left the phone. None of them may read as "sent".
String loopChatImageFailureMessage(Object error) {
  if (error is AttachmentLimitReachedError) {
    return loopChatImageRefusalMessage(LoopChatImageRefusal.tooMany);
  }
  if (error is AttachmentTooLargeError) {
    return loopChatImageRefusalMessage(LoopChatImageRefusal.tooLarge);
  }
  if (error is AttachmentBlockedError) {
    return loopChatImageRefusalMessage(LoopChatImageRefusal.unsupportedFormat);
  }
  if (loopStreamFailureIsOffline(error)) {
    return '设备当前离线，图片没有上传，这条消息也没有发出去。';
  }
  if (error is StreamChatNetworkError && error.statusCode == 403) {
    return '服务端拒绝了这次图片上传，这条消息没有发出去。';
  }
  return '图片没有上传成功，这条消息没有发出去。';
}

/// The LOOP composer: the official one, behind LOOP's gate and LOOP's copy.
///
/// Registered once, on [StreamComponentBuilders.messageComposer], so it also
/// covers the composers LOOP does not construct itself — a thread opened from
/// inside the official message list, say.
class LoopChatImageComposer extends StatefulWidget {
  const LoopChatImageComposer({required this.props, super.key});

  final MessageComposerProps props;

  @override
  State<LoopChatImageComposer> createState() => _LoopChatImageComposerState();
}

class _LoopChatImageComposerState extends State<LoopChatImageComposer> {
  LoopChatImageAttachmentGate? _gate;

  @override
  void initState() {
    super.initState();
    _attachGate();
  }

  @override
  void didUpdateWidget(covariant LoopChatImageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.props.messageComposerController;
    if (!identical(previous, widget.props.messageComposerController)) {
      _gate?.dispose();
      _gate = null;
      _attachGate();
    }
  }

  @override
  void dispose() {
    _gate?.dispose();
    _gate = null;
    super.dispose();
  }

  void _attachGate() {
    // A composer that was handed no controller builds its own, privately.
    // Stream's own `attachmentLimit` still holds there; LOOP's size and format
    // rule cannot, so no LOOP surface leaves the controller out.
    final controller = widget.props.messageComposerController;
    if (controller == null) return;
    _gate = LoopChatImageAttachmentGate(controller: controller, onRefused: _say)
      ..attach();
  }

  void _say(LoopChatImageRefusal refusal) =>
      _toast(loopChatImageRefusalMessage(refusal));

  void _toast(String message) {
    if (!mounted) return;
    // Above the router; a composer is always below it. The guard keeps a test
    // that mounts the composer alone from tripping the host's assertion.
    if (LoopToastHost.maybeOf(context) == null) return;
    LoopToast.show(context, message: message, kind: LoopToastKind.warn);
  }

  @override
  Widget build(BuildContext context) => DefaultStreamMessageComposer(
    props: loopChatImageComposerProps(widget.props, onProblem: _toast).copyWith(
      onError: (error, _) => _toast(loopChatImageFailureMessage(error)),
    ),
  );
}

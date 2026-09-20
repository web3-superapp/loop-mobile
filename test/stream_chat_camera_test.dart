// Taking the picture (S46).
//
// 2026-09-19 裁决：聊天可以拍照，并为此声明 `android.permission.CAMERA`。
// 一条权限换来的只有 composer 里的一行，所以这行要经得起四件事：
//
//  * 入口在那儿，就在「从相册选择图片」旁边，名字是「拍照」，不是「附件」；
//  * 拍出来的图和选出来的图走同一条闸门——四种格式、10 MB、九张；
//  * 权限被拒绝时说的是成员唯一能做的那件事（去系统设置），而不是「重试」；
//  * 取消拍照不是失败：不发消息，也不说话。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_camera.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_composer.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_policy.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

Attachment photo({
  String name = 'IMG_0001.jpg',
  int size = 640 * 1024,
  String? mimeType = 'image/jpeg',
}) => Attachment(
  type: 'image',
  file: AttachmentFile(name: name, size: size, bytes: Uint8List(8)),
  extraData: <String, Object>{'file_size': size, 'mime_type': ?mimeType},
);

void main() {
  group('拍照入口', () {
    testWidgets('就在相册那一行旁边，叫「拍照」', (tester) async {
      final options = await _pickerOptions(tester);

      expect(
        options.map((it) => it.key),
        // Stream's own system row stays; LOOP's camera row is added after it.
        <String>['image-picker', loopChatCameraOptionKey],
      );
      final camera = options.last;
      expect(camera, isA<SystemAttachmentPickerOption>());
      expect(camera.title, '拍照');
      expect(camera.title!.contains('附件'), isFalse);
      // The composer only allows images, and an option whose supported types
      // fall outside that list is filtered out before it is ever drawn.
      expect(camera.supportedTypes, <AttachmentPickerType>[
        AttachmentPickerType.images,
      ]);
    });

    testWidgets('每个 LOOP composer 都有这一行', (tester) async {
      // The props function is what every surface — room, DM, thread — goes
      // through, so the row cannot be mounted on one screen and missing on the
      // next.
      final props = loopChatImageComposerProps(const MessageComposerProps());
      expect(props.attachmentPickerOptionsBuilder, isNotNull);
      expect(props.useSystemAttachmentPicker, isTrue);
      expect(props.attachmentLimit, loopChatImageMaxCount);
    });
  });

  group('拍一张', () {
    testWidgets('取消拍照既不发消息，也不报错', (tester) async {
      final controller = StreamAttachmentPickerController();
      addTearDown(controller.dispose);
      final said = <String>[];

      await _tapCamera(
        tester,
        controller: controller,
        capture: () async => null,
        onProblem: said.add,
      );

      expect(controller.value.attachments, isEmpty);
      expect(said, isEmpty);
    });

    testWidgets('没有相机权限时，只说去系统设置', (tester) async {
      final controller = StreamAttachmentPickerController();
      addTearDown(controller.dispose);
      final said = <String>[];

      await _tapCamera(
        tester,
        controller: controller,
        capture: () async => throw PlatformException(
          code: 'camera_access_denied',
          message: 'The user did not allow camera access.',
        ),
        onProblem: said.add,
      );

      expect(said, <String>['没有相机权限，去系统设置里允许 LOOP 使用相机后再试']);
      expect(said.single, loopChatCameraPermissionMessage);
      expect(controller.value.attachments, isEmpty);
      // LOOP cannot open that settings page itself, so it never promises to.
      expect(said.single.contains('重试'), isFalse);
    });

    testWidgets('相机出别的错时，不说成已经发出去了', (tester) async {
      final controller = StreamAttachmentPickerController();
      addTearDown(controller.dispose);
      final said = <String>[];

      await _tapCamera(
        tester,
        controller: controller,
        capture: () async =>
            throw PlatformException(code: 'no_available_camera'),
        onProblem: said.add,
      );

      expect(said, <String>[loopChatCameraUnavailableMessage]);
      expect(said.single.contains('发出'), isFalse);
      expect(said.single.contains('附件'), isFalse);
      expect(controller.value.attachments, isEmpty);
    });

    testWidgets('拍出来的图走的是 S45 那条闸门', (tester) async {
      final controller = StreamAttachmentPickerController();
      addTearDown(controller.dispose);
      final said = <String>[];

      // Too large: refused with LOOP's own sentence, and never cached.
      await _tapCamera(
        tester,
        controller: controller,
        capture: () async =>
            photo(name: 'IMG_0002.jpg', size: 24 * 1024 * 1024),
        onProblem: said.add,
      );
      expect(said, <String>[
        loopChatImageRefusalMessage(LoopChatImageRefusal.tooLarge),
      ]);
      expect(controller.value.attachments, isEmpty);

      // The tenth picture of a message: refused for the same reason a tenth
      // picked one is.
      said.clear();
      final held = <Attachment>[
        for (var i = 0; i < loopChatImageMaxCount; i++)
          photo(name: 'held$i.jpg'),
      ];
      controller.value = controller.value.copyWith(attachments: held);
      await _tapCamera(
        tester,
        controller: controller,
        capture: () async => photo(name: 'IMG_0003.jpg'),
        onProblem: said.add,
      );
      expect(said, <String>[
        loopChatImageRefusalMessage(LoopChatImageRefusal.tooMany),
      ]);
      expect(controller.value.attachments, held);
    });

    testWidgets('合规的那张进了草稿，一句话也不用说', (tester) async {
      // Adding the picture caches the bytes in the platform's temporary
      // directory, which is the only platform channel this path touches.
      final directory = Directory.systemTemp.createTempSync('loop-camera');
      addTearDown(() => directory.deleteSync(recursive: true));
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'getTemporaryDirectory'
            ? '${directory.path}/'
            : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final controller = StreamAttachmentPickerController();
      addTearDown(controller.dispose);
      final said = <String>[];

      await _tapCamera(
        tester,
        controller: controller,
        capture: () async => photo(),
        onProblem: said.add,
      );

      expect(said, isEmpty);
      expect(controller.value.attachments, hasLength(1));
      expect(controller.value.attachments.single.file?.name, 'IMG_0001.jpg');
      expect(loopChatRefuseImage(controller.value.attachments.single), isNull);
    });
  });

  group('拒绝与失败的说法', () {
    test('只有平台说「没给相机」才算权限问题', () {
      expect(
        loopChatCameraPermissionDenied(
          PlatformException(code: 'camera_access_denied'),
        ),
        isTrue,
      );
      expect(
        loopChatCameraPermissionDenied(
          PlatformException(code: 'multiple_request'),
        ),
        isFalse,
      );
      expect(loopChatCameraPermissionDenied(Exception('boom')), isFalse);
      expect(
        loopChatCameraProblemMessage(Exception('boom')),
        loopChatCameraUnavailableMessage,
      );
    });

    test('闸门的判断和 S45 的规则是同一个', () {
      expect(
        loopChatRefuseCameraPhoto(
          current: const <Attachment>[],
          photo: photo(name: 'IMG.bmp', mimeType: 'image/bmp'),
        ),
        LoopChatImageRefusal.unsupportedFormat,
      );
      // A link preview riding along in the draft is not one of the nine, so it
      // cannot push a photo out.
      expect(
        loopChatRefuseCameraPhoto(
          current: <Attachment>[
            Attachment(type: 'url_preview', ogScrapeUrl: 'https://example.com'),
          ],
          photo: photo(),
        ),
        isNull,
      );
    });
  });
}

/// The options the attachment panel actually draws, built through the props
/// every LOOP composer uses.
Future<List<AttachmentPickerOption>> _pickerOptions(WidgetTester tester) async {
  late List<AttachmentPickerOption> options;
  await tester.pumpWidget(
    _themed(
      Builder(
        builder: (context) {
          final props = loopChatImageComposerProps(
            const MessageComposerProps(),
            capture: () async => null,
            onProblem: (_) {},
          );
          options = props.attachmentPickerOptionsBuilder!(
            context,
            <AttachmentPickerOption>[
              SystemAttachmentPickerOption(
                key: 'image-picker',
                supportedTypes: const <AttachmentPickerType>[
                  AttachmentPickerType.images,
                ],
                icon: Icons.image,
                title: '从相册选择图片',
                onTap: (_, _) async {},
              ),
            ],
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return options;
}

/// Presses LOOP's camera row exactly as the panel does.
Future<void> _tapCamera(
  WidgetTester tester, {
  required StreamAttachmentPickerController controller,
  required LoopChatCameraCapture capture,
  required void Function(String message) onProblem,
}) async {
  late BuildContext pickerContext;
  await tester.pumpWidget(
    _themed(
      Builder(
        builder: (context) {
          pickerContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  final option = loopChatCameraPickerOption(
    pickerContext,
    capture: capture,
    onProblem: onProblem,
  );
  // `runAsync`: accepting a photo writes it to a temporary file, and real file
  // I/O cannot complete inside the test binding's fake clock.
  await tester.runAsync(() => option.onTap(pickerContext, controller));
  await tester.pump();
}

/// The frame the application can actually produce: LOOP's dark theme with the
/// Stream palette and LOOP's Chinese strings above the official widgets.
Widget _themed(Widget child) {
  final theme = LoopTheme.dark;
  return MaterialApp(
    theme: theme.copyWith(
      extensions: <ThemeExtension<Object?>>[
        ...theme.extensions.values,
        loopStreamTheme(platform: theme.platform),
      ],
    ),
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      LoopStreamChatLocalizationsDelegate(),
    ],
    home: Scaffold(
      backgroundColor: LoopColors.ink,
      body: Center(child: child),
    ),
  );
}

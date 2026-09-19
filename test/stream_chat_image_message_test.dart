// Sending and reading a picture in a LOOP room (S45).
//
// 2026-09-19: 「要图片」. The composer can now open the system photo chooser,
// and a message can carry up to nine pictures. Three things have to hold at
// once, and each of them has failed somewhere before:
//
//  * the gate. Stream's own validator reads a server-side ceiling LOOP does
//    not set. LOOP's rule — images only, four formats, 10 MB, nine — is what
//    the member is told and what the composer actually enforces;
//  * the reading. A picture that will not load says so in Chinese; it never
//    prints the CDN address it failed to fetch, and it never grows past the
//    bubble ceiling;
//  * the order. S31a keeps a message the device has just sent at the end of
//    the room whatever the device clock says. An upload takes seconds, so a
//    picture is the longest-lived `sending` message there is — exactly the
//    case that would expose a regression.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_server_clock.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_attachments.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_composer.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_policy.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_outgoing_message_order.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// A 1×1 PNG. Small enough to inline, real enough for `Image.memory`.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmM'
  'IQAAAABJRU5ErkJggg==',
);

Attachment localImage({
  String name = 'photo.jpg',
  int size = 512 * 1024,
  String type = 'image',
  String? mimeType = 'image/jpeg',
  UploadState uploadState = const UploadState.success(),
}) => Attachment(
  type: type,
  file: AttachmentFile(name: name, size: size, bytes: onePixelPng),
  uploadState: uploadState,
  extraData: <String, Object>{
    'file_size': size,
    if (mimeType != null) 'mime_type': mimeType,
  },
);

void main() {
  group('图片规则', () {
    test('一张合规的图片原样留下', () {
      final review = loopChatReviewImages(<Attachment>[localImage()]);

      expect(review.refused, isFalse);
      expect(review.kept, hasLength(1));
    });

    test('超过 10 MB 的图片不会进入草稿', () {
      final big = localImage(
        name: 'huge.png',
        size: 12 * 1024 * 1024,
        mimeType: 'image/png',
      );
      final review = loopChatReviewImages(<Attachment>[localImage(), big]);

      expect(review.refusal, LoopChatImageRefusal.tooLarge);
      expect(review.kept, hasLength(1));
      expect(review.kept.single.file?.name, 'photo.jpg');
      expect(loopChatRefuseImage(big), LoopChatImageRefusal.tooLarge);
      // 10 MB exactly is inside the rule; the refusal is for what exceeds it.
      expect(
        loopChatRefuseImage(
          localImage(
            name: 'edge.png',
            size: loopChatImageMaxBytes,
            mimeType: 'image/png',
          ),
        ),
        isNull,
      );
    });

    test('四种格式以外的图片不会进入草稿', () {
      expect(
        loopChatRefuseImage(
          localImage(name: 'scan.bmp', mimeType: 'image/bmp'),
        ),
        LoopChatImageRefusal.unsupportedFormat,
      );
      // The MIME arm is kept for the picker that reports one LOOP does not
      // send. It cannot be built here: `Attachment`'s own constructor
      // overwrites `mime_type` from the file name whenever the platform can
      // derive one, so name and MIME always agree for a named file.
      for (final name in <String>[
        'a.jpg',
        'b.JPEG',
        'c.png',
        'd.webp',
        'e.gif',
      ]) {
        expect(
          loopChatRefuseImage(localImage(name: name, mimeType: null)),
          isNull,
          reason: name,
        );
      }
    });

    test('不是图片的东西不会进入草稿', () {
      expect(
        loopChatRefuseImage(
          localImage(
            name: 'report.pdf',
            type: 'file',
            mimeType: 'application/pdf',
          ),
        ),
        LoopChatImageRefusal.notAnImage,
      );
    });

    test('一条消息最多九张，第十张被挡住', () {
      final picks = <Attachment>[
        for (var i = 0; i < 10; i++) localImage(name: 'p$i.jpg'),
      ];

      final review = loopChatReviewImages(picks);

      expect(review.refusal, LoopChatImageRefusal.tooMany);
      expect(review.kept, hasLength(loopChatImageMaxCount));
      expect(review.kept.last.file?.name, 'p8.jpg');
    });

    test('不是本机挑的东西一概不碰', () {
      // The link preview the composer scrapes from typed text has no local
      // file. Judging it would delete a fact LOOP did not create, and it is
      // not one of the nine.
      final preview = Attachment(
        type: 'url_preview',
        ogScrapeUrl: 'https://example.com',
      );
      final picks = <Attachment>[
        preview,
        for (var i = 0; i < loopChatImageMaxCount; i++)
          localImage(name: 'p$i.jpg'),
      ];

      final review = loopChatReviewImages(picks);

      expect(review.refused, isFalse);
      expect(review.kept, hasLength(loopChatImageMaxCount + 1));
      expect(review.kept.first.ogScrapeUrl, 'https://example.com');
    });

    test('每条拒绝语都说清了界限，并且不说「附件」', () {
      for (final refusal in LoopChatImageRefusal.values) {
        final message = loopChatImageRefusalMessage(refusal);
        expect(message, isNotEmpty);
        expect(message.contains('附件'), isFalse, reason: message);
        expect(message.contains('图片'), isTrue, reason: message);
      }
      expect(
        loopChatImageRefusalMessage(LoopChatImageRefusal.tooLarge),
        contains('10 MB'),
      );
      expect(
        loopChatImageRefusalMessage(LoopChatImageRefusal.tooMany),
        contains('9'),
      );
    });
  });

  group('composer 入口', () {
    test('LOOP 的 composer 只开图片，一次九张，走系统相册', () {
      final props = loopChatImageComposerProps(
        const MessageComposerProps(
          disableAttachments: true,
          enableVoiceRecording: true,
          attachmentLimit: 30,
        ),
      );

      expect(props.disableAttachments, isFalse);
      expect(props.enableVoiceRecording, isFalse);
      expect(props.attachmentLimit, loopChatImageMaxCount);
      expect(props.allowedAttachmentPickerTypes, <AttachmentPickerType>[
        AttachmentPickerType.images,
      ]);
      // The tabbed picker draws its own gallery grid from `photo_manager`,
      // which needs READ_MEDIA_IMAGES on Android 13+. LOOP declares no new
      // permission, so the choice is handed to the platform chooser.
      expect(props.useSystemAttachmentPicker, isTrue);
    });

    test('闸门把越界的那张退回去，并且只说一次', () {
      final controller = StreamMessageComposerController();
      addTearDown(controller.dispose);
      final refusals = <LoopChatImageRefusal>[];
      final gate = LoopChatImageAttachmentGate(
        controller: controller,
        onRefused: refusals.add,
      )..attach();
      addTearDown(gate.dispose);

      controller.attachments = <Attachment>[
        localImage(),
        localImage(
          name: 'huge.png',
          size: 40 * 1024 * 1024,
          mimeType: 'image/png',
        ),
      ];

      expect(refusals, <LoopChatImageRefusal>[LoopChatImageRefusal.tooLarge]);
      expect(controller.attachments, hasLength(1));
      expect(controller.attachments.single.file?.name, 'photo.jpg');
    });

    test('合规的选择闸门完全不插手', () {
      final controller = StreamMessageComposerController();
      addTearDown(controller.dispose);
      final refusals = <LoopChatImageRefusal>[];
      final gate = LoopChatImageAttachmentGate(
        controller: controller,
        onRefused: refusals.add,
      )..attach();
      addTearDown(gate.dispose);

      final picks = <Attachment>[
        localImage(),
        localImage(name: 'b.png', mimeType: 'image/png'),
      ];
      controller.attachments = picks;

      expect(refusals, isEmpty);
      expect(
        controller.attachments.map((it) => it.id),
        picks.map((it) => it.id),
      );
    });

    test('上传失败的四种说法各说各的，都不谎称发出去了', () {
      expect(
        loopChatImageFailureMessage(
          const AttachmentTooLargeError(fileSize: 1, maxSize: 2),
        ),
        loopChatImageRefusalMessage(LoopChatImageRefusal.tooLarge),
      );
      expect(
        loopChatImageFailureMessage(
          const AttachmentLimitReachedError(maxCount: 9),
        ),
        loopChatImageRefusalMessage(LoopChatImageRefusal.tooMany),
      );
      expect(
        loopChatImageFailureMessage(
          const AttachmentBlockedError(fileExtension: 'bmp'),
        ),
        loopChatImageRefusalMessage(LoopChatImageRefusal.unsupportedFormat),
      );

      final offline = StreamChatNetworkError.raw(
        code: -1,
        message: '',
        type: StreamChatNetworkErrorType.connectionError,
      );
      expect(loopChatImageFailureMessage(offline), contains('离线'));
      expect(loopChatImageFailureMessage(offline), contains('没有发出去'));

      final refused = StreamChatNetworkError.raw(
        code: 17,
        message: 'forbidden',
        statusCode: 403,
      );
      expect(loopChatImageFailureMessage(refused), contains('服务端拒绝'));
      expect(loopChatImageFailureMessage(refused), contains('没有发出去'));

      expect(
        loopChatImageFailureMessage(Exception('boom')),
        contains('没有上传成功'),
      );
      for (final error in <Object>[offline, refused, Exception('boom')]) {
        expect(loopChatImageFailureMessage(error).contains('附件'), isFalse);
      }
    });
  });

  group('气泡里的图片', () {
    testWidgets('单张图片不会长过 LOOP 的上限', (tester) async {
      final image = localImage();
      final message = Message(
        id: 'm1',
        user: User(id: 'me', name: '我'),
        attachments: <Attachment>[image],
      );

      await tester.pumpWidget(
        _themed(
          Builder(
            builder: (context) => loopStreamImageAttachmentBuilder(
              context,
              StreamImageAttachmentProps(message: message, image: image),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StreamImageAttachmentThumbnail), findsOneWidget);
      final size = tester.getSize(find.byType(StreamImageAttachmentThumbnail));
      expect(
        size.height,
        lessThanOrEqualTo(loopChatImageBubbleConstraints.maxHeight),
      );
      expect(
        size.width,
        lessThanOrEqualTo(loopChatImageBubbleConstraints.maxWidth),
      );
      // The bubble draws the picture, not the address it came from.
      expect(find.textContaining('http'), findsNothing);
    });

    testWidgets('加载不出来时说原因，绝不把地址印出来', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _themed(
          SizedBox(
            width: 220,
            height: 180,
            child: Builder(
              builder: (context) => loopChatImagePlaceholder(
                context,
                Exception('https://cdn.example.test/private/abc.png'),
                () => retried += 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('图片没有加载出来'), findsOneWidget);
      expect(find.text('点按重试'), findsOneWidget);
      expect(find.textContaining('http'), findsNothing);
      expect(find.textContaining('cdn.example'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-chat-image-unavailable')),
      );
      expect(retried, 1);
    });
  });

  group('全屏查看', () {
    testWidgets('左右滑动数得清第几张，且不提供下载或分享', (tester) async {
      final message = Message(
        id: 'm1',
        user: User(id: 'other', name: '别人'),
        createdAt: DateTime.utc(2026, 9, 19, 4, 7),
      );
      final attachments = <StreamMediaGalleryAttachment>[
        for (var i = 0; i < 3; i++)
          StreamMediaGalleryAttachment(
            attachment: localImage(name: 'p$i.jpg'),
            message: message,
          ),
      ];

      await tester.pumpWidget(
        _themed(
          Builder(
            builder: (context) => loopStreamMediaGalleryPreviewBuilder(
              context,
              StreamMediaGalleryPreviewProps(attachments: attachments),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LoopChatImageViewer), findsOneWidget);
      expect(find.text('第 1 张 / 共 3 张'), findsOneWidget);
      expect(find.text('别人'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey<String>('loop-chat-image-viewer-pages')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('第 2 张 / 共 3 张'), findsOneWidget);

      // LOOP has proven neither a download nor a share capability, so the
      // viewer offers neither.
      expect(find.text('保存图片'), findsNothing);
      expect(find.text('下载'), findsNothing);
      expect(find.byIcon(Icons.share), findsNothing);

      // The sender stays readable on every page, so a picture is never an
      // anonymous full-screen surface.
      expect(find.text('别人'), findsOneWidget);
    });

    testWidgets('只有一张时不数「第几张」', (tester) async {
      final message = Message(
        id: 'm1',
        user: User(id: 'me', name: '我'),
      );
      await tester.pumpWidget(
        _themed(
          Builder(
            builder: (context) => loopStreamMediaGalleryPreviewBuilder(
              context,
              StreamMediaGalleryPreviewProps(
                attachments: <StreamMediaGalleryAttachment>[
                  StreamMediaGalleryAttachment(
                    attachment: localImage(),
                    message: message,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('loop-chat-image-viewer-counter')),
        findsNothing,
      );
    });
  });

  group('图片不打乱顺序', () {
    test('还在上传的图片消息仍然排在历史下面', () async {
      // The device clock is a day behind; without S31a the picture would be
      // filed a day into the past, which is where the list would draw it.
      final deviceNow = DateTime.utc(2026, 9, 18, 12).toLocal();
      LoopServerClock.instance = LoopServerClock(deviceNow: () => deviceNow);
      LoopServerClock.instance.observe(
        serverTime: DateTime.utc(2026, 9, 19, 12),
        sentAt: deviceNow,
        receivedAt: deviceNow.add(const Duration(milliseconds: 60)),
      );
      addTearDown(() => LoopServerClock.instance = LoopServerClock());

      final client = StreamChatClient('key', logLevel: Level.OFF);
      // ignore: invalid_use_of_internal_member
      client.state.currentUser = OwnUser(id: 'me', name: '我');
      final channel = Channel.fromState(
        client,
        ChannelState(
          channel: ChannelModel(
            id: 'loop_community_0123456789abcdef',
            type: 'messaging',
          ),
          messages: <Message>[
            for (var i = 3; i >= 1; i--)
              Message(
                id: 'h$i',
                text: '历史 $i',
                user: User(id: 'other', name: '别人'),
                createdAt: DateTime.utc(
                  2026,
                  9,
                  19,
                  12,
                ).subtract(Duration(minutes: i)),
                state: MessageState.sent,
              ),
          ],
        ),
      );
      final order = LoopOutgoingMessageOrder(channel: channel)..attach();
      addTearDown(() {
        order.dispose();
        channel.dispose();
      });

      // What `Channel.sendMessage` writes while the upload is still running.
      channel.state!.updateMessage(
        Message(
          id: 'picture',
          user: User(id: 'me', name: '我'),
          localCreatedAt: deviceNow,
          state: MessageState.sending,
          attachments: <Attachment>[
            localImage(
              uploadState: const UploadState.inProgress(uploaded: 1, total: 10),
            ),
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(channel.state!.messages.map((it) => it.id), <String>[
        'h3',
        'h2',
        'h1',
        'picture',
      ]);
      // And the picture keeps its place when the upload finishes and the
      // message is only waiting on the send.
      channel.state!.updateMessage(
        channel.state!.messages.last.copyWith(
          attachments: <Attachment>[localImage()],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(channel.state!.messages.last.id, 'picture');
    });
  });
}

/// The frame the application can actually produce: LOOP's dark theme with the
/// Stream palette injected above the official widgets.
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

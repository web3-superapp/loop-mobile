import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_builder.dart';
import 'package:loop_mobile/features/chat/attachments/token_card_attachment.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  const builder = LoopStreamTokenCardAttachmentBuilder();

  test('custom builder handles only isolated token_card attachments', () {
    final token = _tokenAttachment();
    final image = Attachment(type: 'image', imageUrl: 'https://example.com/x');

    expect(
      builder.canHandle(
        Message(attachments: <Attachment>[token]),
        <String, List<Attachment>>{
          LoopTokenCardAttachment.attachmentType: <Attachment>[token],
        },
      ),
      isTrue,
    );
    expect(
      builder.canHandle(
        Message(attachments: <Attachment>[image]),
        <String, List<Attachment>>{
          'image': <Attachment>[image],
        },
      ),
      isFalse,
    );
    expect(
      builder.canHandle(
        Message(attachments: <Attachment>[token, image]),
        <String, List<Attachment>>{
          LoopTokenCardAttachment.attachmentType: <Attachment>[token],
          'image': <Attachment>[image],
        },
      ),
      isTrue,
      reason: 'any raw token_card must be intercepted and fail closed',
    );
  });

  testWidgets('valid production reference shows identity-only unavailable UI', (
    tester,
  ) async {
    await _pumpBuilder(tester, <Attachment>[_tokenAttachment()]);

    final card = find.byKey(const ValueKey<String>('token-card-unavailable'));
    expect(card, findsOneWidget);
    // Decision 0168: the attachment is the prototype `.tcard` in its 数据缺失
    // shape, not a hand-built frame.
    expect(tester.widget(card), isA<LoopTokenCard>());
    expect(
      tester.widget<LoopTokenCard>(card).state,
      LoopTokenCardState.partial,
    );
    expect(tester.widget<LoopTokenCard>(card).actions, isEmpty);
    expect(find.text('GLYPH'), findsOneWidget);
    expect(find.text('base · 0x71e40…09a2c'), findsOneWidget);
    expect(find.text('当前事实不可得'), findsOneWidget);
    expect(find.textContaining('消息只保存代币标识'), findsOneWidget);
    expect(find.textContaining('2026-08-23 14:07 UTC'), findsOneWidget);
    expect(find.textContaining(r'$0.0842'), findsNothing);
    expect(find.text('Buy'), findsNothing);
    expect(find.text('买入'), findsNothing);
    expect(find.text('自选'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('official Stream message renderer uses the configured builder', (
    tester,
  ) async {
    await _pumpOfficialRenderer(tester, <Attachment>[_tokenAttachment()]);

    expect(find.byType(StreamMessageItem), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('token-card-unavailable')),
      findsOneWidget,
    );
    expect(find.text('当前事实不可得'), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
  });

  testWidgets('raw token card cannot escape into the default link renderer', (
    tester,
  ) async {
    final malicious = Attachment(
      type: LoopTokenCardAttachment.attachmentType,
      title: r'$999999 · Buy now',
      titleLink: 'https://attacker.example/buy',
      ogScrapeUrl: 'https://attacker.example/buy',
      extraData: _tokenAttachment().extraData,
    );
    expect(malicious.rawType, LoopTokenCardAttachment.attachmentType);
    expect(malicious.type, AttachmentType.urlPreview);

    await _pumpOfficialRenderer(tester, <Attachment>[malicious]);

    expect(
      find.byKey(const ValueKey<String>('token-card-malformed')),
      findsOneWidget,
    );
    expect(find.byType(StreamLinkPreviewAttachment), findsNothing);
    expect(find.textContaining(r'$999999'), findsNothing);
    expect(find.textContaining('attacker.example'), findsNothing);
  });

  testWidgets('malformed or repeated cards expose no supplied facts', (
    tester,
  ) async {
    final malformed = Attachment(
      type: LoopTokenCardAttachment.attachmentType,
      extraData: <String, Object?>{
        ..._tokenAttachment().extraData,
        'price': r'$999999',
      },
    );
    await _pumpBuilder(tester, <Attachment>[malformed]);

    expect(
      find.byKey(const ValueKey<String>('token-card-malformed')),
      findsOneWidget,
    );
    expect(find.text('无法识别的代币卡'), findsOneWidget);
    expect(
      tester
          .widget<LoopTokenCard>(
            find.byKey(const ValueKey<String>('token-card-malformed')),
          )
          .actions,
      isEmpty,
    );
    expect(find.text('GLYPH'), findsNothing);
    expect(find.textContaining(r'$999999'), findsNothing);
    expect(find.text('Buy'), findsNothing);

    await _pumpBuilder(tester, <Attachment>[
      _tokenAttachment(),
      _tokenAttachment(),
    ]);
    expect(
      find.byKey(const ValueKey<String>('token-card-malformed')),
      findsOneWidget,
    );

    final image = Attachment(
      type: 'image',
      imageUrl: 'https://attacker.example/image.png',
    );
    await _pumpBuilder(tester, <Attachment>[_tokenAttachment(), image]);
    expect(
      find.byKey(const ValueKey<String>('token-card-malformed')),
      findsOneWidget,
    );
    expect(find.textContaining('attacker.example'), findsNothing);
  });

  testWidgets('identity card survives narrow layout and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpBuilder(tester, <Attachment>[
      _tokenAttachment(),
    ], textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    expect(find.text('当前事实不可得'), findsOneWidget);
  });

  testWidgets('fixture card is visibly preview-only and has no mutation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(child: TokenMessageCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey<String>('token-card-preview'));
    expect(tester.widget(card), isA<LoopTokenCard>());
    expect(find.text('开发预览'), findsOneWidget);
    expect(find.textContaining('非 provider 响应'), findsOneWidget);
    expect(find.textContaining('演示数据'), findsWidgets);
    expect(find.text('图表'), findsOneWidget);
    expect(find.text('买入'), findsOneWidget);
    expect(find.text('自选'), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    for (final action in tester.widget<LoopTokenCard>(card).actions) {
      expect(action.onTap, isNull, reason: action.label);
    }
    expect(tester.takeException(), isNull);
  });
}

Attachment _tokenAttachment() {
  return Attachment(
    type: LoopTokenCardAttachment.attachmentType,
    extraData: const <String, Object?>{
      'loop_schema': LoopTokenCardAttachment.schema,
      'asset_id': 'GLYPH',
      'chain_id': 'base',
      'contract_id': '0x71e4000000000000000000000000000000009a2c',
      'snapshot_at': '2026-08-23T14:07:00.000Z',
    },
  );
}

Future<void> _pumpBuilder(
  WidgetTester tester,
  List<Attachment> attachments, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) =>
                  const LoopStreamTokenCardAttachmentBuilder().build(
                    context,
                    Message(attachments: attachments),
                    <String, List<Attachment>>{
                      LoopTokenCardAttachment.attachmentType: attachments,
                    },
                  ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpOfficialRenderer(
  WidgetTester tester,
  List<Attachment> attachments,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: StreamChatConfiguration(
        data: StreamChatConfigurationData(
          attachmentBuilders: const <StreamAttachmentWidgetBuilder>[
            LoopStreamTokenCardAttachmentBuilder(),
          ],
        ),
        child: StreamComponentFactory(
          builders: StreamComponentBuilders(
            extensions: streamChatComponentBuilders(
              messageLeading: (_, _) => const SizedBox.shrink(),
              messageHeader: (_, _) => const SizedBox.shrink(),
              messageFooter: (_, _) => const SizedBox.shrink(),
            ),
          ),
          child: Scaffold(
            body: StreamMessageItem(
              message: Message(
                id: 'token-reference-message',
                createdAt: DateTime.utc(2026, 8, 23, 14, 7),
                user: User(id: 'other-user'),
                state: MessageState.sent,
                attachments: attachments,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

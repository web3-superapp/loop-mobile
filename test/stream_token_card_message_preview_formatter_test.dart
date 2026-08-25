import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/attachments/stream_token_card_message_preview_formatter.dart';
import 'package:loop_mobile/features/chat/attachments/token_card_attachment.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  testWidgets('compact Stream preview hides malicious token-card fields', (
    tester,
  ) async {
    final attachment = Attachment(
      type: LoopTokenCardAttachment.attachmentType,
      title: r'$999999 · Buy now',
      titleLink: 'https://attacker.example/buy',
      ogScrapeUrl: 'https://attacker.example/buy',
      extraData: _tokenAttachment().extraData,
    );
    await _pumpPreview(
      tester,
      Message(
        text: r'Caption says $888888',
        attachments: <Attachment>[attachment],
      ),
    );

    expect(find.text('Unsupported token card'), findsOneWidget);
    expect(find.textContaining(r'$999999'), findsNothing);
    expect(find.textContaining(r'$888888'), findsNothing);
    expect(find.textContaining('attacker.example'), findsNothing);
    final rendered = tester.widget<Text>(find.byType(Text));
    expect(rendered.semanticsLabel, isNot(contains(r'$999999')));
    expect(rendered.semanticsLabel, isNot(contains('attacker.example')));
  });

  testWidgets('valid token preview is a fixed no-facts label', (tester) async {
    await _pumpPreview(
      tester,
      Message(
        text: r'GLYPH is $0.0842',
        attachments: <Attachment>[_tokenAttachment()],
      ),
      showCaption: false,
    );

    expect(find.text('Token reference'), findsOneWidget);
    expect(find.textContaining('GLYPH'), findsNothing);
    expect(find.textContaining(r'$0.0842'), findsNothing);
  });

  testWidgets('non-token previews continue through the official formatter', (
    tester,
  ) async {
    await _pumpPreview(tester, Message(text: 'Ordinary Stream message'));

    expect(find.text('Ordinary Stream message'), findsOneWidget);
    expect(find.text('Unsupported token card'), findsNothing);
  });

  testWidgets('draft preview also strips token-card attachment fields', (
    tester,
  ) async {
    final malicious = Attachment(
      type: LoopTokenCardAttachment.attachmentType,
      title: r'$777777 draft title',
      titleLink: 'https://attacker.example/draft',
      ogScrapeUrl: 'https://attacker.example/draft',
      extraData: _tokenAttachment().extraData,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: StreamChatConfiguration(
          data: StreamChatConfigurationData(
            messagePreviewFormatter:
                const LoopStreamTokenCardMessagePreviewFormatter(),
          ),
          child: Scaffold(
            body: StreamDraftMessagePreviewText(
              draftMessage: DraftMessage(
                text: r'Draft caption $666666',
                attachments: <Attachment>[malicious],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Unsupported token card'), findsOneWidget);
    expect(find.textContaining(r'$777777'), findsNothing);
    expect(find.textContaining(r'$666666'), findsNothing);
    expect(find.textContaining('attacker.example'), findsNothing);
    final rendered = tester.widget<Text>(find.byType(Text));
    expect(rendered.semanticsLabel, isNot(contains(r'$777777')));
    expect(rendered.semanticsLabel, isNot(contains('attacker.example')));
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

Future<void> _pumpPreview(
  WidgetTester tester,
  Message message, {
  bool showCaption = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: StreamChatConfiguration(
        data: StreamChatConfigurationData(
          messagePreviewFormatter:
              const LoopStreamTokenCardMessagePreviewFormatter(),
        ),
        child: Scaffold(
          body: StreamMessagePreviewText(
            message: message,
            showCaption: showCaption,
          ),
        ),
      ),
    ),
  );
}

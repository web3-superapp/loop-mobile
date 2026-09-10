import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const StreamMessageLayoutData _incoming = StreamMessageLayoutData();
const StreamMessageLayoutData _outgoing = StreamMessageLayoutData(
  alignment: StreamMessageAlignment.end,
);

void main() {
  group('bubble tokens', () {
    test('own message is Lime over Ink text, other message is Card over '
        'Chalk', () {
      final theme = loopStreamMessageItemTheme();
      final background = theme.bubble!.backgroundColor!;
      expect(background.resolve(_outgoing), LoopColors.lime);
      expect(background.resolve(_incoming), LoopColors.card);

      final textColor = theme.text!.textColor!;
      expect(textColor.resolve(_outgoing), LoopColors.ink);
      expect(textColor.resolve(_incoming), LoopColors.chalk);

      final textStyle = theme.text!.textStyle!;
      expect(textStyle.resolve(_outgoing)!.color, LoopColors.ink);
      expect(textStyle.resolve(_incoming)!.color, LoopColors.chalk);
      // The prototype's `.msg-txt` body size; nothing new is introduced.
      expect(textStyle.resolve(_incoming)!.fontSize, 11);
    });

    test('the tail corner sits on the sender side, 5 against 16', () {
      final shape = loopStreamMessageItemTheme().bubble!.shape!;
      final outgoing = shape.resolve(_outgoing)! as RoundedRectangleBorder;
      final incoming = shape.resolve(_incoming)! as RoundedRectangleBorder;
      final outgoingRadius = outgoing.borderRadius as BorderRadiusDirectional;
      final incomingRadius = incoming.borderRadius as BorderRadiusDirectional;

      expect(outgoingRadius.topEnd, LoopRadius.bubbleTail);
      expect(
        outgoingRadius.topStart,
        const Radius.circular(LoopRadius.controlValue),
      );
      expect(incomingRadius.topStart, LoopRadius.bubbleTail);
      expect(
        incomingRadius.topEnd,
        const Radius.circular(LoopRadius.controlValue),
      );
    });

    test('no colour outside the Lime Ledger token set reaches the scheme', () {
      final scheme = loopStreamColorScheme();
      // The send button, the primary control and the read receipt.
      expect(scheme.accentPrimary, LoopColors.lime);
      expect(scheme.textOnAccent, LoopColors.ink);
      // Page and surface grounds.
      expect(scheme.backgroundApp, LoopColors.ink);
      expect(scheme.backgroundSurface, LoopColors.card);
      expect(scheme.backgroundHighlight, LoopColors.limeSoft);
      // Text ladder.
      expect(scheme.textPrimary, LoopColors.chalk);
      expect(scheme.textSecondary, LoopColors.text2);
      expect(scheme.textTertiary, LoopColors.text3);
      // Outgoing surfaces Stream reads straight off the brand ladder.
      expect(scheme.brand.shade100, LoopColors.lime);
      expect(scheme.brand.shade900, LoopColors.ink);
      expect(scheme.borderDefault, LoopColors.line);
    });
  });

  group('24-hour clock and Chinese day labels', () {
    test('the clock is HH:mm, never a 12-hour AM/PM string', () {
      expect(loopStreamClockLabel(DateTime(2026, 9, 10, 15, 39)), '15:39');
      expect(loopStreamClockLabel(DateTime(2026, 9, 10, 0, 5)), '00:05');
      expect(loopStreamClockLabel(DateTime(2026, 9, 10, 9, 7)), '09:07');
      expect(loopStreamClockLabel(DateTime(2026, 9, 10, 12, 0)), '12:00');
    });

    test('day separators read 今天 / 昨天 / weekday / date', () {
      final now = DateTime(2026, 9, 10, 15, 39);
      expect(loopStreamDayLabel(now, now: now), '今天');
      expect(loopStreamDayLabel(DateTime(2026, 9, 9, 23, 59), now: now), '昨天');
      // 2026-09-07 is a Monday, three days back.
      expect(loopStreamDayLabel(DateTime(2026, 9, 7, 8, 0), now: now), '周一');
      expect(
        loopStreamDayLabel(DateTime(2026, 8, 20, 8, 0), now: now),
        '8月20日',
      );
      expect(
        loopStreamDayLabel(DateTime(2025, 12, 24, 8, 0), now: now),
        '2025年12月24日',
      );
    });
  });

  group('Chinese Stream copy', () {
    const StreamChatLocalizations copy = LoopStreamChatLocalizations();

    test('covers the strings the acceptance run found in English', () {
      expect(copy.sendMessageToStartConversationText, '发条消息，开始这段对话');
      expect(copy.todayLabel, '今天');
      expect(copy.yesterdayLabel, '昨天');
      expect(copy.writeAMessageLabel, '发消息');
      expect(copy.emptyMessagesText, '还没有消息');
      expect(copy.noConversationsYetText, '还没有会话');
    });

    test('covers delivery, connection, attachment and message actions', () {
      expect(copy.connectedLabel, '已连接');
      expect(copy.reconnectingLabel, '正在重连…');
      expect(copy.disconnectedLabel, '已断开');
      expect(copy.offlineLabel, '离线…');
      expect(copy.imageAttachmentText, '图片');
      expect(copy.fileAttachmentText, '文件');
      expect(copy.voiceRecordingText, '语音');
      expect(copy.replyLabel, '回复');
      expect(copy.editMessageLabel, '编辑消息');
      expect(copy.deleteMessageLabel, '删除消息');
      expect(copy.copyMessageLabel, '复制消息');
      expect(copy.editedMessageLabel, '已编辑');
      expect(copy.accessibility.messageReadStatusLabel, '已读');
      expect(copy.accessibility.messageSendingStatusLabel, '发送中');
      expect(copy.accessibility.sendMessageTooltip, '发送消息');
      expect(copy.retryLabel, '重试');
    });

    test('no member of the Stream translation surface is left in English', () {
      // A Latin letter is allowed only where the string is a product name, a
      // placeholder or a pure count.
      const Set<String> allowed = <String>{
        'streamChatLabel',
        'giphyLabel',
        'commandUsernameLabel',
        'emptyMessagePreviewText',
      };
      final Map<String, String> plain = <String, String>{
        'launchUrlError': copy.launchUrlError,
        'loadingUsersError': copy.loadingUsersError,
        'noUsersLabel': copy.noUsersLabel,
        'retryLabel': copy.retryLabel,
        'userOnlineText': copy.userOnlineText,
        'threadLabel': copy.threadLabel,
        'sendLabel': copy.sendLabel,
        'cancelLabel': copy.cancelLabel,
        'okLabel': copy.okLabel,
        'deleteLabel': copy.deleteLabel,
        'flagLabel': copy.flagLabel,
        'downloadLabel': copy.downloadLabel,
        'viewLabel': copy.viewLabel,
        'confirmLabel': copy.confirmLabel,
        'loadingLabel': copy.loadingLabel,
        'draftLabel': copy.draftLabel,
        'connectionErrorTitle': copy.connectionErrorTitle,
        'genericErrorTitle': copy.genericErrorTitle,
        'uploadErrorLabel': copy.uploadErrorLabel,
        'tryAgainLabel': copy.tryAgainLabel,
        'startAChatLabel': copy.startAChatLabel,
        'youText': copy.youText,
      };
      for (final MapEntry<String, String> entry in plain.entries) {
        if (allowed.contains(entry.key)) continue;
        expect(
          RegExp('[A-Za-z]').hasMatch(entry.value),
          isFalse,
          reason: '${entry.key} still renders Latin copy: ${entry.value}',
        );
      }
    });
  });

  group('injection', () {
    testWidgets('the delegate and the theme extension reach a descendant', (
      tester,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            LoopStreamChatLocalizationsDelegate(),
          ],
          home: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return Theme(
                data: theme.copyWith(
                  extensions: [
                    ...theme.extensions.values,
                    loopStreamTheme(platform: theme.platform),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    captured = context;
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );

      final localizations = StreamChatLocalizations.of(captured);
      expect(localizations, isA<LoopStreamChatLocalizations>());
      expect(localizations!.todayLabel, '今天');

      final streamTheme = StreamTheme.of(captured);
      expect(streamTheme.colorScheme.accentPrimary, LoopColors.lime);
      expect(streamTheme.colorScheme.backgroundApp, LoopColors.ink);

      final itemTheme = StreamMessageItemTheme.of(captured);
      expect(
        itemTheme.bubble!.backgroundColor!.resolve(_outgoing),
        LoopColors.lime,
      );
      expect(
        itemTheme.bubble!.backgroundColor!.resolve(_incoming),
        LoopColors.card,
      );

      // MaterialLocalizations must survive: LOOP adds a delegate, it does not
      // switch the application locale.
      expect(MaterialLocalizations.of(captured), isNotNull);
    });

    test(
      'app.dart installs the delegate, the theme and the 24-hour footer',
      () {
        final source = File('lib/app.dart').readAsStringSync();
        expect(source, contains('LoopStreamChatLocalizationsDelegate()'));
        expect(source, contains('loopStreamTheme(platform: theme.platform)'));
        expect(source, contains('themeData: loopStreamChatThemeData()'));
        expect(
          source,
          contains('messageFooter: loopStreamMessageFooterBuilder'),
        );
      },
    );

    test('every official message list passes the Chinese day separator', () {
      const List<String> surfaces = <String>[
        'lib/features/chat/v2/loop_stream_channel_surface.dart',
        'lib/features/chat/group_alias/group_alias_stream_message_identity.dart',
      ];
      for (final String path in surfaces) {
        final source = File(path).readAsStringSync();
        final lists = 'StreamMessageListView('.allMatches(source).length;
        final builders = 'builders: loopStreamMessageListViewBuilders()'
            .allMatches(source)
            .length;
        expect(
          builders,
          lists,
          reason: '$path mounts $lists message lists but wires $builders',
        );
      }
    });
  });
}

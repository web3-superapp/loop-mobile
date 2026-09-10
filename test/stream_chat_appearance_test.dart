import 'dart:io';
import 'dart:math' as math;

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

    test('the inbox row prints the clock today, then the day ladder', () {
      final now = DateTime(2026, 9, 10, 15, 39);
      expect(
        loopStreamChannelListDateLabel(DateTime(2026, 9, 10, 8, 4), now: now),
        '08:04',
      );
      expect(
        loopStreamChannelListDateLabel(DateTime(2026, 9, 9, 23, 59), now: now),
        '昨天',
      );
      expect(
        loopStreamChannelListDateLabel(DateTime(2026, 9, 7, 8, 0), now: now),
        '周一',
      );
      expect(
        loopStreamChannelListDateLabel(DateTime(2026, 8, 20, 8, 0), now: now),
        '8月20日',
      );
      expect(
        loopStreamChannelListDateLabel(DateTime(2025, 12, 24, 8, 0), now: now),
        '2025年12月24日',
      );
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

    test('no Chinese-copy literal in the delegate is left in English', () {
      // Scans the delegate's own source rather than a hand-picked sample, so
      // a member translated back to English cannot slip through.
      const String path =
          'lib/integrations/communication/stream_chat_localizations_zh.dart';
      final source = File(path).readAsStringSync();
      // Product names and format identifiers that are correct as Latin.
      const List<String> allowed = <String>[
        'Stream Chat',
        'Giphy',
        'GIF',
        'MB',
        'zh_Hans',
      ];
      final literal = RegExp(r"'([^'\\\n]*)'");
      final interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*');
      var scanned = 0;
      for (final String line in source.split('\n')) {
        final trimmed = line.trimLeft();
        // Imports and doc comments are code, not copy.
        if (trimmed.startsWith('import ') || trimmed.startsWith('//')) continue;
        for (final RegExpMatch match in literal.allMatches(line)) {
          var value = match.group(1)!;
          if (value.isEmpty) continue;
          value = value.replaceAll(interpolation, '');
          for (final String token in allowed) {
            value = value.replaceAll(token, '');
          }
          if (value.trim().isEmpty) continue;
          scanned += 1;
          expect(
            RegExp('[A-Za-z]').hasMatch(value),
            isFalse,
            reason: 'still renders Latin copy on "$line"',
          );
        }
      }
      // A scan that matched nothing would pass vacuously.
      expect(scanned, greaterThan(200));
    });

    test('the accessibility labels are Chinese and complete', () {
      // `implements` rather than `extends`: an English default can never be
      // inherited, so the compiler already proves every member is supplied.
      const AccessibilityTranslations a11y =
          LoopStreamChatAccessibilityTranslations();
      expect(a11y.localeName, 'zh_Hans');
      expect(a11y.messageReadStatusLabel, '已读');
      expect(a11y.messageDeliveredStatusLabel, '已送达');
      expect(a11y.messageSentStatusLabel, '已发送');
      expect(a11y.messageSendingStatusLabel, '发送中');
      expect(a11y.attachmentPickerTooltip, '附件');
      expect(a11y.attachmentPickerOpenedAnnouncement, '附件面板已打开');
      expect(a11y.recordingStartedAnnouncement, '开始录音');
      expect(a11y.attachmentsAddedAnnouncement(count: 3), '已添加 3 个附件');
      expect(a11y.unreadMessagesLabel(count: 2), '2 条未读');
      expect(a11y.slowModeTooltip(seconds: 5), '慢速模式，还需等待 5 秒');
      expect(a11y.imageAttachmentLabel(), '图片附件');
      expect(a11y.imageAttachmentLabel(title: 'a.png'), '图片附件，a.png');
      expect(a11y.formatDuration(const Duration(seconds: 9)), '9 秒');
      expect(
        a11y.formatDuration(const Duration(minutes: 2, seconds: 5)),
        '2 分5 秒',
      );
      expect(
        a11y.formatDateTime(DateTime(2026, 9, 10, 15, 39)),
        contains('15:39'),
      );
      expect(a11y.removePollOptionTooltip(), '删除选项');
      expect(a11y.removePollOptionTooltip(optionText: ' A '), '删除选项 A');
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

    test('every official message list in lib passes the Chinese separator', () {
      // Recursive, so a list mounted by a page added later cannot silently
      // fall back to Jiffy's English weekday.
      var lists = 0;
      for (final File file in _dartSources()) {
        final source = file.readAsStringSync();
        final mounted = 'StreamMessageListView('.allMatches(source).length;
        if (mounted == 0) continue;
        lists += mounted;
        final wired = 'builders: loopStreamMessageListViewBuilders()'
            .allMatches(source)
            .length;
        expect(
          wired,
          mounted,
          reason: '${file.path} mounts $mounted message lists, wires $wired',
        );
      }
      expect(lists, greaterThan(0));
    });

    test('every inbox timestamp in lib carries a LOOP formatter', () {
      var constructed = 0;
      for (final File file in _dartSources()) {
        final source = file.readAsStringSync();
        for (final Match match in 'ChannelLastMessageDate('.allMatches(
          source,
        )) {
          constructed += 1;
          final tail = source.substring(
            match.end,
            math.min(match.end + 300, source.length),
          );
          final call = tail.substring(0, tail.indexOf(');') + 1);
          expect(
            call,
            contains('formatter:'),
            reason: '${file.path} builds a timestamp with no formatter',
          );
        }
      }
      expect(constructed, greaterThan(0));

      // Both branches of the inbox cell must reach that one helper.
      const String inbox =
          'lib/features/chat/group_alias/group_alias_stream_message_identity.dart';
      final source = File(inbox).readAsStringSync();
      final tiles = 'StreamChannelListTile('.allMatches(source).length;
      final timestamps = 'loopStreamChannelListTimestamp(channel)'
          .allMatches(source)
          .length;
      expect(timestamps, tiles);
      expect(
        source.contains('return defaultItem;'),
        isFalse,
        reason: 'a direct cell must not fall back to the unformatted default',
      );
    });
  });
}

/// Every Dart source under `lib/`, so a scan cannot miss a new page.
Iterable<File> _dartSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

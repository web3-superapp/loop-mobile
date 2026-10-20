import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_inbox_row_actions.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/community/community_ai_models.dart';
import 'package:loop_mobile/features/community/community_ai_screen.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

/// Decision 0191 (S197-3, docs/37 §2): 个人 / 社区 / 社交 / 广场 / 聊天弹层
/// draw each word in its one ladder step. Every assertion reads the style
/// the word is actually painted in.

const _id = '7d1c5f64-5717-4562-b3fc-2c963f66a001';
const _loopId = 'LOOP-7KQ2M9XA';

TextStyle _painted(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.text(text, findRichText: true).first,
  );
  return paragraph.text.style!;
}

TextStyle _paintedAt(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find
        .descendant(
          of: finder,
          matching: find.byType(RichText),
          matchRoot: true,
        )
        .first,
  );
  return paragraph.text.style!;
}

void _expectStep(
  TextStyle painted,
  TextStyle step, {
  FontWeight? weight,
  Color? color,
  String reason = '',
}) {
  expect(painted.fontSize, step.fontSize, reason: '$reason · size');
  expect(
    painted.fontWeight,
    weight ?? step.fontWeight,
    reason: '$reason · weight',
  );
  if (color != null) expect(painted.color, color, reason: '$reason · colour');
}

PublicProfileRecord _record() => PublicProfileRecord(
  publicProfileId: _id,
  loopId: _loopId,
  alias: 'frog_maxi',
  avatarRef: null,
  bio: '长期持有',
  joinedAt: DateTime.utc(2026, 9),
  counts: const PublicProfileCounts(
    followers: 128,
    following: 36,
    communities: 4,
  ),
  relationship: const PublicProfileRelationship(
    following: false,
    followedBy: false,
    friendship: ProfileFriendship.none,
    blocked: false,
    blockedBy: false,
  ),
  visibility: const PublicProfileVisibility(holdings: true, trades: true),
);

final class _Profiles implements PublicProfileGateway {
  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<PublicProfileRecord> load(PublicProfileTarget target) async =>
      _record();

  @override
  Future<ProfileHoldings> holdings(String publicProfileId) async =>
      ProfileHoldings(
        status: ProfileSectionStatus.available,
        totalUsd: Decimal.parse('1284.52'),
        items: <ProfileHolding>[
          ProfileHolding(
            assetId: 'eip155:56:native',
            symbol: 'BNB',
            name: 'BNB',
            logoUrl: null,
            balance: Decimal.parse('1.2'),
            usdValue: Decimal.parse('784.52'),
          ),
        ],
        observedAt: DateTime.utc(2026, 10, 8, 4),
      );

  @override
  Future<ProfileTradesPage> trades(
    String publicProfileId, {
    String? cursor,
  }) async => ProfileTradesPage(
    status: ProfileSectionStatus.available,
    items: <ProfileTrade>[
      ProfileTrade(
        eventId: 'evt_1',
        kind: ProfileTradeKind.buy,
        assetId: 'eip155:56:native',
        symbol: 'BNB',
        amount: Decimal.parse('0.4'),
        usdValue: Decimal.parse('261.5'),
        blockTimestamp: DateTime.utc(2026, 10, 8, 1),
        txHash: '0x${'a' * 64}',
      ),
    ],
    nextCursor: null,
  );

  @override
  Future<ProfileCommunitiesPage> communities(
    String publicProfileId, {
    String? cursor,
  }) async => const ProfileCommunitiesPage.available(
    items: <ProfileCommunity>[],
    nextCursor: null,
  );

  @override
  Future<void> removeFriend(String publicProfileId) async {}
}

/// Mounts a page with one button that opens [open]'s sheet, and opens it.
Future<void> _openSheet(
  WidgetTester tester,
  void Function(BuildContext context) open, {
  List<Override> overrides = const <Override>[],
}) async {
  await pumpCommunityPage(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    size: const Size(390, 900),
    overrides: overrides,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// R2: the sheet's title is the one `LoopSheetHeading`, at `heading` 20/600.
void _expectSheetHeading(WidgetTester tester, String title) {
  final heading = find.widgetWithText(LoopSheetHeading, title);
  expect(heading, findsOneWidget, reason: title);
  _expectStep(_painted(tester, title), LoopType.heading, reason: title);
}

void main() {
  loopWatchGround();

  group('他人主页 (H1 / H2 / H7 / M19 / M21 / L5)', () {
    Future<void> pump(WidgetTester tester) => pumpCommunityPage(
      tester,
      const UserProfileScreen(target: PublicProfileById(_id)),
      social: FakeSocialGateway(),
      overrides: <Override>[
        publicProfileGatewayProvider.overrideWithValue(_Profiles()),
      ],
    );

    testWidgets('the name, the counts, the LOOP ID and the total', (
      tester,
    ) async {
      await pump(tester);
      // H1 R27: displaySm 24/600, as on 我的主页.
      _expectStep(
        _paintedAt(
          tester,
          find.byKey(const ValueKey<String>('user-profile-name')),
        ),
        LoopType.displaySm,
        reason: 'name',
      );
      // H2 R28: the figure 13/700, the word bodySm 13 text2.
      _expectStep(
        _painted(tester, '128'),
        LoopType.figure,
        weight: FontWeight.w700,
        reason: 'count',
      );
      _expectStep(
        _painted(tester, '粉丝'),
        LoopType.bodySm,
        color: LoopColors.text2,
        reason: 'count word',
      );
      // M19 an inline LOOP ID: figure 13 at 500, text2.
      _expectStep(
        _painted(tester, _loopId),
        LoopType.figure,
        weight: FontWeight.w500,
        color: LoopColors.text2,
        reason: 'LOOP ID',
      );
      // L25 the bio in text2.
      expect(_painted(tester, '长期持有').color, LoopColors.text2);
      // L5 the holdings total: figureLg 20.
      _expectStep(
        _paintedAt(
          tester,
          find.byKey(const ValueKey<String>('user-profile-holdings-total')),
        ),
        LoopType.figureLg,
        reason: 'holdings total',
      );
    });

    testWidgets('a trade is the shared trade-record row (H7 / M21)', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('交易'));
      await tester.pumpAndSettle();
      final row = find.byKey(
        const ValueKey<String>('user-profile-trade-evt_1'),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: row, matching: find.byType(LoopRecordRow)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byType(LoopQuoteRow)),
        findsNothing,
      );
      _expectStep(_painted(tester, '买入 BNB'), LoopType.title, reason: 'title');
      _expectStep(
        _paintedAt(
          tester,
          find.descendant(of: row, matching: find.textContaining('+0.4')),
        ),
        LoopType.figure,
        color: LoopColors.rise,
        reason: 'amount',
      );
      _expectStep(
        _paintedAt(
          tester,
          find.descendant(of: row, matching: find.textContaining('261')),
        ),
        LoopType.figureXs,
        reason: 'usd',
      );
    });
  });

  testWidgets('M20 a community home names it at displaySm 24/600', (
    tester,
  ) async {
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: FakeCommunityGateway(detail: testDetail()),
    );
    _expectStep(
      _paintedAt(
        tester,
        find.byKey(const ValueKey<String>('community-profile-name')),
      ),
      LoopType.displaySm,
      reason: 'community name',
    );
  });

  group('sheet titles are LoopSheetHeading (R2) with R19 support copy', () {
    testWidgets('M5 / L1 confirm sheet', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(
          confirmCommunityAction(
            context,
            title: '退出社区？',
            body: '退出后不再收到消息。',
            confirmLabel: '退出',
          ),
        ),
      );
      _expectSheetHeading(tester, '退出社区？');
      _expectStep(
        _painted(tester, '退出后不再收到消息。'),
        LoopType.bodySm,
        color: LoopColors.text2,
        reason: 'support copy',
      );
    });

    testWidgets('M5 / L2 presence sheet: 观察于 is captionSm', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(
          showCommunityPresenceMeaningSheet(
            context,
            count: 12,
            observedAt: DateTime.utc(2026, 10, 8, 4),
          ),
        ),
      );
      _expectSheetHeading(tester, '这里数的是连接，不是活跃');
      final observed = find.textContaining('观察于');
      _expectStep(
        _paintedAt(tester, observed),
        LoopType.captionSm,
        reason: '观察于',
      );
    });

    testWidgets('M5 application submitted', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(
          showCommunityApplicationSubmittedSheet(
            context,
            communityName: 'Frog Holders',
          ),
        ),
      );
      _expectSheetHeading(tester, '申请已提交 · 审核中');
    });

    testWidgets('M6 创建社区 is 20/600, not 20/700', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(showCommunityApplySheet(context)),
      );
      _expectSheetHeading(tester, '创建社区');
    });

    testWidgets('M4 community AI source and report sheets', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(
          showCommunityAiSourceSheet(
            context,
            source: CommunityAiSource(
              sourceId: 'src_1',
              kind: CommunityAiSourceKind.communityProfile,
              label: '社区档案：PEPE',
              observedAt: DateTime.utc(2026, 10, 8, 4),
            ),
          ),
        ),
      );
      _expectSheetHeading(tester, '社区档案：PEPE');
      _expectStep(
        _paintedAt(tester, find.textContaining('观察于')),
        LoopType.captionSm,
        reason: '观察于',
      );
    });

    testWidgets('M4 / L1 report sheet', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(showCommunityAiReportSheet(context)),
      );
      _expectSheetHeading(tester, '举报这条回答');
      _expectStep(
        _paintedAt(tester, find.textContaining('选择一个原因')),
        LoopType.bodySm,
        color: LoopColors.text2,
        reason: 'support copy',
      );
    });

    testWidgets('M2 group rename', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(showGroupRenameSheet(context, current: '蛙群')),
      );
      _expectSheetHeading(tester, '修改群名称');
    });

    testWidgets('M10 inbox row actions', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(
          showChatInboxRowActionSheet(
            context,
            title: 'Frog Holders',
            actions: const <ChatInboxRowAction>[ChatInboxRowAction.pin],
          ),
        ),
      );
      _expectSheetHeading(tester, 'Frog Holders');
    });

    testWidgets('M8 QR card', (tester) async {
      await _openSheet(
        tester,
        (context) => unawaited(
          showLoopQrCardSheet(
            context,
            const LoopUserQrCard(loopId: _loopId, displayName: 'frog_maxi'),
          ),
        ),
        overrides: <Override>[
          loopIdLinkBaseUrlProvider.overrideWithValue(
            'https://api-staging.quant-dinger.cc',
          ),
        ],
      );
      _expectSheetHeading(tester, '我的二维码名片');
    });
  });

  testWidgets('M41 / M9 / L1 square communities: search entry and rules', (
    tester,
  ) async {
    await pumpCommunityPage(
      tester,
      SquareCommunityList(onOpenCommunity: (_) {}, onOpenSearch: () {}),
      community: FakeCommunityGateway(),
    );
    _expectStep(
      _painted(tester, '搜索社区'),
      LoopType.body,
      color: LoopColors.text3,
      reason: 'search placeholder',
    );
    final rules = find.byKey(const ValueKey<String>('square-community-rules'));
    await tester.ensureVisible(rules);
    await tester.tap(rules);
    await tester.pumpAndSettle();
    _expectSheetHeading(tester, '排序规则');
    _expectStep(
      _paintedAt(tester, find.textContaining('排序只用成员数')),
      LoopType.bodySm,
      color: LoopColors.text2,
      reason: 'support copy',
    );
  });
}

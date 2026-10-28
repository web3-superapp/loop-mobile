import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/invite_link.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/referral/loop_v2_referral_api.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// S239 · decision 0214: 邀请中心 (invite code, link, poster, 我的邀请,
/// invitee list, boost, 推广榜), faces that open profiles, and `/i/{code}`.

const _profileA = '0e358b31-e49f-48b9-89b2-c5c908c3ad5e';

ReferralOverview _center({
  String? link = 'https://api-staging.example.com/i/LOOP-7HJKM',
  ReferralStats? stats,
  bool boostAvailable = false,
}) {
  final base = s7Referral();
  return ReferralOverview(
    inviteCode: base.inviteCode,
    binding: base.binding,
    levels: base.levels,
    boost: boostAvailable ? null : base.boost,
    boostAvailable: boostAvailable
        ? ReferralBoostAvailable(
            referralPower: '12.5',
            nftReferralPower: '10',
            assetReferralPower: '2.5',
            levels: <ReferralBoostLevel>[
              for (var level = 1; level <= 5; level += 1)
                ReferralBoostLevel(
                  level: level,
                  effectiveMembers: level == 1 ? 1 : 0,
                  nftPower: level == 1 ? '10' : '0',
                  assetPower: level == 1 ? '2.5' : '0',
                ),
            ],
            epochId: _profileA,
            hourStart: DateTime.utc(2026, 10, 19, 8),
            hourEnd: DateTime.utc(2026, 10, 19, 9),
          )
        : null,
    inviteLink: link,
    stats: stats,
    rules: base.rules,
  );
}

ReferralInviteePage _invitees({String? nextCursor}) => ReferralInviteePage(
  items: <ReferralInvitee>[
    ReferralInvitee(
      publicProfileId: _profileA,
      alias: 'alice',
      avatarRef: null,
      boundAt: DateTime.utc(2026, 10, 18, 3),
      status: ReferralInviteeStatus.valid,
    ),
    ReferralInvitee(
      publicProfileId: null,
      alias: null,
      avatarRef: null,
      boundAt: DateTime.utc(2026, 10, 17, 3),
      status: ReferralInviteeStatus.invalid,
    ),
  ],
  nextCursor: nextCursor,
);

void main() {
  loopWatchGround();

  group('邀请中心 · five states', () {
    testWidgets('loading', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(pending: true),
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-state-loading')),
        findsOneWidget,
      );
    });

    for (final (kind, phase) in <(LaunchFailureKind, String)>[
      (LaunchFailureKind.unexpected, 'error'),
      (LaunchFailureKind.offline, 'offline'),
      (LaunchFailureKind.permissionDenied, 'permission'),
      (LaunchFailureKind.unavailable, 'unavailable'),
    ]) {
      testWidgets(phase, (tester) async {
        await pumpS7Page(
          tester,
          const ReferralScreen(),
          referral: FakeReferralGateway(
            overview: S7Answer<ReferralOverview>(failure: kind),
          ),
        );
        expect(
          find.byKey(ValueKey<String>('referral-state-$phase')),
          findsOneWidget,
        );
        expect(find.text('LOOP-7HJKM'), findsNothing);
      });
    }

    testWidgets('empty invitee list says so, and failures stay local', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(overview: S7Answer(value: _center())),
      );
      final empty = find.byKey(
        const ValueKey<String>('referral-invitees-empty'),
      );
      await scrollToS7Section(tester, empty);
      expect(empty, findsOneWidget);

      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer(value: _center()),
          invitees: S7Answer<ReferralInviteePage>(
            failure: LaunchFailureKind.offline,
          ),
        ),
      );
      final offline = find.byKey(
        const ValueKey<String>('referral-invitees-state-offline'),
      );
      await scrollToS7Section(tester, offline);
      expect(offline, findsOneWidget);
      // The invite code still shows above it.
      expect(find.text('LOOP-7HJKM'), findsOneWidget);
    });
  });

  group('邀请中心 · content', () {
    testWidgets('code, link, share and poster actions', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(overview: S7Answer(value: _center())),
      );
      expect(find.text('LOOP-7HJKM'), findsOneWidget);
      expect(find.text('邀请中心'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('referral-copy-code')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-invite-link')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-share-link')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('referral-poster')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('referral-poster-qr')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-poster-code')),
        findsOneWidget,
      );
      expect(ReferralPoster.width * ReferralPoster.exportPixelRatio, 1080);
      expect(ReferralPoster.height * ReferralPoster.exportPixelRatio, 1920);
    });

    testWidgets('without a link: code only, poster without a QR', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer(value: _center(link: null)),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('referral-link-absent')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-share-link')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey<String>('referral-poster')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('referral-poster-qr')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-poster-no-link')),
        findsOneWidget,
      );
    });

    testWidgets('stats absent: dashes and a note; present: the counts', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(overview: S7Answer(value: _center())),
      );
      final grid = find.byKey(const ValueKey<String>('referral-stats'));
      await scrollToS7Section(tester, grid);
      expect(
        find.descendant(of: grid, matching: find.text(loopFigureDash)),
        findsNWidgets(3),
      );
      expect(find.textContaining('邀请统计还没有开放'), findsOneWidget);

      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer(
            value: _center(
              stats: ReferralStats(
                directCount: 3,
                validCount: 1,
                level2to5Count: 4,
                validAsOf: DateTime.utc(2026, 10, 19, 9),
              ),
            ),
          ),
        ),
      );
      await scrollToS7Section(tester, grid);
      expect(
        find.descendant(of: grid, matching: find.text(loopFigureDash)),
        findsNothing,
      );
      expect(find.descendant(of: grid, matching: find.text('4')), findsOne);
    });

    testWidgets('an available boost is drawn in power, not money', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer(value: _center(boostAvailable: true)),
        ),
      );
      final card = find.byKey(
        const ValueKey<String>('referral-boost-available'),
      );
      await scrollToS7Section(tester, card);
      expect(card, findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.textContaining('USD'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('launch-unavailable-邀请加成')),
        findsNothing,
      );
    });

    testWidgets('invitee faces open profiles; a hidden profile opens nothing', (
      tester,
    ) async {
      final opened = <String>[];
      final gateway = FakeReferralGateway(
        overview: S7Answer(value: _center()),
        invitees: S7Answer(value: _invitees(nextCursor: 'abc.def')),
      );
      await pumpS7Page(
        tester,
        ReferralScreen(onNavigate: opened.add),
        referral: gateway,
      );
      final face = find.byKey(
        const ValueKey<String>('referral-invitee-face-0'),
      );
      await scrollToS7Section(tester, face);
      expect(find.text('alice'), findsWidgets);
      expect(find.text('有效'), findsWidgets);
      expect(find.text('已失效'), findsWidgets);
      await tester.tap(face);
      await tester.pump();
      expect(opened, <String>[userProfileLocation(_profileA)]);

      // The hidden profile's face has no gesture of its own.
      final hidden = find.byKey(
        const ValueKey<String>('referral-invitee-face-1'),
      );
      expect(
        find.descendant(of: hidden, matching: find.byType(LoopPressable)),
        findsNothing,
      );

      // The footer asks for the next page once, by itself (decision 0129).
      await tester.pumpAndSettle();
      expect(gateway.inviteeCursors, <String?>[null, 'abc.def']);
    });

    testWidgets('an invite link code opens the binding form pre-filled', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(initialInviteCode: 'LOOP-ABCDE'),
        referral: FakeReferralGateway(),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('referral-claim-sheet')),
        findsOneWidget,
      );
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('referral-claim-input')),
      );
      expect(input.controller!.text, 'LOOP-ABCDE');
    });

    testWidgets('a bound account is told the link code was not used', (
      tester,
    ) async {
      final gateway = FakeReferralGateway(
        overview: S7Answer(value: s7Referral(binding: s7BoundBinding())),
      );
      await pumpS7Page(
        tester,
        const ReferralScreen(initialInviteCode: 'LOOP-ABCDE'),
        referral: gateway,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('referral-claim-sheet')),
        findsNothing,
      );
      expect(find.textContaining('已经绑定过邀请人'), findsOneWidget);
      expect(gateway.claims, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('情报 · 邀请中心 chip', () {
    testWidgets('the chip draws my code over 推广榜 and opens the page', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: opened.add),
        mining: FakeMiningGateway(),
        referral: FakeReferralGateway(overview: S7Answer(value: _center())),
      );
      await tester.tap(find.text('邀请中心'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('intel-referral-code')),
        findsOneWidget,
      );
      expect(find.text('LOOP-7HJKM'), findsOneWidget);
      // The board's own ledger card stays.
      expect(find.byKey(const ValueKey<String>('intel-rank-me')), findsOne);
      final open = find.byKey(const ValueKey<String>('intel-referral-open'));
      await scrollToS7Section(tester, open);
      await tester.tap(open);
      expect(opened, <String>['/profile/referral']);
    });
  });

  // S277 · decision 0235 (需求方 2026-10-22 第 07 条): code, link and counts
  // are three raised blocks; the link is one line with copy / share glyphs.
  group('我的邀请 · layout', () {
    const link = 'https://api-staging.quant-dinger.cc/i/LOOP-7HJKM';

    Future<List<(String, String?)>> pumpCard(
      WidgetTester tester, {
      String? inviteLink = link,
    }) async {
      final shared = <(String, String?)>[];
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: FakeMiningGateway(),
        referral: FakeReferralGateway(
          overview: S7Answer(value: _center(link: inviteLink)),
        ),
        overrides: [
          loopTextShareProvider.overrideWithValue((text, {subject}) async {
            shared.add((text, subject));
            return true;
          }),
        ],
      );
      await tester.tap(find.text('邀请中心'));
      await tester.pumpAndSettle();
      return shared;
    }

    testWidgets('code and link copy from glyphs; share opens the system', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final shared = await pumpCard(tester);

      // The code block carries its copy glyph; no full-width button is left.
      final copyCode = find.byKey(const ValueKey<String>('referral-copy-code'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('intel-referral-code')),
          matching: copyCode,
        ),
        findsOneWidget,
      );
      expect(tester.widget(copyCode), isA<LoopIconButton>());
      expect(find.text('复制邀请码'), findsNothing);
      expect(find.text('分享邀请链接'), findsNothing);
      await tester.tap(copyCode);
      await tester.pump();
      expect(copied, 'LOOP-7HJKM');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The link is one line and keeps the code it ends with.
      final linkFinder = find.byKey(
        const ValueKey<String>('referral-invite-link'),
      );
      final text = tester.widget<Text>(
        find.descendant(of: linkFinder, matching: find.byType(Text)),
      );
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.data, endsWith('LOOP-7HJKM'));
      expect(tester.getSize(linkFinder).height, lessThan(30));

      final copyLink = find.byKey(const ValueKey<String>('referral-copy-link'));
      final share = find.byKey(const ValueKey<String>('referral-share-link'));
      final poster = find.byKey(const ValueKey<String>('referral-poster'));
      for (final glyph in <Finder>[copyLink, share, poster]) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('referral-link-block')),
            matching: glyph,
          ),
          findsOneWidget,
        );
        expect(tester.getSize(glyph).height, greaterThanOrEqualTo(44));
      }
      // Copy and share sit on the link's own line.
      expect(
        (tester.getCenter(copyLink).dy - tester.getCenter(linkFinder).dy).abs(),
        lessThan(4),
      );
      await tester.tap(copyLink);
      await tester.pump();
      expect(copied, link);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(shared, hasLength(1));
      expect(shared.single.$1, referralInviteText('LOOP-7HJKM', link));
      expect(shared.single.$2, '邀请你加入 LOOP');
    });

    testWidgets('three blocks on the raised ground; counts in one row', (
      tester,
    ) async {
      await pumpCard(tester);
      for (final key in <String>[
        'intel-referral-code',
        'referral-link-block',
      ]) {
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(ValueKey<String>(key)),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          LoopColors.card2,
          reason: key,
        );
      }
      final cells = <String>[
        'referral-stats-direct',
        'referral-stats-valid',
        'referral-stats-deep',
      ].map((key) => tester.getCenter(find.byKey(ValueKey<String>(key))));
      expect(cells.map((c) => c.dy).toSet(), hasLength(1));
      // The name sits above its figure.
      expect(tester.getCenter(find.text('直接邀请')).dy, lessThan(cells.first.dy));
      final code = tester.getRect(
        find.byKey(const ValueKey<String>('intel-referral-code')),
      );
      final linkBlock = tester.getRect(
        find.byKey(const ValueKey<String>('referral-link-block')),
      );
      expect(linkBlock.top - code.bottom, LoopSpacing.rowGap);
    });

    testWidgets('without a link the block says so and the poster stays', (
      tester,
    ) async {
      final shared = await pumpCard(tester, inviteLink: null);
      expect(
        find.byKey(const ValueKey<String>('referral-link-absent')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-copy-link')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-poster')),
        findsOneWidget,
      );
      expect(shared, isEmpty);
    });
  });

  group('invite links /i/{code}', () {
    test('the server-accepted variants normalise to one code', () {
      for (final path in <String>[
        '/i/LOOP-7HJKM',
        '/i/loop-7hjkm',
        '/i/7hjkm',
        '/i/LOOP-7HJKM/',
      ]) {
        expect(inviteCodeFromLinkPath(path), 'LOOP-7HJKM', reason: path);
      }
      expect(inviteCodeFromLinkPath('/i/loop-7hjko'), 'LOOP-7HJK0');
    });

    test('anything else is not an invite link', () {
      for (final path in <String>[
        '/u/LOOP-7HJKM',
        '/i/',
        '/i/LOOP-7HJ',
        '/i/LOOP-7HJKM/extra',
        '/i/%E0%A4%A',
        '/profile/referral',
      ]) {
        expect(inviteCodeFromLinkPath(path), isNull, reason: path);
      }
    });

    test('the link opens the existing referral route with the code', () {
      final location = referralClaimLocation('LOOP-7HJKM');
      expect(location, '/profile/referral?code=LOOP-7HJKM');
      final uri = Uri.parse(location);
      expect(uri.path, referralRoutePath);
      expect(referralClaimCodeFromQuery(uri.queryParameters), 'LOOP-7HJKM');
      expect(referralClaimCodeFromQuery(const <String, String>{}), isNull);
      expect(
        referralClaimCodeFromQuery(const <String, String>{'code': 'x'}),
        isNull,
      );
    });
  });

  group('faces open profiles', () {
    test('self opens 我, another account its page, an address nothing', () {
      expect(loopProfileFaceLocation(null, isSelf: true), '/profile');
      expect(
        loopProfileFaceLocation(_profileA),
        userProfileLocation(_profileA),
      );
      expect(loopProfileFaceLocation(null), isNull);
    });

    testWidgets('no profile: no gesture; a profile: a 44 hit box', (
      tester,
    ) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                LoopProfileFaceLink(
                  key: const ValueKey<String>('bare'),
                  publicProfileId: null,
                  name: '0x12…34',
                  onOpen: opened.add,
                  child: const SizedBox(width: 20, height: 20),
                ),
                LoopProfileFaceLink(
                  key: const ValueKey<String>('linked'),
                  publicProfileId: _profileA,
                  name: 'alice',
                  onOpen: opened.add,
                  child: const SizedBox(width: 20, height: 20),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('bare')),
          matching: find.byType(LoopPressable),
        ),
        findsNothing,
      );
      final linked = find.byKey(const ValueKey<String>('linked'));
      expect(tester.getSize(linked).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(linked).height, greaterThanOrEqualTo(44));
      await tester.tap(linked);
      expect(opened, <String>[userProfileLocation(_profileA)]);
    });

    testWidgets('a launch2 tape line names the account and its face opens it', (
      tester,
    ) async {
      final opened = <String>[];
      final now = DateTime.utc(2026, 10, 20, 12);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Launch2DeskTape(
              items: <Launch2Activity>[
                Launch2Activity(
                  kind: Launch2ActivityKind.curveBuy,
                  instanceId: _profileA,
                  ticker: 'DOGE',
                  name: 'Doge',
                  at: now,
                  actor: '0x1d2f000000000000000000000000000000009b',
                  amountUsd1: Decimal.parse('20'),
                  account: const MemeAccountRef(
                    publicProfileId: _profileA,
                    displayName: 'alice',
                  ),
                ),
                Launch2Activity(
                  kind: Launch2ActivityKind.curveSell,
                  instanceId: _profileA,
                  ticker: 'DOGE',
                  name: 'Doge',
                  at: now,
                  actor: '0x1d2f000000000000000000000000000000009c',
                ),
              ],
              now: () => now,
              onNavigate: opened.add,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('launch2-tape-face')), findsOne);
      expect(find.textContaining('alice'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('launch2-tape-face')));
      expect(opened, <String>[userProfileLocation(_profileA)]);
    });
  });

  group('GET /v2/referral/invitees codec', () {
    Map<String, Object?> row({
      Object? id = _profileA,
      Object? alias = 'alice',
      Object? avatar = 'avatar:a/b.png',
      Object? status = 'valid',
    }) => <String, Object?>{
      'publicProfileId': id,
      'alias': alias,
      'avatarRef': avatar,
      'boundAt': '2026-10-18T03:00:00.000Z',
      'validationStatus': status,
    };

    Future<ReferralInviteePage> read(Object? body) =>
        DioLoopV2ReferralApi(_dio(body))
            .getInvitees(accessToken: 'access-token', clientVersion: '1.4.0');

    Matcher invalid() => throwsA(
      isA<LoopBackendFailure>().having(
        (failure) => failure.kind,
        'kind',
        LoopBackendFailureKind.invalidPayload,
      ),
    );

    test('a page with a hidden profile and a cursor', () async {
      final page = await read(<String, Object?>{
        'items': <Object?>[
          row(),
          row(id: null, alias: null, avatar: null, status: 'invalid'),
        ],
        'nextCursor': 'abc.def',
        'contractVersion': '2.0',
      });
      expect(page.items, hasLength(2));
      expect(page.items.first.publicProfileId, _profileA);
      expect(page.items.first.status, ReferralInviteeStatus.valid);
      expect(page.items.last.publicProfileId, isNull);
      expect(page.items.last.status, ReferralInviteeStatus.invalid);
      expect(page.nextCursor, 'abc.def');
    });

    test('refused shapes', () async {
      for (final body in <Object?>[
        <String, Object?>{
          'items': <Object?>[row(status: 'pending_wallet')],
          'nextCursor': null,
          'contractVersion': '2.0',
        },
        <String, Object?>{
          'items': <Object?>[row(id: null)],
          'nextCursor': null,
          'contractVersion': '2.0',
        },
        <String, Object?>{
          'items': <Object?>[
            <String, Object?>{...row(), 'loopId': 'LOOP-ABCDEFGH'},
          ],
          'nextCursor': null,
          'contractVersion': '2.0',
        },
        <String, Object?>{
          'items': const <Object?>[],
          'nextCursor': null,
          'contractVersion': '2.0',
          'extra': true,
        },
      ]) {
        await expectLater(read(body), invalid());
      }
    });
  });
}

Dio _dio(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _JsonAdapter(body);
  return dio;
}

final class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      'cache-control': <String>['no-store'],
      'x-request-id': <String>['11111111-2222-4333-8444-555555555555'],
    },
  );
}

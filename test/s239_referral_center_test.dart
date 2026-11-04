import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/invite_link.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';

import 'support/referral_center_host.dart';

import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/referral/loop_v2_referral_api.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
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
        const ReferralCenterHost(),
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
          const ReferralCenterHost(),
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
        const ReferralCenterHost(),
        referral: FakeReferralGateway(overview: S7Answer(value: _center())),
      );
      final empty = find.byKey(
        const ValueKey<String>('referral-invitees-empty'),
      );
      await scrollToS7Section(tester, empty);
      expect(empty, findsOneWidget);

      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
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
        const ReferralCenterHost(),
        referral: FakeReferralGateway(overview: S7Answer(value: _center())),
      );
      expect(find.text('LOOP-7HJKM'), findsOneWidget);
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
        const ReferralCenterHost(),
        referral: FakeReferralGateway(
          overview: S7Answer(value: _center(link: null)),
        ),
      );
      // S344 review: without a link the 邀请链接 block is left out.
      expect(
        find.byKey(const ValueKey<String>('referral-link-block')),
        findsNothing,
      );
      expect(find.text('Invite link'), findsNothing);
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

    testWidgets(
      'S348: 我的邀请 is not drawn; S353b: the stats are the three cells',
      (tester) async {
        await pumpS7Page(
          tester,
          const ReferralCenterHost(),
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
        // S353b · decision 0279 (主代理 11-04): the counts the server sent
        // stand as the Figma's three cells; 我的邀请 stays gone.
        expect(
          find.byKey(const ValueKey<String>('referral-stats')),
          findsOneWidget,
        );
        expect(find.text('我的邀请'), findsNothing);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey<String>('referral-stats-deep')),
              )
              .data,
          '4',
        );
      },
    );
    testWidgets('an available boost is drawn in power, not money', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(initialTab: ReferralCenterTab.boost),
        referral: FakeReferralGateway(
          overview: S7Answer(value: _center(boostAvailable: true)),
        ),
      );
      final card = find.byKey(const ValueKey<String>('referral-boost'));
      await scrollToS7Section(tester, card);
      expect(card, findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.textContaining('USD'), findsNothing);
      // S348: only the depth with something is drawn.
      expect(
        find.byKey(const ValueKey<String>('referral-boost-level-1')),
        findsOneWidget,
      );
      for (var level = 2; level <= 5; level += 1) {
        expect(
          find.byKey(ValueKey<String>('referral-boost-level-$level')),
          findsNothing,
        );
      }
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
        ReferralCenterHost(onNavigate: opened.add),
        referral: gateway,
      );
      final face = find.byKey(
        const ValueKey<String>('referral-invitee-face-0'),
      );
      await scrollToS7Section(tester, face);
      expect(find.text('alice'), findsWidgets);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Invalid'), findsWidgets);
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
        const ReferralCenterHost(initialInviteCode: 'LOOP-ABCDE'),
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
        const ReferralCenterHost(initialInviteCode: 'LOOP-ABCDE'),
        referral: gateway,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('referral-claim-sheet')),
        findsNothing,
      );
      expect(
        find.textContaining('This account already has an inviter'),
        findsOneWidget,
      );
      expect(gateway.claims, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('情报 · 算力 · 邀请 tab (decision 0272)', () {
    testWidgets('the tab draws the invite center with my code', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
        referral: FakeReferralGateway(overview: S7Answer(value: _center())),
        size: const Size(390, 4000),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('mining-power-tabs')),
          matching: find.text('Invitation'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('referral-invite-code')),
        findsOneWidget,
      );
      expect(find.text('LOOP-7HJKM'), findsOneWidget);
      // S348: 邀请列表 / 邀请加成 side by side, 我的邀请人 at the foot.
      for (final label in <String>[
        'Invite list',
        'Invite boost',
        'My inviter',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('我的邀请'), findsNothing);
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
        const ReferralCenterHost(),
        mining: FakeMiningGateway(),
        referral: FakeReferralGateway(
          overview: S7Answer(
            value: _center(
              link: inviteLink,
              stats: ReferralStats(
                directCount: 0,
                validCount: 0,
                level2to5Count: 0,
                validAsOf: DateTime.utc(2026, 10, 22, 9),
              ),
            ),
          ),
        ),
        overrides: [
          loopTextShareProvider.overrideWithValue((text, {subject}) async {
            shared.add((text, subject));
            return true;
          }),
        ],
      );
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

      // UX-012: one card — the code carries its copy glyph; no 复制邀请码
      // button is left; 分享邀请链接 and 生成海报 close the card.
      final copyCode = find.byKey(const ValueKey<String>('referral-copy-code'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('referral-hero')),
          matching: copyCode,
        ),
        findsOneWidget,
      );
      expect(tester.widget(copyCode), isA<ReferralCopyGlyph>());
      expect(find.text('Copy invite code'), findsNothing);
      expect(find.text('Share link'), findsOneWidget);
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
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('referral-link-block')),
          matching: copyLink,
        ),
        findsOneWidget,
      );
      for (final control in <Finder>[copyLink, share, poster]) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('referral-hero')),
            matching: control,
          ),
          findsOneWidget,
        );
        expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
      }
      // Copy sits on the link's own line.
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
      expect(shared.single.$2, 'Join me on LOOP');
    });

    testWidgets('one invite card; no counts inside it (S348, S353b)', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('referral-hero')),
          matching: find.byKey(const ValueKey<String>('referral-link-block')),
        ),
        findsOneWidget,
      );
      // S353b · decision 0279: the three counts are their own card under
      // the invite card, never inside it.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('referral-hero')),
          matching: find.byKey(const ValueKey<String>('referral-stats-direct')),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-levels')),
        findsNothing,
      );
    });
    testWidgets('without a link the block is left out and the poster stays', (
      tester,
    ) async {
      final shared = await pumpCard(tester, inviteLink: null);
      // S344 review: without a link the 邀请链接 block is left out.
      expect(
        find.byKey(const ValueKey<String>('referral-link-block')),
        findsNothing,
      );
      expect(find.text('Invite link'), findsNothing);
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
      expect(loopProfileFaceLocation(null, isSelf: true), '/wallet');
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

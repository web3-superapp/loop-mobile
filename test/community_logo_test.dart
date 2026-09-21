import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

/// Relative luminance, WCAG 2.1 §1.4.3.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final first = _luminance(a);
  final second = _luminance(b);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

/// The ground key the monogram tile carries, or null when an atlas image was
/// drawn instead.
String? _groundOf(WidgetTester tester) {
  final containers = tester.widgetList<Container>(find.byType(Container));
  for (final container in containers) {
    final key = container.key;
    if (key is ValueKey<String> &&
        key.value.startsWith('community-logo-monogram-')) {
      return key.value.substring('community-logo-monogram-'.length);
    }
  }
  return null;
}

Future<void> _pumpLogo(
  WidgetTester tester, {
  required String identity,
  required String name,
  String? logoRef,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        body: Center(
          child: CommunityLogo(
            identity: identity,
            name: name,
            logoRef: logoRef,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  loopWatchGround();

  group('community logo · the atlas carries all twelve presets', () {
    test('01..12 each resolve to their own atlas cell', () {
      expect(
        <String?>[
          for (var slot = 1; slot <= communityLogoPresetCount; slot += 1)
            communityLogoSlotFor(
              '$communityLogoPresetPrefix'
              '${slot.toString().padLeft(2, '0')}',
            ),
        ],
        <String>[
          'loop',
          'pepe',
          'bonk',
          'mcat',
          'community-05',
          'community-06',
          'community-07',
          'community-08',
          'community-09',
          'community-10',
          'community-11',
          'community-12',
        ],
      );
      // Row-major, and no two presets share a cell: a community is never
      // given another community's mark.
      final cells = <(int, int)>{};
      for (var slot = 1; slot <= communityLogoPresetCount; slot += 1) {
        final key = communityLogoSlotKey(slot)!;
        final cell = LoopIdentityAtlas.communities.slot(key)!;
        expect(
          (cell.column, cell.row),
          ((slot - 1) % 4, (slot - 1) ~/ 4),
          reason: '$slot',
        );
        cells.add((cell.column, cell.row));
      }
      expect(cells, hasLength(communityLogoPresetCount));
    });

    test('a reference outside the catalog resolves to no image', () {
      for (final reference in <String?>[
        null,
        '',
        'avatar:preset/people-01',
        communityLogoPresetPrefix,
        '${communityLogoPresetPrefix}00',
        '${communityLogoPresetPrefix}13',
        '${communityLogoPresetPrefix}ab',
      ]) {
        expect(communityLogoSlotFor(reference), isNull, reason: '$reference');
      }
    });

    testWidgets('every published preset draws its image, not initials', (
      tester,
    ) async {
      for (var slot = 1; slot <= communityLogoPresetCount; slot += 1) {
        final reference =
            '$communityLogoPresetPrefix${slot.toString().padLeft(2, '0')}';
        await _pumpLogo(
          tester,
          identity: testCommunityId,
          name: 'Frog Holders',
          logoRef: reference,
        );

        expect(
          find.byKey(ValueKey<String>('community-logo-image-$reference')),
          findsOneWidget,
          reason: reference,
        );
        expect(
          find.byType(LoopIdentityAvatar),
          findsOneWidget,
          reason: reference,
        );
        expect(_groundOf(tester), isNull, reason: reference);
        expect(find.text('FR'), findsNothing, reason: reference);
      }
    });

    testWidgets('a community with no preset draws its own initials', (
      tester,
    ) async {
      for (final reference in <String?>[
        null,
        '${communityLogoPresetPrefix}13',
        'avatar:preset/people-01',
      ]) {
        await _pumpLogo(
          tester,
          identity: testCommunityId,
          name: 'Frog Holders',
          logoRef: reference,
        );

        expect(
          find.byType(LoopIdentityAvatar),
          findsNothing,
          reason: '$reference',
        );
        expect(find.text('FR'), findsOneWidget, reason: '$reference');
        expect(_groundOf(tester), isNotNull, reason: '$reference');
      }
    });
  });

  group('community logo · the fallback is an identity, not a grey tile', () {
    test('one id always gets one ground, whatever its name becomes', () {
      final first = communityLogoGroundFor(testCommunityId);
      expect(communityLogoGroundFor(testCommunityId).id, first.id);
      expect(communityLogoGroundFor(' $testCommunityId ').id, first.id);
      // The catalogue is closed: a ground is one of the six.
      expect(
        communityLogoGrounds.map((ground) => ground.id),
        contains(first.id),
      );
    });

    test('the dev directory of forty-three communities uses all six grounds', () {
      final used = <String>{};
      for (var index = 0; index < 43; index += 1) {
        final id =
            '3fa85f64-5717-4562-b3fc-2c963f66${index.toString().padLeft(4, '0')}';
        used.add(communityLogoGroundFor(id).id);
      }
      expect(used.length, communityLogoGrounds.length);
    });

    test('an empty id still gets a ground rather than throwing', () {
      expect(communityLogoGroundFor('').id, communityLogoGrounds.first.id);
      expect(communityLogoGroundFor('   ').id, communityLogoGrounds.first.id);
    });

    test('no ground is one of the surfaces the tile lands on', () {
      // The tile is opaque, so a fill that matches its surface is a tile that
      // is not there. These are the grounds a community face actually lands
      // on: the Ink page, a card, the elevated message panel, the Chalk folio
      // and the quiet folio's dark Lime — the last of which the first draft of
      // this table reproduced exactly.
      const surfaces = <String, Color>{
        'ink': LoopColors.ink,
        'graphite': LoopColors.graphite,
        'elevated': LoopColors.elevated,
        'chalk': LoopColors.chalk,
        'card': Color(0xFF111311),
        'quiet folio': Color(0xFF2E400A),
      };
      for (final ground in communityLogoGrounds) {
        for (final surface in surfaces.entries) {
          expect(
            loopGroundDelta(ground.fill, surface.value),
            greaterThanOrEqualTo(16),
            reason: '${ground.id} on ${surface.key}',
          );
        }
      }
    });

    test('every ground clears 4.5:1 between its letters and its fill', () {
      for (final ground in communityLogoGrounds) {
        expect(
          _contrast(ground.fill, ground.ink),
          greaterThanOrEqualTo(4.5),
          reason: ground.id,
        );
      }
    });

    testWidgets('two communities with the same initials still differ', (
      tester,
    ) async {
      await _pumpLogo(
        tester,
        identity: '3fa85f64-5717-4562-b3fc-2c963f66af01',
        name: 'Alpha Signals',
      );
      final first = _groundOf(tester);
      await _pumpLogo(
        tester,
        identity: '3fa85f64-5717-4562-b3fc-2c963f66af02',
        name: 'Alpha Legends',
      );
      expect(_groundOf(tester), isNot(first));
    });
  });

  group('community logo · one face on every page', () {
    testWidgets('home, discovery, the record and the member directory agree', (
      tester,
    ) async {
      // A community the server never gave a preset: every page falls back,
      // and every page must fall back to the same face.
      final summary = testCommunity();
      final expected = communityLogoGroundFor(summary.communityId).id;

      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(
          home: CommunityHome(
            joined: <JoinedCommunity>[
              JoinedCommunity(
                community: summary,
                membership: CommunityMembership(
                  role: CommunityRole.member,
                  status: CommunityMemberStatus.active,
                  joinedAt: DateTime.utc(2026, 7),
                ),
              ),
            ],
            joinedTruncated: false,
            discover: const <CommunitySummary>[],
            unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
            liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
            observedAt: DateTime.utc(2026, 9, 8, 1),
            source: 'database',
            recommendation: const CommunityRecommendation(
              recommendationId: '22222222-2222-4222-8222-222222222222',
              ruleVersion: 'rule:verified-members-v1',
            ),
          ),
        ),
      );
      expect(_groundOf(tester), expected);

      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: FakeCommunityGateway(
          directoryPage: CommunityDirectoryPage(
            ordering: const CommunityOrderingApplied(
              sort: CommunityDirectorySort.members,
              basis: CommunityStoredBasis(),
            ),
            items: <CommunitySummary>[summary],
            nextCursor: null,
            recommendation: const CommunityRecommendation(
              recommendationId: '22222222-2222-4222-8222-222222222222',
              ruleVersion: 'rule:verified-members-v1',
            ),
          ),
        ),
      );
      expect(_groundOf(tester), expected);

      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(detail: testDetail(community: summary)),
      );
      expect(
        find.byKey(const ValueKey<String>('community-folio-logo')),
        findsOneWidget,
      );
      expect(_groundOf(tester), expected);

      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(members: testDirectory()),
      );
      expect(
        find.byKey(const ValueKey<String>('community-members-logo')),
        findsOneWidget,
      );
      expect(_groundOf(tester), communityLogoGroundFor(testCommunityId).id);
    });
  });
}

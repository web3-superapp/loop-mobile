import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';

/// Whether [color] is one of the palette's soft tokens — the Chalk hue at a
/// low alpha.
///
/// The whole family of "invisible on a light ground" bugs is this one shape:
/// `card`, `card2`, `line`, `text2` and `text3` are all Chalk with the alpha
/// turned down, and painted on Chalk they are nothing at all. Asserting the
/// shape rather than a value means a palette tweak does not rewrite the test.
bool _isTranslucentChalk(Color color) {
  final chalk = LoopColors.chalk;
  return color.a < 0.999 &&
      (color.r - chalk.r).abs() < 0.004 &&
      (color.g - chalk.g).abs() < 0.004 &&
      (color.b - chalk.b).abs() < 0.004;
}

Widget _onInk(Widget child) => MaterialApp(
  theme: LoopTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

Widget _onChalk(Widget child) => MaterialApp(
  theme: LoopTheme.dark,
  home: Scaffold(
    body: Center(child: LoopChalkCard(child: child)),
  ),
);

void main() {
  group('a shared surface takes its colours from the ground it is on', () {
    testWidgets('the avatar fallback is visible inside a Chalk card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _onChalk(const LoopProfileAvatar(avatarRef: null, alias: 'cy')),
      );
      await tester.pumpAndSettle();

      final disc = tester.widget<Container>(
        find.byKey(const ValueKey<String>('loop-profile-avatar-monogram')),
      );
      final fill = (disc.decoration! as BoxDecoration).color!;
      expect(_isTranslucentChalk(fill), isFalse);
      // The monogram is the part the owner reads, so it is opaque, and it is
      // not the ground's own colour.
      final text = tester.widget<Text>(find.text('CY'));
      final ink = text.style!.color!;
      expect(ink.a, 1);
      expect(ink, isNot(LoopColors.chalk));
    });

    testWidgets('the same fallback on the Ink page is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        _onInk(const LoopProfileAvatar(avatarRef: null, alias: 'cy')),
      );
      await tester.pumpAndSettle();

      final disc = tester.widget<Container>(
        find.byKey(const ValueKey<String>('loop-profile-avatar-monogram')),
      );
      final fill = (disc.decoration! as BoxDecoration).color!;
      expect(fill.toARGB32(), LoopColors.card2.toARGB32());
      expect(
        tester.widget<Text>(find.text('CY')).style!.color!.toARGB32(),
        LoopColors.chalk.toARGB32(),
      );
    });

    testWidgets('a skeleton block is visible inside a Chalk card', (
      tester,
    ) async {
      await tester.pumpWidget(_onChalk(const LoopSkeletonBlock(height: 30)));
      await tester.pump();

      final fills = tester
          .widgetList<Container>(find.byType(Container))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color)
          .whereType<Color>();
      expect(fills, isNotEmpty);
      for (final fill in fills) {
        expect(_isTranslucentChalk(fill), isFalse);
      }
    });

    testWidgets('a skeleton block on the Ink page is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(_onInk(const LoopSkeletonBlock(height: 30)));
      await tester.pump();

      final fill =
          (tester
                  .widgetList<Container>(find.byType(Container))
                  .map((container) => container.decoration)
                  .whereType<BoxDecoration>()
                  .firstWhere((decoration) => decoration.color != null))
              .color!;
      expect(fill.toARGB32(), LoopColors.card2.toARGB32());
    });

    testWidgets('a state strip is readable inside a Chalk card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _onChalk(const LoopEmpty(message: '二维码不可用', reason: '这一项暂时读不到。')),
      );
      await tester.pumpAndSettle();

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final color = text.style?.color;
        if (color == null) continue;
        expect(_isTranslucentChalk(color), isFalse, reason: text.data);
      }
    });

    testWidgets('the identity tile fallback is visible inside a Chalk card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _onChalk(
          const LoopIdentityAvatar(
            atlas: LoopIdentityAtlas.people,
            // No such slot, so the tile takes the monogram branch.
            slot: 'not-a-slot',
            fallbackMonogram: 'CY',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = tester.widget<Container>(
        find.byKey(const ValueKey<String>('loop-asset-monogram')),
      );
      final decoration = tile.decoration! as BoxDecoration;
      expect(_isTranslucentChalk(decoration.color!), isFalse);
      expect(_isTranslucentChalk(decoration.border!.top.color), isFalse);
    });
  });

  group('an unreachable node is not the reader’s network', () {
    test('the chain and provider sentences say whose side the gap is on', () {
      for (final code in <String>[
        'BSC_RPC_UNREACHABLE',
        'LAUNCH_CHAIN_RPC_UNREACHABLE',
        'MARKET_PROVIDER_UNREACHABLE',
      ]) {
        final text = loopReasonCodeText(code);
        expect(text, contains('与你的网络无关'), reason: code);
        // One sentence, and no instruction to go and fix a working radio.
        expect(text, isNot(contains('请检查')), reason: code);
        expect(text, isNot(contains('离线')), reason: code);
      }
      // The device's own offline state keeps saying so: the two are not the
      // same fact and never share a sentence.
      expect(
        loopChainFailureReason(LoopChainFailureKind.offline),
        contains('设备已离线'),
      );
    });
  });

  group('a wire value never reaches a text slot', () {
    test('both registry enums carry a display name of their own', () {
      for (final status in LoopAssetStatus.values) {
        expect(status.label, isNot(status.wireName));
        expect(RegExp(r'^[\x00-\x7F]+$').hasMatch(status.label), isFalse);
      }
      for (final verification in LoopChainVerification.values) {
        expect(verification.label, isNot(verification.wireName));
        expect(RegExp(r'^[\x00-\x7F]+$').hasMatch(verification.label), isFalse);
      }
      // `verified` means two different things, so it is said two ways.
      expect(
        LoopAssetStatus.verified.label,
        isNot(LoopChainVerification.verified.label),
      );
    });
  });

  group('the community heading says the gap in words', () {
    test('the three placeholders name three different kinds of gap', () {
      expect(communityMissingFigure, '—');
      expect(communityMissingHeading, isNot(communityMissingFigure));
      expect(communityMissingName, isNot(communityMissingHeading));
      // The em dash keeps the small slots; neither heading is one.
      expect(communityMissingHeading.length, greaterThan(1));
      expect(communityMissingName.length, greaterThan(1));
    });
  });

  group('a grouped row keeps every field it was given', () {
    testWidgets('LoopRecordGroup carries subtitleMaxLines through', (
      tester,
    ) async {
      const long =
          '延迟 302ms · 落后 4 块 · 校验通过 · 2 秒前 · 这一段足够长，单行放不下';
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              child: LoopRecordGroup(
                rows: <LoopRecordRow>[
                  LoopRecordRow(
                    key: ValueKey<String>('grouped-row'),
                    title: 'rpc-956a0d5f88ea',
                    subtitle: long,
                    subtitleMaxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // The group rebuilds each row instead of mounting the one it was
      // handed, so a field it forgets to copy is dropped silently and only
      // shows up on a device. Assert on the mounted Text, not on the row.
      expect(tester.widget<Text>(find.text(long)).maxLines, 2);
    });
  });

  group('the sprite sheet carries a re-read glyph', () {
    test('refresh is registered', () {
      expect(LoopIconNames.contains('refresh'), isTrue);
    });
  });

  group('a read that follows a write keeps the rows it already has', () {
    test('lifting a block updates the list in place', () async {
      final gateway = FakeSocialGateway(blocks: _oneBlock());
      final container = ProviderContainer(
        overrides: [socialGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      // The controller is autoDispose: without a listener it would be torn
      // down between reads and the test would watch a fresh state instead of
      // the one the write left behind.
      container.listen(blocklistControllerProvider, (previous, next) {});
      final controller = container.read(blocklistControllerProvider.notifier);
      await controller.load();
      expect(container.read(blocklistControllerProvider).items, hasLength(1));

      final hold = Completer<void>();
      gateway.hold = hold;
      final pending = controller.unblock(
        container.read(blocklistControllerProvider).items.single,
      );
      await _drainMicrotasks();

      // The server accepted the write and the list is being read again. One
      // row is stale; the rest is exactly as true as it was a frame ago, so
      // the page stays a list and says it is updating.
      final inFlight = container.read(blocklistControllerProvider);
      expect(inFlight.items, hasLength(1));
      expect(inFlight.phase, CommunityViewPhase.ready);
      expect(inFlight.refreshing, isTrue);

      hold.complete();
      await pending;
      final settled = container.read(blocklistControllerProvider);
      expect(settled.items, isEmpty);
      expect(settled.refreshing, isFalse);
    });

    test(
      'a governance command on a filtered view keeps the directory',
      () async {
        final gateway = FakeCommunityGateway(
          members: testDirectory(),
          membersByFilter: <CommunityMemberFilter, CommunityMemberDirectory>{
            CommunityMemberFilter.admin: testDirectory(
              items: <CommunityMemberEntry>[
                testMember(
                  role: CommunityRole.admin,
                  publicProfileId: testAdminId,
                ),
              ],
            ),
          },
        );
        final container = ProviderContainer(
          overrides: [communityGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);
        container.listen(
          communityMembersControllerProvider,
          (previous, next) {},
        );
        final controller = container.read(
          communityMembersControllerProvider.notifier,
        );
        await controller.open(testCommunityId);
        await controller.selectFilter(CommunityMemberFilter.admin);
        expect(
          container.read(communityMembersControllerProvider).items,
          hasLength(1),
        );

        // The filtered view is read again because the command answered with the
        // default directory, not this one — but the rows on screen stay.
        gateway.readDelay = const Duration(milliseconds: 30);
        final pending = controller.setMuted(
          publicProfileId: testAdminId,
          muted: true,
        );
        await _drainMicrotasks();

        final inFlight = container.read(communityMembersControllerProvider);
        expect(inFlight.items, hasLength(1));
        expect(inFlight.phase, CommunityViewPhase.ready);
        expect(inFlight.refreshing, isTrue);

        expect(await pending, isNull);
        expect(
          container.read(communityMembersControllerProvider).refreshing,
          isFalse,
        );
      },
    );
  });
}

/// Lets the resolved write and the synchronous start of the re-read run,
/// without letting the re-read itself answer.
Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 4; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

BlockPage _oneBlock() => BlockPage(
  kind: BlockKind.user,
  items: <BlockEntry>[
    BlockEntry(
      kind: BlockKind.user,
      stableId: testMemberId,
      profile: testProfile(publicProfileId: testMemberId, alias: 'spam_bot'),
      reasonCode: 'message_request_report',
      createdAt: DateTime.utc(2026, 8, 20),
    ),
  ],
  userCount: 1,
  nextCursor: null,
);

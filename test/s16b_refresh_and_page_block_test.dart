import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

import 'support/s5_page_harness.dart';

/// S16-B · pull-to-refresh, the whole-page block, and the two sentences a
/// closed gate can carry.
///
/// Three things are pinned here:
///
/// * a pull re-reads what the page already shows and never replaces it with a
///   skeleton, and the gesture behaves the same under reduced motion;
/// * whole-page unavailability is a [LoopPageBlock] that takes the page, not a
///   strip under a folio, and it is a different widget from the inline empty
///   state and from the loading skeleton;
/// * "LOOP did not answer" and "LOOP answered that a node is down" are two
///   sentences with two different next steps, and neither is derived from the
///   other.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduceMotion),
        child: child,
      ),
    ),
  );
  await tester.pump();
}

LoopDashboardPage _dashboard({
  Future<void> Function()? onRefresh,
  Widget? block,
  bool updating = false,
}) => LoopDashboardPage(
  archetype: LoopPageArchetype.listing,
  title: '行情',
  onRefresh: onRefresh,
  block: block,
  updating: updating,
  primary: const Text('folio-figure'),
  sections: const <Widget>[Text('row-one'), Text('row-two')],
);

/// Drags the page's own scroll region past the refresh threshold.
///
/// `RefreshIndicator` arms at a quarter of the viewport height, so the
/// distance is stated per page rather than assumed.
Future<void> _pullDown(WidgetTester tester, {double distance = 320}) async {
  await tester.fling(find.byType(Scrollable).first, Offset(0, distance), 1000);
  await tester.pumpAndSettle();
}

void main() {
  group('pull to refresh', () {
    testWidgets('a pull re-reads the page without clearing it', (tester) async {
      var reads = 0;
      await _pump(
        tester,
        _dashboard(
          onRefresh: () async => reads += 1,
          // The page is re-reading data it already holds, so it wears the mark
          // instead of falling back to a skeleton.
          updating: true,
        ),
      );

      expect(find.text('row-one'), findsOneWidget);
      await _pullDown(tester);

      expect(reads, 1);
      // Everything that was readable before the pull is still readable after
      // it: a refresh never trades data for grey blocks.
      expect(find.text('folio-figure'), findsOneWidget);
      expect(find.text('row-one'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-updating-badge')),
        findsOneWidget,
      );
      expect(find.byType(LoopSkeleton), findsNothing);
    });

    testWidgets('the gesture behaves the same under reduced motion', (
      tester,
    ) async {
      var reads = 0;
      await _pump(
        tester,
        _dashboard(onRefresh: () async => reads += 1),
        reduceMotion: true,
      );

      await _pullDown(tester);

      expect(reads, 1);
    });

    testWidgets('a page with no read to repeat carries no gesture', (
      tester,
    ) async {
      await _pump(tester, _dashboard());

      expect(
        find.byKey(const ValueKey<String>('loop-page-refresh')),
        findsNothing,
      );
    });

    testWidgets('a blocked page has nothing to re-read and takes no gesture', (
      tester,
    ) async {
      var reads = 0;
      await _pump(
        tester,
        _dashboard(
          onRefresh: () async => reads += 1,
          block: const LoopPageBlock(title: '行情模块当前不可用', message: '稍后再试。'),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('loop-page-refresh')),
        findsNothing,
      );
      await _pullDown(tester);
      expect(reads, 0);
    });

    testWidgets('a step page is never refreshable', (tester) async {
      await _pump(
        tester,
        const LoopFocusPage(
          archetype: LoopPageArchetype.action,
          title: '发送',
          body: <Widget>[Text('step-one')],
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('loop-page-refresh')),
        findsNothing,
      );
    });

    testWidgets('the wallet page re-reads its wallet on a pull', (
      tester,
    ) async {
      final wallet = FakeWalletReadGateway();
      await pumpS5Page(tester, const WalletScreen(), wallet: wallet);

      final before = wallet.directoryReads;
      expect(before, greaterThan(0));
      expect(
        find.byKey(const ValueKey<String>('loop-page-refresh')),
        findsOneWidget,
      );
      // The harness mounts a 2400 px tall viewport, so the gesture has to
      // clear a proportionally larger threshold.
      await _pullDown(tester, distance: 900);

      expect(wallet.directoryReads, greaterThan(before));
      // The balances it had read are still on screen.
      expect(
        find.byKey(const ValueKey<String>('wallet-screen')),
        findsOneWidget,
      );
      expect(find.byType(LoopSkeleton), findsNothing);
    });
  });

  group('whole-page unavailability', () {
    testWidgets('a block takes the page instead of sitting under the folio', (
      tester,
    ) async {
      await _pump(
        tester,
        _dashboard(
          block: const LoopPageBlock(title: '钱包读取当前不可用', message: '链上节点当前连不上。'),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('loop-page-block')),
        findsOneWidget,
      );
      // The primary region and every section are gone: a page with nothing to
      // show does not keep a folio that would have to invent a figure.
      expect(
        find.byKey(const ValueKey<String>('loop-page-primary')),
        findsNothing,
      );
      expect(find.text('folio-figure'), findsNothing);
      expect(find.text('row-one'), findsNothing);
      expect(find.text('钱包读取当前不可用'), findsOneWidget);
    });

    testWidgets('the three states stay three different widgets', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopEmpty(message: '还没有自选资产'),
              LoopSkeleton.row(),
            ],
          ),
        ),
      );

      // A block inside a page that did load is a strip; a page that is still
      // reading is a skeleton. Neither is the whole-page block.
      expect(find.byKey(const ValueKey<String>('loop-empty')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-skeleton-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-page-block')),
        findsNothing,
      );
    });
  });

  group('an unreachable client is not an unavailable node', () {
    testWidgets('a read that did not get through says so, and names no rule', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: LoopCapabilityPageBlock(
            title: '钱包读取当前不可用',
            reasonCode: 'BSC_RPC_UNREACHABLE',
            unreachable: true,
          ),
        ),
      );

      expect(find.text(LoopPageBlock.unreachableTitle), findsOneWidget);
      expect(find.text(LoopPageBlock.unreachableMessage), findsOneWidget);
      // The server never answered, so the page must not borrow one of its
      // sentences — including the one about the chain node.
      expect(find.textContaining('链上节点当前连不上'), findsNothing);
      expect(find.text('钱包读取当前不可用'), findsNothing);
    });

    testWidgets('a node the server reported keeps the server sentence', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(
          body: LoopCapabilityPageBlock(
            title: '钱包读取当前不可用',
            reasonCode: 'BSC_RPC_UNREACHABLE',
          ),
        ),
      );

      expect(find.text('钱包读取当前不可用'), findsOneWidget);
      expect(
        find.text(loopReasonCodeText('BSC_RPC_UNREACHABLE')),
        findsOneWidget,
      );
      // Nothing on this device can change the answer, so the page never asks
      // the user to check their network.
      expect(find.text(LoopPageBlock.unreachableTitle), findsNothing);
      expect(find.textContaining('请检查网络'), findsNothing);
    });

    testWidgets('a gate with no document but no failed read still waits', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: LoopCapabilityPageBlock.of(
            title: '钱包读取当前不可用',
            capability: const LoopCapabilityProjection.unknown(),
            fallbackReasonCode: 'WALLET_RUNTIME_UNAVAILABLE',
          ),
        ),
      );

      // Nothing was read and nothing failed: the page says what it cannot do
      // and never blames the network.
      expect(find.text('钱包读取当前不可用'), findsOneWidget);
      expect(find.text(LoopPageBlock.unreachableTitle), findsNothing);
    });

    test(
      'a failed capability observation is the only unreachable one',
      () async {
        final failed = ProviderContainer(
          overrides: [
            loopV2MetaSnapshotProvider.overrideWith(
              (ref) => Future<LoopV2MetaSnapshot?>.error(
                StateError('the capability read did not get through'),
              ),
            ),
          ],
        );
        addTearDown(failed.dispose);
        final absent = ProviderContainer(
          overrides: [
            loopV2MetaSnapshotProvider.overrideWith((ref) async => null),
          ],
        );
        addTearDown(absent.dispose);

        // Reading the family starts the observation; the projection is only
        // honest once the read has actually finished.
        await expectLater(
          failed.read(loopV2MetaSnapshotProvider.future),
          throwsA(isA<StateError>()),
        );
        await absent.read(loopV2MetaSnapshotProvider.future);

        final failedGate = failed.read(
          loopCapabilityProvider(LoopV2CapabilityId.walletRead),
        );
        final absentGate = absent.read(
          loopCapabilityProvider(LoopV2CapabilityId.walletRead),
        );

        expect(failedGate.isUnobserved, isTrue);
        expect(failedGate.unreachable, isTrue);
        // A build with no backend to ask never read a document either, but the
        // client is not the reason — so it is not the network sentence.
        expect(absentGate.isUnobserved, isTrue);
        expect(absentGate.unreachable, isFalse);
      },
    );
  });
}

// S279 · decision 0237 (需求方 2026-10-22 第 15、16 条): the MEME home's
// 「内盘 / 预告 / 已毕业」 tabs, the top bar's 「发射」 capsule, and the two
// block grounds.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_entry.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _id(int n) => '8b9f3c1e-2d4a-4f6b-9c8d-${n.toString().padLeft(12, '0')}';

Map<String, Object?> _row(int n, String stage, {int soldBps = 0}) => l2RowJson(
  instanceId: _id(n),
  stage: stage,
  soldBps: soldBps,
  noNextChange: stage == 'public' || stage == 'graduated',
);

/// The desk list answers [all]; `stage=graduated` answers [graduated].
final class _Gateway implements Launch2Gateway {
  _Gateway(this.all, {this.graduated});

  final List<Map<String, Object?>> all;
  final Future<Launch2InstancePage> Function()? graduated;
  final List<Launch2Stage?> stages = <Launch2Stage?>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) {
    stages.add(stage);
    if (stage == Launch2Stage.graduated) {
      final answer = graduated;
      if (answer != null) return answer();
      return Future<Launch2InstancePage>.value(
        l2Page(<Map<String, Object?>>[
          for (final row in all)
            if (row['stage'] == 'graduated') row,
        ]),
      );
    }
    return Future<Launch2InstancePage>.value(l2Page(all));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

LoopV2MetaSnapshot _meta() {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.launch2)
            const LoopV2Capability(
              id: LoopV2CapabilityId.launch2,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            )
          else
            capability,
      ],
    ),
  );
}

List<Override> _overrides(
  _Gateway gateway, {
  LoopFeatureSwitchValues switches = const LoopFeatureSwitchValues(
    launch2Visible: true,
  ),
}) => <Override>[
  launch2GatewayProvider.overrideWithValue(gateway),
  launch2ClockProvider.overrideWithValue(() => l2Now),
  launch2PollingProvider.overrideWithValue(
    const Launch2Polling(
      detailInterval: Duration(hours: 1),
      tradingInterval: Duration(hours: 1),
      listInterval: Duration(hours: 1),
    ),
  ),
  loopFeatureSwitchesProvider.overrideWithValue(switches),
];

Future<List<String>> _pumpHome(
  WidgetTester tester,
  _Gateway gateway, {
  bool settle = true,
}) async {
  final opened = <String>[];
  await pumpS7Page(
    tester,
    MemeScreen(onNavigate: opened.add),
    meta: _meta(),
    overrides: _overrides(gateway),
    settle: settle,
  );
  return opened;
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

/// Row 4 (内盘 80 %) is the main event, drawn as its record card on 内盘;
/// row 1 is a 内盘 row, row 2 a 预告 row, row 3 a graduated one.
final List<Map<String, Object?>> _rows = <Map<String, Object?>>[
  _row(4, 'public', soldBps: 8000),
  _row(1, 'public', soldBps: 2500),
  _row(2, 'upcoming'),
  _row(3, 'graduated', soldBps: 10000),
];

void main() {
  loopWatchGround();

  group('the MEME home\'s tabs', () {
    test('every stage has one tab; 内盘 holds everything still running', () {
      for (final stage in Launch2Stage.values) {
        final tab = Launch2DeskTab.of(stage);
        expect(tab, switch (stage) {
          Launch2Stage.upcoming => Launch2DeskTab.upcoming,
          Launch2Stage.graduated => Launch2DeskTab.graduated,
          _ => Launch2DeskTab.live,
        }, reason: stage.name);
      }
      expect(
        launch2DeskTabCounts(<(Launch2DeskSegment, int)>[
          (Launch2DeskSegment.minting, 2),
          (Launch2DeskSegment.curve, 6),
          (Launch2DeskSegment.upcoming, 0),
          (Launch2DeskSegment.graduated, 12),
        ]),
        <(Launch2DeskTab, int)>[
          (Launch2DeskTab.live, 8),
          (Launch2DeskTab.upcoming, 0),
          (Launch2DeskTab.graduated, 12),
        ],
      );
      expect(
        launch2DefaultDeskTab(null, <(Launch2DeskTab, int)>[
          (Launch2DeskTab.live, 0),
          (Launch2DeskTab.upcoming, 0),
          (Launch2DeskTab.graduated, 3),
        ]),
        Launch2DeskTab.graduated,
      );
      expect(
        launch2DefaultDeskTab(null, <(Launch2DeskTab, int)>[
          (Launch2DeskTab.live, 0),
          (Launch2DeskTab.upcoming, 0),
          (Launch2DeskTab.graduated, 0),
        ]),
        Launch2DeskTab.live,
      );
    });

    testWidgets('one list on screen; switching shows only that tab; the '
        'graduated list is read on first open and its row opens the '
        'project', (tester) async {
      final gateway = _Gateway(_rows);
      final opened = await _pumpHome(tester, gateway);
      expect(_key('launch2-desk-tabs'), findsOneWidget);
      // No stacked numbered sections.
      expect(find.byType(LoopSprayHeading), findsNothing);
      expect(_key('launch2-tile-${_id(1)}'), findsOneWidget);
      expect(_key('launch2-tile-${_id(2)}'), findsNothing);
      expect(_key('launch2-tile-${_id(3)}'), findsNothing);
      expect(gateway.stages, isNot(contains(Launch2Stage.graduated)));

      final scrollable = tester.state<ScrollableState>(
        find
            .ancestor(
              of: _key('launch2-desk-tabs'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(_key('launch2-desk-tab-upcoming'));
      await tester.pumpAndSettle();
      // The page is the same page: only the list under the tabs changed.
      expect(
        tester.state<ScrollableState>(
          find
              .ancestor(
                of: _key('launch2-desk-tabs'),
                matching: find.byType(Scrollable),
              )
              .first,
        ),
        same(scrollable),
      );
      expect(_key('launch2-tile-${_id(1)}'), findsNothing);
      expect(_key('launch2-tile-${_id(2)}'), findsOneWidget);

      await tester.tap(_key('launch2-desk-tab-graduated'));
      await tester.pumpAndSettle();
      expect(gateway.stages, contains(Launch2Stage.graduated));
      expect(_key('launch2-tile-${_id(2)}'), findsNothing);
      await tester.tap(_key('launch2-tile-${_id(3)}'));
      await tester.pump();
      expect(opened.last, Launch2Route.instance(_id(3)));
      await _drain(tester);
    });

    testWidgets('the chosen tab is remembered across a remount', (
      tester,
    ) async {
      final gateway = _Gateway(_rows);
      final shown = ValueNotifier<bool>(true);
      addTearDown(shown.dispose);
      await pumpS7Page(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: shown,
          builder: (context, on, _) =>
              on ? MemeScreen(onNavigate: (_) {}) : const SizedBox.shrink(),
        ),
        meta: _meta(),
        overrides: _overrides(gateway),
      );
      await tester.tap(_key('launch2-desk-tab-upcoming'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(_key('launch2-desk-tabs')),
      );
      expect(
        container.read(loopTabSegmentMemoryProvider)[launch2DeskTabMemoryKey],
        Launch2DeskTab.upcoming.index,
      );
      shown.value = false;
      await tester.pumpAndSettle();
      shown.value = true;
      await tester.pumpAndSettle();
      expect(_key('launch2-desk-tab-splat-upcoming'), findsOneWidget);
      expect(_key('launch2-tile-${_id(2)}'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('已毕业 · loading, empty and error stay inside the tab', (
      tester,
    ) async {
      final pending = Completer<Launch2InstancePage>();
      var answer = () => pending.future;
      final gateway = _Gateway(<Map<String, Object?>>[
        _row(1, 'public', soldBps: 2500),
      ], graduated: () => answer());
      await _pumpHome(tester, gateway);
      await tester.tap(_key('launch2-desk-tab-graduated'));
      await tester.pump();
      await tester.pump();
      expect(_key('launch2-list-graduated-loading'), findsOneWidget);
      // The desk above stays.
      expect(_key('launch2-desk-tabs'), findsOneWidget);
      pending.complete(l2Page(const <Map<String, Object?>>[]));
      await tester.pumpAndSettle();
      expect(_key('launch2-graduated-empty'), findsOneWidget);
      expect(find.text('还没有毕业的 v2 项目，内盘卖满后自动建官方池，会出现在这里'), findsOneWidget);
      await _drain(tester);

      answer = () => Future<Launch2InstancePage>.error(
        const LoopChainException(LoopChainFailureKind.offline),
      );
      await _pumpHome(tester, gateway);
      await tester.tap(_key('launch2-desk-tab-graduated'));
      await tester.pumpAndSettle();
      expect(_key('launch2-list-graduated-state-offline'), findsOneWidget);
      expect(_key('launch2-desk-tabs'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('内盘 with nothing running and no page left: its own empty '
        'board', (tester) async {
      await _pumpHome(
        tester,
        _Gateway(<Map<String, Object?>>[_row(3, 'graduated', soldBps: 10000)]),
      );
      // The only row is graduated: the home opens on 已毕业.
      expect(_key('launch2-desk-tab-splat-graduated'), findsOneWidget);
      await tester.tap(_key('launch2-desk-tab-live'));
      await tester.pumpAndSettle();
      expect(_key('launch2-live-empty'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('IDO on: the desk tabs sit inside the 发射台 segment and a tab '
        'tap does not move the segment', (tester) async {
      await pumpS7Page(
        tester,
        MemeScreen(onNavigate: (_) {}),
        meta: _meta(),
        overrides: _overrides(
          _Gateway(_rows),
          switches: const LoopFeatureSwitchValues(
            launch2Visible: true,
            idoLaunchVisible: true,
          ),
        ),
      );
      expect(_key('meme-segment-0'), findsOneWidget);
      expect(_key('meme-segment-1'), findsOneWidget);
      expect(_key('launch2-desk-tabs'), findsOneWidget);
      await tester.tap(_key('launch2-desk-tab-upcoming'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(_key('launch2-desk-tabs')),
      );
      expect(container.read(loopTabSegmentMemoryProvider)['meme'], isNull);
      expect(_key('launch2-tile-${_id(2)}'), findsOneWidget);
      expect(_key('launch2-create-action'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('the top bar', () {
    testWidgets('我的项目 is a 24 glyph in a 44 target; 发射 is the Yellow '
        'capsule with its words and opens the create page at once while '
        'classic is retired', (tester) async {
      final opened = await _pumpHome(tester, _Gateway(_rows));
      final mine = _key('launch2-my-projects-action');
      expect(tester.getSize(mine), const Size(44, 44));
      final glyphs = tester.widgetList<LoopIcon>(
        find.descendant(of: mine, matching: find.byType(LoopIcon)),
      );
      expect(glyphs, isNotEmpty);
      expect(glyphs.every((icon) => icon.size == 24), isTrue);
      final capsule = _key('launch2-create-action');
      expect(tester.getSize(capsule).height, greaterThanOrEqualTo(44));
      expect(
        find.descendant(of: capsule, matching: find.text('发射')),
        findsOneWidget,
      );
      final ground = tester.widget<Container>(_key('launch2-create-capsule'));
      expect((ground.decoration! as BoxDecoration).color, LoopColors.yellow);
      // Left of it, 我的项目.
      expect(tester.getCenter(mine).dx, lessThan(tester.getCenter(capsule).dx));
      await tester.tap(mine);
      expect(opened.last, Launch2CreatorRoute.minePath);
      await tester.tap(capsule);
      await tester.pumpAndSettle();
      expect(_key('launch2-create-chooser'), findsNothing);
      expect(opened.last, Launch2CreatorRoute.createPath);
      // The empty 预告 keeps its own 「我要发射」.
      await tester.tap(_key('launch2-desk-tab-upcoming'));
      await tester.pumpAndSettle();
      expect(_key('launch2-tile-${_id(2)}'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('no entry while launch2 is closed', (tester) async {
      await pumpS7Page(
        tester,
        Scaffold(
          body: Launch2CreatorActions(
            onNavigate: (_) {},
            classicCreatePath: '/meme/create',
          ),
        ),
        overrides: _overrides(_Gateway(_rows)),
      );
      expect(_key('launch2-create-action'), findsNothing);
      expect(find.byType(Launch2LaunchCapsule), findsNothing);
    });
  });

  group('the block grounds (第 16 条)', () {
    test('two levels: a block stands off the page, an inset off the block', () {
      expect(LoopColors.card, LoopColors.plate);
      expect(LoopColors.panel, LoopColors.plate);
      expect(LoopColors.card2, LoopColors.plateRaised);
      expect(LoopColors.input, LoopColors.plateRaised);
      double delta(Color a, Color b) =>
          <double>[
            (a.r - b.r).abs(),
            (a.g - b.g).abs(),
            (a.b - b.b).abs(),
          ].reduce((x, y) => x > y ? x : y) *
          255;
      // Visible on Ink, never a light grey.
      expect(delta(LoopColors.plate, LoopColors.ink), greaterThanOrEqualTo(15));
      expect(
        delta(LoopColors.plateRaised, LoopColors.plate),
        greaterThanOrEqualTo(10),
      );
      expect(LoopColors.plateRaised.computeLuminance(), lessThan(0.03));
      // Muted copy still reads on the raised ground.
      expect(
        loopContrastRatio(LoopColors.muted, LoopColors.plateRaised),
        greaterThan(4.5),
      );
      // The chat board is the same block, only just translucent.
      expect(loopChatBoardFill.withValues(alpha: 1), LoopColors.plate);
      expect(loopChatBoardFill.a, greaterThan(0.9));
    });

    testWidgets('a record group is one block on the plate; its rows take the '
        '16 inset', (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                LoopRecordGroup(
                  rows: <LoopRecordRow>[
                    LoopRecordRow(
                      key: const ValueKey<String>('row-a'),
                      title: '多因素验证',
                      onTap: () {},
                    ),
                    const LoopRecordRow(title: 'Passkey'),
                  ],
                ),
                const LoopRecordRow(
                  key: ValueKey<String>('row-alone'),
                  title: '单独一行',
                ),
              ],
            ),
          ),
        ),
      );
      final block = _key('loop-record-group-block');
      final ground = tester.widget<Container>(block);
      expect((ground.decoration! as BoxDecoration).color, LoopColors.plate);
      final face = find
          .descendant(of: block, matching: find.byType(DecoratedBox))
          .first;
      expect(tester.getRect(face).left, LoopSpacing.page);
      expect(tester.getRect(face).right, 390 - LoopSpacing.page);
      final title = tester.getTopLeft(find.text('多因素验证'));
      expect(title.dx, LoopSpacing.page + LoopSpacing.card);
      // A row outside a group keeps the page margin.
      expect(tester.getTopLeft(find.text('单独一行')).dx, LoopSpacing.page);
    });
  });
}

// S264 · MEME 主页氛围层 (client decision 0220): the wall, the numbered
// sections over boards, the chrome default avatar, the drip bar and the
// 预告 empty state with 「我要发射」.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';
import 'package:loop_mobile/widgets/loop_tab_strip.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _id(int n) => '8b9f3c1e-2d4a-4f6b-9c8d-${n.toString().padLeft(12, '0')}';

Map<String, Object?> _row(
  int n,
  String stage, {
  int soldBps = 0,
  String name = 'Frog Launch',
  String ticker = 'FROG',
}) => l2RowJson(
  instanceId: _id(n),
  stage: stage,
  soldBps: soldBps,
  name: name,
  ticker: ticker,
  noNextChange: stage == 'public' || stage == 'graduated',
);

final class _ListGateway implements Launch2Gateway {
  _ListGateway(this.page);

  final Launch2InstancePage page;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) => Future<Launch2InstancePage>.value(page);

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

Future<void> _pump(
  WidgetTester tester,
  List<Map<String, Object?>> rows, {
  List<String>? opened,
  String? tabTitle,
}) => pumpS7Page(
  tester,
  Scaffold(
    body: Launch2ListSegment(
      scope: Launch2ListScope.all,
      tabTitle: tabTitle,
      onNavigate: (location) => opened?.add(location),
    ),
  ),
  meta: _meta(),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(_ListGateway(l2Page(rows))),
    launch2ClockProvider.overrideWithValue(() => l2Now),
    launch2PollingProvider.overrideWithValue(
      const Launch2Polling(
        detailInterval: Duration(hours: 1),
        tradingInterval: Duration(hours: 1),
        listInterval: Duration(hours: 1),
      ),
    ),
    loopFeatureSwitchesProvider.overrideWithValue(
      const LoopFeatureSwitchValues(launch2Visible: true),
    ),
  ],
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

void main() {
  loopWatchGround();

  testWidgets('decision 0223: the main event page wears the banner art, '
      'at the banner height, its countdown not in the hand\'s corner', (
    tester,
  ) async {
    await _pump(tester, <Map<String, Object?>>[
      l2RowJson(instanceId: _id(1), stage: 'priority'),
    ], tabTitle: 'MEME');
    final page = _key('launch2-desk-page-${_id(1)}');
    expect(page, findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.byType(Launch2BannerBackdrop)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: _key('launch2-atmo-hand')),
      findsOneWidget,
    );
    final card = tester.getRect(page);
    expect(card.height, launch2DeskCampaignHeight);
    // S361 · decision 0286: the hand sits inside the card, not past it.
    final hand = tester.getRect(
      find.descendant(of: page, matching: _key('launch2-atmo-hand')),
    );
    expect(card.contains(hand.topLeft), isTrue);
    expect(hand.right, lessThanOrEqualTo(card.right));
    expect(hand.bottom, lessThanOrEqualTo(card.bottom));
    final countdown = tester.getRect(
      find.descendant(of: page, matching: _key('launch2-desk-event-countdown')),
    );
    expect(countdown.left, moreOrLessEquals(card.left + 20));
    expect(countdown.center.dx, lessThan(card.center.dx));
    await _drain(tester);
  });

  // S367 · decision 0291: the wall and the title crown are gone; the
  // backdrop is plain Ink and still does not scroll.
  testWidgets('the home stands on a plain Ink backdrop, no title crown', (
    tester,
  ) async {
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500),
    ], tabTitle: 'MEME');
    // The page's wall, and the same wall cut to the sticky bar's box.
    expect(_key('launch2-atmo-backdrop'), findsNWidgets(2));
    expect(_key('launch2-atmo-wall'), findsNWidgets(2));
    expect(_key('launch2-atmo-title-crown'), findsNothing);
    expect(
      tester.widget<ColoredBox>(_key('launch2-atmo-wall').first).color,
      LoopColors.ink,
    );
    expect(find.text('MEME'), findsOneWidget);
    // The wall does not scroll with the rows.
    final wall = tester.getRect(_key('launch2-atmo-backdrop').first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_key('launch2-atmo-backdrop').first), wall);
    await _drain(tester);
  });

  testWidgets('S279 · 0237: three tabs (S326: no index), one board at a '
      'time; a '
      'row without a logo wears the chrome medal; the bar drips past 0 and '
      'not at 0', (tester) async {
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500, name: '天才', ticker: 'TC'),
      _row(2, 'public', name: 'S234W', ticker: 'S234W'),
      _row(3, 'graduated', soldBps: 10000),
    ]);
    for (final (index, tab, title) in <(String, String, String)>[
      ('01', 'live', 'Bonding pool'),
      ('02', 'upcoming', 'Upcoming'),
      ('03', 'graduated', 'Graduated'),
    ]) {
      final key = _key('launch2-desk-tab-$tab');
      expect(key, findsOneWidget, reason: tab);
      // S326 · decision 0256: the 「01 / 02 / 03」 index is gone.
      expect(
        find.descendant(of: key, matching: find.text(index)),
        findsNothing,
      );
      expect(
        find.descendant(of: key, matching: find.text(title)),
        findsOneWidget,
      );
    }
    // No stacked numbered sections any more: one board, the chosen tab's.
    expect(find.byType(Launch2Board), findsOneWidget);
    expect(_key('launch2-board-live'), findsOneWidget);
    expect(_key('launch2-tile-${_id(3)}'), findsNothing);
    // Rows: S353b · decision 0279 (docs/58 §5.4) — 71 with the 1 px line
    // the board draws, the chrome medal, no letter tile.
    expect(tester.getSize(_key('launch2-row-${_id(1)}')).height, 70);
    expect(_key('launch2-avatar-chrome-${_id(1)}'), findsOneWidget);
    expect(_key('launch2-avatar-chrome-${_id(2)}'), findsOneWidget);
    expect(find.text('天才'), findsOneWidget);
    expect(find.text('TC'), findsOneWidget);
    // S353b · decision 0279 (docs/58 §5.4): the white 80 % bar on its 4
    // high track, 142 at most (it gives way first on a narrow row), filled
    // to the share sold; no drip any more.
    double fill(String id) => tester
        .widget<FractionallySizedBox>(
          find.descendant(
            of: _key('launch2-bar-$id'),
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .widthFactor!;
    final bar = tester.getRect(_key('launch2-bar-${_id(1)}'));
    expect(bar.width, lessThanOrEqualTo(Launch2ProgressBar.figmaWidth));
    expect(bar.height, Launch2ProgressBar.height);
    expect(fill(_id(1)), moreOrLessEquals(0.25));
    expect(_key('launch2-drip-${_id(1)}'), findsNothing);
    expect(_key('launch2-bar-${_id(2)}'), findsOneWidget);
    expect(fill(_id(2)), 0);
    await tester.tap(_key('launch2-desk-tab-graduated'));
    await tester.pumpAndSettle();
    expect(_key('launch2-board-graduated'), findsOneWidget);
    expect(_key('launch2-board-live'), findsNothing);
    expect(fill(_id(3)), 1);
    // 已毕业 is a light Purple word on Purple 18 %.
    final pill = tester.widget<Container>(
      find
          .descendant(
            of: _key('launch2-tile-${_id(3)}'),
            matching: _key('launch2-stage-pill-graduated'),
          )
          .first,
    );
    // Decision 0277: the Figma's tag ground, solid (`#290a3b`).
    expect((pill.decoration! as BoxDecoration).color, LoopColors.tagPurpleBg);
    await _drain(tester);
  });

  testWidgets('预告 with nothing queued: the grey crown, the sentence and '
      '「我要发射」 into the create flow', (tester) async {
    final opened = <String>[];
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500),
    ], opened: opened);
    expect(_key('launch2-upcoming-empty'), findsNothing);
    await tester.tap(_key('launch2-desk-tab-upcoming'));
    await tester.pumpAndSettle();
    expect(_key('launch2-upcoming-empty'), findsOneWidget);
    expect(_key('launch2-upcoming-empty-crown'), findsOneWidget);
    // S350b · decision 0275: the fact alone; 我要发射 is the invitation.
    expect(find.text('No projects in the queue yet'), findsOneWidget);
    await tester.ensureVisible(_key('launch2-upcoming-empty-launch'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(_key('launch2-upcoming-empty-launch')).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(_key('launch2-upcoming-empty-launch'));
    await tester.pump();
    expect(opened, <String>[Launch2CreatorRoute.createPath]);
    await _drain(tester);
  });

  testWidgets('a queued preview takes the 预告 board; no empty state', (
    tester,
  ) async {
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500),
      l2RowJson(
        instanceId: _id(2),
        stage: 'upcoming',
        nextChangeAt: l2Now.add(const Duration(days: 9)),
      ),
      l2RowJson(
        instanceId: _id(3),
        stage: 'upcoming',
        nextChangeAt: l2Now.add(const Duration(days: 10)),
      ),
    ]);
    // The nearest preview is the main event: the home opens on 预告, its
    // record card first and the next preview on the 预告 board.
    expect(_tabOn(tester, 'upcoming'), isTrue);
    expect(_key('launch2-upcoming-empty'), findsNothing);
    expect(_key('launch2-desk-record-${_id(2)}'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('launch2-board-upcoming'),
        matching: _key('launch2-tile-${_id(3)}'),
      ),
      findsOneWidget,
    );
    await _drain(tester);
  });

  testWidgets('a project with a logo keeps its logo; without one, the chrome '
      'medal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: <Widget>[
            Launch2ProjectAvatar(
              identity: 'a',
              logoUrl: 'https://media.example/logo.png',
            ),
            Launch2ProjectAvatar(identity: 'b'),
          ],
        ),
      ),
    );
    expect(_key('launch2-avatar-logo-a'), findsOneWidget);
    expect(
      tester.widget<LoopRemoteAvatar>(_key('launch2-avatar-logo-a')).url,
      'https://media.example/logo.png',
    );
    expect(_key('launch2-avatar-logo-b'), findsNothing);
    expect(_key('launch2-avatar-chrome-b'), findsOneWidget);
  });

  testWidgets('the chosen tab is white over the Yellow line (S353b)', (
    tester,
  ) async {
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500),
      _row(2, 'graduated', soldBps: 10000),
    ]);
    // No main event: the first tab holding projects is on. S353b · decision
    // 0279: no splat on it any more.
    expect(_tabOn(tester, 'live'), isTrue);
    expect(_tabOn(tester, 'graduated'), isFalse);
    expect(_key('launch2-desk-tab-splat-live'), findsNothing);
    expect(
      find.descendant(
        of: _key('launch2-desk-tab-live'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    // The cell and the strip's 2 + 2 make the 44 finger floor.
    expect(
      tester.getSize(find.byType(LoopTabStrip)).height,
      greaterThanOrEqualTo(44),
    );
    await _drain(tester);
  });
}

/// Whether the home's tab [id] reads as chosen.
bool _tabOn(WidgetTester tester, String id) =>
    tester
        .widget<Semantics>(
          find
              .descendant(
                of: _key('launch2-desk-tab-$id'),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties
        .selected ??
    false;

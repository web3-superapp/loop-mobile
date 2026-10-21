// S264 · MEME 主页氛围层 (client decision 0220): the wall, the numbered
// sections over boards, the chrome default avatar, the drip bar and the
// 预告 empty state with 「我要发射」.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
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
    final countdown = tester.getRect(
      find.descendant(of: page, matching: _key('launch2-desk-event-countdown')),
    );
    expect(countdown.left, moreOrLessEquals(card.left + 20));
    expect(countdown.center.dx, lessThan(card.center.dx));
    await _drain(tester);
  });

  testWidgets('the home stands on the wall with the crown behind its title', (
    tester,
  ) async {
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500),
    ], tabTitle: 'MEME');
    // The page's wall, and the same wall cut to the sticky bar's box.
    expect(_key('launch2-atmo-backdrop'), findsNWidgets(2));
    expect(_key('launch2-atmo-wall'), findsNWidgets(2));
    expect(_key('launch2-atmo-title-crown'), findsOneWidget);
    expect(find.text('MEME'), findsOneWidget);
    // The wall does not scroll with the rows.
    final wall = tester.getRect(_key('launch2-atmo-backdrop').first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_key('launch2-atmo-backdrop').first), wall);
    await _drain(tester);
  });

  testWidgets('numbered sections over boards; a row without a logo wears the '
      'chrome medal; the bar drips past 0 and not at 0', (tester) async {
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500, name: '天才', ticker: 'TC'),
      _row(2, 'public', name: 'S234W', ticker: 'S234W'),
      _row(3, 'graduated', soldBps: 10000),
    ]);
    for (final (index, group, title) in <(String, String, String)>[
      ('01', 'curve', '内盘'),
      ('02', 'upcoming', '预告'),
      ('03', 'graduated', '已毕业'),
    ]) {
      final heading = _key('launch2-group-$group');
      expect(heading, findsOneWidget, reason: group);
      expect(
        find.descendant(of: heading, matching: find.text(index)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heading, matching: find.text(title)),
        findsOneWidget,
      );
    }
    // Rows: 72 high, the chrome medal, no letter tile.
    expect(tester.getSize(_key('launch2-row-${_id(1)}')).height, 72);
    expect(_key('launch2-avatar-chrome-${_id(1)}'), findsOneWidget);
    expect(_key('launch2-avatar-chrome-${_id(2)}'), findsOneWidget);
    expect(find.text('天才'), findsOneWidget);
    expect(find.text('TC'), findsOneWidget);
    // The drip hangs at the end of a bar past 0, at 25 % of 96.
    final bar = tester.getRect(_key('launch2-bar-${_id(1)}'));
    final drip = tester.getRect(_key('launch2-drip-${_id(1)}'));
    expect(drip.left, moreOrLessEquals(bar.left + 96 * 0.25 - 3));
    expect(_key('launch2-bar-${_id(2)}'), findsOneWidget);
    expect(_key('launch2-drip-${_id(2)}'), findsNothing);
    expect(_key('launch2-drip-${_id(3)}'), findsOneWidget);
    // 已毕业 is a light Purple word on Purple 18 %.
    final pill = tester.widget<Container>(
      find
          .descendant(
            of: _key('launch2-tile-${_id(3)}'),
            matching: _key('launch2-stage-pill-graduated'),
          )
          .first,
    );
    expect((pill.decoration! as BoxDecoration).color, const Color(0x2E9C36FF));
    await _drain(tester);
  });

  testWidgets('预告 with nothing queued: the grey crown, the sentence and '
      '「我要发射」 into the create flow', (tester) async {
    final opened = <String>[];
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500),
    ], opened: opened);
    expect(_key('launch2-upcoming-empty'), findsOneWidget);
    expect(_key('launch2-upcoming-empty-crown'), findsOneWidget);
    expect(find.text('还没有排队中的项目，第一个发射的就是你'), findsOneWidget);
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
    // The nearest preview is the main event's record card; the next one
    // sits on the 预告 board.
    expect(_key('launch2-upcoming-empty'), findsNothing);
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

  testWidgets('the chosen stage chip carries the Yellow splat', (tester) async {
    await _pump(tester, <Map<String, Object?>>[
      _row(1, 'public', soldBps: 2500),
      _row(2, 'graduated', soldBps: 10000),
    ]);
    // No main event: the first chip holding projects is on.
    expect(_key('launch2-desk-seg-splat-curve'), findsOneWidget);
    expect(_key('launch2-desk-seg-splat-minting'), findsNothing);
    expect(find.text('内盘 1'), findsOneWidget);
    expect(
      tester.getSize(_key('launch2-desk-seg-curve')).height,
      greaterThanOrEqualTo(44),
    );
    await _drain(tester);
  });
}

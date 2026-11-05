// S361 · decision 0286 (docs/58 §5.5): the MEME banner's chrome hand, crown
// and 「IN THE LOOP」 tag all sit inside the 353 × 162 card; the banner's
// foot stands 16 above the trade band.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_shots.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment('LOOP_SHOTS_DIR');

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _id(int n) => '8b9f3c1e-2d4a-4f6b-9c8d-${n.toString().padLeft(12, '0')}';

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
  Size size = const Size(390, 2600),
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
  size: size,
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

  void expectInside(Rect card, Rect part) {
    expect(part.left, greaterThanOrEqualTo(card.left - 0.01));
    expect(part.top, greaterThanOrEqualTo(card.top - 0.01));
    expect(part.right, lessThanOrEqualTo(card.right + 0.01));
    expect(part.bottom, lessThanOrEqualTo(card.bottom + 0.01));
  }

  for (final width in <double>[360, 393]) {
    testWidgets('at $width wide the hand, crown and tag sit inside the card, '
        'the band 16 under it', (tester) async {
      await _pump(
        tester,
        <Map<String, Object?>>[
          l2RowJson(instanceId: _id(1), stage: 'priority'),
        ],
        tabTitle: 'MEME',
        size: Size(width, 800),
      );
      final page = _key('launch2-desk-page-${_id(1)}');
      expect(page, findsOneWidget);
      final card = tester.getRect(page);
      expect(card.height, launch2DeskCampaignHeight);
      for (final part in <String>[
        'launch2-atmo-hand',
        'launch2-banner-crown',
        'launch2-banner-tag',
      ]) {
        final rect = tester.getRect(
          find.descendant(of: page, matching: _key(part)),
        );
        expectInside(card, rect);
      }
      // The hand stands in the card's bottom right corner.
      final hand = tester.getRect(
        find.descendant(of: page, matching: _key('launch2-atmo-hand')),
      );
      expect(hand.right, moreOrLessEquals(card.right));
      expect(hand.bottom, moreOrLessEquals(card.bottom));
      // docs/58 §9: Banner → trade band, 16.
      final band = tester.getRect(_key('launch2-ticker-band'));
      expect(band.top - card.bottom, moreOrLessEquals(launch2DeskBandGap));
      expect(launch2DeskBandGap, 16);
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });
  }

  testWidgets('the default art clips everything to its 8 corner', (
    tester,
  ) async {
    await _pump(tester, <Map<String, Object?>>[
      l2RowJson(instanceId: _id(1), stage: 'priority'),
    ], tabTitle: 'MEME');
    final art = tester.widget(
      find.byKey(const ValueKey<String>('launch2-campaign-default-art')).first,
    );
    expect(art, isA<ClipRRect>());
    expect((art as ClipRRect).borderRadius, LoopRadius.chip);
    await _drain(tester);
  });

  for (final count in <int>[1, 2]) {
    testWidgets('shot · 360 MEME banner, $count page(s)', skip: !_shots, (
      tester,
    ) async {
      await tester.runAsync(loopLoadShotFonts);
      await _pump(
        tester,
        <Map<String, Object?>>[
          for (var n = 1; n <= count; n++)
            l2RowJson(instanceId: _id(n), stage: 'priority'),
        ],
        tabTitle: 'MEME',
        size: const Size(360, 800),
      );
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await tester.runAsync(() => precacheImage(image.image, element));
      }
      await tester.pump(const Duration(milliseconds: 100));
      await loopShot(tester, 'meme-banner-360-$count', dir: _dir);
      await _drain(tester);
    });
  }
}

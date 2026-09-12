import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';

/// The ground probe stopped being a test of eleven shared widgets and became a
/// property of every page the harnesses mount. What is pinned here is the
/// judgement it makes — because a rule nobody can state is a rule somebody
/// will relax by lowering a number.
Widget _wrap(Widget child) => MaterialApp(
  theme: LoopTheme.dark,
  home: Scaffold(backgroundColor: LoopColors.ink, body: child),
);

List<LoopPaintedColour> _probe(WidgetTester tester, {Color? ground}) =>
    loopProbeGround(
      tester.element(find.byType(Scaffold)),
      ground ?? LoopColors.ink,
    );

void main() {
  group('a control the application calls off may be quiet, not absent', () {
    testWidgets('a disabled label below the reading floor is not a finding', (
      tester,
    ) async {
      // `LoopButton` fades the whole control to 40% when `onPressed` is null,
      // so its Ink label lands on its own faded Lime at a contrast of 1.78.
      // That is the disabled look, and the application says so itself with
      // the `Semantics(enabled: false)` it publishes.
      await tester.pumpWidget(
        _wrap(const LoopButton(label: '保存', primary: true)),
      );
      await tester.pump();

      final probes = _probe(tester);
      final label = probes.firstWhere(
        (probe) => probe.kind == 'text' && probe.where.contains('保存'),
      );
      expect(label.inactive, isTrue);
      expect(label.contrast, lessThan(2.5));
      expect(label.groundDelta, greaterThan(3));
      expect(loopVanishedPaint(probes), isEmpty);
    });

    testWidgets('the same label on an enabled control keeps the floor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(LoopButton(label: '保存', primary: true, onPressed: () {})),
      );
      await tester.pump();

      final label = _probe(tester).firstWhere(
        (probe) => probe.kind == 'text' && probe.where.contains('保存'),
      );
      expect(label.inactive, isFalse);
      expect(label.contrast, greaterThan(2.5));
    });

    testWidgets('a disabled label that is Chalk on Chalk is still a finding', (
      tester,
    ) async {
      // The exemption is "quiet", never "gone": this is the shipped bug put
      // inside a control the application calls off, and it still has to fail.
      await tester.pumpWidget(
        _wrap(
          Semantics(
            button: true,
            enabled: false,
            child: const LoopChalkCard(
              child: Text('未配置', style: TextStyle(color: LoopColors.chalk)),
            ),
          ),
        ),
      );
      await tester.pump();

      final vanished = loopVanishedPaint(_probe(tester));
      expect(vanished, hasLength(1));
      expect(vanished.single.inactive, isTrue);
      expect(vanished.single.where, contains('未配置'));
      expect(vanished.single.groundDelta, lessThan(1));
    });
  });

  group('a border in the box own fill is the box having no border', () {
    testWidgets('a Lime edge on a Lime card is not reported', (tester) async {
      // `_DiscoverHero` asks for a solid Lime card by naming Lime for both.
      // There is no edge to lose, so there is nothing to report.
      await tester.pumpWidget(
        _wrap(
          const LoopSurfaceCard(
            background: LoopColors.lime,
            borderColor: LoopColors.lime,
            child: SizedBox(height: 20),
          ),
        ),
      );
      await tester.pump();

      expect(_probe(tester).where((probe) => probe.kind == 'edge'), isEmpty);
      expect(loopVanishedPaint(_probe(tester)), isEmpty);
    });

    testWidgets('an edge in another colour that moves nothing is reported', (
      tester,
    ) async {
      // Same zero delta, different claim: this one asked for an edge.
      await tester.pumpWidget(
        _wrap(
          const LoopSurfaceCard(
            background: LoopColors.lime,
            borderColor: Color(0x01B8FF20),
            child: SizedBox(height: 20),
          ),
        ),
      );
      await tester.pump();

      final vanished = loopVanishedPaint(_probe(tester));
      expect(vanished, hasLength(1));
      expect(vanished.single.kind, 'edge');
    });
  });

  group('the exempt sites are named, and nothing else is', () {
    test('every exemption states a reason', () {
      expect(loopGroundProbeExemptions, isNotEmpty);
      for (final entry in loopGroundProbeExemptions.entries) {
        expect(entry.key, contains(' · '), reason: 'an exemption names a site');
        expect(entry.value.length, greaterThan(40), reason: entry.key);
      }
    });

    testWidgets('the sticky dock restates the page and is exempt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Align(
            alignment: Alignment.bottomCenter,
            child: LoopActionDock(child: SizedBox(height: 20)),
          ),
        ),
      );
      await tester.pump();

      final dock = _probe(tester)
          .firstWhere((probe) => probe.site == 'LoopActionDock · DecoratedBox');
      expect(dock.groundDelta, lessThan(1));
      expect(loopVanishedPaint(_probe(tester)), isEmpty);
      // The same fill anywhere else is still a finding: the exemption is one
      // site, not one colour.
      expect(
        loopVanishedPaint(<LoopPaintedColour>[
          LoopPaintedColour(
            colour: dock.colour,
            ground: dock.ground,
            kind: 'fill',
            where: 'SomeScreen · DecoratedBox',
            site: 'SomeScreen · DecoratedBox',
          ),
        ]),
        hasLength(1),
      );
    });
  });

  group('the armed probe watches a real page, not a fixture', () {
    // The harness arms the probe for these pages the way it does for every
    // other one; what is asserted here is the premise that makes that worth
    // anything — a page test really does render the Chalk and Lime grounds,
    // and not only the Ink page on which none of these bugs is visible.
    Set<int> groundsOf(WidgetTester tester, Finder page) => loopProbeGround(
      tester.element(page),
      LoopColors.ink,
    ).map((probe) => probe.ground.toARGB32()).toSet();

    testWidgets('the Market page opens on a Lime folio', (tester) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      expect(
        groundsOf(tester, find.byType(MarketScreen)),
        contains(LoopColors.lime.toARGB32()),
      );
    });

    testWidgets('the Receive page puts the address on a Chalk card', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(
        groundsOf(tester, find.byType(ReceiveScreen)),
        contains(LoopColors.chalk.toARGB32()),
      );
    });
  });
}

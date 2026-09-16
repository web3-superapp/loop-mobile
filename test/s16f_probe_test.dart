import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
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
      // Ink at 40% on Lime is a contrast of 1.78, under the reading floor.
      // The judgement being pinned is the probe's, so the case is built here:
      // `LoopButton` used to paint a disabled primary exactly like this, and
      // 自选管理's 保存 was read off the device as a button in a strange
      // colour rather than one that is off.
      await tester.pumpWidget(
        _wrap(
          Semantics(
            button: true,
            enabled: false,
            child: Opacity(
              opacity: 0.4,
              child: Container(
                color: LoopColors.lime,
                padding: const EdgeInsets.all(12),
                child: const Text(
                  '保存',
                  style: TextStyle(color: LoopColors.ink),
                ),
              ),
            ),
          ),
        ),
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

    testWidgets('a disabled primary keeps its own label readable', (
      tester,
    ) async {
      // Being exempt from the floor is not a reason to sit under it: the
      // disabled primary keeps the button's shape, drops the Lime fill and
      // says 「off」 through the semantics it publishes.
      await tester.pumpWidget(
        _wrap(const LoopButton(label: '保存', primary: true)),
      );
      await tester.pump();

      final probes = _probe(tester);
      final label = probes.firstWhere(
        (probe) => probe.kind == 'text' && probe.where.contains('保存'),
      );
      expect(label.inactive, isTrue);
      expect(label.contrast, greaterThan(2.5));
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

  group('paint the walk cannot see is still paint', () {
    testWidgets('a Badge label is judged on the pill the Badge draws', (
      tester,
    ) async {
      // `Badge` draws its pill inside its own render object, so the walk sees
      // no box for it. Before the probe read the declared colour, the label
      // was judged against whatever happened to be behind the badge — here
      // the Ink page, on which Ink text is invisible and the finding was
      // pure invention.
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: Badge(
              backgroundColor: LoopColors.lime,
              textColor: LoopColors.ink,
              label: Text('9'),
              child: SizedBox.square(dimension: 24),
            ),
          ),
        ),
      );
      await tester.pump();

      final probes = _probe(tester);
      final label = probes.firstWhere(
        (probe) => probe.kind == 'text' && probe.where.contains('9'),
      );
      expect(label.ground, LoopColors.lime);
      expect(label.contrast, greaterThan(2.5));
      expect(loopVanishedPaint(probes), isEmpty);
    });

    testWidgets('a Badge that really is invisible is still a finding', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Center(
            child: Badge(
              backgroundColor: LoopColors.lime,
              textColor: LoopColors.lime,
              label: Text('9'),
              child: SizedBox.square(dimension: 24),
            ),
          ),
        ),
      );
      await tester.pump();

      final vanished = loopVanishedPaint(_probe(tester));
      expect(vanished, hasLength(1));
      expect(vanished.single.where, contains('9'));
      expect(vanished.single.ground, LoopColors.lime);
    });
  });

  group('a seam is declared where it is drawn', () {
    // The probe carries the tree, not the geometry, so it cannot see that a
    // ring around one of three stacked avatars lies half on the avatar behind
    // it. `LoopSeam` is the call site saying so. What is pinned here is how
    // far that claim reaches: one border, on the box the seam draws, once.
    const seamOnItsCard = LoopSeam(
      colour: LoopColors.basalt,
      child: SizedBox.square(dimension: 32),
    );
    final undeclaredRing = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: LoopColors.basalt, width: 2),
      ),
      child: const SizedBox.square(dimension: 32),
    );

    testWidgets('the ring that continues the card reports nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoopCard(child: seamOnItsCard)));
      await tester.pump();

      expect(loopVanishedPaint(_probe(tester)), isEmpty);
    });

    testWidgets('the same ring undeclared is a finding', (tester) async {
      // The control: nothing about the colour or the geometry changed, only
      // whether the call site claimed it. Without the claim the probe reads
      // basalt on the card's own basalt-at-94% and says the mark is not there.
      await tester.pumpWidget(_wrap(LoopCard(child: undeclaredRing)));
      await tester.pump();

      final vanished = loopVanishedPaint(_probe(tester));
      expect(vanished, hasLength(1));
      expect(vanished.single.kind, 'edge');
      expect(vanished.single.groundDelta, lessThan(3));
    });

    testWidgets('a divider beside the seam, on the same card, still fails', (
      tester,
    ) async {
      // The question a claim has to answer: can the next person draw a line
      // nobody can see on this card and have it pass because a seam is
      // declared somewhere above? No.
      await tester.pumpWidget(
        _wrap(
          LoopCard(
            child: Column(children: <Widget>[seamOnItsCard, undeclaredRing]),
          ),
        ),
      );
      await tester.pump();

      expect(loopVanishedPaint(_probe(tester)), hasLength(1));
    });

    testWidgets('a second border under the same seam is judged as usual', (
      tester,
    ) async {
      // The claim is spent by the border it was made about, so it does not
      // become a licence for the subtree hanging off it.
      await tester.pumpWidget(
        _wrap(
          LoopCard(
            child: LoopSeam(colour: LoopColors.basalt, child: undeclaredRing),
          ),
        ),
      );
      await tester.pump();

      expect(loopVanishedPaint(_probe(tester)), hasLength(1));
    });
  });

  group('a frame between two states is not a state', () {
    // `Material` hands its subtree's copy down through an
    // `AnimatedDefaultTextStyle` and its own colour down as a plain field, so
    // for the 200ms a button takes to change state the walk used to read the
    // colour the copy is leaving on the ground it is arriving at. Both ends
    // of that transition are fine; the middle is an artefact of reading one
    // end of it and not the other.
    Future<void> pumpButton(WidgetTester tester, {required bool enabled}) =>
        tester.pumpWidget(
          _wrap(
            Center(
              child: FilledButton(
                onPressed: enabled ? () {} : null,
                child: const Text('搜索'),
              ),
            ),
          ),
        );

    LoopPaintedColour labelOf(WidgetTester tester) => _probe(
      tester,
    ).firstWhere((probe) => probe.kind == 'text' && probe.where.contains('搜索'));

    testWidgets('both settled ends of an enable are read', (tester) async {
      await pumpButton(tester, enabled: false);
      await tester.pumpAndSettle();
      final off = labelOf(tester);
      expect(off.colour.a, closeTo(0.38, 0.01), reason: 'the disabled label');
      expect(off.contrast, greaterThan(2.5));

      await pumpButton(tester, enabled: true);
      await tester.pumpAndSettle();
      final on = labelOf(tester);
      expect(on.ground, LoopColors.lime);
      expect(on.colour, LoopColors.ink);
      expect(loopVanishedPaint(_probe(tester)), isEmpty);
    });

    testWidgets('the frames in between report nothing', (tester) async {
      await pumpButton(tester, enabled: false);
      await tester.pumpAndSettle();
      await pumpButton(tester, enabled: true);

      // One frame in, the ground is already the Lime the button is arriving
      // at. The label has to be read from the same end of the transition.
      await tester.pump();
      expect(labelOf(tester).ground, LoopColors.lime);
      expect(labelOf(tester).colour, LoopColors.ink);
      expect(loopVanishedPaint(_probe(tester)), isEmpty);

      await tester.pump(const Duration(milliseconds: 100));
      expect(loopVanishedPaint(_probe(tester)), isEmpty);

      await tester.pumpAndSettle();
      expect(loopVanishedPaint(_probe(tester)), isEmpty);
    });

    testWidgets('a label that states its own vanishing colour still fails', (
      tester,
    ) async {
      // The suppression is "read the declared state", never "skip text under
      // a Material": a colour the widget asks for itself is still judged.
      await tester.pumpWidget(
        _wrap(
          Center(
            child: FilledButton(
              onPressed: () {},
              child: const Text('搜索', style: TextStyle(color: LoopColors.lime)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vanished = loopVanishedPaint(_probe(tester));
      expect(vanished, hasLength(1));
      expect(vanished.single.where, contains('搜索'));
      expect(vanished.single.ground, LoopColors.lime);
    });
  });

  group('every generated avatar disc can carry its own monogram', () {
    // The fan-out's other finding: `ChatAvatar` builds its disc from one of
    // eight fixed hues and paints Chalk initials on it, and three of the eight
    // are lighter than Chalk. On a real inbox that is a name nobody can read,
    // not a fixture artefact — the seed is the conversation's, and every
    // account whose seed lands on Lime, the pale green or the amber got it.
    for (final ground in <Color>[LoopColors.ink, LoopColors.chalk]) {
      testWidgets('on ${ground == LoopColors.ink ? 'Ink' : 'Chalk'}', (
        tester,
      ) async {
        for (var seed = 0; seed < 8; seed++) {
          await tester.pumpWidget(
            MaterialApp(
              theme: LoopTheme.dark,
              home: Scaffold(
                backgroundColor: ground,
                body: DefaultTextStyle(
                  style: TextStyle(
                    color: ground == LoopColors.ink
                        ? LoopColors.chalk
                        : LoopColors.ink,
                  ),
                  child: Center(
                    child: ChatAvatar(label: 'Nova Onchain', colorSeed: seed),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final probes = loopProbeGround(
            tester.element(find.byType(ChatAvatar)),
            ground,
          );
          final monogram = probes.firstWhere(
            (probe) => probe.kind == 'text' && probe.where.contains('NO'),
          );
          expect(
            monogram.contrast,
            greaterThanOrEqualTo(2.5),
            reason: 'seed $seed on ${_hexOf(ground)}: $monogram',
          );
          expect(loopVanishedPaint(probes), isEmpty, reason: 'seed $seed');

          // A seed that already cleared the floor comes back untouched, so
          // the discs that were never the bug keep exactly the colour they
          // had. On Ink that is the violet, the pink and the lilac.
          if (ground == LoopColors.ink && const <int>[3, 4, 7].contains(seed)) {
            final disc = probes.firstWhere((probe) => probe.kind == 'fill');
            expect(
              disc.colour.withValues(alpha: 1).toARGB32(),
              const <int>[
                0xFF68B9FF,
                0xFFF2B562,
                0xFFB8FF20,
                0xFF8D82FF,
                0xFFFF7E9B,
                0xFF57C8D5,
                0xFFB3D66E,
                0xFFB993FF,
              ][seed],
              reason: 'seed $seed was already dark enough',
            );
          }
        }
      });
    }
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

String _hexOf(Color colour) =>
    '#${colour.toARGB32().toRadixString(16).padLeft(8, '0')}';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// `.ledger-card::before` — the dot texture, asserted as parameters rather
/// than as a golden image.
///
/// The prototype declares it as a masked radial-gradient grid:
///
/// ```css
/// .ledger-card::before{
///   opacity:.24;
///   background-image:radial-gradient(rgba(5,6,4,.7) 1px,transparent 1px);
///   background-size:9px 9px;
///   mask-image:linear-gradient(105deg,transparent 28%,var(--ink))
/// }
/// ```
///
/// Every number below is read straight off that rule, so a change to the
/// implementation that drifts from the frozen style sheet fails here.
void main() {
  group('the texture matches the frozen CSS', () {
    test('grid, dot and mask parameters', () {
      expect(LoopLedgerTexture.spacing, 9);
      expect(LoopLedgerTexture.dotRadius, 1);
      expect(LoopLedgerTexture.maskAngleDegrees, 105);
      expect(LoopLedgerTexture.maskTransparentStop, 0.28);

      // Ink at 70% under a 24% layer; Lime at 50% under a 12% layer.
      expect(LoopLedgerTexture.primary.dotColor, LoopColors.ink);
      expect(LoopLedgerTexture.primary.dotAlpha, 0.7);
      expect(LoopLedgerTexture.primary.layerOpacity, 0.24);
      expect(LoopLedgerTexture.primary.effectiveAlpha, closeTo(0.168, 1e-9));

      expect(LoopLedgerTexture.quiet.dotColor, LoopColors.lime);
      expect(LoopLedgerTexture.quiet.dotAlpha, 0.5);
      expect(LoopLedgerTexture.quiet.layerOpacity, 0.12);
      expect(LoopLedgerTexture.quiet.effectiveAlpha, closeTo(0.06, 1e-9));

      // The texture is a hint, not a surface: even the strongest dot stays
      // far below the card's own contrast.
      expect(LoopLedgerTexture.primary.effectiveAlpha, lessThan(0.2));
      expect(LoopLedgerTexture.quiet.effectiveAlpha, lessThan(0.2));
    });

    test('the grid starts half a cell in and repeats every 9px', () {
      const size = Size(27, 18);
      final centers = LoopLedgerTexture.dotCenters(size);

      expect(centers, hasLength(6));
      expect(centers.first, const Offset(4.5, 4.5));
      expect(centers[1], const Offset(13.5, 4.5));
      expect(centers[3], const Offset(4.5, 13.5));
      for (final center in centers) {
        expect(center.dx, lessThan(size.width));
        expect(center.dy, lessThan(size.height));
      }
      expect(LoopLedgerTexture.dotCenters(Size.zero), isEmpty);
    });

    test(
      'the 105deg mask hides the leading corner and fills the trailing one',
      () {
        const size = Size(200, 120);

        // The gradient runs right and slightly down, so the top-left corner is
        // inside the transparent 28% and the bottom-right is fully opaque.
        expect(LoopLedgerTexture.maskFactor(Offset.zero, size), 0);
        expect(
          LoopLedgerTexture.maskFactor(Offset(size.width, size.height), size),
          closeTo(1, 1e-9),
        );
        // The centre sits exactly halfway along the gradient line.
        expect(
          LoopLedgerTexture.maskPosition(
            Offset(size.width / 2, size.height / 2),
            size,
          ),
          closeTo(0.5, 1e-9),
        );
        // The ramp is monotonic from the stop to the end.
        var previous = 0.0;
        for (var step = 0; step <= 10; step++) {
          final factor = LoopLedgerTexture.maskFactor(
            Offset(size.width * step / 10, size.height * step / 10),
            size,
          );
          expect(factor, greaterThanOrEqualTo(previous));
          previous = factor;
        }
        // A degenerate box never divides by zero.
        expect(LoopLedgerTexture.maskFactor(Offset.zero, Size.zero), 0);
      },
    );
  });

  group('the card mounts the texture', () {
    testWidgets('both variants paint their own spec', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                LoopLedgerCard(child: Text('primary')),
                LoopLedgerCard(quiet: true, child: Text('quiet')),
              ],
            ),
          ),
        ),
      );

      expect(
        _painterOf(tester, 'loop-ledger-texture').spec,
        LoopLedgerTexture.primary,
      );
      expect(
        _painterOf(tester, 'loop-ledger-quiet-texture').spec,
        LoopLedgerTexture.quiet,
      );
    });

    testWidgets('reduced motion changes nothing: it is painted, not animated', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: LoopLedgerCard(child: Text('primary'))),
          ),
        ),
      );

      final painter = _painterOf(tester, 'loop-ledger-texture');
      expect(painter.spec, LoopLedgerTexture.primary);
      // Nothing in the painter depends on time or on an animation controller,
      // so it repaints only when its own spec changes.
      expect(painter.shouldRepaint(painter), isFalse);
      expect(
        painter.shouldRepaint(
          const LoopLedgerTexturePainter(spec: LoopLedgerTexture.quiet),
        ),
        isTrue,
      );
    });
  });
}

LoopLedgerTexturePainter _painterOf(WidgetTester tester, String key) {
  final paint = tester.widget<CustomPaint>(find.byKey(ValueKey<String>(key)));
  return paint.painter! as LoopLedgerTexturePainter;
}

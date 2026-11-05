// S361: the feedback key sits beside the Scaffold, outside any Material.
// Without a Material of its own its label inherited MaterialApp's fallback
// text style and the device drew a double underline under 「Feedback」.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_entry.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

const _entry = ValueKey<String>('beta-feedback-entry');

void main() {
  testWidgets('the label carries no underline outside a Material', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loopFeatureSwitchesProvider.overrideWithValue(
            const LoopFeatureSwitchValues(betaFeedbackVisible: true),
          ),
          loopSessionProvider.overrideWith(_SignedIn.new),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark,
          // No Scaffold and no Material: exactly how the shell mounts it.
          home: Stack(
            children: <Widget>[
              Positioned.fill(
                child: BetaFeedbackEntry(
                  location: '/meme',
                  lowestBottom: 100,
                  floorLift: 0,
                  onOpen: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(of: find.byKey(_entry), matching: find.byType(Material)),
      findsNothing,
      reason: 'the shell gives the entry no Material of its own',
    );
    final label = tester.widget<RichText>(
      find.descendant(of: find.byKey(_entry), matching: find.byType(RichText)),
    );
    final style = label.text.style!;
    expect(style.decoration, anyOf(isNull, TextDecoration.none));
    expect(style.decorationStyle, isNot(TextDecorationStyle.double));
    expect(style.fontSize, 10);
  });
}

class _SignedIn extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );
}

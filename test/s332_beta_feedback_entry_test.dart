import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/navigation/loop_routing_error_log.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_controllers.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_entry.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_screen.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';

const _entry = ValueKey<String>('beta-feedback-entry');
const _on = LoopFeatureSwitchValues(betaFeedbackVisible: true);

void main() {
  loopWatchGround();

  group('switch', () {
    test('off unless the build passes LOOP_BETA_FEEDBACK=true', () {
      expect(AppConfig.betaFeedbackDefine, isFalse);
      expect(LoopFeatureSwitches.betaFeedbackVisible, isFalse);
      expect(const LoopFeatureSwitchValues().betaFeedbackVisible, isFalse);
    });

    test('Development and staging turn it on; the release template not', () {
      Map<String, Object?> read(String path) =>
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      expect(read('config/debug.json')['LOOP_BETA_FEEDBACK'], 'true');
      expect(read('config/staging.json')['LOOP_BETA_FEEDBACK'], 'true');
      expect(
        read('config/release.example.json')['LOOP_BETA_FEEDBACK'],
        'false',
      );
    });

    test('the entry needs the switch and a session that may enter', () {
      bool visible({
        required LoopFeatureSwitchValues switches,
        required LoopSessionController Function() session,
      }) {
        final container = ProviderContainer(
          overrides: [
            loopFeatureSwitchesProvider.overrideWithValue(switches),
            loopSessionProvider.overrideWith(session),
          ],
        );
        addTearDown(container.dispose);
        return container.read(betaFeedbackEntryVisibleProvider);
      }

      expect(visible(switches: _on, session: _SignedIn.new), isTrue);
      expect(
        visible(
          switches: const LoopFeatureSwitchValues(),
          session: _SignedIn.new,
        ),
        isFalse,
      );
      expect(visible(switches: _on, session: _SignedOut.new), isFalse);
    });

    test('both pages are in the manifest', () {
      expect(LoopRouteManifest.pathFor('beta-feedback'), '/beta-feedback');
      expect(
        LoopRouteManifest.pathFor('beta-feedback-mine'),
        '/beta-feedback/mine',
      );
      expect(
        LoopRouteManifest.bySlug('beta-feedback').status,
        LoopRouteStatus.implemented,
      );
    });
  });

  group('floating entry', () {
    Future<List<BetaFeedbackOrigin>> pumpEntry(
      WidgetTester tester, {
      bool reduceMotion = false,
      double keyboard = 0,
      double floorLift = 0,
      ValueNotifier<bool>? shown,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      loopArmGroundProbe(tester);
      final opened = <BetaFeedbackOrigin>[];
      final visible = shown ?? ValueNotifier<bool>(true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopFeatureSwitchesProvider.overrideWithValue(_on),
            loopSessionProvider.overrideWith(_SignedIn.new),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduceMotion,
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: child!,
            ),
            // No Scaffold: in the shell the entry sits over it, where the
            // keyboard's inset is still visible.
            home: Material(
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (context, show, _) => Stack(
                  children: <Widget>[
                    if (show)
                      Positioned.fill(
                        child: BetaFeedbackEntry(
                          location: '/meme',
                          lowestBottom: 100,
                          floorLift: floorLift,
                          onOpen: opened.add,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    Rect target(WidgetTester tester) => tester.getRect(find.byKey(_entry));

    testWidgets('a 56 Yellow key on the right edge, glyph and word, tappable', (
      tester,
    ) async {
      final opened = await pumpEntry(tester);
      expect(target(tester).right, 390 - LoopSpacing.page);
      expect(target(tester).bottom, 844 - 100);
      expect(target(tester).size, const Size(56, 56));
      const keyFinder = ValueKey<String>('beta-feedback-entry-key');
      expect(tester.getSize(find.byKey(keyFinder)), const Size(56, 56));
      final box = tester.widget<Container>(find.byKey(keyFinder));
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, LoopColors.yellow);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
      expect(decoration.boxShadow, const <BoxShadow>[
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ]);
      expect(find.byType(BackdropFilter), findsNothing);
      final glyph = tester.widget<LoopIcon>(
        find.descendant(
          of: find.byKey(keyFinder),
          matching: find.byType(LoopIcon),
        ),
      );
      expect(glyph.name, 'feedback');
      expect(glyph.size, 22);
      expect(glyph.color, LoopColors.ink);
      final word = tester.widget<Text>(
        find.descendant(of: find.byKey(keyFinder), matching: find.byType(Text)),
      );
      expect(word.data, 'Feedback');
      expect(word.style?.fontSize, 10);
      expect(word.style?.fontWeight, FontWeight.w600);
      expect(word.style?.color, LoopColors.ink);
      // Glyph over word, both inside the key.
      final glyphRect = tester.getRect(find.byType(LoopIcon));
      final wordRect = tester.getRect(find.text('Feedback'));
      expect(glyphRect.bottom, lessThanOrEqualTo(wordRect.top));
      expect(target(tester).contains(glyphRect.center), isTrue);
      expect(wordRect.left, greaterThanOrEqualTo(target(tester).left));
      expect(wordRect.right, lessThanOrEqualTo(target(tester).right));
      expect(find.bySemanticsLabel('Feedback'), findsOneWidget);
      expect(find.bySemanticsLabel('内测反馈'), findsNothing);

      await tester.tap(find.byKey(_entry));
      expect(opened.single.route, '/meme');
      expect(opened.single.locale, isNotEmpty);
    });

    testWidgets('a floor lift raises the default place and the lowest drag', (
      tester,
    ) async {
      await pumpEntry(tester, floorLift: 68);
      expect(target(tester).bottom, 844 - 100 - 68);
      await tester.drag(find.byKey(_entry), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(target(tester).bottom, 844 - 100 - 68);
      final gesture = await tester.startGesture(target(tester).center);
      await gesture.moveBy(const Offset(0, -100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(target(tester).bottom, closeTo(844 - 100 - 168, 0.5));
    });

    testWidgets('drags anywhere, snaps back to the right edge, keeps height', (
      tester,
    ) async {
      final shown = ValueNotifier<bool>(true);
      await pumpEntry(tester, shown: shown);
      final gesture = await tester.startGesture(target(tester).center);
      await gesture.moveBy(const Offset(-50, -100));
      await gesture.moveBy(const Offset(-50, -100));
      await tester.pump();
      expect(target(tester).right, closeTo(390 - 20 - 100, 0.5));
      expect(target(tester).bottom, closeTo(744 - 200, 0.5));

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Mid-slide: on its way back, not there yet.
      expect(target(tester).right, greaterThan(390 - 20 - 100));
      expect(target(tester).right, lessThan(390 - 20));
      await tester.pumpAndSettle();
      expect(target(tester).right, 390 - 20);
      expect(target(tester).bottom, closeTo(744 - 200, 0.5));

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(_entry)),
      );
      expect(container.read(betaFeedbackEntryLiftProvider), closeTo(200, 0.5));

      // Gone and back within the run: the same height.
      shown.value = false;
      await tester.pump();
      expect(find.byKey(_entry), findsNothing);
      shown.value = true;
      await tester.pump();
      expect(target(tester).bottom, closeTo(744 - 200, 0.5));
    });

    testWidgets('never below its default place, never over the tab bar', (
      tester,
    ) async {
      await pumpEntry(tester);
      await tester.drag(find.byKey(_entry), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(target(tester).bottom, 744);
    });

    testWidgets('under reduced motion it jumps back', (tester) async {
      await pumpEntry(tester, reduceMotion: true);
      final gesture = await tester.startGesture(target(tester).center);
      await gesture.moveBy(const Offset(-120, -40));
      await tester.pump();
      expect(target(tester).right, closeTo(390 - 20 - 120, 0.5));
      await gesture.up();
      await tester.pump();
      expect(target(tester).right, 390 - 20);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('steps aside while the keyboard is up', (tester) async {
      await pumpEntry(tester, keyboard: 300);
      expect(find.byKey(_entry), findsNothing);
    });
  });

  group('in the application', () {
    Future<GoRouter> pumpApp(
      WidgetTester tester, {
      required LoopFeatureSwitchValues switches,
      LoopRoutingErrorLog? routingErrors,
    }) async {
      loopArmGroundProbe(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
            hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
              const _EmptySpotMarketRepository(),
            ),
            loopFeatureSwitchesProvider.overrideWithValue(switches),
            if (routingErrors != null)
              loopRoutingErrorLogProvider.overrideWithValue(routingErrors),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();
      return GoRouter.of(tester.element(find.byType(MemeScreen)));
    }

    testWidgets('switch off: no entry, and both pages are unknown', (
      tester,
    ) async {
      final routingErrors = LoopRoutingErrorLog();
      final router = await pumpApp(
        tester,
        switches: const LoopFeatureSwitchValues(),
        routingErrors: routingErrors,
      );
      expect(find.byType(LoopTabBar), findsOneWidget);
      expect(find.byKey(_entry), findsNothing);

      for (final location in <String>[
        '/beta-feedback',
        '/beta-feedback/mine',
      ]) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/meme');
        expect(routingErrors.last?.location, location);
      }
      expect(find.byType(BetaFeedbackScreen), findsNothing);
    });

    testWidgets(
      'switch on: on every tab, above the bar, under every pushed page',
      (tester) async {
        final router = await pumpApp(tester, switches: _on);
        for (final path in LoopRouteManifest.tabPaths) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(find.byKey(_entry), findsOneWidget, reason: path);
        }
        router.go('/meme');
        await tester.pumpAndSettle();

        final capsule = tester.getRect(
          find.byKey(const ValueKey<String>('beta-feedback-entry-key')),
        );
        final bar = tester.getRect(
          find.byKey(const ValueKey<String>('loop-tab-bar-float')),
        );
        expect(capsule.bottom, lessThanOrEqualTo(bar.top - 12));
        expect(capsule.right, closeTo(800 - LoopSpacing.page, 0.5));

        // 聊天: S343 · decision 0271 moved 「发起」 to the bar's 「＋」; the
        // entry stays clear of it.
        router.go('/chat');
        await tester.pumpAndSettle();
        final create = tester.getRect(
          find.byKey(const ValueKey<String>('chat-create-menu')),
        );
        final onChat = tester.getRect(
          find.byKey(const ValueKey<String>('beta-feedback-entry-key')),
        );
        expect(onChat.overlaps(create), isFalse);
        router.go('/meme');
        await tester.pumpAndSettle();

        unawaited(router.push('/profile/settings'));
        await tester.pumpAndSettle();
        expect(find.byKey(_entry), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byKey(_entry), findsOneWidget);

        await tester.tap(find.byKey(_entry));
        await tester.pumpAndSettle();
        expect(find.byType(BetaFeedbackScreen), findsOneWidget);
        expect(find.byKey(_entry), findsNothing);
        // S337 · decision 0266: the page says 意见反馈, never 内测反馈.
        expect(find.textContaining('Feedback'), findsWidgets);
        expect(find.textContaining('内测反馈'), findsNothing);
        expect(
          GoRouterState.of(tester.element(find.byType(BetaFeedbackScreen)))
              .uri
              .path,
          '/beta-feedback',
        );
        // No adapter in this composition: the page says so.
        expect(
          find.byKey(const ValueKey<String>('beta-feedback-unavailable')),
          findsOneWidget,
        );
        final screen = tester.widget<BetaFeedbackScreen>(
          find.byType(BetaFeedbackScreen),
        );
        expect(screen.origin.route, '/meme');
      },
    );
  });
}

class _SignedIn extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );
}

class _SignedOut extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState.signedOut();
}

final class _EmptySpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  const _EmptySpotMarketRepository();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    return HyperliquidSpotSnapshot(
      receivedAt: DateTime.utc(2026, 11, 2),
      markets: const <HyperliquidSpotMarket>[],
    );
  }
}

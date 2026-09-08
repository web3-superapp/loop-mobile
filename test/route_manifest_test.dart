import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/loop_routing_error_log.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/features/shell/loop_pending_surface.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  group('manifest table', () {
    late Map<String, Object?> json;

    setUpAll(() {
      json = jsonDecode(
        File('docs/product/routes-manifest.json').readAsStringSync(),
      ) as Map<String, Object?>;
    });

    test(
      'Dart table mirrors routes-manifest.json slug, module, tab and order',
      () {
        expect(json['count'], 93);
        expect(json['defaultRoute'], LoopRouteManifest.defaultSlug);
        expect(json['tabs'], LoopRouteManifest.tabSlugs);
        expect(json['frozenAt'], LoopRouteManifest.frozenAt);
        expect(json['sha256'], LoopRouteManifest.sha256);
        expect(LoopRouteManifest.entries, hasLength(93));

        final modules = json['modules']! as Map<String, Object?>;
        expect(
          modules.keys,
          LoopRouteModule.values.map((module) => module.manifestKey),
        );
        for (final module in LoopRouteModule.values) {
          final expected = (modules[module.manifestKey]! as List<Object?>)
              .cast<Map<String, Object?>>();
          final actual = LoopRouteManifest.forModule(module);
          expect(
            actual.map((entry) => entry.slug),
            expected.map((item) => item['slug']),
            reason: module.manifestKey,
          );
          expect(
            actual.map((entry) => entry.tab),
            expected.map((item) => item['tab']),
            reason: module.manifestKey,
          );
          expect(
            actual.map((entry) => entry.prototypeOrder),
            expected.map((item) => item['prototypeOrder']),
            reason: module.manifestKey,
          );
        }
      },
    );

    test('every slug maps to one unique path and non-empty page facts', () {
      final slugs = LoopRouteManifest.entries.map((entry) => entry.slug);
      final paths = LoopRouteManifest.entries.map((entry) => entry.path);
      expect(slugs.toSet(), hasLength(93));
      expect(paths.toSet(), hasLength(93));
      for (final entry in LoopRouteManifest.entries) {
        expect(entry.path, startsWith('/'), reason: entry.slug);
        expect(entry.path, isNot(contains(':')), reason: entry.slug);
        expect(entry.title, isNotEmpty, reason: entry.slug);
        expect(entry.step, inInclusiveRange(1, 8), reason: entry.slug);
        expect(entry.prototypeSectionId, 'scr-${entry.slug}');
        if (entry.legacyPath != null) {
          expect(entry.legacyPath, isNot(entry.path), reason: entry.slug);
          expect(
            LoopRouteManifest.retiredPaths,
            contains(entry.legacyPath),
            reason: '${entry.slug} legacy path must be retired',
          );
        }
      }
      expect(
        LoopRouteManifest.pathFor('community-members'),
        '/community/members',
      );
      expect(LoopRouteManifest.pathFor('send-confirm'), '/wallet/send/confirm');
      expect(LoopRouteManifest.pathFor('tx-result'), '/wallet/tx/result');
      expect(LoopRouteManifest.pathFor('loop-id-setup'), '/auth/loop-id');
      expect(LoopRouteManifest.pathFor('chart-full'), '/market/chart');
      expect(() => LoopRouteManifest.bySlug('home'), throwsArgumentError);
      expect(LoopRouteManifest.byPath('/home'), isNull);
    });

    test('five tabs keep the fixed order and no retired destination', () {
      expect(LoopRouteManifest.tabPaths, <String>[
        '/community',
        '/mining',
        '/launch',
        '/market',
        '/wallet',
      ]);
      expect(LoopRouteManifest.entries.where((entry) => entry.tab).length, 5);
      expect(LoopRouteManifest.defaultPath, '/community');
      expect(LoopShell.destinationPaths, LoopRouteManifest.tabPaths);
      expect(LoopShell.destinationLabels, <String>[
        '社区',
        '挖矿',
        'Launch',
        '行情',
        '钱包',
      ]);
      for (final retired in <String>[
        '/home',
        '/onboarding',
        '/notifications',
        '/onramp',
        '/perp',
        '/auth/wallet/seed',
      ]) {
        expect(LoopRouteManifest.tabPaths, isNot(contains(retired)));
        expect(
          LoopRouteManifest.entries.map((e) => e.path),
          isNot(contains(retired)),
        );
      }
    });

    test('supplementary paths stay an explicit, non-manifest allowlist', () {
      // The doc comment on `supplementaryPaths` promises this test names every
      // entry, so nothing can be added without an assertion changing.
      expect(LoopRouteManifest.supplementaryPaths, <String>[
        '/chat',
        '/chat/channel/:cid',
        '/chat/groups/create',
        '/chat/groups/:groupId/alias',
        '/preview/signing-review',
        '/preview/contract-facts',
        '/preview/asset-message',
        '/preview/token-card',
      ]);
      // `/profile/social-privacy` is no longer mounted: the V1 resource was
      // retired by the V2 privacy resource and the location is now only
      // recorded as informational.
      expect(
        LoopRouteManifest.supplementaryPaths,
        isNot(contains('/profile/social-privacy')),
      );
      expect(
        LoopRouteManifest.informationalRetiredPaths,
        contains('/profile/social-privacy'),
      );
      // Step 3 folded the V1 friend list and alias search into `search` +
      // `connections`: neither is mounted, and both stay informational.
      // Step 4 folded the V1 friend-request page into `dm-requests` and the
      // CID-addressed alias entry into `group-info`.
      for (final retired in <String>[
        '/profile/friends',
        '/chat/friends/add',
        '/chat/friends/requests',
        '/chat/channel/:cid/alias',
      ]) {
        expect(
          LoopRouteManifest.informationalRetiredPaths,
          contains(retired),
          reason: retired,
        );
        expect(
          LoopRouteManifest.supplementaryPaths,
          isNot(contains(retired)),
          reason: retired,
        );
        expect(
          LoopRouteManifest.retiredPaths,
          isNot(contains(retired)),
          reason: retired,
        );
      }
      final manifestPaths = LoopRouteManifest.entries
          .map((entry) => entry.path)
          .toSet();
      for (final path in LoopRouteManifest.supplementaryPaths) {
        expect(manifestPaths, isNot(contains(path)), reason: path);
      }
    });

    test('manifest keeps every retired Perp path unmounted', () {
      final perp = LoopRouteManifest.retiredPaths.where(
        (path) => path.startsWith('/perp'),
      );
      expect(perp, hasLength(12));
      expect(
        LoopRouteManifest.entries.any(
          (entry) => entry.path.startsWith('/perp'),
        ),
        isFalse,
      );
      expect(
        LoopRouteManifest.supplementaryPaths.any((p) => p.startsWith('/perp')),
        isFalse,
      );
    });

    test('Wallet manifest maps every slug to its mounted route', () {
      final wallet = LoopRouteManifest.forModule(LoopRouteModule.wallet);
      expect(wallet, hasLength(19));
      expect(
        wallet.where((entry) => entry.status == LoopRouteStatus.pending),
        isEmpty,
      );
      expect(
        LoopRouteManifest.bySlug('pay').status,
        LoopRouteStatus.unavailable,
      );
      expect(
        LoopRouteManifest.bySlug('networth').legacyPath,
        '/home/net-worth',
      );
      expect(
        LoopRouteManifest.bySlug('approval-guard').path,
        '/preview/approval',
      );
    });
  });

  group('application router', () {
    testWidgets(
      'mounts exactly the manifest, supplementary and compatibility paths',
      (tester) async {
        final router = await _pumpApp(tester);
        final mounted = _flatten(router.configuration.routes).toSet();

        final manifestPaths = LoopRouteManifest.entries
            .map((entry) => entry.path)
            .toSet();
        for (final path in manifestPaths) {
          expect(mounted, contains(path), reason: 'manifest path $path');
        }
        final allowed = <String>{
          ...manifestPaths,
          ...LoopRouteManifest.supplementaryPaths,
          ...LoopRouteManifest.compatibilityRedirects.keys,
          '/',
          '/:unmatched(.*)',
        };
        expect(mounted.difference(allowed), isEmpty);
        for (final retired in LoopRouteManifest.retiredPaths) {
          expect(mounted, isNot(contains(retired)), reason: retired);
        }
      },
    );

    testWidgets('pending manifest routes render the truthful pending surface', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      final pending = LoopRouteManifest.withStatus(LoopRouteStatus.pending);
      // S2 connected `/auth/otp` and `/auth/loop-id`; S3 connected
      // `community-discover`, `community-profile` and `community-members`;
      // S4 connected `community-chat`, `community-ai`, `chat-forward` and
      // `chat-merge-preview`.
      expect(pending, hasLength(16));
      expect(
        LoopRouteManifest.bySlug('auth-otp').status,
        LoopRouteStatus.implemented,
      );
      expect(
        LoopRouteManifest.bySlug('loop-id-setup').status,
        LoopRouteStatus.implemented,
      );
      expect(LoopRouteManifest.withStatus(LoopRouteStatus.redirect), isEmpty);
      expect(pending.map((entry) => entry.slug), isNot(contains('auth-otp')));

      for (final slug in <String>[
        'community-chat',
        'community-ai',
        'chat-forward',
        'chat-merge-preview',
      ]) {
        expect(
          LoopRouteManifest.bySlug(slug).status,
          LoopRouteStatus.implemented,
          reason: slug,
        );
        expect(pending.map((entry) => entry.slug), isNot(contains(slug)));
      }

      for (final entry in <LoopRouteEntry>[
        LoopRouteManifest.bySlug('launch-trade'),
        LoopRouteManifest.bySlug('mining-rules'),
        LoopRouteManifest.bySlug('key-export'),
        LoopRouteManifest.bySlug('launch-apply'),
      ]) {
        router.go(entry.path);
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, entry.path);
        expect(
          find.byType(LoopPendingSurface),
          findsOneWidget,
          reason: entry.slug,
        );
        expect(find.text(LoopPendingSurface.pendingHeadline), findsOneWidget);
        expect(find.text(entry.title), findsOneWidget, reason: entry.slug);
        expect(
          find.text('来源：${entry.module.label} 第 ${entry.step} 步'),
          findsOneWidget,
          reason: entry.slug,
        );
        expect(find.byType(LoopTabBar), findsNothing, reason: entry.slug);
        expect(find.byType(FilledButton), findsNothing, reason: entry.slug);
        expect(find.byType(TextField), findsNothing, reason: entry.slug);
        expect(find.textContaining('演示数据'), findsNothing, reason: entry.slug);
      }

      await tester.tap(find.byKey(const ValueKey<String>('loop-pending-back')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/community');
    });

    testWidgets('Pay stays an informational unavailable manifest route', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      router.go('/pay');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/pay');
      expect(find.text(LoopPendingSurface.unavailableHeadline), findsOneWidget);
      expect(find.textContaining('Pay 尚未开放'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(LoopTabBar), findsNothing);
    });

    testWidgets(
      'illegal and retired locations are logged and land on Community',
      (tester) async {
        final routingErrors = LoopRoutingErrorLog();
        final router = await _pumpApp(tester, routingErrors: routingErrors);

        for (final location in <String>[
          '/not-a-loop-route',
          '/onboarding',
          '/notifications',
          '/onramp',
          '/auth/wallet/seed',
          '/profile/recovery',
          '/home/net-worth',
          '/wallet/transaction',
          '/inventory',
        ]) {
          router.go(location);
          await tester.pumpAndSettle();

          expect(
            router.routeInformationProvider.value.uri.path,
            '/community',
            reason: location,
          );
          expect(routingErrors.last?.location, location, reason: location);
          expect(routingErrors.last?.fallback, '/community');
          expect(find.byType(LoopTabBar), findsOneWidget, reason: location);
        }
        expect(routingErrors.entries, hasLength(9));

        router.go('/home');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/community');
        router.go('/launchpad');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/launch');
        expect(
          routingErrors.entries,
          hasLength(9),
          reason: 'compatibility redirects are not routing errors',
        );
      },
    );

    testWidgets('the tab bar is shown only on the five tab routes', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      for (final path in LoopRouteManifest.tabPaths) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.byType(LoopTabBar), findsOneWidget, reason: path);
      }
      for (final path in <String>[
        '/profile',
        '/search',
        '/wallet/networth',
        '/system/offline',
        '/preview/toast',
        '/launch/detail',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.byType(LoopTabBar), findsNothing, reason: path);
      }
    });
  });
}

Iterable<String> _flatten(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route.path;
      yield* _flatten(route.routes);
    } else if (route is ShellRouteBase) {
      yield* _flatten(route.routes);
    }
  }
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  LoopRoutingErrorLog? routingErrors,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpotMarketRepository(),
        ),
        if (routingErrors != null)
          loopRoutingErrorLogProvider.overrideWithValue(routingErrors),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(
    tester.element(find.byKey(const ValueKey<String>('community-screen'))),
  );
}

final class _EmptySpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  const _EmptySpotMarketRepository();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    return HyperliquidSpotSnapshot(
      receivedAt: DateTime.utc(2026, 9, 7),
      markets: const <HyperliquidSpotMarket>[],
    );
  }
}

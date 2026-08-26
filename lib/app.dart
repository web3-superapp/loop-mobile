import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/app/notifications/loop_notification_coordinator.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/navigation/spot_market_route.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/features/catalog/catalog_surface_screen.dart';
import 'package:loop_mobile/features/chat/chat.dart';
import 'package:loop_mobile/features/home/home_screens.dart';
import 'package:loop_mobile/features/launchpad/launchpad_screen.dart';
import 'package:loop_mobile/features/market/market.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/review/signing_review_surface.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/features/wallet/wallet_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show
        DefaultStreamMessageComposer,
        StreamChat,
        StreamChatConfigurationData,
        StreamComponentBuilders,
        streamChatComponentBuilders;

final _loopStreamComponentBuilders = StreamComponentBuilders(
  extensions: streamChatComponentBuilders(
    messageComposer: (context, props) => DefaultStreamMessageComposer(
      props: props.copyWith(
        // Platform permissions and attachment policy are intentionally not
        // fabricated. Text messaging remains available through official UI.
        disableAttachments: true,
        enableVoiceRecording: false,
      ),
    ),
  ),
);

final _loopStreamConfiguration = StreamChatConfigurationData(
  messagePreviewFormatter: const LoopStreamTokenCardMessagePreviewFormatter(),
  attachmentBuilders: const <LoopStreamTokenCardAttachmentBuilder>[
    LoopStreamTokenCardAttachmentBuilder(),
  ],
);

class LoopApp extends ConsumerStatefulWidget {
  const LoopApp({super.key});

  @override
  ConsumerState<LoopApp> createState() => _LoopAppState();
}

class _LoopAppState extends ConsumerState<LoopApp> {
  late final GoRouter router;
  late final LoopNotificationCoordinator notificationCoordinator;

  @override
  void initState() {
    super.initState();
    router = _buildRouter(() => ref.read(loopSessionProvider));
    notificationCoordinator = LoopNotificationCoordinator(
      source: ref.read(loopNotificationEventSourceProvider),
      readSession: () => ref.read(loopSessionProvider),
      readBootstrapSession: () => ref.read(loopBootstrapSessionProvider),
      navigate: (intent) => router.go(intent.location),
    );
    ref.listenManual<LoopSessionState>(loopSessionProvider, (previous, next) {
      if (previous?.mode != next.mode) router.refresh();
      notificationCoordinator.onIdentityMayHaveChanged();
    });
    ref.listenManual(loopBootstrapSessionProvider, (previous, next) {
      if (!identical(previous, next)) {
        notificationCoordinator.onIdentityMayHaveChanged();
      }
    });
    notificationCoordinator.start();
  }

  @override
  void dispose() {
    unawaited(notificationCoordinator.dispose());
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streamSession = ref.watch(streamChatSdkSessionProvider);
    final reduceMotion = ref.watch(
      loopDisplayPreferencesProvider.select(
        (preferences) => preferences.reduceMotion,
      ),
    );
    return MaterialApp.router(
      title: 'LOOP',
      debugShowCheckedModeBanner: false,
      theme: LoopTheme.dark,
      darkTheme: LoopTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) {
        Widget content = child ?? const SizedBox.shrink();
        if (reduceMotion && !MediaQuery.disableAnimationsOf(context)) {
          content = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: content,
          );
        }
        if (streamSession != null) {
          content = StreamChat(
            key: ObjectKey(streamSession.client),
            client: streamSession.client,
            configData: _loopStreamConfiguration,
            componentBuilders: _loopStreamComponentBuilders,
            child: content,
          );
        }
        return content;
      },
    );
  }
}

GoRouter _buildRouter(LoopSessionState Function() readSession) {
  return GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      final session = readSession();
      final isAuthRoute = state.matchedLocation == '/auth';
      if (!session.canEnterProduct) {
        return isAuthRoute ? null : '/auth';
      }
      if (isAuthRoute) return '/home';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const PrivyLoginScreen(),
      ),
      GoRoute(path: '/auth/otp', redirect: (context, state) => '/auth'),
      ShellRoute(
        builder: (context, state, child) =>
            LoopShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/market',
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: '/launchpad',
            builder: (context, state) => const LaunchpadScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatInboxPage(),
          ),
          GoRoute(
            path: '/wallet',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  _profileScreen(context, ref, 'profile'),
            ),
          ),
        ],
      ),
      ..._accountRoutes,
      GoRoute(
        path: '/home/net-worth',
        builder: (context, state) => const NetWorthScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/home/security',
        builder: (context, state) => const SecurityActivityScreen(),
      ),
      GoRoute(
        path: SpotMarketRoute.path,
        redirect: (context, state) =>
            state.uri.queryParameters.containsKey(
              SpotMarketRoute.indexParameter,
            )
            ? null
            : '/market',
        builder: (context, state) {
          final rawSpotIndex =
              state.uri.queryParameters[SpotMarketRoute.indexParameter];
          return SpotMarketDetailScreen(
            spotIndex: int.tryParse(rawSpotIndex ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/market/chart',
        builder: (context, state) => FullChartScreen(
          symbol: state.extra is String ? state.extra! as String : 'ETH',
        ),
      ),
      GoRoute(
        path: '/market/new',
        builder: (context, state) => const NewPairsScreen(),
      ),
      GoRoute(
        path: '/market/holders',
        builder: (context, state) => HolderDistributionScreen(
          symbol: state.extra is String ? state.extra! as String : 'ETH',
        ),
      ),
      GoRoute(
        path: '/market/trades',
        builder: (context, state) => TradingActivityScreen(
          symbol: state.extra is String ? state.extra! as String : 'ETH',
        ),
      ),
      GoRoute(
        path: '/market/watchlist',
        builder: (context, state) => const WatchlistEditorScreen(),
      ),
      GoRoute(
        path: '/market/alerts',
        builder: (context, state) => PriceAlertsScreen(
          symbol: state.extra is String ? state.extra! as String : 'ETH',
        ),
      ),
      GoRoute(
        path: '/market/smart-money',
        builder: (context, state) => const SmartMoneyScreen(),
      ),
      ..._retainedPerpRedirectRoutes,
      GoRoute(
        path: '/chat/group',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Group conversation',
          child: GroupChatPage(),
        ),
      ),
      GoRoute(
        path: '/chat/dm',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Direct conversation',
          child: DirectMessagePage(),
        ),
      ),
      GoRoute(
        path: '/chat/voice',
        builder: (context, state) => const VoiceRoomPage(),
      ),
      GoRoute(
        path: '/chat/voice/full',
        builder: (context, state) => const VoiceRoomPage(),
      ),
      GoRoute(
        path: '/chat/group-info',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Group information',
          child: GroupInfoPage(),
        ),
      ),
      GoRoute(
        path: '/chat/requests',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Message requests',
          child: MessageRequestsPage(),
        ),
      ),
      GoRoute(
        path: '/chat/search',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Message search',
          child: MessageSearchPage(),
        ),
      ),
      GoRoute(
        path: '/chat/channel/:cid',
        builder: (context, state) =>
            StreamChatChannelRoutePage(cid: state.pathParameters['cid'] ?? ''),
      ),
      GoRoute(
        path: '/chat/meeting',
        builder: (context, state) => const MeetingPlaceholderPage(),
      ),
      GoRoute(
        path: '/preview/token-card',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Token card preview',
          child: TokenCardPreviewPage(),
        ),
      ),
      GoRoute(
        path: '/preview/contract-facts',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Contract facts preview',
          child: ContractFactsPreviewPage(),
        ),
      ),
      GoRoute(
        path: '/preview/asset-message',
        builder: (context, state) => const ChatPreviewRouteGuard(
          surfaceLabel: 'Asset message preview',
          child: AssetMessagePreviewPage(),
        ),
      ),
      GoRoute(
        path: '/wallet/asset',
        redirect: (context, state) =>
            state.extra is WalletPreviewAsset ? null : '/wallet',
        builder: (context, state) =>
            AssetDetailScreen(asset: state.extra! as WalletPreviewAsset),
      ),
      GoRoute(
        path: '/wallet/send',
        builder: (context, state) => const SendAssetScreen(),
      ),
      GoRoute(
        path: '/wallet/send/to',
        redirect: (context, state) =>
            state.extra is TransferDraft ? null : '/wallet/send',
        builder: (context, state) =>
            SendRecipientScreen(draft: state.extra! as TransferDraft),
      ),
      GoRoute(
        path: '/wallet/send/confirm',
        redirect: (context, state) {
          final draft = state.extra;
          return draft is TransferDraft && draft.recipient.trim().isNotEmpty
              ? null
              : '/wallet/send';
        },
        builder: (context, state) =>
            SendConfirmScreen(draft: state.extra! as TransferDraft),
      ),
      GoRoute(
        path: '/wallet/receive',
        builder: (context, state) => const ReceiveScreen(),
      ),
      GoRoute(
        path: '/wallet/swap',
        builder: (context, state) => const SwapScreen(),
      ),
      GoRoute(
        path: '/wallet/swap/route',
        builder: (context, state) => const SwapRouteScreen(),
      ),
      GoRoute(
        path: '/wallet/bridge',
        builder: (context, state) => const BridgeScreen(),
      ),
      GoRoute(
        path: '/wallet/bridge/status',
        builder: (context, state) => const BridgeStatusScreen(),
      ),
      GoRoute(
        path: '/wallet/transaction',
        builder: (context, state) => const TransactionResultScreen(),
      ),
      GoRoute(
        path: '/wallet/history',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/wallet/manage',
        builder: (context, state) => const WalletManagerScreen(),
      ),
      GoRoute(
        path: '/wallet/dapp',
        builder: (context, state) => const DappBrowserScreen(),
      ),
      GoRoute(
        path: '/preview/approval',
        builder: (context, state) => const ApprovalInterceptScreen(),
      ),
      GoRoute(
        path: '/wallet/approvals',
        builder: (context, state) => const ApprovalsScreen(),
      ),
      GoRoute(
        path: '/wallet/dapps',
        builder: (context, state) => const DappListScreen(),
      ),
      GoRoute(
        path: '/wallet/networks',
        builder: (context, state) => const NetworksScreen(),
      ),
      GoRoute(
        path: '/wallet/protection',
        builder: (context, state) => const ProtectionScreen(),
      ),
      GoRoute(
        path: '/preview/signing-review',
        redirect: (context, state) =>
            state.extra is SigningIntent ? null : '/wallet',
        builder: (context, state) =>
            SigningReviewPage(intent: state.extra! as SigningIntent),
      ),
      ..._profileRoutes,
      ..._systemRoutes,
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const UiInventoryScreen(),
      ),
      ..._catalogRoutes,
    ],
    errorBuilder: (context, state) =>
        UnknownRouteScreen(location: state.uri.toString()),
  );
}

final List<RouteBase> _accountRoutes =
    <(String, String)>[
          ('/splash', 'splash'),
          ('/onboarding', 'onboarding'),
          ('/auth/wallet', 'auth-wallet'),
          ('/auth/wallet/create', 'wallet-create'),
          ('/auth/wallet/backup', 'wallet-backup'),
          ('/auth/wallet/seed', 'seed-show'),
          ('/auth/wallet/seed/verify', 'seed-verify'),
          ('/auth/wallet/import', 'wallet-import'),
          ('/auth/security', 'security-setup'),
          ('/auth/profile', 'profile-setup'),
        ]
        .map((item) {
          return GoRoute(
            path: item.$1,
            builder: (context, state) => AccountSurfaceScreen.fromId(
              item.$2,
              onNavigate: (destination) =>
                  context.go(_accountPath(destination)),
            ),
          );
        })
        .toList(growable: false);

final List<RouteBase> _profileRoutes =
    <(String, String)>[
          ('/profile/edit', 'profile-edit'),
          ('/profile/privacy', 'privacy'),
          ('/profile/copy', 'copytrade-perms'),
          ('/profile/security', 'security'),
          ('/profile/devices', 'devices'),
          ('/profile/recovery', 'seed-backup'),
          ('/profile/social-recovery', 'social-recovery'),
          ('/profile/notifications', 'notif-settings'),
          ('/profile/connections', 'connections'),
          ('/profile/blocked', 'blocklist'),
          ('/profile/settings', 'settings'),
          ('/profile/about', 'about'),
          ('/profile/help', 'support'),
          ('/profile/rewards', 'mining'),
          ('/profile/referral', 'referral'),
        ]
        .map((item) {
          return GoRoute(
            path: item.$1,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  _profileScreen(context, ref, item.$2),
            ),
          );
        })
        .toList(growable: false);

final List<RouteBase> _systemRoutes =
    <(String, String)>[
          ('/system/offline', 'offline'),
          ('/system/error', 'server-error'),
          ('/system/update', 'force-update'),
          ('/system/maintenance', 'maintenance'),
          ('/system/region', 'region-restricted'),
          ('/system/permission', 'permission'),
          ('/preview/toast', 'toast'),
          ('/preview/loading', 'loading'),
        ]
        .map((item) {
          return GoRoute(
            path: item.$1,
            builder: (context, state) => SystemSurfaceScreen.fromId(
              item.$2,
              onRetry: () => context.go('/home'),
              onSecondaryAction: () => context.go('/home'),
              onPrimaryAction: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This action requires the production app host.',
                  ),
                ),
              ),
            ),
          );
        })
        .toList(growable: false);

Widget _profileScreen(BuildContext context, WidgetRef ref, String id) {
  final session = ref.watch(loopSessionProvider);
  final account = session.account;
  final identity = ProfileIdentity(
    alias: account == null
        ? (session.isPreview ? 'Development preview' : 'Restricted session')
        : 'Privy session',
    address: account?.wallet?.address ?? 'No wallet connected',
    bio: 'Provider-backed profile bootstrap is not connected.',
    connections: 0,
    groups: 0,
    watchlistItems: 0,
  );
  return ProfileSurfaceScreen.fromId(
    id,
    identity: identity,
    onNavigate: (destination) => context.push(_profilePath(destination)),
    onSignOut: () => ref.read(loopSessionProvider.notifier).exit(),
  );
}

String _accountPath(String id) => switch (id) {
  'splash' => '/splash',
  'onboarding' => '/onboarding',
  'auth' => '/auth',
  'auth-otp' => '/auth/otp',
  'auth-wallet' => '/auth/wallet',
  'wallet-create' => '/auth/wallet/create',
  'wallet-backup' => '/auth/wallet/backup',
  'seed-show' => '/auth/wallet/seed',
  'seed-verify' => '/auth/wallet/seed/verify',
  'wallet-import' => '/auth/wallet/import',
  'security-setup' => '/auth/security',
  'profile-setup' => '/auth/profile',
  'home' => '/home',
  _ => '/auth',
};

String _profilePath(String id) => switch (id) {
  'profile' => '/profile',
  'profile-edit' => '/profile/edit',
  'privacy' => '/profile/privacy',
  'copytrade-perms' => '/profile/copy',
  'security' => '/profile/security',
  'devices' => '/profile/devices',
  'seed-backup' => '/profile/recovery',
  'social-recovery' => '/profile/social-recovery',
  'notif-settings' => '/profile/notifications',
  'connections' => '/profile/connections',
  'blocklist' => '/profile/blocked',
  'settings' => '/profile/settings',
  'about' => '/profile/about',
  'support' => '/profile/help',
  'mining' => '/profile/rewards',
  'referral' => '/profile/referral',
  _ => '/profile',
};

abstract final class LoopRouteRegistry {
  static const Set<String> retainedPerpPaths = <String>{
    '/perp',
    '/perp/trade',
    '/perp/confirm',
    '/perp/positions',
    '/perp/position',
    '/perp/orders',
    '/perp/history',
    '/perp/account',
    '/perp/transfer',
    '/perp/deposit',
    '/perp/funding',
    '/perp/risk',
  };

  static const Set<String> customSurfacePaths = <String>{
    '/splash',
    '/onboarding',
    '/auth',
    '/auth/otp',
    '/auth/wallet',
    '/auth/wallet/create',
    '/auth/wallet/backup',
    '/auth/wallet/seed',
    '/auth/wallet/seed/verify',
    '/auth/wallet/import',
    '/auth/security',
    '/auth/profile',
    '/home',
    '/home/net-worth',
    '/notifications',
    '/search',
    '/home/security',
    '/market',
    SpotMarketRoute.path,
    '/market/chart',
    '/market/new',
    '/market/holders',
    '/market/trades',
    '/market/watchlist',
    '/market/alerts',
    '/market/smart-money',
    ...retainedPerpPaths,
    '/chat',
    '/chat/group',
    '/chat/voice',
    '/chat/dm',
    '/chat/group-info',
    '/chat/voice/full',
    '/chat/requests',
    '/chat/search',
    '/chat/meeting',
    '/preview/token-card',
    '/preview/contract-facts',
    '/preview/asset-message',
    '/wallet',
    '/wallet/asset',
    '/wallet/send',
    '/wallet/send/to',
    '/wallet/send/confirm',
    '/wallet/receive',
    '/wallet/swap',
    '/wallet/swap/route',
    '/wallet/bridge',
    '/wallet/bridge/status',
    '/preview/signing-review',
    '/wallet/transaction',
    '/wallet/history',
    '/wallet/manage',
    '/wallet/dapp',
    '/preview/approval',
    '/wallet/approvals',
    '/wallet/dapps',
    '/wallet/networks',
    '/wallet/protection',
    '/launchpad',
    '/profile',
    '/profile/edit',
    '/profile/privacy',
    '/profile/copy',
    '/profile/security',
    '/profile/devices',
    '/profile/recovery',
    '/profile/social-recovery',
    '/profile/notifications',
    '/profile/connections',
    '/profile/blocked',
    '/profile/settings',
    '/profile/about',
    '/profile/help',
    '/profile/rewards',
    '/profile/referral',
    '/system/offline',
    '/system/error',
    '/system/update',
    '/system/maintenance',
    '/system/region',
    '/system/permission',
    '/preview/toast',
    '/preview/loading',
  };
}

final List<RouteBase> _retainedPerpRedirectRoutes = LoopRouteRegistry
    .retainedPerpPaths
    .map((path) => GoRoute(path: path, redirect: (context, state) => '/market'))
    .toList(growable: false);

final List<RouteBase> _catalogRoutes = SurfaceCatalog.all
    .where(
      (surface) => !LoopRouteRegistry.customSurfacePaths.contains(surface.path),
    )
    .map(
      (surface) => GoRoute(
        path: surface.path,
        builder: (context, state) => CatalogSurfaceScreen(surface: surface),
      ),
    )
    .toList(growable: false);

class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    return LoopPage(
      title: 'Route not found',
      eyebrow: '404',
      subtitle: location,
      children: <Widget>[
        LoopStateCard(
          title: 'This surface is not in the product map',
          message: 'Return home or inspect the full UI inventory.',
          icon: Icons.route_outlined,
          tone: LoopTone.warning,
          action: Wrap(
            spacing: 10,
            children: <Widget>[
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go home'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/inventory'),
                child: const Text('UI inventory'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

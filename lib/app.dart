import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/app/notifications/loop_notification_coordinator.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/app/session/loop_communication_retirement.dart';
import 'package:loop_mobile/app/session/post_auth_bootstrap_coordinator.dart';
import 'package:loop_mobile/app/session/post_auth_profile_redirect_coordinator.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/navigation/spot_market_route.dart';
import 'package:loop_mobile/core/navigation/loop_routing_error_log.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/policy/loop_client_policy.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/loop_id_setup_screen.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/features/account/privy_otp_screen.dart';
import 'package:loop_mobile/features/chat/chat.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/home/home_screens.dart';
import 'package:loop_mobile/features/launchpad/launchpad_screen.dart';
import 'package:loop_mobile/features/market/market.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/review/signing_review_surface.dart';
import 'package:loop_mobile/features/shell/loop_pending_surface.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/features/wallet/wallet_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_coordinator.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
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
    messageItem: loopStreamGroupMessageItemBuilder,
    mentionItem: loopStreamGroupMentionItemBuilder,
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
  late final PostAuthBootstrapCoordinator postAuthBootstrapCoordinator;
  late final PostAuthProfileRedirectCoordinator postAuthProfileCoordinator;

  @override
  void initState() {
    super.initState();
    // D0 metadata is a startup observation, not an authentication or feature
    // gate. Keeping the subscription alive starts both public reads while an
    // AsyncError remains isolated inside Riverpod and cannot block routing.
    ref.listenManual(
      loopV2MetaSnapshotProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    router = _buildRouter(
      () => ref.read(loopSessionProvider),
      ref.read(loopRoutingErrorLogProvider),
    );
    notificationCoordinator = LoopNotificationCoordinator(
      source: ref.read(loopNotificationEventSourceProvider),
      readSession: () => ref.read(loopSessionProvider),
      readBootstrapSession: () => ref.read(loopBootstrapSessionProvider),
      navigate: (intent) => router.go(intent.location),
    );
    postAuthBootstrapCoordinator = PostAuthBootstrapCoordinator(() async {
      // Riverpod invalidates principal-dependent providers after publishing
      // the session state. Yield once so this read cannot observe the retired
      // signed-out bootstrap owner.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      await ref.read(loopBootstrapSessionProvider)?.authorize();
    });
    postAuthProfileCoordinator = PostAuthProfileRedirectCoordinator(
      readProfile: () async {
        // Riverpod rotates principal-scoped gateways after publishing the
        // session; yield once so this read cannot use a retired owner.
        await Future<void>.delayed(Duration.zero);
        return ref.read(profileGatewayProvider).load();
      },
      publish: (landing, kind) {
        if (!mounted) return;
        ref
            .read(loopProfileLandingProvider.notifier)
            .publish(landing, kind: kind);
      },
      navigate: (landing) {
        if (!mounted || landing != LoopProfileLanding.loopIdSetup) return;
        // Only lift an owner out of the credential or landing pages. A deep
        // link the owner opened deliberately is never interrupted.
        const liftable = <String>{'/auth', '/auth/otp', '/community'};
        final location = router.state.matchedLocation;
        if (liftable.contains(location)) {
          router.go(LoopRouteManifest.pathFor('loop-id-setup'));
        }
      },
    );
    ref.listenManual<LoopSessionState>(loopSessionProvider, (previous, next) {
      if (previous?.mode != next.mode) router.refresh();
      notificationCoordinator.onIdentityMayHaveChanged();
      postAuthBootstrapCoordinator.onSessionChanged(previous, next);
      postAuthProfileCoordinator.onSessionChanged(previous, next);
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
        // One toast host above the router: fixed above the tab bar, z 90.
        return LoopToastHost(child: content);
      },
    );
  }
}

GoRouter _buildRouter(
  LoopSessionState Function() readSession,
  LoopRoutingErrorLog routingErrors,
) {
  return GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      final session = readSession();
      final location = state.matchedLocation;
      // Credential pages reachable before a verified session. Everything else
      // stays behind the gate.
      const signedOutRoutes = <String>{
        '/auth',
        '/auth/otp',
        '/auth/wallet',
        '/splash',
      };
      const credentialRoutes = <String>{'/auth', '/auth/otp'};
      if (!session.canEnterProduct) {
        return signedOutRoutes.contains(location) ? null : '/auth';
      }
      if (credentialRoutes.contains(location)) return '/community';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => '/community'),
      GoRoute(
        path: '/auth',
        builder: (context, state) => PrivyLoginScreen(
          onCodeSent: () => context.push(LoopRouteManifest.pathFor('auth-otp')),
        ),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) => PrivyOtpScreen(
            onBack: () {
              // Leaving the step abandons the pending code on purpose.
              ref.read(emailAuthProvider.notifier).changeEmail();
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go(LoopRouteManifest.pathFor('auth'));
              }
            },
          ),
        ),
      ),
      GoRoute(
        path: '/auth/loop-id',
        builder: (context, state) => LoopIdSetupScreen(
          onActivated: () => context.go(LoopRouteManifest.defaultPath),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => LoopShell(
          location: state.uri.path,
          child: Column(
            children: <Widget>[
              const LoopSoftUpdatePrompt(),
              const ProfileAvailabilityBanner(),
              Expanded(child: child),
            ],
          ),
        ),
        // Peer tabs fade; every other route pushes horizontally through the
        // theme's LoopPushTransitionsBuilder.
        routes: <RouteBase>[
          GoRoute(
            path: '/community',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const CommunityScreen(),
            ),
          ),
          GoRoute(
            path: '/mining',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const MiningScreen(),
            ),
          ),
          GoRoute(
            path: '/launch',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const LaunchpadScreen(),
            ),
          ),
          GoRoute(
            path: '/market',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const MarketScreen(),
            ),
          ),
          GoRoute(
            path: '/wallet',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const WalletScreen(),
            ),
          ),
        ],
      ),
      GoRoute(path: '/home', redirect: (context, state) => '/community'),
      GoRoute(path: '/launchpad', redirect: (context, state) => '/launch'),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatInboxPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) =>
              _profileScreen(context, ref, 'profile'),
        ),
      ),
      ..._accountRoutes,
      GoRoute(
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      // Manifest `networth` (legacy `/home/net-worth`, retired with Home).
      GoRoute(
        path: '/wallet/networth',
        builder: (context, state) => const NetWorthScreen(),
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
        path: SpotMarketRoute.chartPath,
        builder: (context, state) => FullChartScreen(
          spotIndex: SpotMarketRoute.parseChartSpotIndex(state.uri),
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
      GoRoute(
        path: '/chat/friends/add',
        builder: (context, state) => const AddFriendPage(),
      ),
      GoRoute(
        path: '/chat/friends/requests',
        builder: (context, state) => const FriendRequestsPage(),
      ),
      GoRoute(
        path: '/chat/groups/create',
        builder: (context, state) => const CreateFriendGroupPage(),
      ),
      GoRoute(
        path: '/chat/groups/:groupId/alias',
        builder: (context, state) => GroupAliasRoutePage(
          routeGroupId: state.pathParameters['groupId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/chat/channel/:cid/alias',
        builder: (context, state) => StreamGroupAliasChannelRoutePage(
          cid: state.pathParameters['cid'] ?? '',
        ),
      ),
      GoRoute(
        path: '/chat/group',
        builder: (context, state) => ChatPreviewRouteGuard(
          surfaceLabel: 'Group conversation',
          child: GroupChatPage(
            conversationId:
                PreviewConversationIdentity.readSingleConversationId(
                  state.uri,
                ) ??
                '',
          ),
        ),
      ),
      GoRoute(
        path: '/chat/dm',
        builder: (context, state) => ChatPreviewRouteGuard(
          surfaceLabel: 'Direct conversation',
          child: DirectMessagePage(
            conversationId:
                PreviewConversationIdentity.readSingleConversationId(
                  state.uri,
                ) ??
                '',
          ),
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
        builder: (context, state) => ChatPreviewRouteGuard(
          surfaceLabel: 'Group information',
          child: GroupInfoPage(
            conversationId:
                PreviewConversationIdentity.readSingleConversationId(
                  state.uri,
                ) ??
                '',
          ),
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
        builder: (context, state) => ChatPreviewRouteGuard(
          surfaceLabel: 'Message search',
          child: MessageSearchPage(
            key: ValueKey<String>('preview-message-search-${state.uri}'),
            conversationId:
                PreviewConversationIdentity.hasConversationIdQuery(state.uri)
                ? PreviewConversationIdentity.readSingleConversationId(
                        state.uri,
                      ) ??
                      ''
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/chat/channel/:cid',
        builder: (context, state) =>
            StreamChatChannelRoutePage(cid: state.pathParameters['cid'] ?? ''),
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
        redirect: (context, state) =>
            state.extra is SwapPreviewSnapshot ? null : '/wallet/swap',
        builder: (context, state) =>
            SwapRouteScreen(snapshot: state.extra! as SwapPreviewSnapshot),
      ),
      GoRoute(
        path: '/wallet/bridge',
        builder: (context, state) => const BridgeScreen(),
      ),
      GoRoute(
        path: '/wallet/bridge/status',
        redirect: (context, state) =>
            state.extra is BridgePreviewSnapshot ? null : '/wallet/bridge',
        builder: (context, state) =>
            BridgeStatusScreen(snapshot: state.extra! as BridgePreviewSnapshot),
      ),
      // Manifest `tx-result` (legacy `/wallet/transaction`).
      GoRoute(
        path: '/wallet/tx/result',
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
        path: '/wallet/networks',
        builder: (context, state) => const NetworksScreen(),
      ),
      GoRoute(
        path: '/preview/signing-review',
        redirect: (context, state) =>
            state.extra is SigningIntent ? null : '/wallet',
        builder: (context, state) =>
            SigningReviewPage(intent: state.extra! as SigningIntent),
      ),
      ..._profileRoutes,
      GoRoute(
        path: '/profile/friends',
        builder: (context, state) => const FriendListPage(),
      ),
      ..._systemRoutes,
      // Manifest `pay`: informational unavailable surface (fail closed).
      GoRoute(
        path: '/pay',
        builder: (context, state) => LoopPendingSurface.unavailable(
          entry: LoopRouteManifest.bySlug('pay'),
        ),
      ),
      ..._pendingManifestRoutes,
      // Illegal locations are recorded and land on Community.
      GoRoute(
        path: '/:unmatched(.*)',
        redirect: (context, state) {
          routingErrors.record(state.uri.toString());
          return '/community';
        },
      ),
    ],
    errorBuilder: (context, state) =>
        UnknownRouteScreen(location: state.uri.toString()),
  );
}

/// Every manifest slug without a dedicated screen mounts the pending surface,
/// so all 93 routes are reachable and none silently falls through.
final List<RouteBase> _pendingManifestRoutes =
    LoopRouteManifest.withStatus(LoopRouteStatus.pending)
        .map((entry) {
          return GoRoute(
            path: entry.path,
            builder: (context, state) => LoopPendingSurface(entry: entry),
          );
        })
        .toList(growable: false);

// Manifest 0-global-account pages with an existing screen. Onboarding, seed
// reveal/verify, wallet import and the old profile setup are retired.
final List<RouteBase> _accountRoutes =
    <(String, String)>[
          ('/splash', 'splash'),
          ('/auth/wallet', 'auth-wallet'),
          ('/auth/wallet/create', 'wallet-create'),
          ('/auth/wallet/backup', 'wallet-recovery'),
          ('/auth/security', 'security-setup'),
        ]
        .map((item) {
          return GoRoute(
            path: item.$1,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  _accountScreen(context, ref, item.$2),
            ),
          );
        })
        .toList(growable: false);

/// Account step pages. Every capability stays fail-closed: this composition
/// never asserts a wallet, recovery or protection capability it has not been
/// told about by the integration layer.
Widget _accountScreen(BuildContext context, WidgetRef ref, String id) {
  final config = ref.watch(appConfigProvider);
  void back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(LoopRouteManifest.pathFor('auth'));
    }
  }

  return AccountSurfaceScreen.fromId(
    id,
    versionLabel: 'Version ${config.loopClientVersionForCurrentBuild}',
    capabilities: PrivyWalletCapabilities(
      canConnectExternalWallet: config.canConnectExternalWallet,
    ),
    onBack: back,
    onPrimaryAction: id == 'auth-wallet' && config.canConnectExternalWallet
        ? () => unawaited(
            ref.read(emailAuthProvider.notifier).connectExternalWallet(context),
          )
        : null,
    onNavigate: (destination) => context.go(_accountPath(destination)),
  );
}

// Manifest 7-profile pages with an existing screen. Copy permissions, seed
// backup and profile rewards are retired; `/profile/social-privacy` retired
// with V2 privacy (step 2).
final List<RouteBase> _profileRoutes =
    <(String, String)>[
          ('/profile/edit', 'profile-edit'),
          ('/profile/privacy', 'privacy'),
          ('/profile/security', 'security'),
          ('/profile/devices', 'devices'),
          ('/profile/social-recovery', 'social-recovery'),
          ('/profile/notifications', 'notif-settings'),
          ('/profile/connections', 'connections'),
          ('/profile/blocked', 'blocklist'),
          ('/profile/settings', 'settings'),
          ('/profile/about', 'about'),
          ('/profile/help', 'support'),
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

// Manifest module 8 plus the two module-0 gates. `force-update` and
// `region-blocked` read the D0 client-policy projection; the component-state
// showcases read the preview-only showcase provider (null in production).
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
          ('/system/token-card', 'token-card-states'),
          ('/system/sign-sheet', 'sign-sheet-states'),
        ]
        .map((item) {
          return GoRoute(
            path: item.$1,
            builder: (context, state) => Consumer(
              builder: (context, ref, child) =>
                  _systemSurface(context, ref, item.$2),
            ),
          );
        })
        .toList(growable: false);

Widget _systemSurface(BuildContext context, WidgetRef ref, String id) {
  final policy = ref.watch(loopV2MetaSnapshotProvider).value?.clientPolicy;
  final version = LoopClientPolicyProjection.version(
    policy,
    platform: defaultTargetPlatform,
    clientVersion: ref.watch(appConfigProvider).loopClientVersion,
  );
  final region = LoopClientPolicyProjection.region(policy);
  void returnToCommunity() => context.go(LoopRouteManifest.defaultPath);
  void back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      returnToCommunity();
    }
  }

  return SystemSurfaceScreen.fromId(
    id,
    onBack: back,
    onSecondaryAction: returnToCommunity,
    forceUpdateRequirement:
        version.decision == LoopVersionPolicyDecision.updateRequired
        ? LoopForceUpdateRequirement(
            forceUpdateBelow: version.forceUpdateBelow,
            minimumSupportedVersion: version.minimumVersion,
            configVersion: version.configVersion,
            storeUrl: version.storeUrl,
          )
        : null,
    featureAvailabilityRestriction:
        region.decision == LoopRegionPolicyDecision.blocked
        ? LoopFeatureAvailabilityRestriction(
            reasonCode: region.reasonCode,
            supportUrl: region.supportUrl,
            readOnlyAssetAccess: region.readOnlyAssetAccess,
          )
        : null,
    onRegionContinue: region.decision == LoopRegionPolicyDecision.blocked
        ? returnToCommunity
        : null,
    showcase: ref.watch(loopSystemShowcaseProvider),
  );
}

Widget _profileScreen(BuildContext context, WidgetRef ref, String id) {
  final session = ref.watch(loopSessionProvider);
  final account = session.account;
  final identity = ProfileIdentity(
    alias: account == null
        ? (session.isPreview ? 'Development preview' : 'Restricted session')
        : 'Privy session',
    address: account?.wallet?.address ?? 'No wallet connected',
    bio: 'Bio is not part of the reviewed Profile presentation contract.',
    connections: 0,
    groups: 0,
    watchlistItems: 0,
  );
  void back() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(LoopRouteManifest.defaultPath);
    }
  }

  return ProfileSurfaceScreen.fromId(
    id,
    identity: identity,
    onBack: back,
    onNavigate: (destination) {
      final path = _profilePath(destination);
      // Tab destinations replace the stack; only child pages push.
      if (LoopRouteManifest.isTabPath(path)) {
        context.go(path);
      } else {
        context.push(path);
      }
    },
    onSignOut: () => _signOut(ref),
  );
}

Future<void> _signOut(WidgetRef ref) {
  final retirement = ref
      .read(loopCommunicationRetirementRegistryProvider)
      .capture();
  final bootstrapRepository = ref.read(loopBootstrapRepositoryProvider);
  final bootstrapQuiescence = bootstrapRepository is LoopV2BootstrapRepository
      ? bootstrapRepository.prepareForLogout()
      : Future<void>.value();
  final backend = ref.read(loopV2LogoutCoordinatorProvider);
  return ref
      .read(loopSessionProvider.notifier)
      .exit(
        revokeBackend: backend == null
            ? null
            : (principalKey) async {
                await bootstrapQuiescence;
                final result = await backend.logout(principalKey);
                return switch (result) {
                  LoopV2LogoutDisposition.notRequired =>
                    LoopBackendLogoutResult.notRequired,
                  LoopV2LogoutDisposition.confirmed =>
                    LoopBackendLogoutResult.confirmed,
                  LoopV2LogoutDisposition.unconfirmed =>
                    LoopBackendLogoutResult.unconfirmed,
                };
              },
        retireCommunications: retirement.retire,
      );
}

// Account screen destinations. Retired ids (onboarding, seed reveal/verify,
// wallet import) resolve to the nearest manifest page instead of a dead route.
String _accountPath(String id) => switch (id) {
  'splash' => LoopRouteManifest.pathFor('splash'),
  'onboarding' => LoopRouteManifest.pathFor('auth'),
  'auth' => LoopRouteManifest.pathFor('auth'),
  'auth-otp' => LoopRouteManifest.pathFor('auth-otp'),
  'auth-wallet' => LoopRouteManifest.pathFor('auth-wallet'),
  'wallet-create' => LoopRouteManifest.pathFor('wallet-create'),
  'wallet-recovery' => LoopRouteManifest.pathFor('wallet-recovery'),
  'security-setup' => LoopRouteManifest.pathFor('security-setup'),
  'loop-id-setup' => LoopRouteManifest.pathFor('loop-id-setup'),
  'profile-setup' => LoopRouteManifest.pathFor('loop-id-setup'),
  'community' => LoopRouteManifest.defaultPath,
  'home' => LoopRouteManifest.defaultPath,
  _ => LoopRouteManifest.pathFor('auth'),
};

// Profile screen destinations. Copy permissions live inside Privacy, seed
// backup is replaced by the manifest `key-export` page and rewards by the
// Mining tab; none of the retired ids reaches a dead route.
String _profilePath(String id) => switch (id) {
  'profile' => LoopRouteManifest.pathFor('profile'),
  'friends' => '/profile/friends',
  'wallets' => LoopRouteManifest.pathFor('wallets'),
  'community-discover' => LoopRouteManifest.pathFor('community-discover'),
  'launch-history' => LoopRouteManifest.pathFor('launch-history'),
  'launch-tier' => LoopRouteManifest.pathFor('launch-tier'),
  'profile-edit' => LoopRouteManifest.pathFor('profile-edit'),
  'privacy' => LoopRouteManifest.pathFor('privacy'),
  'social-privacy' => LoopRouteManifest.pathFor('privacy'),
  'copytrade-perms' => LoopRouteManifest.pathFor('privacy'),
  'security' => LoopRouteManifest.pathFor('security'),
  'devices' => LoopRouteManifest.pathFor('devices'),
  'social-recovery' => LoopRouteManifest.pathFor('social-recovery'),
  'notif-settings' => LoopRouteManifest.pathFor('notif-settings'),
  'connections' => LoopRouteManifest.pathFor('connections'),
  'blocklist' => LoopRouteManifest.pathFor('blocklist'),
  'settings' => LoopRouteManifest.pathFor('settings'),
  'about' => LoopRouteManifest.pathFor('about'),
  'support' => LoopRouteManifest.pathFor('support'),
  'mining' => LoopRouteManifest.pathFor('mining'),
  'referral' => LoopRouteManifest.pathFor('referral'),
  _ => LoopRouteManifest.pathFor('profile'),
};

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
          title: 'This location is not in the 93-route product map',
          message: 'Return to Community. The request has been recorded.',
          icon: Icons.route_outlined,
          tone: LoopTone.warning,
          action: FilledButton(
            onPressed: () => context.go(LoopRouteManifest.defaultPath),
            child: const Text('Go to Community'),
          ),
        ),
      ],
    );
  }
}

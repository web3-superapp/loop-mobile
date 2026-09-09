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
import 'package:loop_mobile/core/navigation/launch_route.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/navigation/loop_routing_error_log.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/policy/loop_client_policy.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/loop_id_setup_screen.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/features/account/privy_otp_screen.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/chat.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/chat_search_screen.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_ai_screen.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/market/market.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/blocklist_screen.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/features/shell/loop_pending_surface.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/features/wallet/wallet_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_coordinator.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
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

/// Chooses between the labelled Development Preview surface and the V2
/// production page for one chat route.
///
/// The Preview keeps its own fixture conversation, which decision 0025 binds
/// to an exact conversation ID; production never sees it. The two never share
/// a widget, so a fixture cannot leak into a server-backed surface.
Widget _chatSurface({
  required Widget Function() preview,
  required Widget Function() production,
}) => Consumer(
  builder: (context, ref, child) =>
      ref.watch(communicationGatewayProvider).mode == CommunicationMode.preview
      ? preview()
      : production(),
);

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
              child: MiningScreen(
                onOpenAssets: () =>
                    context.push(LoopRouteManifest.pathFor('mining-assets')),
                onOpenRewards: () =>
                    context.push(LoopRouteManifest.pathFor('mining-rewards')),
                onOpenRank: () =>
                    context.push(LoopRouteManifest.pathFor('mining-rank')),
                onOpenRules: () =>
                    context.push(LoopRouteManifest.pathFor('mining-rules')),
                onOpenReferral: () =>
                    context.push(LoopRouteManifest.pathFor('referral')),
              ),
            ),
          ),
          GoRoute(
            path: '/launch',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: LaunchScreen(
                onOpenLaunch: (launchId) =>
                    context.push(LaunchRoute.detail(launchId)),
                onOpenStake: () =>
                    context.push(LoopRouteManifest.pathFor('loop-stake')),
                onOpenRules: () =>
                    context.push(LoopRouteManifest.pathFor('launch-rounds')),
                onOpenEconomy: () =>
                    context.push(LoopRouteManifest.pathFor('loop-economy')),
                onOpenApply: () =>
                    context.push(LoopRouteManifest.pathFor('launch-apply')),
              ),
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
        builder: (context, state) => GlobalSearchScreen(
          initialQuery: state.uri.queryParameters['q'],
          onBack: () => _popOrHome(context),
          // A `publicProfile` result opens the shared public-profile sheet
          // inside the page; LOOP has no route for another account.
          onOpenCommunity: (communityId) =>
              context.push('/community/profile?id=$communityId'),
        ),
      ),
      GoRoute(
        path: '/community/discover',
        builder: (context, state) => CommunityDiscoverScreen(
          joinedOnly: state.uri.queryParameters['membership'] == 'joined',
          onBack: () => _popOrHome(context),
          onOpenCommunity: (communityId) =>
              context.push('/community/profile?id=$communityId'),
        ),
      ),
      GoRoute(
        path: '/community/profile',
        builder: (context, state) => CommunityProfileScreen(
          communityId: state.uri.queryParameters['id'],
          onBack: () => _popOrHome(context),
          onOpenMembers: (communityId) =>
              context.push('/community/members?id=$communityId'),
          onOpenChat: (communityId) =>
              context.push('/community/chat?id=$communityId'),
          onOpenVoiceRoom: (communityId) =>
              context.push('/chat/voice?id=$communityId'),
          onOpenMiningPanel: (communityId) =>
              context.push(MiningRoute.community(communityId)),
        ),
      ),
      GoRoute(
        path: '/community/members',
        builder: (context, state) => CommunityMembersScreen(
          communityId: state.uri.queryParameters['id'],
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/community/chat',
        builder: (context, state) => CommunityChatScreen(
          communityId: state.uri.queryParameters['id'],
          onBack: () => _popOrHome(context),
          onOpenProfile: (communityId) =>
              context.push('/community/profile?id=$communityId'),
          onOpenVoiceRoom: (communityId) =>
              context.push('/chat/voice?id=$communityId'),
          onOpenSearch: (cid) =>
              context.push('/chat/search?cid=${Uri.encodeComponent(cid)}'),
          onOpenForward: (cid) =>
              context.push('/chat/forward?cid=${Uri.encodeComponent(cid)}'),
        ),
      ),
      GoRoute(
        path: '/community/ai',
        builder: (context, state) => CommunityAiScreen(
          communityId: state.uri.queryParameters['id'],
          onBack: () => _popOrHome(context),
        ),
      ),
      // Manifest `networth` (legacy `/home/net-worth`, retired with Home).
      GoRoute(
        path: '/wallet/networth',
        builder: (context, state) =>
            NetWorthScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: MarketAssetRoute.tokenPath,
        builder: (context, state) => TokenDetailScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.tokenPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: MarketAssetRoute.chartPath,
        builder: (context, state) => FullChartScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.chartPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/market/new',
        builder: (context, state) =>
            NewPairsScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: MarketAssetRoute.holdersPath,
        builder: (context, state) => HolderDistributionScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.holdersPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: MarketAssetRoute.tradesPath,
        builder: (context, state) => TradingActivityScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.tradesPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/market/watchlist',
        builder: (context, state) =>
            WatchlistEditorScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: MarketAssetRoute.alertsPath,
        builder: (context, state) => PriceAlertsScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.alertsPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/market/smart-money',
        builder: (context, state) =>
            SmartMoneyScreen(onBack: () => _popOrHome(context)),
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
        path: '/chat/group',
        builder: (context, state) => _chatSurface(
          preview: () => ChatPreviewRouteGuard(
            surfaceLabel: 'Group conversation',
            child: GroupChatPage(
              conversationId:
                  PreviewConversationIdentity.readSingleConversationId(
                    state.uri,
                  ) ??
                  '',
            ),
          ),
          production: () => GroupChatScreen(
            channelCid: state.uri.queryParameters['cid'],
            onBack: () => _popOrHome(context),
            onOpenInfo: (cid) => context.push(
              '/chat/group-info?cid=${Uri.encodeComponent(cid)}',
            ),
            onOpenSearch: (cid) =>
                context.push('/chat/search?cid=${Uri.encodeComponent(cid)}'),
            onOpenForward: (cid) =>
                context.push('/chat/forward?cid=${Uri.encodeComponent(cid)}'),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/dm',
        builder: (context, state) => _chatSurface(
          preview: () => ChatPreviewRouteGuard(
            surfaceLabel: 'Direct conversation',
            child: DirectMessagePage(
              conversationId:
                  PreviewConversationIdentity.readSingleConversationId(
                    state.uri,
                  ) ??
                  '',
            ),
          ),
          production: () => DirectMessageScreen(
            target: state.extra is DirectMessageTarget
                ? state.extra! as DirectMessageTarget
                : null,
            channelCid: state.uri.queryParameters['cid'],
            onBack: () => _popOrHome(context),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/voice',
        builder: (context, state) => _chatSurface(
          preview: () => const VoiceRoomPage(),
          production: () => VoiceRoomScreen(
            communityId: state.uri.queryParameters['id'],
            onBack: () => _popOrHome(context),
            onOpenExpanded: (id) => context.push('/chat/voice/full?id=$id'),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/voice/full',
        builder: (context, state) => _chatSurface(
          preview: () => const VoiceRoomPage(),
          production: () => VoiceRoomScreen(
            communityId: state.uri.queryParameters['id'],
            expanded: true,
            onBack: () => _popOrHome(context),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/group-info',
        builder: (context, state) => _chatSurface(
          preview: () => ChatPreviewRouteGuard(
            surfaceLabel: 'Group information',
            child: GroupInfoPage(
              conversationId:
                  PreviewConversationIdentity.readSingleConversationId(
                    state.uri,
                  ) ??
                  '',
            ),
          ),
          production: () => GroupInfoScreen(
            channelCid: state.uri.queryParameters['cid'],
            onBack: () => _popOrHome(context),
            onLeft: () => context.go('/community'),
          ),
        ),
      ),
      GoRoute(
        path: '/chat/requests',
        builder: (context, state) =>
            MessageRequestsScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/chat/search',
        builder: (context, state) => _chatSurface(
          preview: () => ChatPreviewRouteGuard(
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
          production: () => ChatSearchScreen(
            key: ValueKey<String>('chat-search-${state.uri}'),
            originCid: state.uri.queryParameters['cid'],
            onBack: () => _popOrHome(context),
            onOpen: (cid) {
              final location = loopChatLocationForCid(cid);
              if (location != null) context.push(location);
            },
          ),
        ),
      ),
      GoRoute(
        path: '/chat/forward',
        builder: (context, state) => ChatForwardScreen(
          sourceCid: state.uri.queryParameters['cid'],
          onBack: () => _popOrHome(context),
          onOpenMergePreview: () => context.push('/chat/merge-preview'),
        ),
      ),
      GoRoute(
        path: '/chat/merge-preview',
        builder: (context, state) =>
            ChatMergePreviewScreen(onBack: () => _popOrHome(context)),
      ),
      // Compatibility deep link for installed clients and notification
      // payloads: a channel CID resolves to the surface its LOOP-assigned
      // prefix names, and an unknown shape falls through to the unmatched
      // handler rather than opening a generic channel page.
      GoRoute(
        path: '/chat/channel/:cid',
        redirect: (context, state) =>
            loopChatLocationForCid(state.pathParameters['cid'] ?? '') ??
            routingErrors.record(state.uri.toString()),
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
        path: MarketAssetRoute.walletAssetPath,
        builder: (context, state) => WalletAssetScreen(
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.walletAssetPath,
          ),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/send',
        builder: (context, state) =>
            SendAssetScreen(onBack: () => _popOrHome(context)),
      ),
      // The Send draft travels as typed navigation state: an asset, a wallet
      // and the exact text the owner typed never belong in a URL.
      GoRoute(
        path: '/wallet/send/to',
        redirect: (context, state) =>
            state.extra is SendDraft ? null : '/wallet/send',
        builder: (context, state) => SendRecipientScreen(
          draft: state.extra! as SendDraft,
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/send/confirm',
        redirect: (context, state) {
          final draft = state.extra;
          return draft is SendDraft && draft.isComplete ? null : '/wallet/send';
        },
        builder: (context, state) => SendConfirmScreen(
          draft: state.extra! as SendDraft,
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: WalletRoute.receivePath,
        builder: (context, state) => ReceiveScreen(
          walletId: WalletRoute.parse(state.uri, WalletRoute.receivePath),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/swap',
        builder: (context, state) =>
            SwapScreen(onBack: () => _popOrHome(context)),
      ),
      // The quote object itself travels to the detail page, so the read-only
      // view can never show a different quote from the one being confirmed.
      GoRoute(
        path: '/wallet/swap/route',
        redirect: (context, state) =>
            state.extra is LoopSwapQuoteView ? null : '/wallet/swap',
        builder: (context, state) => SwapRouteScreen(
          quote: state.extra! as LoopSwapQuoteView,
          onBack: () => _popOrHome(context),
        ),
      ),
      // D21: `bridge` and `bridge-status` are entry points only. The status
      // page is reachable on its own because there is nothing to carry into
      // it: all three steps are pending and none of them has a source.
      GoRoute(
        path: '/wallet/bridge',
        builder: (context, state) => BridgeScreen(
          onBack: () => _popOrHome(context),
          onOpenStatus: () => context.push('/wallet/bridge/status'),
        ),
      ),
      GoRoute(
        path: '/wallet/bridge/status',
        builder: (context, state) => BridgeStatusScreen(
          onBack: () => _popOrHome(context),
          onOpenWallet: () => context.go(LoopRouteManifest.pathFor('wallet')),
        ),
      ),
      // Manifest `tx-result` (legacy `/wallet/transaction`). The intent id is
      // an opaque server id and is the only thing this page needs, so it may
      // travel in the query and survive a cold restore.
      GoRoute(
        path: '/wallet/tx/result',
        builder: (context, state) => TransactionResultScreen(
          intentId: _intentIdOf(state.uri),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: WalletRoute.historyPath,
        builder: (context, state) => TransactionHistoryScreen(
          walletId: WalletRoute.parse(state.uri, WalletRoute.historyPath),
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/manage',
        builder: (context, state) =>
            WalletManagerScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/wallet/dapp',
        builder: (context, state) =>
            DappReviewScreen(onBack: () => _popOrHome(context)),
      ),
      // Manifest `approval-guard` (legacy `/preview/approval`). The guard is a
      // real money action now, so it lives under `/wallet`.
      GoRoute(
        path: '/wallet/approval-guard',
        redirect: (context, state) =>
            state.extra is ApprovalGuardRequest ? null : '/wallet/approvals',
        builder: (context, state) => ApprovalGuardScreen(
          request: state.extra! as ApprovalGuardRequest,
          onBack: () => _popOrHome(context),
        ),
      ),
      GoRoute(
        path: '/wallet/approvals',
        builder: (context, state) =>
            ApprovalsScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/wallet/networks',
        builder: (context, state) =>
            NetworksScreen(onBack: () => _popOrHome(context)),
      ),
      ..._profileRoutes,
      GoRoute(
        path: '/profile/connections',
        builder: (context, state) => ConnectionsScreen(
          onBack: () => _popOrHome(context),
          // The identity travels as typed navigation state, never in the URL:
          // a deep link must not be able to put an unverified alias in the
          // conversation header.
          onOpenConversation: (publicProfileId) => context.push(
            '/chat/dm',
            extra: DirectMessageTarget(publicProfileId: publicProfileId),
          ),
        ),
      ),
      GoRoute(
        path: '/profile/blocked',
        builder: (context, state) =>
            BlocklistScreen(onBack: () => _popOrHome(context)),
      ),
      GoRoute(
        path: '/profile/referral',
        builder: (context, state) => ReferralScreen(
          onBack: () => _popOrHome(context),
          onOpenMining: () => context.go(LoopRouteManifest.pathFor('mining')),
        ),
      ),
      ..._systemRoutes,
      // Manifest `pay`: reached from Wallet, unavailable with the server's own
      // `PAY_RUNTIME_DEFERRED` (fail closed).
      GoRoute(
        path: '/pay',
        builder: (context, state) =>
            PayScreen(onBack: () => _popOrHome(context)),
      ),
      ..._launchRoutes,
      ..._miningRoutes,
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

/// The eleven Launch pages. Each record page carries its subject as the exact
/// `launchId` query parameter produced by [LaunchRoute]; a missing or
/// malformed value fails closed into the page's unavailable state rather than
/// substituting another project.
final List<RouteBase> _launchRoutes = <RouteBase>[
  GoRoute(
    path: LaunchRoute.detailPath,
    builder: (context, state) => LaunchDetailScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.detailPath),
      onBack: () => _popOrHome(context),
      onOpenTier: () => _pushLaunchChild(context, state, LaunchRoute.tierPath),
      onOpenRounds: () =>
          _pushLaunchChild(context, state, LaunchRoute.roundsPath),
      onOpenTrade: () =>
          _pushLaunchChild(context, state, LaunchRoute.tradePath),
      onOpenHolders: () =>
          _pushLaunchChild(context, state, LaunchRoute.holdersPath),
      onOpenGraduation: () =>
          _pushLaunchChild(context, state, LaunchRoute.graduationPath),
      onOpenHistory: () =>
          _pushLaunchChild(context, state, LaunchRoute.historyPath),
    ),
  ),
  GoRoute(
    path: LaunchRoute.tierPath,
    builder: (context, state) => LaunchTierScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.tierPath),
      onBack: () => _popOrHome(context),
      onOpenStake: () => context.push(LoopRouteManifest.pathFor('loop-stake')),
    ),
  ),
  GoRoute(
    path: LaunchRoute.tradePath,
    builder: (context, state) => LaunchTradeScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.tradePath),
      onBack: () => _popOrHome(context),
      onOpenHolders: () =>
          _pushLaunchChild(context, state, LaunchRoute.holdersPath),
    ),
  ),
  GoRoute(
    path: LaunchRoute.holdersPath,
    builder: (context, state) => LaunchHoldersScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.holdersPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: LaunchRoute.graduationPath,
    builder: (context, state) => LaunchGraduationScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.graduationPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: LaunchRoute.historyPath,
    builder: (context, state) => LaunchHistoryScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.historyPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: LaunchRoute.roundsPath,
    builder: (context, state) => LaunchRoundsScreen(
      launchId: LaunchRoute.parse(state.uri, LaunchRoute.roundsPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: '/launch/loop-stake',
    builder: (context, state) =>
        LoopStakeScreen(onBack: () => _popOrHome(context)),
  ),
  GoRoute(
    path: '/launch/loop-economy',
    builder: (context, state) =>
        LoopEconomyScreen(onBack: () => _popOrHome(context)),
  ),
  GoRoute(
    path: '/launch/apply',
    builder: (context, state) =>
        LaunchApplyScreen(onBack: () => _popOrHome(context)),
  ),
];

/// Carries the current page's launch identity to a sibling record page. When
/// the current location has no canonical identity the sibling is opened
/// without one and renders its own unavailable state.
void _pushLaunchChild(BuildContext context, GoRouterState state, String path) {
  final launchId = LaunchRoute.parse(state.uri, state.uri.path);
  context.push(launchId == null ? path : LaunchRoute.location(path, launchId));
}

/// The five Mining child pages.
final List<RouteBase> _miningRoutes = <RouteBase>[
  GoRoute(
    path: '/mining/assets',
    builder: (context, state) => MiningAssetsScreen(
      onBack: () => _popOrHome(context),
      onOpenRules: () =>
          context.push(LoopRouteManifest.pathFor('mining-rules')),
    ),
  ),
  GoRoute(
    path: '/mining/rewards',
    builder: (context, state) =>
        MiningRewardsScreen(onBack: () => _popOrHome(context)),
  ),
  GoRoute(
    path: '/mining/rank',
    builder: (context, state) =>
        MiningRankScreen(onBack: () => _popOrHome(context)),
  ),
  GoRoute(
    path: MiningRoute.communityPath,
    builder: (context, state) => MiningCommunityScreen(
      communityId: MiningRoute.parse(state.uri, MiningRoute.communityPath),
      onBack: () => _popOrHome(context),
    ),
  ),
  GoRoute(
    path: '/mining/rules',
    builder: (context, state) => MiningRulesScreen(
      onBack: () => _popOrHome(context),
      onOpenReferral: () => context.push(LoopRouteManifest.pathFor('referral')),
    ),
  ),
];

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
          ('/profile/key-export', 'key-export'),
          ('/profile/social-recovery', 'social-recovery'),
          ('/profile/notifications', 'notif-settings'),
          ('/profile/settings', 'settings'),
          ('/profile/about', 'about'),
          ('/profile/help', 'support'),
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

/// Pops when the page was pushed, otherwise lands on the manifest default.
/// The opaque intent id carried by `/wallet/tx/result?intentId=`.
///
/// A value that is not a canonical UUIDv4 is dropped rather than requested:
/// the result page then renders its empty state instead of asking the server
/// about an id a deep link invented.
String? _intentIdOf(Uri uri) {
  final value = uri.queryParameters['intentId'];
  if (value == null || !LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
    return null;
  }
  return value;
}

void _popOrHome(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    context.pop();
  } else {
    context.go(LoopRouteManifest.defaultPath);
  }
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
  // `/profile/friends` and `/chat/friends/add` were folded into `search`
  // and `connections` in step 3; step 4 folded the V1 request inbox into the
  // `dm-requests` page, so the profile row now opens that manifest slug.
  'friend-requests' => LoopRouteManifest.pathFor('dm-requests'),
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
  'key-export' => LoopRouteManifest.pathFor('key-export'),
  'social-recovery' => LoopRouteManifest.pathFor('social-recovery'),
  'networks' => LoopRouteManifest.pathFor('networks'),
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

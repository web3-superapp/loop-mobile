import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/about/about_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/security/security_gateway.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/support/support_gateway.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_display_store.dart';
import 'package:loop_mobile/integrations/personalization/loop_personalization_providers.dart';
import 'package:loop_mobile/integrations/social/loop_social_providers.dart';
import 'package:loop_mobile/integrations/social/loop_group_alias_providers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_communication_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s6_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s8_providers.dart';
import 'package:loop_mobile/integrations/sharing/system_chat_merge_export_sink.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final displayBootstrap = await bootstrapSharedPreferencesDisplayPreferences();
  runApp(
    ProviderScope(
      overrides: [
        loopDisplayPreferencesStoreProvider.overrideWithValue(
          displayBootstrap.store,
        ),
        loopDisplayPreferencesInitialProvider.overrideWithValue(
          displayBootstrap.initial,
        ),
        friendGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProductionFriendGatewayProvider),
        ),
        groupAliasGatewayProvider.overrideWith(
          (ref) => ref.watch(loopGroupAliasGatewayProvider),
        ),
        profileGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProfileGatewayProvider),
        ),
        profileActivationGatewayProvider.overrideWith(
          (ref) => ref.watch(loopProfileActivationGatewayProvider),
        ),
        avatarCatalogGatewayProvider.overrideWith(
          (ref) => ref.watch(loopAvatarCatalogGatewayProvider),
        ),
        privacyGatewayProvider.overrideWith(
          (ref) => ref.watch(loopPrivacyGatewayProvider),
        ),
        communityGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2CommunityGatewayProvider),
        ),
        socialGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SocialGatewayProvider),
        ),
        searchGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SearchGatewayProvider),
        ),
        chatV2GatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2ChatGatewayProvider),
        ),
        voiceRoomGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2VoiceRoomGatewayProvider),
        ),
        // The merged image is encoded on device and handed to the operating
        // system; it never reaches a LOOP service, in either composition.
        chatMergeExportSinkProvider.overrideWithValue(
          const SystemChatMergeExportSink(),
        ),
        // S5 read modules. Each stays fail-closed until its Dio client,
        // client metadata and authenticated session all exist.
        chainGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2ChainGatewayProvider),
        ),
        walletReadGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2WalletReadGatewayProvider),
        ),
        marketReadGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2MarketReadGatewayProvider),
        ),
        watchlistGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2WatchlistGatewayProvider),
        ),
        alertsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2AlertsGatewayProvider),
        ),
        notificationsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2NotificationsGatewayProvider),
        ),
        // S6 money actions. Availability here is transport assembly only: the
        // write switch, the canary ceiling and the device evidence stay
        // server-owned, and every page still reads its capability gate.
        walletIntentsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2WalletIntentsGatewayProvider),
        ),
        swapQuoteGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SwapQuoteGatewayProvider),
        ),
        approvalsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2ApprovalsGatewayProvider),
        ),
        // S7 launch catalogue, mining skeleton and referral graph. Each stays
        // fail-closed until its Dio client, client metadata and authenticated
        // session all exist.
        launchGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2LaunchGatewayProvider),
        ),
        miningGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2MiningGatewayProvider),
        ),
        referralGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2ReferralGatewayProvider),
        ),
        // S8 security / settings / support. `about` is public and needs only a
        // backend origin; the other three also need an authenticated session.
        securityGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SecurityGatewayProvider),
        ),
        accountSettingsGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2AccountSettingsGatewayProvider),
        ),
        supportGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2SupportGatewayProvider),
        ),
        aboutGatewayProvider.overrideWith(
          (ref) => ref.watch(loopV2AboutGatewayProvider),
        ),
      ],
      child: const LoopApp(),
    ),
  );
}

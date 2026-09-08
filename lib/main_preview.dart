import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_fixture_adapter.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_trading_gateway.dart';
import 'package:loop_mobile/integrations/personalization/memory_privacy_gateway.dart';
import 'package:loop_mobile/integrations/personalization/memory_profile_gateway.dart';
import 'package:loop_mobile/integrations/personalization/memory_social_privacy_gateway.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_display_store.dart';
import 'package:loop_mobile/integrations/privy/privy_fixture_adapter.dart';
import 'package:loop_mobile/features/system/system_showcase_preview.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/social/memory_friend_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/integrations/communication/memory_chat_v2_gateways.dart';
import 'package:loop_mobile/integrations/community/memory_community_gateways.dart';
import 'package:loop_mobile/integrations/sharing/system_chat_merge_export_sink.dart';

/// Explicit offline UI catalog entry point.
///
/// Run with `bin/flutter run -t lib/main_preview.dart`, then choose
/// Development Preview on the login screen. Chat, wallet, trading, and owner
/// settings stay in labelled memory-only Preview adapters. The Market tab may
/// still read public, identity-free Hyperliquid Testnet spot facts.
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
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: '',
            privyAppClientId: '',
            reownProjectId: '',
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
        developmentPreviewEnabledProvider.overrideWithValue(true),
        communicationGatewayProvider.overrideWithValue(
          MemoryCommunicationGateway(),
        ),
        friendGatewayProvider.overrideWithValue(MemoryFriendGateway()),
        // Labelled memory-only S3 adapters. Every surface backed by one of
        // these renders the visible 演示数据 notice.
        communityGatewayProvider.overrideWithValue(MemoryCommunityGateway()),
        socialGatewayProvider.overrideWithValue(MemorySocialGateway()),
        searchGatewayProvider.overrideWithValue(const MemorySearchGateway()),
        chatV2GatewayProvider.overrideWithValue(MemoryChatV2Gateway()),
        voiceRoomGatewayProvider.overrideWithValue(MemoryVoiceRoomGateway()),
        // The merged image is encoded on device and handed to the operating
        // system; it never reaches a LOOP service, in either composition.
        chatMergeExportSinkProvider.overrideWithValue(
          const SystemChatMergeExportSink(),
        ),
        // Step 5 retired the Preview Watchlist and notification-preference
        // adapters with the V1 modules they implemented (decision 0057). Both
        // surfaces are unavailable in Preview rather than showing a fixture
        // written against a contract that no longer exists.
        privacyGatewayProvider.overrideWithValue(
          MemoryPrivacyGateway(
            initialResource: PrivacyResource(
              version: 1,
              values: const PrivacyValues.defaults(),
              updatedAt: DateTime.utc(2026, 8, 25),
            ),
          ),
        ),
        socialPrivacyGatewayProvider.overrideWithValue(
          MemorySocialPrivacyGateway(
            initialResource: SocialPrivacyResource(
              version: 1,
              values: const SocialPrivacyValues.defaults(),
              updatedAt: DateTime.utc(2026, 8, 31),
            ),
          ),
        ),
        profileGatewayProvider.overrideWithValue(
          MemoryProfileGateway(
            initialResource: ProfileResource(
              version: 1,
              values: ProfileValues(alias: 'QuietComet', avatarRef: null),
              updatedAt: DateTime.utc(2026, 8, 25),
            ),
          ),
        ),
        hyperliquidTradingGatewayProvider.overrideWithValue(
          const HyperliquidFixtureAdapter(),
        ),
        walletSigningGatewayProvider.overrideWithValue(
          const PrivyFixtureAdapter(),
        ),
        // Component showcases (token-card-states / sign-sheet-states) carry
        // fixture figures, so only this Preview root may supply them.
        loopSystemShowcaseProvider.overrideWithValue(
          buildLoopSystemShowcasePreview(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
}

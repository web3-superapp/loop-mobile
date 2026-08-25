import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_gateway.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_fixture_adapter.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_trading_gateway.dart';
import 'package:loop_mobile/integrations/personalization/memory_notification_preferences_gateway.dart';
import 'package:loop_mobile/integrations/personalization/memory_privacy_gateway.dart';
import 'package:loop_mobile/integrations/personalization/memory_profile_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_fixture_adapter.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/personalization/memory_watchlist_gateway.dart';

/// Explicit offline UI catalog entry point.
///
/// Run with `bin/flutter run -t lib/main_preview.dart`, then choose
/// Development Preview on the login screen. Chat, wallet, trading, and owner
/// settings stay in labelled memory-only Preview adapters. The Market tab may
/// still read public, identity-free Hyperliquid Testnet spot facts.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: '',
            privyAppClientId: '',
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
        developmentPreviewEnabledProvider.overrideWithValue(true),
        communicationGatewayProvider.overrideWithValue(
          MemoryCommunicationGateway(),
        ),
        notificationPreferencesGatewayProvider.overrideWithValue(
          MemoryNotificationPreferencesGateway(
            initialResource: NotificationPreferencesResource(
              version: 1,
              values: const NotificationPreferenceValues.disabled(),
              delivery: NotificationDeliveryState.unavailable,
            ),
          ),
        ),
        privacyGatewayProvider.overrideWithValue(
          MemoryPrivacyGateway(
            initialResource: PrivacyResource(
              version: 1,
              values: const PrivacyValues.defaults(),
              updatedAt: DateTime.utc(2026, 8, 25),
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
        watchlistGatewayProvider.overrideWithValue(
          MemoryWatchlistGateway(
            initialSnapshot: WatchlistSnapshot(
              version: 1,
              groups: <WatchlistGroup>[
                WatchlistGroup(
                  key: 'core',
                  name: 'Core',
                  items: <WatchlistItem>[
                    WatchlistItem(assetKey: 'BTC'),
                    WatchlistItem(assetKey: 'ETH'),
                    WatchlistItem(assetKey: 'SOL'),
                  ],
                ),
              ],
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
      ],
      child: const LoopApp(),
    ),
  );
}

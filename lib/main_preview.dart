import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_fixture_adapter.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_trading_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_fixture_adapter.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';

/// Explicit offline UI catalog entry point.
///
/// Run with `bin/flutter run -t lib/main_preview.dart`, then choose
/// Development Preview on the login screen. No provider operation is enabled.
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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_fixture_adapter.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_trading_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_fixture_adapter.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // Explicit UI Preview composition root. A production entry point must not
    // reuse these memory/fixture overrides.
    ProviderScope(
      overrides: [
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

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  testWidgets(
    'explicit Preview shows live public Spot and an interactive offline Chat',
    (tester) async {
      final spotRepository = _PreviewSpotRepository();
      final communicationGateway = MemoryCommunicationGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const UnconfiguredPrivyAuthGateway(),
            ),
            developmentPreviewEnabledProvider.overrideWithValue(true),
            communicationGatewayProvider.overrideWithValue(
              communicationGateway,
            ),
            hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
              spotRepository,
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter development preview'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'Market'));
      await tester.pumpAndSettle();

      expect(spotRepository.fetchCount, 1);
      expect(find.text('HYPE/USDC'), findsOneWidget);
      expect(find.text('TESTNET · SPOT · 实时公共数据 · 只读'), findsOneWidget);
      expect(find.textContaining('Buy'), findsNothing);
      expect(find.textContaining('Sell'), findsNothing);

      final spotRow = find.byKey(const ValueKey<String>('spot-market-1035'));
      await tester.ensureVisible(spotRow);
      await tester.pumpAndSettle();
      await tester.tap(spotRow);
      await tester.pumpAndSettle();

      expect(
        find.text('C2 · HYPERLIQUID TESTNET · SPOT #1035'),
        findsOneWidget,
      );
      expect(find.text('HYPE/USDC'), findsOneWidget);
      expect(find.text('46.25 USDC'), findsWidgets);
      expect(
        find.text('Client received 2026-08-25 12:30:00 UTC'),
        findsOneWidget,
      );
      expect(find.textContaining('Buy'), findsNothing);
      expect(find.textContaining('Sell'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, 'Chat'));
      await tester.pumpAndSettle();

      expect(find.text('Offline preview · not connected'), findsWidgets);
      expect(find.text('Glyph Hunters'), findsOneWidget);
      expect(find.text('ETH Macro Room'), findsOneWidget);
      expect(find.text('0xSable'), findsOneWidget);

      final group = find.text('Glyph Hunters');
      await tester.ensureVisible(group);
      await tester.pumpAndSettle();
      await tester.tap(group);
      await tester.pumpAndSettle();

      expect(
        find.text('Offline preview · simulated conversation'),
        findsOneWidget,
      );
      expect(find.text('NightOwl'), findsWidgets);
      expect(find.text('GLYPH'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'Local preview hello');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      final messages = await communicationGateway.loadMessages(
        ChatContent.groupId,
      );
      expect(messages.value?.last.text, 'Local preview hello');
      expect(
        find.text('Simulated message added to the offline preview.'),
        findsOneWidget,
      );
    },
  );
}

final class _PreviewSpotRepository implements HyperliquidSpotMarketRepository {
  var fetchCount = 0;

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    fetchCount += 1;
    return HyperliquidSpotSnapshot(
      receivedAt: DateTime.utc(2026, 8, 25, 12, 30),
      markets: <HyperliquidSpotMarket>[
        HyperliquidSpotMarket(
          spotIndex: 1035,
          providerCoin: '@1035',
          baseTokenIndex: 1105,
          quoteTokenIndex: 0,
          baseTokenId: '0x11111111111111111111111111111111',
          quoteTokenId: '0x00000000000000000000000000000000',
          baseSymbol: 'HYPE',
          quoteSymbol: 'USDC',
          baseSizeDecimals: 2,
          isCanonical: true,
          markPrice: HyperliquidSpotDecimal(
            source: '46.25',
            value: Decimal.parse('46.25'),
          ),
          previousDayPrice: HyperliquidSpotDecimal(
            source: '45.00',
            value: Decimal.parse('45.00'),
          ),
          dayNotionalVolume: HyperliquidSpotDecimal(
            source: '1234567.89',
            value: Decimal.parse('1234567.89'),
          ),
          dayBaseVolume: HyperliquidSpotDecimal(
            source: '27000.10',
            value: Decimal.parse('27000.10'),
          ),
        ),
      ],
    );
  }
}

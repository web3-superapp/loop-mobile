import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';

const String _asset = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';

/// The canonical serialisation percent-encodes the CAIP separators, so this is
/// the only spelling of [_asset] a location may carry.
const String _encoded =
    'eip155%3A56%3A0x55d398326f99059ff775485246999027b3197955';
const String _wallet = '3f2a1c4e-8b7d-4a19-9c02-5e6f7a8b9c0d';

void main() {
  group('MarketAssetRoute', () {
    test('accepts only canonical CAIP asset identities', () {
      expect(MarketAssetRoute.isCanonical(_asset), isTrue);
      expect(MarketAssetRoute.isCanonical('eip155:1:native'), isTrue);

      for (final candidate in <String>[
        'PEPE',
        '0x55d398326f99059ff775485246999027b3197955',
        'eip155:0:native',
        'eip155:56:0x55D398326F99059FF775485246999027B3197955',
        'eip155:56:0x55d398326f99059ff775485246999027b31979',
        'eip155:56:native ',
        'eip155:56',
        'solana:mainnet:native',
      ]) {
        expect(
          MarketAssetRoute.isCanonical(candidate),
          isFalse,
          reason: candidate,
        );
      }
    });

    test('round-trips every asset page through the canonical identity', () {
      final locations = <String, String>{
        MarketAssetRoute.tokenPath: MarketAssetRoute.token(_asset),
        MarketAssetRoute.chartPath: MarketAssetRoute.chart(_asset),
        MarketAssetRoute.holdersPath: MarketAssetRoute.holders(_asset),
        MarketAssetRoute.tradesPath: MarketAssetRoute.trades(_asset),
        MarketAssetRoute.alertsPath: MarketAssetRoute.alerts(_asset),
        MarketAssetRoute.walletAssetPath: MarketAssetRoute.walletAsset(_asset),
      };

      expect(
        locations[MarketAssetRoute.tokenPath],
        '/market/token?assetId=$_encoded',
      );
      expect(
        locations[MarketAssetRoute.chartPath],
        '/market/chart?assetId=$_encoded',
      );
      expect(
        locations[MarketAssetRoute.holdersPath],
        '/market/holders?assetId=$_encoded',
      );
      expect(
        locations[MarketAssetRoute.tradesPath],
        '/market/trades?assetId=$_encoded',
      );
      expect(
        locations[MarketAssetRoute.alertsPath],
        '/market/alerts?assetId=$_encoded',
      );
      expect(
        locations[MarketAssetRoute.walletAssetPath],
        '/wallet/asset?assetId=$_encoded',
      );

      for (final entry in locations.entries) {
        expect(
          MarketAssetRoute.parse(Uri.parse(entry.value), entry.key),
          _asset,
          reason: entry.key,
        );
      }
    });

    test('refuses to build a location for a non-canonical asset', () {
      expect(() => MarketAssetRoute.token('PEPE'), throwsArgumentError);
      expect(
        () => MarketAssetRoute.walletAsset('eip155:56:0xABC'),
        throwsArgumentError,
      );
    });

    test('parses no asset from a missing, repeated, extra, or malformed '
        'parameter', () {
      for (final location in <String>[
        '/market/token',
        '/market/token?',
        '/market/token?assetId=',
        '/market/token?assetId=$_encoded&assetId=eip155%3A1%3Anative',
        '/market/token?assetId=$_encoded&source=preview',
        '/market/token?assetId=$_encoded#fragment',
        '/market/token?symbol=PEPE',
        '/market/token?assetid=$_encoded',
        '/market/token?assetId=PEPE',
        '/market/token?assetId=eip155%3A56%3A0x55D398326F99059FF775485246999027B3197955',
        '/market/token?assetId=eip155%3A0%3Anative',
        // The same asset spelled outside the canonical serialisation.
        '/market/token?assetId=$_asset',
        'https://loop.invalid/market/token?assetId=$_encoded',
      ]) {
        expect(
          MarketAssetRoute.parse(
            Uri.parse(location),
            MarketAssetRoute.tokenPath,
          ),
          isNull,
          reason: location,
        );
      }
    });

    test('never reads one page identity from another page path', () {
      final token = Uri.parse(MarketAssetRoute.token(_asset));
      for (final path in <String>[
        MarketAssetRoute.chartPath,
        MarketAssetRoute.holdersPath,
        MarketAssetRoute.tradesPath,
        MarketAssetRoute.alertsPath,
        MarketAssetRoute.walletAssetPath,
        '/market',
        '/market/token/',
      ]) {
        expect(MarketAssetRoute.parse(token, path), isNull, reason: path);
      }
    });
  });

  group('WalletRoute', () {
    test('accepts only an opaque UUIDv4 wallet identity', () {
      expect(WalletRoute.isCanonical(_wallet), isTrue);

      for (final candidate in <String>[
        '0x1234567890123456789012345678901234567890',
        'primary',
        '3F2A1C4E-8B7D-4A19-9C02-5E6F7A8B9C0D',
        '3f2a1c4e-8b7d-1a19-9c02-5e6f7a8b9c0d',
        '3f2a1c4e-8b7d-4a19-cc02-5e6f7a8b9c0d',
        '3f2a1c4e8b7d4a199c025e6f7a8b9c0d',
      ]) {
        expect(WalletRoute.isCanonical(candidate), isFalse, reason: candidate);
      }
    });

    test('round-trips the receive and history locations', () {
      expect(WalletRoute.receive(_wallet), '/wallet/receive?walletId=$_wallet');
      expect(WalletRoute.history(_wallet), '/wallet/history?walletId=$_wallet');
      expect(
        WalletRoute.parse(
          Uri.parse(WalletRoute.receive(_wallet)),
          WalletRoute.receivePath,
        ),
        _wallet,
      );
      expect(
        WalletRoute.parse(
          Uri.parse(WalletRoute.history(_wallet)),
          WalletRoute.historyPath,
        ),
        _wallet,
      );
    });

    test('refuses to build a location for a client-chosen address', () {
      expect(() => WalletRoute.receive('primary'), throwsArgumentError);
      expect(
        () => WalletRoute.history('0x1234567890123456789012345678901234567890'),
        throwsArgumentError,
      );
    });

    test('parses no wallet from a missing, repeated, extra, or malformed '
        'parameter', () {
      for (final location in <String>[
        '/wallet/receive',
        '/wallet/receive?',
        '/wallet/receive?walletId=',
        '/wallet/receive?walletId=$_wallet&walletId=$_wallet',
        '/wallet/receive?walletId=$_wallet&chain=bsc',
        '/wallet/receive?walletId=$_wallet#fragment',
        '/wallet/receive?address=0x1234567890123456789012345678901234567890',
        '/wallet/receive?walletId=primary',
        'https://loop.invalid/wallet/receive?walletId=$_wallet',
      ]) {
        expect(
          WalletRoute.parse(Uri.parse(location), WalletRoute.receivePath),
          isNull,
          reason: location,
        );
      }
    });

    test('never reads the receive identity from another path', () {
      final receive = Uri.parse(WalletRoute.receive(_wallet));
      for (final path in <String>[
        WalletRoute.historyPath,
        '/wallet',
        '/wallet/receive/',
        MarketAssetRoute.walletAssetPath,
      ]) {
        expect(WalletRoute.parse(receive, path), isNull, reason: path);
      }
    });
  });
}

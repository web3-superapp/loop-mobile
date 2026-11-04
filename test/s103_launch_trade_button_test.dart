import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_chain_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';

/// Decision 0108 · the detail page's 「进入内盘交易」 button follows the chain:
/// enterable only while a round is live and the sale is not paused; every
/// other state turns it off and names the reason on the button.
LaunchOnChainAvailable _chain({
  LaunchSaleState sale = LaunchSaleState.live,
  LaunchEntitlementState entitlement = LaunchEntitlementState.none,
  LaunchLiquidityState liquidity = LaunchLiquidityState.notStarted,
  LaunchOperationalState operational = LaunchOperationalState.active,
}) => LaunchOnChainAvailable(
  saleState: sale,
  entitlementState: entitlement,
  liquidityState: liquidity,
  operationalState: operational,
  stateTupleDigest: '0x00',
  snapshotBlockNumber: '1',
  snapshotBlockHash: '0x00',
  configVersion: '0x00',
);

void main() {
  group('launchTradeButtonSpec', () {
    test('a live, active sale opens the internal market', () {
      final spec = launchTradeButtonSpec(_chain());
      expect(spec.enabled, isTrue);
      expect(spec.label, 'Go to bonding pool trading');
    });

    test('an unavailable chain read keeps the prototype label and opens', () {
      final spec = launchTradeButtonSpec(
        const LaunchOnChainUnavailable('LAUNCH_CHAIN_UNAVAILABLE'),
      );
      expect(spec.enabled, isTrue);
      expect(spec.label, 'Go to bonding pool trading');
    });

    test('paused wins over every sale state', () {
      for (final sale in LaunchSaleState.values) {
        final spec = launchTradeButtonSpec(
          _chain(sale: sale, operational: LaunchOperationalState.paused),
        );
        expect(spec.enabled, isFalse, reason: sale.wireName);
        expect(spec.label, 'Bonding pool paused', reason: sale.wireName);
      }
    });

    test('every non-live sale state is off and names the reason', () {
      expect(launchTradeButtonSpec(_chain(sale: LaunchSaleState.scheduled)), (
        label: 'Bonding pool not started',
        enabled: false,
      ));
      expect(launchTradeButtonSpec(_chain(sale: LaunchSaleState.ended)), (
        label: 'Bonding pool ended, awaiting finalization',
        enabled: false,
      ));
      expect(launchTradeButtonSpec(_chain(sale: LaunchSaleState.failed)), (
        label: 'Bonding pool ended, soft cap not reached',
        enabled: false,
      ));
      expect(launchTradeButtonSpec(_chain(sale: LaunchSaleState.cancelled)), (
        label: 'Bonding pool cancelled',
        enabled: false,
      ));
    });

    test('a succeeded sale reads as graduated once the LP is locked', () {
      expect(
        launchTradeButtonSpec(
          _chain(
            sale: LaunchSaleState.succeeded,
            entitlement: LaunchEntitlementState.frozen,
            liquidity: LaunchLiquidityState.preparing,
          ),
        ),
        (label: 'Bonding pool ended, raise succeeded', enabled: false),
      );
      for (final liquidity in <LaunchLiquidityState>[
        LaunchLiquidityState.lpLocked,
        LaunchLiquidityState.completed,
      ]) {
        expect(
          launchTradeButtonSpec(
            _chain(
              sale: LaunchSaleState.succeeded,
              entitlement: LaunchEntitlementState.completed,
              liquidity: liquidity,
            ),
          ),
          (label: 'Graduated, bonding pool closed', enabled: false),
          reason: liquidity.wireName,
        );
      }
    });
  });
}

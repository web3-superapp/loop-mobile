import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/wallet/wallet_preview_activity.dart';

void main() {
  test('each history filter returns only its labelled Preview category', () {
    expect(
      WalletPreviewActivity.filteredBy(WalletPreviewActivityFilter.all),
      hasLength(3),
    );
    final sent = WalletPreviewActivity.filteredBy(
      WalletPreviewActivityFilter.sent,
    );
    final received = WalletPreviewActivity.filteredBy(
      WalletPreviewActivityFilter.received,
    );
    final swaps = WalletPreviewActivity.filteredBy(
      WalletPreviewActivityFilter.swaps,
    );

    expect(sent, hasLength(1));
    expect(sent.single.kind, WalletPreviewActivityKind.sent);
    expect(sent.single.title, 'Sent ETH');
    expect(received, hasLength(1));
    expect(received.single.kind, WalletPreviewActivityKind.received);
    expect(received.single.title, 'Received USDC');
    expect(swaps, hasLength(1));
    expect(swaps.single.kind, WalletPreviewActivityKind.swap);
    expect(swaps.single.title, 'Swapped ETH to USDC');
  });
}

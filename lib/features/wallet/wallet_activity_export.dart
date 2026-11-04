import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// The result of one wallet-activity export.
enum WalletExportOutcome {
  /// The system share sheet opened with the encoded file.
  shared,

  /// The owner dismissed the sheet without choosing a destination.
  dismissed,

  /// Encoding or the platform share failed. Nothing left the device.
  failed,

  /// No share adapter is composed, so nothing was encoded or handed over.
  unavailable,

  /// There were no rows to export. Nothing was encoded.
  empty,
}

/// Hands one already-encoded CSV to the operating system's share sheet.
///
/// The bytes come from rows the owner can already see on `tx-history`, are
/// never uploaded to a LOOP service, and are not written anywhere the app
/// keeps. The port exists so `lib/features/` never depends on a platform
/// plugin and a test can observe exactly what would have been shared.
abstract interface class WalletActivityExportSink {
  Future<WalletExportOutcome> shareCsv({
    required String csv,
    required String fileName,
  });
}

/// Production-safe default until the composition root supplies an adapter.
final class UnavailableWalletActivityExportSink
    implements WalletActivityExportSink {
  const UnavailableWalletActivityExportSink();

  @override
  Future<WalletExportOutcome> shareCsv({
    required String csv,
    required String fileName,
  }) async => WalletExportOutcome.unavailable;
}

/// Overridden by `main.dart` and `main_preview.dart` with the system adapter.
final walletActivityExportSinkProvider = Provider<WalletActivityExportSink>(
  (ref) => const UnavailableWalletActivityExportSink(),
);

/// zh-CN copy for one export outcome. It states only what happened.
String walletExportMessage(WalletExportOutcome outcome) => switch (outcome) {
  WalletExportOutcome.shared => LoopL10n.current.wallet_activityExportShared,
  WalletExportOutcome.dismissed =>
    LoopL10n.current.wallet_activityExportDismissed,
  WalletExportOutcome.failed => LoopL10n.current.wallet_activityExportFailed,
  WalletExportOutcome.unavailable =>
    LoopL10n.current.wallet_activityExportUnavailable,
  WalletExportOutcome.empty => LoopL10n.current.wallet_activityExportEmpty,
};

/// The header row, in the order [walletActivityCsv] writes its columns.
List<String> get walletActivityCsvHeader => <String>[
  LoopL10n.current.wallet_activityExportSwitch,
  LoopL10n.current.wallet_activityExportSwitch2,
  LoopL10n.current.common_assets,
  LoopL10n.current.wallet_activityExportSwitch3,
  LoopL10n.current.common_amount,
  LoopL10n.current.wallet_activityExportSwitch4,
  LoopL10n.current.wallet_activityExportSwitch5,
  LoopL10n.current.wallet_txResultTxResultHashLabel,
  LoopL10n.current.wallet_activityExportSwitch6,
  LoopL10n.current.wallet_activityExportSwitch7,
  LoopL10n.current.wallet_txResultTxResultConfirmationsLabel,
  LoopL10n.current.wallet_activityExportSwitch8,
];

/// Encodes the rows this page is currently listing as RFC 4180 CSV.
///
/// It exports exactly what is on screen — the pages already loaded and the
/// segment currently selected — and nothing else: an export that silently
/// fetched more than the owner was looking at would be a different answer in
/// the shape of this one. Every figure is the exact string or [Decimal] the
/// server sent; nothing here rounds, groups or localises a number, because a
/// CSV is read by other software.
///
/// A field is quoted whenever it could otherwise change meaning, and an inner
/// quote is doubled, so an address or a symbol can never break a row.
String walletActivityCsv(List<LoopWalletActivityEntry> entries) {
  final buffer = StringBuffer()
    ..writeln(walletActivityCsvHeader.map(_csvField).join(','));
  for (final entry in entries) {
    buffer.writeln(
      <String>[
        entry.observedAt.toUtc().toIso8601String(),
        switch (entry.direction) {
          LoopTransferDirection.incoming =>
            LoopL10n.current.wallet_activityExportIncoming,
          LoopTransferDirection.outgoing =>
            LoopL10n.current.wallet_activityExportOutgoing,
          LoopTransferDirection.self =>
            LoopL10n.current.wallet_activityExportSelf,
        },
        entry.symbol,
        entry.assetId,
        entry.displayValue.toString(),
        entry.rawValue,
        entry.counterpartyAddress,
        entry.transactionHash,
        entry.logIndex.toString(),
        entry.blockNumber.toString(),
        entry.confirmations?.toString() ?? '',
        loopConfirmationLabel(entry.status),
      ].map(_csvField).join(','),
    );
  }
  return buffer.toString();
}

/// The file name one export carries. It names the wallet by its truncated
/// address, never by an opaque id a reader cannot check.
String walletActivityCsvFileName({
  required String walletAddress,
  required DateTime now,
}) {
  final stamp = now
      .toUtc()
      .toIso8601String()
      .split('.')
      .first
      .replaceAll(RegExp(r'[:-]'), '');
  return 'loop-${loopTruncatedAddress(walletAddress).replaceAll('…', '-')}'
      '-$stamp.csv';
}

String _csvField(String value) {
  if (!value.contains(RegExp('[",\n\r]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

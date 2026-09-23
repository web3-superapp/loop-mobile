import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

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
  WalletExportOutcome.shared => '记录已导出，请在分享面板中选择去处',
  WalletExportOutcome.dismissed => '已生成 CSV，但没有选择分享去处',
  WalletExportOutcome.failed => '导出没有完成，没有任何内容离开这台设备',
  WalletExportOutcome.unavailable => '本次运行没有装配系统分享，没有导出任何内容',
  WalletExportOutcome.empty => '这一段没有记录可以导出',
};

/// The header row, in the order [walletActivityCsv] writes its columns.
const List<String> walletActivityCsvHeader = <String>[
  '时间(UTC)',
  '方向',
  '资产',
  '资产标识',
  '数量',
  '最小单位数量',
  '对方地址',
  '交易哈希',
  '日志序号',
  '区块',
  '确认数',
  '状态',
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
          LoopTransferDirection.incoming => '收到',
          LoopTransferDirection.outgoing => '发出',
          LoopTransferDirection.self => '自转',
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

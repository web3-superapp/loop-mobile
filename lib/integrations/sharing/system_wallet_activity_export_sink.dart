import 'dart:convert';

import 'package:loop_mobile/features/wallet/wallet_activity_export.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the operating system's share sheet with one in-memory CSV.
///
/// The text is passed as bytes, so it never becomes a file the application
/// keeps, and it is never uploaded to a LOOP service. LOOP learns only whether
/// the sheet was used; it never learns the destination.
final class SystemWalletActivityExportSink implements WalletActivityExportSink {
  const SystemWalletActivityExportSink();

  @override
  Future<WalletExportOutcome> shareCsv({
    required String csv,
    required String fileName,
  }) async {
    if (csv.isEmpty) return WalletExportOutcome.failed;
    try {
      // A BOM, because the spreadsheet applications people open a CSV with
      // read UTF-8 as the local code page without one — and every header on
      // this export is Chinese.
      final bytes = utf8.encode('﻿$csv');
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              bytes,
              mimeType: 'text/csv',
              name: fileName,
              length: bytes.length,
            ),
          ],
          fileNameOverrides: <String>[fileName],
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => WalletExportOutcome.shared,
        ShareResultStatus.dismissed => WalletExportOutcome.dismissed,
        ShareResultStatus.unavailable => WalletExportOutcome.unavailable,
      };
    } catch (_) {
      // A platform failure is not a partial success: nothing was shared.
      return WalletExportOutcome.failed;
    }
  }
}

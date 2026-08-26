import 'package:flutter/foundation.dart';

enum WalletPreviewActivityKind { sent, received, swap }

enum WalletPreviewActivityFilter { all, sent, received, swaps }

extension WalletPreviewActivityFilterLabel on WalletPreviewActivityFilter {
  String get label => switch (this) {
    WalletPreviewActivityFilter.all => 'All',
    WalletPreviewActivityFilter.sent => 'Sent',
    WalletPreviewActivityFilter.received => 'Received',
    WalletPreviewActivityFilter.swaps => 'Swaps',
  };

  bool includes(WalletPreviewActivity activity) => switch (this) {
    WalletPreviewActivityFilter.all => true,
    WalletPreviewActivityFilter.sent =>
      activity.kind == WalletPreviewActivityKind.sent,
    WalletPreviewActivityFilter.received =>
      activity.kind == WalletPreviewActivityKind.received,
    WalletPreviewActivityFilter.swaps =>
      activity.kind == WalletPreviewActivityKind.swap,
  };
}

@immutable
final class WalletPreviewActivity {
  const WalletPreviewActivity._({
    required this.section,
    required this.kind,
    required this.title,
    required this.detail,
    required this.meta,
  });

  static const all = <WalletPreviewActivity>[
    WalletPreviewActivity._(
      section: 'Today',
      kind: WalletPreviewActivityKind.received,
      title: 'Received USDC',
      detail: '+1,250.00 USDC',
      meta: 'Arbitrum · confirmed',
    ),
    WalletPreviewActivity._(
      section: 'Today',
      kind: WalletPreviewActivityKind.swap,
      title: 'Swapped ETH to USDC',
      detail: '-0.12 ETH',
      meta: 'Ethereum · confirmed',
    ),
    WalletPreviewActivity._(
      section: 'August 21',
      kind: WalletPreviewActivityKind.sent,
      title: 'Sent ETH',
      detail: '-0.08 ETH',
      meta: 'Ethereum · 0x71e4…c02a',
    ),
  ];

  final String section;
  final WalletPreviewActivityKind kind;
  final String title;
  final String detail;
  final String meta;

  static List<WalletPreviewActivity> filteredBy(
    WalletPreviewActivityFilter filter,
  ) => List<WalletPreviewActivity>.unmodifiable(all.where(filter.includes));
}

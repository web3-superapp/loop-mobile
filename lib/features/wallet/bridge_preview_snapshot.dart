import 'package:flutter/foundation.dart';

enum BridgePreviewProgress { destinationPending, manualClaimRequired }

@immutable
final class BridgePreviewStep {
  const BridgePreviewStep._({
    required this.index,
    required this.title,
    required this.detail,
    required this.complete,
    required this.warning,
  });

  final String index;
  final String title;
  final String detail;
  final bool complete;
  final bool warning;
}

@immutable
final class BridgePreviewSnapshot {
  const BridgePreviewSnapshot._({
    required this.sourceLabel,
    required this.destinationLabel,
    required this.estimatedTimeLabel,
    required this.estimatedFeesLabel,
    required this.sourceConfirmationLabel,
    required this.relayLabel,
    required this.progress,
  });

  static const demo = BridgePreviewSnapshot._(
    sourceLabel: 'Ethereum · 250 USDC',
    destinationLabel: 'Arbitrum · 248.92 USDC',
    estimatedTimeLabel: '2–5 minutes',
    estimatedFeesLabel: '1.08 USDC',
    sourceConfirmationLabel: 'Ethereum · 14 confirmations',
    relayLabel: 'Provider is preparing the destination transfer',
    progress: BridgePreviewProgress.destinationPending,
  );

  final String sourceLabel;
  final String destinationLabel;
  final String estimatedTimeLabel;
  final String estimatedFeesLabel;
  final String sourceConfirmationLabel;
  final String relayLabel;
  final BridgePreviewProgress progress;

  bool get needsClaim => progress == BridgePreviewProgress.manualClaimRequired;

  String get destinationStepTitle =>
      needsClaim ? 'Manual claim required' : 'Destination pending';

  String get destinationStepDetail => needsClaim
      ? 'Verified provider claim flow is unavailable'
      : '演示数据 · no destination receipt was queried';

  List<BridgePreviewStep> get progressSteps =>
      List<BridgePreviewStep>.unmodifiable(<BridgePreviewStep>[
        BridgePreviewStep._(
          index: '01',
          title: 'Source confirmed',
          detail: sourceConfirmationLabel,
          complete: true,
          warning: false,
        ),
        BridgePreviewStep._(
          index: '02',
          title: 'Relay processing',
          detail: relayLabel,
          complete: true,
          warning: false,
        ),
        BridgePreviewStep._(
          index: '03',
          title: destinationStepTitle,
          detail: destinationStepDetail,
          complete: false,
          warning: needsClaim,
        ),
      ]);

  BridgePreviewSnapshot withNeedsClaim(bool value) {
    return BridgePreviewSnapshot._(
      sourceLabel: sourceLabel,
      destinationLabel: destinationLabel,
      estimatedTimeLabel: estimatedTimeLabel,
      estimatedFeesLabel: estimatedFeesLabel,
      sourceConfirmationLabel: sourceConfirmationLabel,
      relayLabel: relayLabel,
      progress: value
          ? BridgePreviewProgress.manualClaimRequired
          : BridgePreviewProgress.destinationPending,
    );
  }
}

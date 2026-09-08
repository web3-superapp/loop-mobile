import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';

/// The threshold is always a positive decimal STRING on the wire: a JSON
/// number is rejected by the server before type coercion. This pattern is the
/// client-side mirror so a malformed draft never leaves the device.
final RegExp loopAlertThresholdPattern = RegExp(
  r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,18})?$',
);

enum LoopAlertCondition {
  above('above', '涨破'),
  atOrAbove('at_or_above', '涨到'),
  below('below', '跌破'),
  atOrBelow('at_or_below', '跌到');

  const LoopAlertCondition(this.wireName, this.label);

  final String wireName;
  final String label;

  bool get isUpward =>
      this == LoopAlertCondition.above || this == LoopAlertCondition.atOrAbove;

  static LoopAlertCondition? tryParse(String value) {
    for (final condition in values) {
      if (condition.wireName == value) return condition;
    }
    return null;
  }
}

enum LoopAlertState {
  active('active', '监听中'),
  triggered('triggered', '已触发'),
  expired('expired', '已过期');

  const LoopAlertState(this.wireName, this.label);

  final String wireName;
  final String label;

  static LoopAlertState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

/// One price alert.
///
/// A triggered alert is one-shot: it fires once and only a `PUT` re-arms it.
@immutable
final class LoopPriceAlert {
  const LoopPriceAlert({
    required this.alertId,
    required this.assetId,
    required this.asset,
    required this.condition,
    required this.threshold,
    required this.thresholdText,
    required this.expiresAt,
    required this.state,
    required this.triggeredAt,
    required this.lastEvaluatedAt,
    required this.delivery,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String alertId;
  final String assetId;
  final LoopAssetSummary? asset;
  final LoopAlertCondition condition;

  /// Exact decimal value for comparison and display.
  final Decimal threshold;

  /// The verbatim wire string, so the UI never re-formats a stored threshold.
  final String thresholdText;
  final DateTime? expiresAt;
  final LoopAlertState state;
  final DateTime? triggeredAt;

  /// `null` means the evaluator has not looked at this alert yet.
  final DateTime? lastEvaluatedAt;

  /// Always unavailable in this step: there is no push channel.
  final LoopUnavailable delivery;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => asset?.symbol ?? loopTruncatedAssetId(assetId);

  /// "PEPE 涨到 0.00001" — the one-line prototype title.
  String get headline => '$displayName ${condition.label} $thresholdText';

  /// Distance from [current] to the threshold, as a percentage. Computed on
  /// the client from the current market price; `null` when either input is
  /// missing or the current price is zero.
  Decimal? distancePercent(Decimal? current) {
    if (current == null || current == Decimal.zero) return null;
    return ((threshold - current) / current).toDecimal(
          scaleOnInfinitePrecision: 6,
        ) *
        Decimal.fromInt(100);
  }
}

/// A draft the editor holds before it becomes a request.
@immutable
final class LoopAlertDraft {
  const LoopAlertDraft({
    required this.assetId,
    required this.condition,
    required this.threshold,
    required this.expiresAt,
  });

  final String assetId;
  final LoopAlertCondition condition;

  /// The exact string that will be sent. Never a `double`.
  final String threshold;
  final DateTime? expiresAt;

  /// `null` when the draft is contract-valid, otherwise the offending field.
  String? get invalidField {
    if (!loopAssetIdPattern.hasMatch(assetId)) return 'assetId';
    if (!loopAlertThresholdPattern.hasMatch(threshold)) return 'threshold';
    if (Decimal.tryParse(threshold) case final parsed?) {
      if (parsed <= Decimal.zero) return 'threshold';
    } else {
      return 'threshold';
    }
    final expires = expiresAt;
    if (expires != null && !expires.isAfter(DateTime.now().toUtc())) {
      return 'expiresAt';
    }
    return null;
  }

  /// Signature of one logical create/edit operation for the idempotency keyring.
  String get signature =>
      '$assetId|${condition.wireName}|$threshold|${expiresAt?.toIso8601String() ?? ''}';
}

@immutable
final class LoopAlertPage {
  LoopAlertPage({required List<LoopPriceAlert> items, required this.nextCursor})
    : items = List<LoopPriceAlert>.unmodifiable(items);

  final List<LoopPriceAlert> items;
  final String? nextCursor;

  List<LoopPriceAlert> get armed => items
      .where((alert) => alert.state == LoopAlertState.active)
      .toList(growable: false);
}

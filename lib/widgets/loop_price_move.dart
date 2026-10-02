import 'package:decimal/decimal.dart';
import 'package:flutter/painting.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// Which way a figure moved, and the one colour LOOP paints that direction in.
///
/// Decision 0113 restores the user's green / white / black UI palette:
/// Lime rises, Chalk falls, muted stands still. Signed labels, candle bodies
/// and explicit unavailable states retain the meaning independently of colour.
enum LoopPriceMove {
  up,
  down,
  flat,

  /// The figure was not read. It is not zero and it is not a direction.
  unread;

  /// The direction of [value]; `null` is [LoopPriceMove.unread].
  static LoopPriceMove of(Decimal? value) {
    if (value == null) return LoopPriceMove.unread;
    if (value > Decimal.zero) return LoopPriceMove.up;
    if (value < Decimal.zero) return LoopPriceMove.down;
    return LoopPriceMove.flat;
  }

  /// The direction implied by a pair of prices, as a candle body reads it.
  static LoopPriceMove between({
    required Decimal open,
    required Decimal close,
  }) => LoopPriceMove.of(close - open);

  /// Ink for a figure printed on the page's own dark ground.
  Color get color => switch (this) {
    LoopPriceMove.up => LoopColors.lime,
    LoopPriceMove.down => LoopColors.danger,
    // `muted` is opaque and reads as a third state rather than as dimmed
    // Chalk, which a reader takes for a rise that lost contrast.
    LoopPriceMove.flat || LoopPriceMove.unread => LoopColors.muted,
  };

  /// Ground for a solid block whose text is [LoopColors.ink]. All three
  /// grounds are opaque and light, so the Ink on them never changes.
  Color get ground => color;

  bool get isDirectional =>
      this == LoopPriceMove.up || this == LoopPriceMove.down;
}

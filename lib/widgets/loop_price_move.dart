import 'package:decimal/decimal.dart';
import 'package:flutter/painting.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// Which way a figure moved, and the one colour LOOP paints that direction in.
///
/// The frozen prototype paints `.down` in Chalk (`style-v2.css:221`), so a
/// fall and a rise differed only by a sign character; the walkthrough of
/// 2026-09-23 found the reader could not tell them apart at a glance. The
/// approved design draft answers with `#FF6B82` — [LoopColors.danger] — and
/// the requester approved it, first for the 行情 list (decision 0084 §2) and
/// then for the whole application (decision 0086).
///
/// Three states and no more: Lime rises, `danger` falls, `muted` stands still
/// **and** stands for a figure that was not read. Zero has no direction, and a
/// reading that never arrived has none either — neither may borrow a colour
/// that would claim one.
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

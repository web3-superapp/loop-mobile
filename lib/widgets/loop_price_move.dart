import 'package:decimal/decimal.dart';
import 'package:flutter/painting.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// Which way a figure moved, and the one colour LOOP paints that direction in.
///
/// The frozen prototype paints `.down` in Chalk (`style-v2.css:221`), so a
/// fall and a rise differed only by a sign character; the walkthrough of
/// 2026-09-23 found the reader could not tell them apart at a glance.
/// Decision 0086 answered with Lime for a rise and `danger` for a fall.
/// Decision 0117 (v3 requirement §6.2.1, D3) takes price movement out of the
/// brand palette: a rise is [LoopColors.rise] green and a fall is
/// [LoopColors.fall] red, so Lime is left meaning "LOOP" and `danger` is left
/// meaning "something went wrong".
///
/// Three states and no more: `rise` rises, `fall` falls, `muted` stands still
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

  /// The direction of a close series, first close to last.
  ///
  /// Fewer than two closes have no direction and read [LoopPriceMove.unread].
  static LoopPriceMove ofSeries(List<Decimal> closes) {
    if (closes.length < 2) return LoopPriceMove.unread;
    return LoopPriceMove.between(open: closes.first, close: closes.last);
  }

  /// Ink for a figure printed on the page's own dark ground.
  Color get color => switch (this) {
    LoopPriceMove.up => LoopColors.rise,
    LoopPriceMove.down => LoopColors.fall,
    // `muted` is opaque and reads as a third state rather than as dimmed
    // Chalk, which a reader takes for a rise that lost contrast.
    LoopPriceMove.flat || LoopPriceMove.unread => LoopColors.muted,
  };

  /// Ground for a solid block whose text is [LoopColors.ink]. All three
  /// grounds are opaque and mid-to-light, so the Ink on them never changes.
  Color get ground => color;

  /// The 13% wash behind a soft badge; transparent when there is no
  /// direction to state.
  Color get soft => switch (this) {
    LoopPriceMove.up => LoopColors.riseSoft,
    LoopPriceMove.down => LoopColors.fallSoft,
    LoopPriceMove.flat || LoopPriceMove.unread => const Color(0x00000000),
  };

  bool get isDirectional =>
      this == LoopPriceMove.up || this == LoopPriceMove.down;
}

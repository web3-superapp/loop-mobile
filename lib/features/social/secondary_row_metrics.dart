import 'package:flutter/painting.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// S370b · decision 0294: the Figma's row measures (docs/58 §3.2 / §3.3 /
/// §9.4) for the 社区 / 聊天 / 社交 second-level pages the requester did not
/// draw. Each one is the nearest drawn row, named here so the pages say which
/// row they borrow instead of repeating a number.
abstract final class SecondaryRowMetrics {
  /// A person row (members, friends, requests, a blocked account, a forward
  /// target, a search hit) reads as the conversation row: 67 high, face 48.
  static const double personRow = LoopRowHeight.chat;
  static const double personFace = 48;

  /// A community row: 86 high, logo 56 square at r12, divider.
  static const double communityRow = LoopRowHeight.community;
  static const double communityLogo = 56;
  static const double communityLogoRadius = LoopRadius.cardValue;

  /// A function row (manage center, leave, community AI entry): 56 high, the
  /// glyph on a 34 ground.
  static const double functionRow = LoopRowHeight.management;
  static const double functionGlyph = 34;

  /// A token row: logo 44.
  static const double tokenLogo = 44;

  /// A token row's height: 71.
  static const double tokenRow = LoopRowHeight.token;

  /// S371 · decision 0297: a borrowed row's padding — the page margin and
  /// 6 above and below (docs/58 §9.4 「上下 6 统一」).
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(
    horizontal: LoopSpacing.page,
    vertical: 6,
  );
}

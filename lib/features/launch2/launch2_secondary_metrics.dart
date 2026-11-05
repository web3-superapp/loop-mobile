import 'package:loop_mobile/core/theme/loop_theme.dart';

/// S370a · decision 0293: the measures the MEME second-level pages take
/// from docs/58 §9 where the requester's Figma drew no page of their own.
///
/// Every value here is a §9.4 rule applied by analogy (「类推」): a trade or
/// an event line is read like a holding / leaderboard row, a project's face
/// like a token row's.
abstract final class Launch2SecondaryMetrics {
  /// A holding / leaderboard row (§9.4): 51 high, 6 above and below, no
  /// line. Trades and creator events take it.
  static const double recordRow = LoopRowHeight.holdings;

  /// The record row's top and bottom inset.
  static const double recordInset = 6;

  /// A record row's face: 36, round.
  static const double recordFace = LoopRowHeight.holdingsAvatar;

  /// A face to the words beside it.
  static const double faceGap = 12;

  /// A token's face (§9.4 代币 44, round): the detail page's head, a
  /// creator's project row and the project page's head.
  static const double tokenFace = 44;

  /// A filter chip row (二级胶囊) to what it filters (§9.4 胶囊 → 内容 12).
  static const double chipToContent = LoopSpacing.chipGap;

  /// The gap between two chips in a row (§9.4 胶囊间距 8).
  static const double chipSpacing = LoopSpacing.chipSpacing;
}

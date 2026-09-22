import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the owner has arrived at Community in this run.
///
/// It answers one question and holds nothing else: has this account been put
/// down on the page LOOP opens into — Community — on this device, since the
/// session began. It is not a position in the opening sequence, not a route
/// history, and not a record of anything the owner did once there.
///
/// It exists because a permission prompt needs a moment as well as a reason.
/// Decision 0076: the notification permission is asked for when the owner
/// first reaches Community — after the five-step opening, or straight away on
/// a restored session — rather than the instant the backend accepts the
/// account, which lands the system dialog on top of 创建钱包.
final class LoopCommunityArrivalController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Marks the arrival, and answers whether this call is the one that did.
  ///
  /// Returning `false` for every later call is what keeps the one action
  /// bound to it — asking the device about notifications — from happening
  /// again on each return to the tab.
  bool reach() {
    if (state) return false;
    state = true;
    return true;
  }

  /// Leaving the account takes the arrival with it: the next account on this
  /// device has not been anywhere yet.
  void leave() {
    if (state) state = false;
  }
}

final loopCommunityArrivalProvider =
    NotifierProvider<LoopCommunityArrivalController, bool>(
      LoopCommunityArrivalController.new,
    );

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';

/// Presentation models for the `referral` module (loop-api decision 0036).
///
/// A referral relationship is a **Mining Power** boost and nothing else: this
/// file never carries a commission, a payout, a revenue share or a downline
/// income. The boost itself has no value until a mining formula is approved.

@immutable
final class ReferralInviteCode {
  const ReferralInviteCode({required this.code, required this.issuedAt});

  /// `LOOP-` + four Crockford Base32 characters and one check character.
  static final RegExp pattern = RegExp(r'^LOOP-[0-9A-HJKMNP-TV-Z]{5}$');

  final String code;
  final DateTime issuedAt;
}

/// Whether the seven-day binding window is open. `unavailable` means the
/// account has no LOOP ID yet, so no window has started.
@immutable
sealed class ReferralClaimWindow {
  const ReferralClaimWindow();
}

@immutable
final class ReferralClaimWindowTimed extends ReferralClaimWindow {
  const ReferralClaimWindowTimed({
    required this.isOpen,
    required this.activatedAt,
    required this.closesAt,
  });

  final bool isOpen;
  final DateTime activatedAt;
  final DateTime closesAt;
}

@immutable
final class ReferralClaimWindowUnavailable extends ReferralClaimWindow {
  const ReferralClaimWindowUnavailable(this.reasonCode);

  final String reasonCode;
}

enum ReferralValidationStatus {
  pendingActivation('pending_activation'),
  pendingWallet('pending_wallet'),
  pendingMining('pending_mining'),
  valid('valid'),
  invalidated('invalidated');

  const ReferralValidationStatus(this.wireName);

  final String wireName;

  static ReferralValidationStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

String referralValidationStatusLabel(ReferralValidationStatus status) =>
    switch (status) {
      ReferralValidationStatus.pendingActivation => '待激活',
      ReferralValidationStatus.pendingWallet => '待绑定钱包',
      ReferralValidationStatus.pendingMining => '待挖矿生效',
      ReferralValidationStatus.valid => '有效',
      ReferralValidationStatus.invalidated => '已作废',
    };

/// The inviter side of a binding. It deliberately exposes no identity: only
/// the depth, the validation state and the rule version.
@immutable
final class ReferralInviter {
  const ReferralInviter({
    required this.depth,
    required this.validationStatus,
    required this.lockedAt,
    required this.effectiveFrom,
    required this.configVersion,
  });

  final int depth;
  final ReferralValidationStatus validationStatus;
  final DateTime lockedAt;
  final DateTime effectiveFrom;
  final String configVersion;
}

@immutable
final class ReferralBinding {
  const ReferralBinding({
    required this.isBound,
    required this.inviter,
    required this.claimWindow,
  });

  final bool isBound;
  final ReferralInviter? inviter;
  final ReferralClaimWindow claimWindow;

  /// The claim entry point is offered only while the account is unbound and
  /// the server says its window is open. Nothing else may open it.
  bool get canClaim {
    if (isBound) return false;
    final window = claimWindow;
    return window is ReferralClaimWindowTimed && window.isOpen;
  }
}

@immutable
final class ReferralValidationCounts {
  const ReferralValidationCounts({
    required this.pendingActivation,
    required this.pendingWallet,
    required this.pendingMining,
    required this.valid,
    required this.invalidated,
  });

  final int pendingActivation;
  final int pendingWallet;
  final int pendingMining;
  final int valid;
  final int invalidated;

  /// Everything that is not yet `valid` and not `invalidated`. A page that
  /// counts "有效关系" may only use [valid].
  int get pending => pendingActivation + pendingWallet + pendingMining;

  List<(ReferralValidationStatus, int)> get entries =>
      <(ReferralValidationStatus, int)>[
        (ReferralValidationStatus.valid, valid),
        (ReferralValidationStatus.pendingMining, pendingMining),
        (ReferralValidationStatus.pendingWallet, pendingWallet),
        (ReferralValidationStatus.pendingActivation, pendingActivation),
        (ReferralValidationStatus.invalidated, invalidated),
      ];
}

@immutable
final class ReferralLevel {
  const ReferralLevel({
    required this.level,
    required this.boostPercent,
    required this.counts,
    required this.total,
  });

  final int level;

  /// The server's own value, rendered verbatim. The client never restates a
  /// fixed ladder of its own.
  final String boostPercent;
  final ReferralValidationCounts counts;
  final int total;
}

@immutable
final class ReferralRulesInfo {
  const ReferralRulesInfo({
    required this.configVersion,
    required this.effectiveAt,
    required this.appliesTo,
    required this.maximumDepth,
    required this.claimWindowDays,
  });

  final String configVersion;
  final DateTime effectiveAt;
  final String appliesTo;
  final int maximumDepth;
  final int claimWindowDays;
}

@immutable
final class ReferralOverview {
  const ReferralOverview({
    required this.inviteCode,
    required this.binding,
    required this.levels,
    required this.boost,
    required this.rules,
  });

  final ReferralInviteCode inviteCode;
  final ReferralBinding binding;
  final List<ReferralLevel> levels;

  /// The final boost. Unavailable until a mining formula version is approved.
  final LaunchUnavailable boost;
  final ReferralRulesInfo rules;

  /// Only `valid` edges may be counted as effective relationships.
  int get validRelationships {
    var total = 0;
    for (final level in levels) {
      total += level.counts.valid;
    }
    return total;
  }

  int get pendingRelationships {
    var total = 0;
    for (final level in levels) {
      total += level.counts.pending;
    }
    return total;
  }
}

/// zh-CN copy for one referral level. The description is a relationship depth,
/// never a rank or a progression.
String referralLevelDescription(int level) => switch (level) {
  1 => 'L1 · 我直接邀请并经服务端验证的人',
  2 => 'L2 · 我的 L1 再邀请的人',
  3 => 'L3 · 我的 L2 再邀请的人',
  4 => 'L4 · 我的 L3 再邀请的人',
  5 => 'L5 · 我的 L4 再邀请的人',
  _ => '服务端定义的关系层级',
};

/// Normalises what the user typed before it leaves the device.
///
/// The server accepts a lower-case code, a missing prefix and the Crockford
/// substitutions; normalising locally only avoids an obviously malformed
/// request. Acceptance stays the server's decision.
String normaliseReferralInviteCode(String raw) {
  final trimmed = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  final body = trimmed.startsWith('LOOP-')
      ? trimmed.substring(5)
      : (trimmed.startsWith('LOOP') ? trimmed.substring(4) : trimmed);
  final substituted = body
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll('O', '0');
  return 'LOOP-$substituted';
}

/// Whether the normalised code can possibly be accepted. A locally malformed
/// code is refused before the request rather than spending an attempt.
bool isReferralInviteCodeShaped(String raw) =>
    ReferralInviteCode.pattern.hasMatch(normaliseReferralInviteCode(raw));

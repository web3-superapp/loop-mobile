import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';

/// S347 · N4: the retired 邀请中心 page is gone; its sections live on as
/// 情报 · 算力 · 邀请. Tests that read those sections draw them here, in a
/// plain scroll, with the (i) the 邀请 tab hands them.
class ReferralCenterHost extends ConsumerWidget {
  const ReferralCenterHost({
    super.key,
    this.initialInviteCode,
    this.onNavigate,
    this.initialTab = ReferralCenterTab.invitees,
  });

  final String? initialInviteCode;
  final ReferralCenterTab initialTab;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SingleChildScrollView(
      key: const ValueKey<String>('referral-screen'),
      child: ReferralCenterSections(
        initialInviteCode: initialInviteCode,
        onNavigate: onNavigate,
        initialTab: initialTab,
        info: LoopInfoButton(
          key: const ValueKey<String>('referral-explain-action'),
          title: '邀请说明',
          label: '邀请说明',
          notes: referralInfoNotes(ref.watch(referralControllerProvider).value),
          sheetKey: 'referral-explain-sheet',
        ),
      ),
    ),
  );
}

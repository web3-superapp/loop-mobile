import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `referral` · my invite code and relationship counts.
///
/// The page reads `GET /v2/referral`. Everything it shows is a relationship
/// count grouped by the server's own validation state; the final boost has no
/// value until a mining formula version is approved. Nothing here is a
/// commission, a payout or a downline income.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key, this.onBack, this.onOpenMining});

  final VoidCallback? onBack;

  /// The prototype's "back to mining" control. Referral is a Mining Power
  /// rule page, so it offers a way back to the Mining tab.
  final VoidCallback? onOpenMining;

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.referral),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(referralControllerProvider);
    final controller = ref.read(referralControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final overview = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('referral-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: 'Referral Boost',
      kicker: 'MINING POWER · SERVER VERIFIED',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('referral-explain-action'),
          icon: 'info',
          label: 'Referral 说明',
          onPressed: () => unawaited(_explain()),
        ),
      ],
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'FINAL BOOST',
        // The boost has no value: it depends on the unapproved formula.
        heading: launchMissingHeading,
        caption: overview == null
            ? '加成只计入 Mining Power，不是收入、佣金或返佣。'
            : '${overview.validRelationships} 个有效关系 · '
                  '${overview.pendingRelationships} 个待验证；加成只计入 Mining Power。',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('referral-capability-unavailable'),
              title: '邀请关系当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (overview == null)
          LaunchStateBlock(
            prefix: 'referral',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到邀请关系',
            emptyReason: '暂时读不到邀请码和邀请人数。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('我的邀请码'),
          _InviteCodeBlock(code: overview.inviteCode),
          const LoopLabel('各层关系'),
          _LevelBlock(levels: overview.levels),
          const LoopLabel('加成'),
          LaunchUnavailableCard(label: 'Mining Power 加成', fact: overview.boost),
          const LoopLabel('我的邀请人'),
          _BindingBlock(
            binding: overview.binding,
            busy: state.busy,
            claimed: state.claimed,
            claimFailureKind: state.claimFailureKind,
            claimShapeInvalid: state.claimShapeInvalid,
            onClaim: () => unawaited(_openClaimSheet()),
          ),
          _RulesFooter(rules: overview.rules),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('referral-back-to-mining'),
                label: '返回挖矿',
                onPressed: widget.onOpenMining,
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('referral-mining-only'),
            icon: 'info',
            title: '只计入 Mining Power',
            body: '这是 Mining Power 加成，不是收入、佣金或返佣。分享完成不代表关系成立，还需要验证。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _openClaimSheet() async {
    final code = await showLoopSheet<String>(
      context,
      barrierLabel: '关闭绑定邀请码',
      builder: (sheetContext) => const _ClaimForm(),
    );
    if (code == null || !mounted) return;
    await ref.read(referralControllerProvider.notifier).claim(code);
    if (!mounted) return;
    final state = ref.read(referralControllerProvider);
    // A success Toast only after the server confirmed the binding.
    if (state.claimed) {
      LoopToast.show(context, message: '邀请码已绑定', kind: LoopToastKind.ok);
    }
  }

  Future<void> _explain() => showLoopSheet<void>(
    context,
    barrierLabel: '关闭 Referral 说明',
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('referral-explain-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Referral 说明',
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '每个账号只有一个邀请码。被邀请人激活 LOOP ID 并绑定钱包后，关系进入下一个验证阶段；'
            '「有效」需要挖矿公式版本被批准，因此当前不会出现有效关系。'
            '加成只计入 Mining Power，不是收入、佣金或返佣。',
            style: LoopTypography.body(13, color: LoopColors.muted),
          ),
          const SizedBox(height: 16),
          LoopButton(
            key: const ValueKey<String>('referral-explain-close'),
            label: '知道了',
            block: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}

class _InviteCodeBlock extends ConsumerWidget {
  const _InviteCodeBlock({required this.code});

  final ReferralInviteCode code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('referral-invite-code'),
              title: code.code,
              subtitle: '签发于 ${launchTimestampLabel(code.issuedAt)}',
              trailingCaption: '每个账号一个',
              semanticLabel: '我的邀请码 ${code.code}',
            ),
          ],
        ),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('referral-copy-code'),
              label: '复制邀请码',
              primary: true,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code.code));
                if (!context.mounted) return;
                LoopToast.show(
                  context,
                  message: '邀请码已复制',
                  kind: LoopToastKind.ok,
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _LevelBlock extends StatelessWidget {
  const _LevelBlock({required this.levels});

  final List<ReferralLevel> levels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          key: const ValueKey<String>('referral-levels'),
          rows: <LoopRecordRow>[
            for (var index = 0; index < levels.length; index += 1)
              _levelRow(levels[index], index, levels.length),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '「有效」只统计已验证的关系，其余一律显示为待验证，'
            '不计入任何加成。',
            style: LoopTypography.caption(11, color: LoopColors.text2),
          ),
        ),
      ],
    );
  }

  LoopRecordRow _levelRow(ReferralLevel level, int index, int length) {
    final counts = level.counts;
    final detail = <String>[
      for (final entry in counts.entries)
        '${referralValidationStatusLabel(entry.$1)} ${entry.$2}',
    ].join(' · ');
    return LoopRecordRow(
      key: ValueKey<String>('referral-level-${level.level}'),
      leading: _LevelTile(level: level.level),
      title: 'L${level.level} · ${level.boostPercent}%',
      subtitle: '${referralLevelDescription(level.level)}\n$detail',
      // The trailing figure is the only provable one: how many valid edges.
      trailing: '${counts.valid}',
      trailingCaption: '有效',
      position: launchRowPosition(index, length),
      semanticLabel:
          'L${level.level}，加成 ${level.boostPercent}%，'
          '有效关系 ${counts.valid}，待验证 ${counts.pending}',
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: level == 1 ? LoopColors.lime : LoopColors.card2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'L$level',
        style: LoopTypography.figure(
          13,
          color: level == 1 ? LoopColors.ink : LoopColors.chalk,
        ),
      ),
    );
  }
}

class _BindingBlock extends StatelessWidget {
  const _BindingBlock({
    required this.binding,
    required this.busy,
    required this.claimed,
    required this.claimFailureKind,
    required this.claimShapeInvalid,
    required this.onClaim,
  });

  final ReferralBinding binding;
  final bool busy;
  final bool claimed;
  final LaunchFailureKind? claimFailureKind;
  final bool claimShapeInvalid;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final window = binding.claimWindow;
    final inviter = binding.inviter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (inviter != null)
          LoopRecordGroup(
            key: const ValueKey<String>('referral-bound'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('referral-bound-row'),
                title: '已绑定邀请人',
                // Never the inviter's identity: only depth and state.
                subtitle:
                    '深度 L${inviter.depth} · '
                    '${referralValidationStatusLabel(inviter.validationStatus)} · '
                    '锁定于 ${launchTimestampLabel(inviter.lockedAt)}',
              ),
            ],
          )
        else
          switch (window) {
            ReferralClaimWindowUnavailable(:final reasonCode) => LoopEmpty(
              key: const ValueKey<String>('referral-claim-unavailable'),
              icon: 'id',
              message: '还不能绑定邀请码',
              reason: launchReasonCodeText(reasonCode),
            ),
            ReferralClaimWindowTimed(:final isOpen, :final closesAt) =>
              isOpen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        LoopRecordGroup(
                          key: const ValueKey<String>('referral-claim-window'),
                          rows: <LoopRecordRow>[
                            LoopRecordRow(
                              key: const ValueKey<String>(
                                'referral-claim-window-row',
                              ),
                              title: '绑定窗口开放中',
                              subtitle:
                                  '截止 ${launchTimestampLabel(closesAt)}；'
                                  '一个账号只能绑定一次，关系锁定后不可更换。',
                            ),
                          ],
                        ),
                        LoopButtonPair(
                          children: <Widget>[
                            LoopButton(
                              key: const ValueKey<String>('referral-claim'),
                              label: '绑定邀请码',
                              primary: true,
                              onPressed: busy ? null : onClaim,
                            ),
                          ],
                        ),
                      ],
                    )
                  : LoopEmpty(
                      key: const ValueKey<String>('referral-claim-closed'),
                      icon: 'clock',
                      message: '绑定窗口已关闭',
                      reason:
                          '邀请码只能在账号激活后的窗口期内绑定，本账号的窗口已于 '
                          '${launchTimestampLabel(closesAt)} 结束。',
                    ),
          },
        if (claimShapeInvalid)
          const LoopNotice(
            key: ValueKey<String>('referral-claim-shape-invalid'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '邀请码格式不对',
            body: '邀请码形如 LOOP- 加 5 位字符。格式明显不对时不会提交，以免浪费唯一的一次绑定机会。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
        if (claimFailureKind != null)
          LoopNotice(
            key: const ValueKey<String>('referral-claim-failure'),
            icon: 'warn',
            tone: LoopNoticeTone.danger,
            title: '这次绑定没有完成',
            body: referralClaimFailureReason(claimFailureKind),
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
        if (claimed)
          const LoopNotice(
            key: ValueKey<String>('referral-claim-success'),
            icon: 'check',
            title: '关系已锁定',
            body: '这条关系已确认。绑定后不能更换。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
      ],
    );
  }
}

class _RulesFooter extends StatelessWidget {
  const _RulesFooter({required this.rules});

  final ReferralRulesInfo rules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('referral-rules-footer'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        '生效于 ${launchTimestampLabel(rules.effectiveAt)} · '
        '最大深度 L${rules.maximumDepth} · '
        '绑定窗口 ${rules.claimWindowDays} 天 · 作用于 ${rules.appliesTo}',
        style: LoopTypography.caption(11, color: LoopColors.text3),
      ),
    );
  }
}

/// The binding form. The shape check runs locally so an obviously malformed
/// code never spends the account's single binding attempt.
class _ClaimForm extends StatefulWidget {
  const _ClaimForm();

  @override
  State<_ClaimForm> createState() => _ClaimFormState();
}

class _ClaimFormState extends State<_ClaimForm> {
  final TextEditingController _code = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _code.text;
    if (!isReferralInviteCodeShaped(raw)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(normaliseReferralInviteCode(raw));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('referral-claim-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '绑定邀请码',
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '一个账号只能绑定一次，关系锁定后不可更换。不能绑定自己的邀请码，也不能绑定自己下级的邀请码。',
            style: LoopTypography.caption(12, color: LoopColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('referral-claim-input'),
            controller: _code,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: '邀请码（形如 LOOP-XXXXX）',
              errorText: _invalid ? '邀请码格式不对，请检查后再试。' : null,
            ),
          ),
          const SizedBox(height: 16),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('referral-claim-submit'),
                label: '绑定',
                primary: true,
                onPressed: _submit,
              ),
              LoopButton(
                key: const ValueKey<String>('referral-claim-cancel'),
                label: '取消',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

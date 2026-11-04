import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_gate.dart';
import 'package:loop_mobile/features/security/step_up/step_up_controller.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_steps.dart';
import 'package:loop_mobile/widgets/loop_keyboard.dart';

// ---------------------------------------------------------------------------
// The step in a signing sheet (decision 0152)
// ---------------------------------------------------------------------------

/// 「验证身份」 as one step of the signing strip.
@immutable
final class LoopStepUpStep {
  const LoopStepUpStep(this.status, {this.verdict});

  final LoopSignStepStatus status;

  /// How the prompt ended, once it did.
  final LoopStepUpVerdict? verdict;

  String get caption => switch (status) {
    LoopSignStepStatus.waiting =>
      LoopL10n.current.securityStepUp_widgetsWaiting,
    LoopSignStepStatus.active || LoopSignStepStatus.refreshing =>
      LoopL10n.current.securityStepUp_widgetsRefreshing,
    LoopSignStepStatus.done => LoopL10n.current.securityStepUp_widgetsDone,
    LoopSignStepStatus.failed || LoopSignStepStatus.unknown =>
      verdict == LoopStepUpVerdict.cancelled
          ? LoopL10n.current.common_cancelled
          : LoopL10n.current.common_rejected,
  };

  LoopSignStep get step => LoopSignStep(
    id: 'verify',
    label: LoopL10n.current.securityAppLock_gateLoopAppLockUnlockLabel2,
    status: status,
    caption: caption,
    waitingCaption: LoopL10n.current.securityStepUp_widgetsWaiting,
  );
}

/// The caption of a single-transaction signing step.
String loopSignStepCaption(LoopSignStepStatus status) => switch (status) {
  LoopSignStepStatus.waiting => LoopL10n.current.common_awaitingSignature,
  LoopSignStepStatus.active => LoopL10n.current.securityStepUp_widgetsActive,
  LoopSignStepStatus.refreshing =>
    LoopL10n.current.securityStepUp_widgetsRefreshing2,
  LoopSignStepStatus.done => LoopL10n.current.common_broadcast,
  LoopSignStepStatus.failed => LoopL10n.current.securityStepUp_widgetsFailed,
  LoopSignStepStatus.unknown => LoopL10n.current.securityStepUp_widgetsUnknown,
};

/// The large-amount step-up inside one signing sheet.
///
/// The sheet asks [runStepUp] before it hands anything to its signer. The
/// signing exit itself is the rule — [LoopStepUpWalletSigningGateway] asks
/// whatever the sheet did — and this only draws the step and runs the prompt
/// first, so the owner sees 「验证身份」 before the wallet rather than a
/// system prompt over a 「签名中」 sheet. A passed prompt covers the rest of
/// the operation at the exit, and the cover ends when the sheet closes.
mixin LoopStepUpSheetMixin<T extends StatefulWidget> on State<T> {
  /// The exit the sheet's signer hands to.
  WalletSigningGateway get stepUpWallet;

  /// What the sheet's intent is worth in USD1, or `null` when unknown.
  Decimal? get stepUpUsd1;

  LoopStepUpPlan? _stepUpPlan;
  LoopSignStepStatus _stepUpStatus = LoopSignStepStatus.waiting;
  LoopStepUpVerdict? _stepUpVerdict;
  bool _walletReached = false;

  LoopStepUpGuard? get _stepUpGuard => loopStepUpGuardOf(stepUpWallet);

  /// The strip shows 「验证身份」.
  bool get stepUpShown => _stepUpPlan?.required ?? false;

  /// The device's prompt is up.
  bool get stepUpVerifying => _stepUpStatus == LoopSignStepStatus.active;

  /// The step, or `null` when the step-up does not run for this sheet.
  LoopStepUpStep? get stepUpStep => stepUpShown
      ? LoopStepUpStep(_stepUpStatus, verdict: _stepUpVerdict)
      : null;

  /// What the busy body says right now.
  String get stepUpSigningTitle => stepUpVerifying
      ? LoopL10n.current.securityStepUp_widgetsStepUpSigningTitle
      : LoopL10n.current.securityStepUp_widgetsS;

  /// Reads whether the step-up will run, so the strip is drawn before the
  /// owner confirms.
  void planStepUp() {
    final guard = _stepUpGuard;
    if (guard == null) return;
    unawaited(
      guard
          .plan(stepUpUsd1)
          .then((plan) {
            if (mounted) setState(() => _stepUpPlan = plan);
          })
          .catchError((Object _) {}),
    );
  }

  /// Runs the prompt when the amount reaches the threshold. Returns `null`
  /// when the wallet may open, or the refusal code when it may not.
  Future<String?> runStepUp() async {
    final guard = _stepUpGuard;
    if (guard == null) {
      _walletReached = true;
      return null;
    }
    LoopStepUpPlan plan;
    try {
      plan = await guard.plan(stepUpUsd1);
    } on Object {
      plan = _stepUpPlan ?? const LoopStepUpPlan.none();
    }
    if (!mounted) return loopStepUpCancelledCode;
    if (!plan.required) {
      setState(() => _stepUpPlan = plan);
      _walletReached = true;
      return null;
    }
    setState(() {
      _stepUpPlan = plan;
      _stepUpStatus = LoopSignStepStatus.active;
      _stepUpVerdict = null;
    });
    LoopStepUpVerdict verdict;
    try {
      verdict = await guard.verify(stepUpUsd1);
    } on Object {
      verdict = LoopStepUpVerdict.failed;
    }
    if (!mounted) return verdict.refusalCode;
    setState(() {
      _stepUpVerdict = verdict;
      _stepUpStatus = verdict.allowsSigning
          ? LoopSignStepStatus.done
          : LoopSignStepStatus.failed;
    });
    if (verdict.allowsSigning) _walletReached = true;
    return verdict.refusalCode;
  }

  /// The signing step's status, read from the sheet's own state.
  LoopSignStepStatus stepUpSignStatus(
    LoopSignSheetState state, {
    bool locked = false,
  }) => switch (state) {
    LoopSignSheetState.signing =>
      _walletReached ? LoopSignStepStatus.active : LoopSignStepStatus.waiting,
    LoopSignSheetState.complete =>
      locked ? LoopSignStepStatus.unknown : LoopSignStepStatus.done,
    LoopSignSheetState.simulationFailed || LoopSignSheetState.policyRejected =>
      _walletReached ? LoopSignStepStatus.failed : LoopSignStepStatus.waiting,
    LoopSignSheetState.pending => LoopSignStepStatus.waiting,
  };

  /// [sheet] with 「1 验证身份 → 2 [signLabel]」 above it when the step-up
  /// runs, and [sheet] alone when it does not.
  Widget withStepUpStrip(
    Widget sheet, {
    required String signLabel,
    required LoopSignStepStatus signStatus,
    String? signCaption,
  }) {
    final step = stepUpStep;
    if (step == null) return sheet;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSignStepStrip(
          keyPrefix: 'loop-sign',
          steps: <LoopSignStep>[
            step.step,
            LoopSignStep(
              id: 'sign',
              label: signLabel,
              status: signStatus,
              caption: signCaption ?? loopSignStepCaption(signStatus),
            ),
          ],
        ),
        sheet,
      ],
    );
  }

  @override
  void dispose() {
    _stepUpGuard?.release();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// The setting (security-setup and 安全中心)
// ---------------------------------------------------------------------------

String get _stepUpTitle => LoopL10n.current.securityStepUp_widgetsStepUpTitle;

/// The 大额交易二次验证 row: a switch, the threshold under the title, and a
/// tap that opens the threshold sheet.
///
/// [rowBuilder] lets a page draw the row in its own face (the setup card
/// draws rows without the shared row's edge). A tree that composed no
/// provider scope gets the same row without a switch, saying that this run
/// has nothing to verify with.
class LoopStepUpSettingRow extends StatelessWidget {
  const LoopStepUpSettingRow({
    super.key,
    this.position = LoopRowPosition.single,
    this.rowBuilder,
  });

  final LoopRowPosition position;
  final Widget Function(LoopRecordRow row)? rowBuilder;

  static const rowKey = ValueKey<String>('security-large-amount-step-up');

  @override
  Widget build(BuildContext context) {
    final scoped =
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
        null;
    if (!scoped) {
      // S278 · decision 0236: what the rule does is behind (i); why it
      // cannot run here stays on the row.
      final row = LoopRecordRow(
        key: rowKey,
        title: _stepUpTitle,
        subtitle: context.l10n.securityStepUp_widgetsSubtitle,
        subtitleMaxLines: 2,
        trailingBadge: loopStepUpInfoButton(loopStepUpDefaultThresholdUsd1),
        trailing: context.l10n.common_unavailable,
        position: position,
        semanticLabel: context.l10n.securityStepUp_widgetsSemanticLabel(
          _stepUpTitle,
        ),
      );
      return rowBuilder?.call(row) ?? row;
    }
    return _LoopStepUpSettingConsumer(
      position: position,
      rowBuilder: rowBuilder,
    );
  }
}

class _LoopStepUpSettingConsumer extends ConsumerStatefulWidget {
  const _LoopStepUpSettingConsumer({
    required this.position,
    required this.rowBuilder,
  });

  final LoopRowPosition position;
  final Widget Function(LoopRecordRow row)? rowBuilder;

  @override
  ConsumerState<_LoopStepUpSettingConsumer> createState() =>
      _LoopStepUpSettingConsumerState();
}

class _LoopStepUpSettingConsumerState
    extends ConsumerState<_LoopStepUpSettingConsumer> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (!mounted) return;
      final controller = ref.read(loopStepUpProvider.notifier);
      unawaited(controller.load().then((_) => controller.refreshCapability()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loopStepUpProvider);
    final controller = ref.read(loopStepUpProvider.notifier);
    final threshold = state.settings.thresholdUsd1;
    final available = state.isAvailable;
    final on = state.isActive;
    final base = loopStepUpSubtitle(threshold);
    final capability = state.capability;
    // S278 · decision 0236 (需求方第 12 条): 「达到 … 时再验一次身份」 is
    // behind the row's (i); a reason it cannot run, or that it will not
    // survive a restart, stays on the row.
    final String? subtitle = !state.loaded || capability == null
        ? null
        : !available
        ? loopAppLockFactorText(capability)
        : !state.persisted
        ? context.l10n.securityStepUp_widgetsBuild
        : null;
    void toggle() => unawaited(controller.setEnabled(!on));
    final row = LoopRecordRow(
      key: LoopStepUpSettingRow.rowKey,
      title: _stepUpTitle,
      subtitle: subtitle,
      subtitleMaxLines: 2,
      selected: on,
      trailingBadge: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          loopStepUpInfoButton(threshold),
          const SizedBox(width: 4),
          if (available && !state.busy)
            LoopFlatSwitch(
              key: const ValueKey<String>('security-step-up-switch'),
              value: on,
              onChanged: toggle,
            )
          else
            LoopBadge(
              state.busy
                  ? context.l10n.common_verifying
                  : !state.loaded
                  ? context.l10n.securityStepUp_widgetsLoopBadge
                  : context.l10n.common_unavailable,
              kind: LoopBadgeKind.mute,
            ),
        ],
      ),
      onTap: available && !state.busy
          ? () => unawaited(showLoopStepUpThresholdSheet(context))
          : null,
      position: widget.position,
      semanticLabel: !available
          ? context.l10n
                .securityStepUp_widgetsSecurityStepUpSwitchSemanticLabel(
                  capability == null
                      ? context.l10n.securityAppLock_gateSwitch2
                      : loopAppLockFactorText(capability),
                  _stepUpTitle,
                )
          : context.l10n
                .securityStepUp_widgetsSecurityStepUpSwitchSemanticLabel2(
                  base,
                  on
                      ? context.l10n.common_on
                      : context.l10n.wallet_readScreensLoopBadge4,
                  _stepUpTitle,
                ),
    );
    return widget.rowBuilder?.call(row) ?? row;
  }
}

/// The step-up row's (i): what the rule does at [threshold]
/// (S278 · decision 0236).
Widget loopStepUpInfoButton(int threshold) => LoopInfoButton(
  key: const ValueKey<String>('security-step-up-info'),
  title: _stepUpTitle,
  sheetKey: 'security-step-up-info-sheet',
  notes: <LoopInfoNote>[
    LoopInfoNote(
      key: const ValueKey<String>('security-step-up-info-body'),
      body: LoopL10n.current.securityStepUp_widgetsSecurityStepUpInfoBodyBody(
        loopStepUpSubtitle(threshold),
      ),
    ),
  ],
);

/// Opens the threshold sheet. `true` when a new threshold was saved.
Future<bool> showLoopStepUpThresholdSheet(BuildContext context) async {
  final saved = await showLoopSheet<bool>(
    context,
    builder: (context) => const LoopStepUpThresholdSheet(),
  );
  return saved ?? false;
}

/// One number, three presets, one save.
class LoopStepUpThresholdSheet extends ConsumerStatefulWidget {
  const LoopStepUpThresholdSheet({super.key});

  @override
  ConsumerState<LoopStepUpThresholdSheet> createState() =>
      _LoopStepUpThresholdSheetState();
}

class _LoopStepUpThresholdSheetState
    extends ConsumerState<LoopStepUpThresholdSheet> {
  late final TextEditingController _input = TextEditingController(
    text: '${ref.read(loopStepUpProvider).settings.thresholdUsd1}',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  int? get _value => loopStepUpParseThreshold(_input.text);

  void _pick(int preset) {
    setState(() {
      _input.text = '$preset';
      _error = null;
    });
  }

  Future<void> _save() async {
    final value = _value;
    final invalid = loopStepUpThresholdError(value);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await ref
        .read(loopStepUpProvider.notifier)
        .setThreshold(value!);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = LoopL10n.current.securityStepUp_widgetsError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return Column(
      key: const ValueKey<String>('step-up-threshold-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSheetHeading(context.l10n.securityStepUp_widgetsLoopSheetHeading),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            context.l10n.securityStepUp_widgetsBuild2,
            style: LoopType.bodySm,
          ),
        ),
        LoopFlatField(
          label: context.l10n.securityStepUp_widgetsStepUpThresholdFieldLabel,
          footnote:
              _error ??
              context.l10n.securityStepUp_widgetsStepUpThresholdFieldFootnote,
          error: _error != null,
          child: TextField(
            key: const ValueKey<String>('step-up-threshold-field'),
            controller: _input,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            style: LoopType.figureLg,
            decoration: loopFormFieldDecoration(
              hint: context.l10n.securityStepUp_widgetsHint,
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          // Decision 0234: a preset fills the field; the keyboard stays.
          child: LoopKeepsKeyboard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final preset in loopStepUpThresholdPresets)
                  LoopSeg(
                    key: ValueKey<String>('step-up-preset-$preset'),
                    label: loopStepUpThresholdLabel(preset),
                    selected: value == preset,
                    onSelected: _saving ? null : () => _pick(preset),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: LoopButton(
            key: const ValueKey<String>('step-up-threshold-save'),
            label: _saving
                ? context.l10n.common_verifying
                : context.l10n.common_save,
            primary: true,
            block: true,
            onPressed: _saving ? null : () => unawaited(_save()),
          ),
        ),
      ],
    );
  }
}

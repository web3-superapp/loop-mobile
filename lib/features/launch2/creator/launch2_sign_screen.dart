import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_gateway.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart'
    show launch2CurveCapFigure;
import 'package:loop_mobile/features/meme/meme_wallet.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

/// The name of the chain a domain's `chainId` names, or its number.
String launch2ChainLabel(int reference) {
  for (final chainId in loopKnownChainIds) {
    if (loopChainReference(chainId) == reference) return loopChainName(chainId);
  }
  return 'chainId $reference';
}

/// What a wallet refusal means to the owner.
String launch2WalletRefusalText(String code) => switch (code) {
  'privy_signature_rejected' =>
    LoopL10n.current.launch2Creator_launch2SignSwitch,
  'privy_wallet_mismatch' => LoopL10n.current.launch2Creator_launch2SignSwitch2,
  'privy_chain_mismatch' => LoopL10n.current.launch2Creator_launch2SignSwitch3,
  'privy_session_required' || 'privy_wallet_unavailable' =>
    LoopL10n.current.launch2Creator_launch2SignSwitch4,
  _ => LoopL10n.current.launch2Creator_launch2SignSwitch5,
};

/// `launch2-project-sign` · 签名部署 (archetype `action`, layout `focus`).
///
/// The server's signing request — the predicted MEME address with its 6666
/// tail, the Hook, and the EIP-712 summary — signed through the sign sheet
/// with the embedded wallet (`eth_signTypedData_v4`) and submitted as one
/// deployment job. An expired request is renewed; a `409` re-reads it and
/// asks for a new signature.
class Launch2SignScreen extends ConsumerStatefulWidget {
  const Launch2SignScreen({
    required this.projectId,
    super.key,
    this.onBack,
    this.onSubmitted,
    this.onEdit,
    this.clock,
  });

  final String? projectId;
  final VoidCallback? onBack;
  final void Function(String projectId, String jobId)? onSubmitted;

  /// Opens the edit form: the answer to `422 HOOKS_BUYBACK_RECIPIENT_FIXED`
  /// (decision 0144), a version that names another recipient.
  final void Function(String projectId)? onEdit;
  final DateTime Function()? clock;

  @override
  ConsumerState<Launch2SignScreen> createState() => _Launch2SignScreenState();
}

class _Launch2SignScreenState extends ConsumerState<Launch2SignScreen> {
  String? _loadedFor;
  bool _expired = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  void _loadOnce(String projectId, String walletId) {
    if (_loadedFor == walletId) return;
    _loadedFor = walletId;
    scheduleMicrotask(() {
      if (!mounted) return;
      unawaited(
        ref
            .read(launch2SignControllerProvider(projectId).notifier)
            .load(walletId),
      );
    });
  }

  Future<void> _renew(String projectId, String walletId) async {
    setState(() => _expired = false);
    await ref
        .read(launch2SignControllerProvider(projectId).notifier)
        .load(walletId);
  }

  Future<void> _sign(
    String projectId,
    String walletId,
    Launch2SigningRequest request,
  ) async {
    final job = await showLoopSheet<Launch2DeploymentJob>(
      context,
      isDismissible: false,
      builder: (context) => _Launch2SignSheet(
        projectId: projectId,
        walletId: walletId,
        request: request,
        clock: widget.clock,
      ),
    );
    if (job != null && mounted) {
      widget.onSubmitted?.call(projectId, job.jobId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId;
    if (projectId == null) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-sign-screen'),
        archetype: LoopPageArchetype.action,
        title: context.l10n.launch2Creator_launch2SignLaunch2SignScreenTitle,
        onBack: widget.onBack,
        block: LoopPageBlock(
          key: ValueKey<String>('launch2-sign-missing'),
          title: context.l10n.launch2Creator_launch2CreateEmptyMessage,
          message: context
              .l10n
              .launch2Creator_launch2ProjectLaunch2ProjectMissingMessage,
        ),
        body: const <Widget>[],
      );
    }
    final wallet = memeActiveWallet(ref);
    final walletId = wallet.walletId;
    final state = ref.watch(launch2SignControllerProvider(projectId));
    if (walletId != null) _loadOnce(projectId, walletId);
    final request = state.request;
    final expired = _expired || (request != null && request.expiredAt(_now));

    final Widget? primary;
    if (walletId == null || request == null) {
      primary = null;
    } else if (expired) {
      primary = LoopButton(
        key: const ValueKey<String>('launch2-sign-renew'),
        label: context.l10n.launch2Creator_launch2SignLaunch2SignRenewLabel,
        primary: true,
        block: true,
        onPressed: state.busy
            ? null
            : () => unawaited(_renew(projectId, walletId)),
      );
    } else {
      primary = LoopButton(
        key: const ValueKey<String>('launch2-sign-submit'),
        label: switch (state.phase) {
          Launch2SignPhase.signing =>
            context.l10n.launch2Creator_launch2SignSigning,
          Launch2SignPhase.submitting =>
            context.l10n.launch2Creator_launch2SignSubmitting,
          _ => context.l10n.launch2Creator_launch2SignLoopButton,
        },
        primary: true,
        block: true,
        onPressed: state.busy || state.phase == Launch2SignPhase.submitted
            ? null
            : () => unawaited(_sign(projectId, walletId, request)),
      );
    }

    return LoopFocusPage(
      key: const ValueKey<String>('launch2-sign-screen'),
      archetype: LoopPageArchetype.action,
      title: context.l10n.launch2Creator_launch2SignLaunch2SignScreenTitle,
      onBack: widget.onBack,
      primaryAction: primary,
      body: <Widget>[
        if (walletId == null)
          LoopNotice(
            key: const ValueKey<String>('launch2-sign-no-wallet'),
            icon: 'wallet',
            tone: LoopNoticeTone.warn,
            body: wallet.loading
                ? context.l10n.launch2Creator_launch2SignLaunch2SignNoWalletBody
                : context
                      .l10n
                      .launch2Creator_launch2SignLaunch2SignNoWalletBody2,
          )
        else if (request == null)
          ..._unready(projectId, walletId, state)
        else
          ..._ready(projectId, walletId, request, state, expired),
      ],
    );
  }

  List<Widget> _unready(
    String projectId,
    String walletId,
    Launch2SignState state,
  ) {
    final failure = state.failure;
    if (state.phase != Launch2SignPhase.failed || failure == null) {
      return <Widget>[
        const LoopSkeleton(
          key: ValueKey<String>('launch2-sign-loading'),
          type: LoopSkeletonType.list,
          rows: 4,
        ),
        Padding(
          padding: const EdgeInsets.all(LoopSpacing.page),
          child: Text(
            LoopL10n.current.launch2Creator_launch2SignIf,
            style: LoopType.caption.copyWith(color: LoopColors.text3),
          ),
        ),
      ];
    }
    // Decision 0150: a used config version is answered by saving again too.
    final recipient = launch2FailureNeedsResave(failure.reasonCode);
    final blocked =
        failure.kind == LoopChainFailureKind.permissionDenied ||
        failure.kind == LoopChainFailureKind.notFound;
    return <Widget>[
      LoopNotice(
        key: ValueKey<String>('launch2-sign-load-failed-${failure.kind.name}'),
        icon: 'warn',
        tone: LoopNoticeTone.warn,
        body: launch2FailureText(failure),
        trailing: recipient
            ? _editButton(projectId)
            : blocked
            ? null
            : LoopButton(
                key: const ValueKey<String>('launch2-sign-retry'),
                label: LoopL10n.current.common_retry,
                onPressed: () => unawaited(_renew(projectId, walletId)),
              ),
      ),
    ];
  }

  Widget? _editButton(String projectId) {
    final onEdit = widget.onEdit;
    if (onEdit == null) return null;
    return LoopButton(
      key: const ValueKey<String>('launch2-sign-edit'),
      label:
          LoopL10n.current.launch2Creator_launch2CreateLaunch2CreateScreenTitle,
      onPressed: () => onEdit(projectId),
    );
  }

  List<Widget> _ready(
    String projectId,
    String walletId,
    Launch2SigningRequest request,
    Launch2SignState state,
    bool expired,
  ) {
    final failure = state.failure;
    final refusal = state.walletRefusal;
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          4,
          LoopSpacing.page,
          4,
        ),
        child: Text(
          LoopL10n.current.launch2Creator_launch2SignReady,
          style: LoopType.caption.copyWith(color: LoopColors.text3),
        ),
      ),
      Padding(
        key: const ValueKey<String>('launch2-sign-meme-address'),
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          16,
        ),
        child: Launch2AddressTail(address: request.memeAddress),
      ),
      LoopKeyValue(
        label: 'Hook',
        value: loopTruncatedAddress(request.hookAddress),
      ),
      LoopKeyValue(
        label: LoopL10n.current.common_network,
        value: launch2ChainLabel(request.domainChainId),
      ),
      const SizedBox(height: 8),
      LoopLabel(LoopL10n.current.launch2Creator_launch2SignLoopLabel),
      LoopKeyValue(label: LoopL10n.current.common_name, value: request.name),
      LoopKeyValue(
        label: LoopL10n.current.launch2Creator_launch2CreateLabel3,
        value: loopTickerLabel(request.ticker),
      ),
      LoopKeyValue(
        label: LoopL10n
            .current
            .launch2Creator_launch2ProjectLaunch2ProjectSaleStartLabel,
        value: loopLocalTimestampLabel(request.nftSaleStartAt),
      ),
      LoopKeyValue(
        label: LoopL10n.current.launch2Creator_launch2CreateLoopLabel,
        value: loopTruncatedAddress(request.buybackRecipient),
      ),
      // Decision 0284: the project's own terms the request signs.
      LoopKeyValue(
        key: const ValueKey<String>('launch2-sign-nft-price'),
        label: LoopL10n.current.launch2Creator_termsNftPriceLabel,
        value: launch2Usd1Label(request.nftPriceRaw),
      ),
      LoopKeyValue(
        key: const ValueKey<String>('launch2-sign-wallet-cap'),
        label: LoopL10n.current.launch2Creator_launch2Build6,
        value: LoopL10n.current.launch2Creator_launch2CapFigure(
          launch2CurveCapFigure(launch2Units(request.maxCumulativeBuyRaw)),
        ),
      ),
      LoopKeyValue(label: 'nonce', value: request.nonce),
      _DeadlineRow(
        key: ValueKey<String>('launch2-sign-deadline-${request.deadline}'),
        deadline: request.deadlineAt,
        clock: widget.clock,
        onExpired: () {
          if (mounted && !_expired) setState(() => _expired = true);
        },
      ),
      const SizedBox(height: 12),
      if (expired)
        LoopNotice(
          key: ValueKey<String>('launch2-sign-expired'),
          icon: 'clock',
          tone: LoopNoticeTone.warn,
          body:
              LoopL10n.current.launch2Creator_launch2SignLaunch2SignExpiredBody,
        ),
      if (state.refreshedAfterConflict)
        LoopNotice(
          key: ValueKey<String>('launch2-sign-refreshed'),
          icon: 'refresh',
          body: LoopL10n
              .current
              .launch2Creator_launch2SignLaunch2SignRefreshedBody,
        ),
      if (refusal != null)
        LoopNotice(
          key: const ValueKey<String>('launch2-sign-wallet-refused'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: launch2WalletRefusalText(refusal),
        ),
      if (failure != null)
        LoopNotice(
          key: ValueKey<String>(
            'launch2-sign-failed-${failure.reasonCode ?? failure.kind.name}',
          ),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: launch2FailureText(failure),
          trailing: launch2FailureNeedsResave(failure.reasonCode)
              ? _editButton(projectId)
              : null,
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          12,
        ),
        child: Text(
          LoopL10n.current.launch2Creator_launch2SignText,
          style: LoopType.captionSm.copyWith(color: LoopColors.text3),
        ),
      ),
    ];
  }
}

/// A predicted address with its last four characters in Lime — where the
/// 6666 tail shows. The page's one large figure.
class Launch2AddressTail extends StatelessWidget {
  const Launch2AddressTail({required this.address, super.key});

  final String address;

  @override
  Widget build(BuildContext context) {
    final head = address.substring(0, address.length - 4);
    final tail = address.substring(address.length - 4);
    return Semantics(
      label: context.l10n.launch2Creator_launch2SignLabel(address),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: head,
              style: LoopType.figureMd.copyWith(color: LoopColors.text2),
            ),
            TextSpan(
              text: tail,
              style: LoopType.figureMd.copyWith(color: LoopColors.yellow),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「签名有效期 · 12:34 后过期」, redrawn each second on its own.
class _DeadlineRow extends StatefulWidget {
  const _DeadlineRow({
    required this.deadline,
    required this.onExpired,
    super.key,
    this.clock,
  });

  final DateTime deadline;
  final VoidCallback onExpired;
  final DateTime Function()? clock;

  @override
  State<_DeadlineRow> createState() => _DeadlineRowState();
}

class _DeadlineRowState extends State<_DeadlineRow> {
  Timer? _timer;
  bool _reported = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadline.difference(_now);
    if (left <= Duration.zero) {
      _timer?.cancel();
      if (!_reported) {
        _reported = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExpired());
      }
    }
    final minutes = left.inMinutes.clamp(0, 999);
    final seconds = (left.inSeconds % 60).clamp(0, 59);
    return LoopKeyValue(
      label: context.l10n.launch2Creator_launch2SignLabel2,
      value: left <= Duration.zero
          ? context.l10n.common_expired
          : context.l10n.launch2Creator_launch2SignValue(
              minutes.toString().padLeft(2, '0'),
              seconds.toString().padLeft(2, '0'),
            ),
      valueUp: left <= Duration.zero ? false : null,
    );
  }
}

/// The signing exit for one launch request: the shared sign sheet, then the
/// wallet, then the submission. It closes with the job, or with nothing.
class _Launch2SignSheet extends ConsumerStatefulWidget {
  const _Launch2SignSheet({
    required this.projectId,
    required this.walletId,
    required this.request,
    this.clock,
  });

  final String projectId;
  final String walletId;
  final Launch2SigningRequest request;
  final DateTime Function()? clock;

  @override
  ConsumerState<_Launch2SignSheet> createState() => _Launch2SignSheetState();
}

class _Launch2SignSheetState extends ConsumerState<_Launch2SignSheet> {
  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  bool _submitted = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    if (!ref.read(launch2TypedDataSignerProvider).available) {
      _state = LoopSignSheetState.policyRejected;
      _reason = launch2WalletRefusalText('privy_wallet_unavailable');
    }
  }

  Future<void> _confirm() async {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _state = LoopSignSheetState.signing;
      _reason = null;
    });
    final job = await ref
        .read(launch2SignControllerProvider(widget.projectId).notifier)
        .signAndSubmit(walletId: widget.walletId, now: _now);
    if (!mounted) return;
    if (job != null) {
      Navigator.of(context).pop(job);
      return;
    }
    // The page under the sheet says what refused; the sheet closes.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return PopScope(
      canPop: _state != LoopSignSheetState.signing,
      child: LoopSignSheet(
        key: const ValueKey<String>('launch2-sign-sheet'),
        state: _state,
        title: context.l10n.launch2Creator_launch2SignLaunch2SignSheetTitle,
        networkBadge:
            request.domainChainId ==
                loopChainReference(loopLaunchTestnetChainId)
            ? loopTestnetBadgeFor(loopLaunchTestnetChainId)
            : null,
        confirmLabel: context.l10n.common_sign,
        facts: <LoopSignFact>[
          LoopSignFact(
            context.l10n.common_actions,
            context.l10n.launch2Creator_launch2SignLoopSignFact(
              loopTickerLabel(request.ticker),
            ),
          ),
          LoopSignFact(
            context.l10n.launch2Creator_launch2SignReady,
            loopTruncatedAddress(request.memeAddress),
          ),
          LoopSignFact(
            context.l10n.launch2Creator_launch2SignLoopSignFact2,
            loopTruncatedAddress(request.projectOwner),
          ),
          LoopSignFact(
            context.l10n.common_validUntil,
            loopLocalTimestampLabel(request.deadlineAt),
          ),
          LoopSignFact(
            context.l10n.launch2Creator_launch2SignLoopSignFact3,
            context.l10n.launch2Creator_launch2SignLoopSignFact4,
          ),
        ],
        reason: _reason,
        onConfirm: _submitted ? null : _confirm,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

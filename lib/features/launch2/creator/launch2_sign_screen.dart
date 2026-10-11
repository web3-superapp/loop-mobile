import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_gateway.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';
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
  'privy_signature_rejected' => '你在钱包里取消了签名，没有提交任何内容。',
  'privy_wallet_mismatch' => '签名请求属于另一个钱包，请切换到项目方钱包。',
  'privy_chain_mismatch' => '签名请求的网络不对，没有签名。',
  'privy_session_required' || 'privy_wallet_unavailable' => '内嵌钱包不可用，请重新登录后再试。',
  _ => '钱包没有完成签名，没有提交任何内容。',
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
        title: '签名部署',
        onBack: widget.onBack,
        block: const LoopPageBlock(
          key: ValueKey<String>('launch2-sign-missing'),
          title: '找不到这个项目',
          message: '链接里没有有效的项目编号。',
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
        label: '续期签名请求',
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
          Launch2SignPhase.signing => '等待钱包签名…',
          Launch2SignPhase.submitting => '正在提交…',
          _ => '签名并提交',
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
      title: '签名部署',
      onBack: widget.onBack,
      primaryAction: primary,
      body: <Widget>[
        if (walletId == null)
          LoopNotice(
            key: const ValueKey<String>('launch2-sign-no-wallet'),
            icon: 'wallet',
            tone: LoopNoticeTone.warn,
            body: wallet.loading ? '正在读取钱包…' : '还没有可用的钱包，先在钱包里创建或激活一个。',
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
            '正在准备签名请求，服务端计算地址可能要几秒。',
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
                label: '重试',
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
      label: '修改资料',
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
          '代币地址',
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
        label: '网络',
        value: launch2ChainLabel(request.domainChainId),
      ),
      const SizedBox(height: 8),
      const LoopLabel('签名内容'),
      LoopKeyValue(label: '名称', value: request.name),
      LoopKeyValue(label: '代码', value: '\$${request.ticker}'),
      LoopKeyValue(
        label: 'NFT 开售',
        value: loopLocalTimestampLabel(request.nftSaleStartAt),
      ),
      LoopKeyValue(
        label: '回购收币地址',
        value: loopTruncatedAddress(request.buybackRecipient),
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
        const LoopNotice(
          key: ValueKey<String>('launch2-sign-expired'),
          icon: 'clock',
          tone: LoopNoticeTone.warn,
          body: '签名请求已过期。续期后会拿到新的请求，需要重新签名。',
        ),
      if (state.refreshedAfterConflict)
        const LoopNotice(
          key: ValueKey<String>('launch2-sign-refreshed'),
          icon: 'refresh',
          body: '配置或 nonce 已变化，已刷新签名请求，请重新签名。',
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
          '这是一次授权签名，不花费资产；平台收到后部署并激活，进度在下一页。',
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
      label: '代币地址 $address',
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
              style: LoopType.figureMd.copyWith(color: LoopColors.lime),
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
      label: '签名有效期',
      value: left <= Duration.zero
          ? '已过期'
          : '${minutes.toString().padLeft(2, '0')}:'
                '${seconds.toString().padLeft(2, '0')} 后过期',
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
        title: '授权部署',
        networkBadge:
            request.domainChainId ==
                loopChainReference(loopLaunchTestnetChainId)
            ? loopTestnetBadgeLabel
            : null,
        confirmLabel: '签名',
        facts: <LoopSignFact>[
          LoopSignFact('操作', '授权部署 \$${request.ticker}'),
          LoopSignFact('代币地址', loopTruncatedAddress(request.memeAddress)),
          LoopSignFact('签名钱包', loopTruncatedAddress(request.projectOwner)),
          LoopSignFact('有效期至', loopLocalTimestampLabel(request.deadlineAt)),
          const LoopSignFact('花费', '无（只签名，不发交易）'),
        ],
        reason: _reason,
        onConfirm: _submitted ? null : _confirm,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

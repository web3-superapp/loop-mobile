import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The route argument carried through the three Send steps.
///
/// It holds only opaque ids and the exact text the owner typed. Nothing here
/// is a fact: the amount is checked against a balance snapshot, the recipient
/// against a preflight, and the transaction is built by the server.
@immutable
final class SendDraft {
  const SendDraft({
    required this.walletId,
    required this.assetId,
    required this.symbol,
    this.recipientAddress,
    this.amount,
  });

  final String walletId;
  final String assetId;
  final String symbol;

  /// The EIP-55 checksum address the preflight returned.
  final String? recipientAddress;

  /// The exact decimal string the owner typed, never a `double`.
  final String? amount;

  bool get isComplete =>
      (recipientAddress?.isNotEmpty ?? false) && (amount?.isNotEmpty ?? false);

  SendDraft copyWith({String? recipientAddress, String? amount}) => SendDraft(
    walletId: walletId,
    assetId: assetId,
    symbol: symbol,
    recipientAddress: recipientAddress ?? this.recipientAddress,
    amount: amount ?? this.amount,
  );
}

/// The shared gate for every money-action page: the module capability plus the
/// assembled adapter. A closed gate renders the server's own reason code.
bool sendCapabilityBlocks(WidgetRef ref) => moneyActionBlocks(
  ref.watch(walletIntentsGatewayProvider).mode,
  ref.watch(loopCapabilityProvider(LoopV2CapabilityId.sendApprovals)),
);

String sendCapabilityReason(WidgetRef ref) =>
    ref
        .watch(loopCapabilityProvider(LoopV2CapabilityId.sendApprovals))
        .reasonCode ??
    'WALLET_INTENT_RUNTIME_UNAVAILABLE';

/// Loads the wallet directory once and returns the active wallet id.
String? watchActiveMoneyWalletId(WidgetRef ref, {required bool blocked}) {
  final directory = ref.watch(walletDirectoryControllerProvider);
  if (!blocked && directory.phase == LoopChainViewPhase.loading) {
    scheduleMicrotask(
      () => unawaited(
        ref.read(walletDirectoryControllerProvider.notifier).load(),
      ),
    );
  }
  return directory.value?.activeWalletId;
}

// ---------------------------------------------------------------------------
// send · choose the asset
// ---------------------------------------------------------------------------

/// `send` · step 1. Every row is a registry asset read at one block height.
class SendAssetScreen extends ConsumerStatefulWidget {
  const SendAssetScreen({super.key, this.onBack, this.onNavigate});

  final VoidCallback? onBack;
  final void Function(String location, {Object? extra})? onNavigate;

  @override
  ConsumerState<SendAssetScreen> createState() => _SendAssetScreenState();
}

class _SendAssetScreenState extends ConsumerState<SendAssetScreen> {
  void _open(String location, {Object? extra}) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location, extra: extra);
      return;
    }
    context.push(location, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = sendCapabilityBlocks(ref);
    final walletId = watchActiveMoneyWalletId(ref, blocked: blocked);
    final directory = ref.watch(walletDirectoryControllerProvider);
    final balancesState = walletId == null
        ? null
        : ref.watch(walletBalancesControllerProvider(walletId));
    if (!blocked &&
        walletId != null &&
        balancesState != null &&
        balancesState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .load(),
          );
        }
      });
    }
    final balances = balancesState?.value;

    return LoopFocusPage(
      key: const ValueKey<String>('send-asset-screen'),
      archetype: LoopPageArchetype.action,
      title: '发送',
      onBack: widget.onBack,
      folio: const LoopFolioPrimary(
        key: ValueKey<String>('send-asset-folio'),
        kicker: 'FROM WALLET',
        heading: '选择要发送的资产',
        caption: '余额与网络先展示，再进入收款地址。',
        stamp: 'STEP 1',
      ),
      body: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('send-capability-block'),
            label: '发送当前不可用',
            reasonCode: sendCapabilityReason(ref),
          )
        else if (walletId == null)
          LoopChainStateBlock(
            keyPrefix: 'send-directory',
            phase: directory.phase,
            failureKind: directory.failureKind,
            emptyMessage: '这个账号还没有可用于发送的钱包',
            emptyReason: '只有 Privy 嵌入式钱包可以从本机签名并广播。',
            onRetry: () => unawaited(
              ref.read(walletDirectoryControllerProvider.notifier).reload(),
            ),
          )
        else if (balancesState == null || !balancesState.isReady)
          LoopChainStateBlock(
            keyPrefix: 'send-balances',
            phase: balancesState?.phase ?? LoopChainViewPhase.loading,
            failureKind: balancesState?.failureKind,
            emptyMessage: '这个钱包还没有可读资产',
            onRetry: () => unawaited(
              ref
                  .read(walletBalancesControllerProvider(walletId).notifier)
                  .reload(),
            ),
          )
        else ...<Widget>[
          const LoopLabel('选择资产'),
          if (balances!.balances.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('send-assets-empty'),
              message: '还没有可读取的资产',
              reason: '登记资产后，这里会为每一个资产恒定保留一行。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final row in balances.balances)
                  _sendAssetRow(
                    row,
                    onTap: row.balance is LoopBalanceAvailable
                        ? () => _open(
                            '/wallet/send/to',
                            extra: SendDraft(
                              walletId: walletId,
                              assetId: row.assetId,
                              symbol: row.symbol,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
          WalletSnapshotFooter(snapshot: balances.snapshot),
          const LoopNotice(
            key: ValueKey<String>('send-power-notice'),
            icon: 'mine',
            tone: LoopNoticeTone.warn,
            title: '发送会降低算力',
            body: '转出有权重的社区币后，算力会随持仓下降。具体数值暂时读不到，这里不做估算。',
          ),
        ],
      ],
    );
  }

  /// A row whose chain read failed is kept and stated, never hidden and never
  /// rendered as a zero balance — but it cannot be selected either.
  LoopRecordRow _sendAssetRow(LoopAssetBalanceRow row, {VoidCallback? onTap}) {
    final balance = row.balance;
    return LoopRecordRow(
      key: ValueKey<String>('send-asset-${row.assetId}'),
      onTap: onTap,
      leading: LoopTokenLogo(
        assetSymbol: row.symbol,
        fallbackMonogram: row.symbol,
      ),
      title: row.symbol,
      subtitle: switch (balance) {
        LoopBalanceUnavailable(reasonCode: final reasonCode) =>
          loopReasonCodeText(reasonCode),
        LoopBalanceAvailable(spendableBalance: final spendable) =>
          '${row.name} · 可动用 ${loopFormatDecimal(spendable)}',
      },
      trailing: switch (balance) {
        LoopBalanceUnavailable() => null,
        LoopBalanceAvailable(displayBalance: final display) =>
          loopFormatDecimal(display),
      },
      trailingBadge: balance is LoopBalanceUnavailable
          ? const LoopBadge('读不到', kind: LoopBadgeKind.down)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// send-to · recipient and amount
// ---------------------------------------------------------------------------

/// `send-to` · step 2. The recipient is checked by the server's preflight; the
/// amount is checked against the same balance snapshot the review will use.
class SendRecipientScreen extends ConsumerStatefulWidget {
  const SendRecipientScreen({
    required this.draft,
    super.key,
    this.onBack,
    this.onNavigate,
  });

  final SendDraft draft;
  final VoidCallback? onBack;
  final void Function(String location, {Object? extra})? onNavigate;

  @override
  ConsumerState<SendRecipientScreen> createState() =>
      _SendRecipientScreenState();
}

class _SendRecipientScreenState extends ConsumerState<SendRecipientScreen> {
  late final TextEditingController _address = TextEditingController(
    text: widget.draft.recipientAddress ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.draft.amount ?? '',
  );

  LoopSendPreflight? _preflight;
  LoopChainException? _preflightFailure;
  bool _checking = false;

  static final RegExp _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

  @override
  void dispose() {
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _open(String location, {Object? extra}) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location, extra: extra);
      return;
    }
    context.push(location, extra: extra);
  }

  Future<void> _check() async {
    final address = _address.text.trim();
    if (_checking || !_addressPattern.hasMatch(address)) return;
    setState(() {
      _checking = true;
      _preflight = null;
      _preflightFailure = null;
    });
    try {
      final result = await ref
          .read(walletIntentsGatewayProvider)
          .preflightRecipient(
            walletId: widget.draft.walletId,
            address: address,
          );
      if (!mounted) return;
      setState(() {
        _preflight = result;
        _checking = false;
        // The server normalises the address; the field adopts its checksum
        // form so what is reviewed is what was checked.
        _address.text = result.recipient.checksumAddress;
      });
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _preflightFailure = failure;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preflightFailure = const LoopChainException(
          LoopChainFailureKind.unexpected,
        );
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = sendCapabilityBlocks(ref);
    final balancesState = ref.watch(
      walletBalancesControllerProvider(widget.draft.walletId),
    );
    if (!blocked && balancesState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(
                  walletBalancesControllerProvider(widget.draft.walletId)
                      .notifier,
                )
                .load(),
          );
        }
      });
    }
    final row = balancesState.value?.rowFor(widget.draft.assetId);
    final spendable = row?.balance is LoopBalanceAvailable
        ? (row!.balance as LoopBalanceAvailable).spendableBalance
        : null;
    final amount = TransferAmount.tryParse(_amount.text.trim());
    final preflight = _preflight;
    final overSpendable =
        amount != null &&
        spendable != null &&
        Decimal.parse(amount.wire) > spendable;
    final ready =
        !blocked && preflight != null && amount != null && !overSpendable;

    return LoopFocusPage(
      key: const ValueKey<String>('send-recipient-screen'),
      archetype: LoopPageArchetype.action,
      title: '发送到',
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('send-recipient-folio'),
        kicker: 'WALLET SEND',
        heading: widget.draft.symbol,
        caption: '地址与网络先校验，金额会在下一步单独确认。',
        stamp: 'STEP 2',
      ),
      primaryAction: LoopButton(
        key: const ValueKey<String>('send-recipient-next'),
        label: '下一步',
        primary: true,
        block: true,
        onPressed: ready
            ? () => _open(
                '/wallet/send/confirm',
                extra: widget.draft.copyWith(
                  recipientAddress: preflight.recipient.checksumAddress,
                  amount: amount.wire,
                ),
              )
            : null,
      ),
      body: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('send-recipient-capability-block'),
            label: '发送当前不可用',
            reasonCode: sendCapabilityReason(ref),
          )
        else ...<Widget>[
          const LoopLabel('收款地址'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: LoopSurfaceCard(
              child: TextField(
                key: const ValueKey<String>('send-recipient-field'),
                controller: _address,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 42,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                onChanged: (_) => setState(() {
                  _preflight = null;
                  _preflightFailure = null;
                }),
                onSubmitted: (_) => unawaited(_check()),
                decoration: const InputDecoration(
                  labelText: '完整收款地址（BNB Smart Chain）',
                  hintText: '0x…',
                  counterText: '',
                ),
              ),
            ),
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('send-recipient-paste'),
                label: '粘贴',
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  final text = data?.text?.trim() ?? '';
                  if (!mounted || text.isEmpty) return;
                  setState(() {
                    _address.text = text;
                    _preflight = null;
                    _preflightFailure = null;
                  });
                },
              ),
              LoopButton(
                key: const ValueKey<String>('send-recipient-check'),
                label: _checking ? '校验中' : '校验地址',
                primary: true,
                onPressed:
                    _checking || !_addressPattern.hasMatch(_address.text.trim())
                    ? null
                    : () => unawaited(_check()),
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('send-recipient-scan-unavailable'),
            icon: 'camera',
            body: '扫码与最近联系人还没有开放，请粘贴或输入完整地址。',
          ),
          // An address check that never reached the server has not prepared an
          // intent, opened a wallet or submitted anything. It pauses; only a
          // server answer is an error.
          if (MoneyOfflinePause.covers(_preflightFailure))
            MoneyOfflinePause(
              blockKey: 'send-recipient-preflight-offline',
              pausedActions: const <String>['校验地址', '下一步', '签名'],
              onRetry: () => unawaited(_check()),
            )
          // The server read the address and refused to answer for it. It is a
          // refusal, not a failed read: retrying cannot change it.
          else if (MoneyPolicyNotice.covers(_preflightFailure))
            MoneyPolicyNotice(
              blockKey: 'send-to-permission',
              failure: _preflightFailure!,
              onOpenSecurity: () => _open('/profile/security'),
            )
          else if (_preflightFailure != null)
            LoopErrorState(
              key: const ValueKey<String>('send-recipient-preflight-error'),
              title: '地址没有校验成功',
              reason: loopChainFailureReason(_preflightFailure!.kind),
              onRetry: () => unawaited(_check()),
            ),
          if (preflight != null) ..._recipientNotices(preflight),
          const LoopLabel('金额'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: LoopSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    key: const ValueKey<String>('send-amount-field'),
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    // The amount stays the exact text all the way to the wire.
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    maxLength: TransferAmount.maxWireLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: '发送数量（${widget.draft.symbol}）',
                      counterText: '',
                      errorText: overSpendable ? '超过可动用余额' : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    spendable == null
                        ? '读不到可用余额，这里不做估算。'
                        : '可动用 ${loopFormatDecimal(spendable)} '
                              '${widget.draft.symbol}'
                              '（已扣除手续费保留）',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (balancesState.value != null)
            WalletSnapshotFooter(snapshot: balancesState.value!.snapshot),
        ],
      ],
    );
  }

  List<Widget> _recipientNotices(LoopSendPreflight preflight) {
    final recipient = preflight.recipient;
    return <Widget>[
      if (preflight.warnings.contains(LoopSendPreflight.firstTimeWarning))
        const LoopNotice(
          key: ValueKey<String>('send-recipient-first-time'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '首次向该地址转账',
          body: '这个地址不在你自己的已索引转账历史中。请逐字核对完整地址后再继续。',
        ),
      if (preflight.warnings.contains(LoopSendPreflight.contractWarning))
        const LoopNotice(
          key: ValueKey<String>('send-recipient-contract'),
          icon: 'warn',
          tone: LoopNoticeTone.danger,
          title: '收款方是合约地址',
          body: '向合约地址直接转账可能永久失去这笔资产。请确认这个合约确实接受直接转账。',
        ),
      LoopNotice(
        key: const ValueKey<String>('send-recipient-screening'),
        icon: 'shield',
        tone: LoopNoticeTone.warn,
        title: '恶意地址筛查不可用',
        body: loopReasonCodeText(recipient.screening.reasonCode),
      ),
      LoopProvenanceFooter(
        key: const ValueKey<String>('send-recipient-basis'),
        text: '首次收款方的判断依据：你自己的 ERC-20 转账记录（${preflight.basis}）',
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// send-confirm · prepare the intent and open the signing exit
// ---------------------------------------------------------------------------

/// `send-confirm` · step 3.
///
/// Entering this page prepares a server intent. Preparing a second intent for
/// the same wallet expires the first one, so an unsigned intent that already
/// exists is surfaced first and must be reported or cancelled by hand.
class SendConfirmScreen extends ConsumerStatefulWidget {
  const SendConfirmScreen({
    required this.draft,
    super.key,
    this.onBack,
    this.onNavigate,
    this.clock,
  });

  final SendDraft draft;
  final VoidCallback? onBack;
  final void Function(String location, {Object? extra})? onNavigate;
  final DateTime Function()? clock;

  @override
  ConsumerState<SendConfirmScreen> createState() => _SendConfirmScreenState();
}

class _SendConfirmScreenState extends ConsumerState<SendConfirmScreen> {
  LoopWalletIntent? _intent;
  LoopWalletIntent? _pendingOther;
  LoopChainException? _failure;
  bool _busy = false;
  bool _started = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  void _open(String location, {Object? extra}) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location, extra: extra);
      return;
    }
    context.push(location, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = sendCapabilityBlocks(ref);
    if (!blocked && !_started) {
      _started = true;
      scheduleMicrotask(() {
        if (mounted) unawaited(_prepare());
      });
    }
    final intent = _intent;
    final other = _pendingOther;

    return LoopFocusPage(
      key: const ValueKey<String>('send-confirm-screen'),
      archetype: LoopPageArchetype.action,
      title: '确认发送',
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('send-confirm-folio'),
        kicker: 'FINAL REVIEW',
        heading: '${widget.draft.amount ?? ''} ${widget.draft.symbol}'.trim(),
        caption: '收款方、网络费与试算结果全部确认后才会请求签名。',
        stamp: 'SIGN',
      ),
      primaryAction: intent == null
          ? null
          : MoneyCountdown(
              expiresAt: intent.expiresAt,
              clock: widget.clock,
              builder: (context, remaining) => LoopButton(
                key: const ValueKey<String>('send-confirm-sign'),
                label: remaining == Duration.zero
                    ? '事实已过期 · 重新准备'
                    : '确认发送（${moneyCountdownLabel(remaining)}）',
                primary: true,
                block: true,
                onPressed: _busy
                    ? null
                    : remaining == Duration.zero
                    ? () => unawaited(_prepare(force: true))
                    : intent.canSignAt(_now)
                    ? () => unawaited(_sign(intent))
                    : null,
              ),
            ),
      body: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('send-confirm-capability-block'),
            label: '发送当前不可用',
            reasonCode: sendCapabilityReason(ref),
          )
        else if (other != null)
          _PendingIntentBlock(
            intent: other,
            busy: _busy,
            onReport: () =>
                _open('/wallet/tx/result?intentId=${other.intentId}'),
            onCancel: () => unawaited(_cancelOther(other)),
          )
        else if (MoneyPolicyNotice.covers(_failure))
          MoneyPolicyNotice(
            blockKey: 'send-confirm-permission',
            failure: _failure!,
            onOpenSecurity: () => _open('/profile/security'),
          )
        else if (intent == null)
          LoopChainStateBlock(
            keyPrefix: 'send-confirm',
            phase: _failure == null
                ? LoopChainViewPhase.loading
                : loopChainPhaseForFailure(_failure!.kind),
            failureKind: _failure?.kind,
            skeleton: LoopSkeletonType.detail,
            onRetry: () => unawaited(_prepare(force: true)),
          )
        else ...<Widget>[
          MoneyIntentReviewCard(intent: intent, clock: widget.clock),
          if (!intent.simulation.passed)
            LoopNotice(
              key: const ValueKey<String>('send-confirm-simulation-failed'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title: '试算没有通过，不能签名',
              body: loopReasonCodeText(intent.simulation.reasonCode),
            ),
          MoneyCountdown(
            expiresAt: intent.expiresAt,
            clock: widget.clock,
            builder: (context, remaining) => remaining == Duration.zero
                ? const LoopNotice(
                    key: ValueKey<String>('send-confirm-expired'),
                    icon: 'clock',
                    tone: LoopNoticeTone.warn,
                    title: '事实已过期',
                    body: '余额、费用与试算结果都取自同一时刻。请重新准备一次再签名。',
                  )
                : const SizedBox.shrink(),
          ),
          const LoopNotice(
            key: ValueKey<String>('send-confirm-signing-exit'),
            body:
                '签名由 Privy 嵌入式钱包在本机执行；所有资金操作都汇聚到同一个签名弹层，'
                '这是全产品唯一的签名出口。',
            title: '统一签名出口',
          ),
          const LoopNotice(
            key: ValueKey<String>('send-confirm-power'),
            icon: 'mine',
            tone: LoopNoticeTone.warn,
            title: '算力会随持仓下降',
            body: '转出后算力会随持仓下降。具体数值暂时读不到，这里不做估算。',
          ),
        ],
      ],
    );
  }

  /// Prepares one intent, after checking that the wallet has no unsigned one.
  Future<void> _prepare({bool force = false}) async {
    if (_busy) return;
    final draft = widget.draft;
    final amount = draft.amount;
    final recipient = draft.recipientAddress;
    if (amount == null || recipient == null) return;
    setState(() {
      _busy = true;
      _failure = null;
      _pendingOther = null;
    });
    final gateway = ref.read(walletIntentsGatewayProvider);
    try {
      if (!force) {
        final page = await gateway.loadIntents();
        final blocking = page.items
            .where(
              (item) =>
                  item.walletId == draft.walletId &&
                  (item.state == LoopIntentState.awaitingSignature ||
                      item.state == LoopIntentState.prepared) &&
                  !item.isExpiredAt(_now),
            )
            .toList(growable: false);
        if (blocking.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _pendingOther = blocking.first;
            _busy = false;
          });
          return;
        }
      }
      final intent = await gateway.prepareSend(
        walletId: draft.walletId,
        assetId: draft.assetId,
        amount: amount,
        recipientAddress: recipient,
      );
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _busy = false;
      });
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failure = const LoopChainException(LoopChainFailureKind.unexpected);
        _busy = false;
      });
    }
  }

  Future<void> _cancelOther(LoopWalletIntent other) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(walletIntentsGatewayProvider).cancel(other.intentId);
      if (!mounted) return;
      setState(() {
        _pendingOther = null;
        _busy = false;
      });
      await _prepare(force: true);
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _busy = false;
      });
    }
  }

  Future<void> _sign(LoopWalletIntent intent) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await showMoneySignSheet(
      context,
      intent: intent,
      signer: ref.read(moneyActionSignerProvider),
      clock: widget.clock,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == null) return;
    // A locked outcome — including a broadcast the server did not accept —
    // has only one honest next screen.
    if (outcome.opensResult) {
      _open('/wallet/tx/result?intentId=${intent.intentId}');
    }
  }
}

/// The block that appears when the wallet already has an unsigned intent.
///
/// Preparing a new one would expire it, and a hash broadcast after that has to
/// be recovered by the late-report path — so the owner resolves it first.
class _PendingIntentBlock extends StatelessWidget {
  const _PendingIntentBlock({
    required this.intent,
    required this.busy,
    required this.onReport,
    required this.onCancel,
  });

  final LoopWalletIntent intent;
  final bool busy;
  final VoidCallback onReport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('money-pending-intent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopNotice(
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '这个钱包还有一笔未完成的操作',
          body:
              '${moneyActionTitle(intent.kind)} · '
              '${moneyIntentStateLabel(intent.state)}。'
              '再准备一笔新的会让它失效；如果它已经签名并广播，请先上报或取消。',
        ),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('money-pending-open'),
              label: '查看那一笔',
              onPressed: busy ? null : onReport,
            ),
            LoopButton(
              key: const ValueKey<String>('money-pending-cancel'),
              label: '取消并重新准备',
              primary: true,
              onPressed: busy ? null : onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

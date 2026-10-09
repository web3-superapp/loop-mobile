import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_capability_refresh.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/money_asset_picker.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
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
    this.recipientPrefill,
  });

  final String walletId;
  final String assetId;
  final String symbol;

  /// The EIP-55 checksum address the preflight returned.
  final String? recipientAddress;

  /// An address the recipient field starts with, from a scanned code
  /// (decision 0113). It is text in a field and nothing more: the reader
  /// still asks the preflight to check it, exactly as if they had pasted it.
  final String? recipientPrefill;

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
    recipientPrefill: recipientPrefill,
  );
}

/// The typed state `/wallet/send` takes from the scanner (decision 0113):
/// the address a code carried. It travels as navigation state, never in the
/// URL, and the asset is still the reader's choice.
@immutable
final class SendRecipientPrefill {
  const SendRecipientPrefill(this.address);

  final String address;

  /// The prefill [extra] carries, or null for any other navigation state.
  static String? addressFrom(Object? extra) =>
      extra is SendRecipientPrefill ? extra.address : null;
}

/// The shared gate for every money-action page: the module capability plus the
/// assembled adapter. A closed gate renders the server's own reason code.
bool sendCapabilityBlocks(WidgetRef ref) => moneyActionBlocks(
  ref.watch(walletIntentsGatewayProvider).mode,
  ref.watch(loopCapabilityProvider(LoopV2CapabilityId.sendApprovals)),
);

/// The same gate, as a strip inside a page that keeps its own shape.
///
/// A deferred capability is not a page with nothing on it: the prototype's
/// action pages keep their primary and their group headings and state the
/// reason where the content would be (visual audit item 4). The page still
/// pins no confirmation button — there is nothing to confirm.
Widget sendCapabilityBlockCard(
  WidgetRef ref, {
  required Key key,
  required String label,
}) {
  final capability = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.sendApprovals),
  );
  return LoopUnavailableCard(
    key: key,
    label: label,
    // An unreachable gate has no server reason to render; the client never
    // invents one for it.
    reasonCode: capability.unreachable
        ? null
        : capability.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
  );
}

/// The whole-page block a closed send/approval gate renders. A blocked action
/// page shows no pinned confirmation button: there is nothing to confirm.
Widget sendCapabilityPageBlock(
  WidgetRef ref, {
  required Key key,
  required String title,
}) => LoopCapabilityPageBlock.of(
  key: key,
  title: title,
  capability: ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.sendApprovals),
  ),
  fallbackReasonCode: 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
);

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
// send · send-to · the two input steps (decision 0131)
// ---------------------------------------------------------------------------

/// The typed state `/wallet/send` pushes `/scan` with: the scanner hands a
/// recognised wallet address back to the page that asked instead of opening
/// a new send flow on top of it.
@immutable
final class SendScanForRecipient {
  const SendScanForRecipient();
}

/// How long a typed full-length address waits before it is checked by itself.
const Duration sendRecipientCheckDebounce = Duration(milliseconds: 400);

/// The three send steps, in the order a wallet app asks for them.
const int sendStepCount = 3;

/// `send` · the route that starts the flow at its first step.
///
/// The class keeps its name because the route table builds it; since decision
/// 0131 it is the recipient step of [SendFlowScreen], not an asset list. A
/// scanned address arrives as [recipientPrefill] and is checked at once.
class SendAssetScreen extends StatelessWidget {
  const SendAssetScreen({
    super.key,
    this.onBack,
    this.onNavigate,
    this.onScan,
    this.recipientPrefill,
  });

  final VoidCallback? onBack;
  final void Function(String location, {Object? extra})? onNavigate;
  final Future<String?> Function()? onScan;

  /// A scanned address the recipient field starts with.
  final String? recipientPrefill;

  @override
  Widget build(BuildContext context) => SendFlowScreen(
    onBack: onBack,
    onNavigate: onNavigate,
    onScan: onScan,
    recipientPrefill: recipientPrefill,
  );
}

/// `send-to` · the same flow, entered with a draft another page prepared — a
/// wallet asset page's 发送 names the asset. The flow still starts at the
/// recipient; the asset is already chosen when the amount step opens.
class SendRecipientScreen extends StatelessWidget {
  const SendRecipientScreen({
    required this.draft,
    super.key,
    this.onBack,
    this.onNavigate,
    this.onScan,
  });

  final SendDraft draft;
  final VoidCallback? onBack;
  final void Function(String location, {Object? extra})? onNavigate;
  final Future<String?> Function()? onScan;

  @override
  Widget build(BuildContext context) => SendFlowScreen(
    initialDraft: draft,
    onBack: onBack,
    onNavigate: onNavigate,
    onScan: onScan,
  );
}

/// Steps 1 and 2 of 发送 (decision 0131, audit 2026-10-09 M9).
///
/// Step 1 is the recipient alone: the field takes a paste or a scan from
/// its own trailing controls and asks the server's preflight by itself — on
/// a paste, a scan, leaving the field, the keyboard's done key, or a typed
/// address that has reached its full length — and 下一步 opens only on a
/// checked address. Step 2 is the asset and the amount, with 全部 filling
/// the spendable balance (the gas reserve already taken off). Step 3 is
/// `send-confirm`, where the server's intent is reviewed and the one signing
/// sheet opens. System back on step 2 returns to step 1.
class SendFlowScreen extends ConsumerStatefulWidget {
  const SendFlowScreen({
    super.key,
    this.initialDraft,
    this.recipientPrefill,
    this.onBack,
    this.onNavigate,
    this.onScan,
  });

  /// A draft from another page: its asset is preselected, and a recipient in
  /// it is a prefill that is checked again like any other.
  final SendDraft? initialDraft;
  final String? recipientPrefill;
  final VoidCallback? onBack;
  final void Function(String location, {Object? extra})? onNavigate;

  /// Opens the scanner and returns the address it read, or null. Defaults to
  /// pushing `/scan` with [SendScanForRecipient].
  final Future<String?> Function()? onScan;

  @override
  ConsumerState<SendFlowScreen> createState() => _SendFlowScreenState();
}

class _SendFlowScreenState extends ConsumerState<SendFlowScreen> {
  late final TextEditingController _address = TextEditingController(
    text:
        widget.initialDraft?.recipientAddress ??
        widget.initialDraft?.recipientPrefill ??
        widget.recipientPrefill ??
        '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.initialDraft?.amount ?? '',
  );
  final FocusNode _addressFocus = FocusNode();

  int _step = 1;
  String? _assetId;
  String? _symbol;

  LoopSendPreflight? _preflight;
  LoopChainException? _preflightFailure;
  bool _checking = false;

  /// The address the current preflight answer (or request) is about. An
  /// answer for any other text is dropped.
  String? _checkedAddress;
  int _checkRequest = 0;
  Timer? _debounce;

  /// Whether the field has been left once with text in it, so a malformed
  /// address is pointed out only after the owner is done typing it.
  bool _addressTouched = false;

  static final RegExp _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

  @override
  void initState() {
    super.initState();
    _assetId = widget.initialDraft?.assetId;
    _symbol = widget.initialDraft?.symbol;
    _addressFocus.addListener(_onAddressFocus);
    // A prefilled address — scanned, or carried by a draft — is checked as
    // soon as the page has a wallet to check it against.
    if (_address.text.trim().isNotEmpty) {
      _addressTouched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_check());
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressFocus
      ..removeListener(_onAddressFocus)
      ..dispose();
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

  void _onAddressFocus() {
    if (_addressFocus.hasFocus) return;
    if (_address.text.trim().isEmpty) return;
    setState(() => _addressTouched = true);
    unawaited(_check());
  }

  void _addressEdited() {
    _debounce?.cancel();
    setState(() {
      _preflight = null;
      _preflightFailure = null;
      _checkedAddress = null;
      _checking = false;
      _checkRequest += 1;
    });
    if (_addressPattern.hasMatch(_address.text.trim())) {
      _debounce = Timer(sendRecipientCheckDebounce, () => unawaited(_check()));
    }
  }

  void _setAddress(String text) {
    _debounce?.cancel();
    setState(() {
      _address.text = text;
      _addressTouched = true;
      _preflight = null;
      _preflightFailure = null;
      _checkedAddress = null;
    });
    unawaited(_check());
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted || text.isEmpty) return;
    _setAddress(text);
  }

  Future<void> _scan() async {
    final scan = widget.onScan;
    final String? scanned = scan != null
        ? await scan()
        : await context.push<String>(
            '/scan',
            extra: const SendScanForRecipient(),
          );
    if (!mounted || scanned == null || scanned.trim().isEmpty) return;
    _setAddress(scanned.trim());
  }

  /// Asks the server's preflight about the address in the field, once per
  /// distinct address. A malformed address is never sent.
  Future<void> _check() async {
    _debounce?.cancel();
    final address = _address.text.trim();
    if (!_addressPattern.hasMatch(address)) return;
    final walletId = ref
        .read(walletDirectoryControllerProvider)
        .value
        ?.activeWalletId;
    if (walletId == null || sendCapabilityBlocks(ref)) return;
    final lowered = address.toLowerCase();
    if (_checkedAddress == lowered && (_checking || _preflight != null)) {
      return;
    }
    final request = ++_checkRequest;
    setState(() {
      _checking = true;
      _checkedAddress = lowered;
      _preflight = null;
      _preflightFailure = null;
    });
    try {
      final result = await ref
          .read(walletIntentsGatewayProvider)
          .preflightRecipient(walletId: walletId, address: address);
      if (!mounted || request != _checkRequest) return;
      setState(() {
        _preflight = result;
        _checking = false;
        // The server normalises the address; the field adopts its checksum
        // form so what is reviewed is what was checked.
        _address.text = result.recipient.checksumAddress;
        _checkedAddress = result.recipient.checksumAddress.toLowerCase();
      });
    } on LoopChainException catch (failure) {
      if (!mounted || request != _checkRequest) return;
      setState(() {
        _preflightFailure = failure;
        _checking = false;
        _checkedAddress = null;
      });
    } catch (_) {
      if (!mounted || request != _checkRequest) return;
      setState(() {
        _preflightFailure = const LoopChainException(
          LoopChainFailureKind.unexpected,
        );
        _checking = false;
        _checkedAddress = null;
      });
    }
  }

  void _retryCheck() {
    _checkedAddress = null;
    unawaited(_check());
  }

  void _toStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
  }

  void _back() {
    if (_step > 1) {
      _toStep(_step - 1);
      return;
    }
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _loadBalances(String walletId) {
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(
          ref.read(walletBalancesControllerProvider(walletId).notifier).load(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocked = sendCapabilityBlocks(ref);
    final walletId = watchActiveMoneyWalletId(ref, blocked: blocked);
    final directory = ref.watch(walletDirectoryControllerProvider);
    // A prefill waits for the wallet directory; it is checked once the
    // wallet is known.
    if (!blocked &&
        walletId != null &&
        _preflight == null &&
        _preflightFailure == null &&
        !_checking &&
        _checkedAddress == null &&
        _addressPattern.hasMatch(_address.text.trim()) &&
        (_debounce == null || !_debounce!.isActive)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_check());
      });
    }
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 1) _toStep(_step - 1);
      },
      child: _step == 1
          ? _recipientStep(context, blocked, walletId, directory)
          : _amountStep(context, blocked, walletId!),
    );
  }

  Widget _recipientStep(
    BuildContext context,
    bool blocked,
    String? walletId,
    LoopChainResourceState<LoopWalletDirectory> directory,
  ) {
    final preflight = _preflight;
    final text = _address.text.trim();
    final wellFormed = _addressPattern.hasMatch(text);
    final String? status = _checking
        ? '正在校验地址…'
        : preflight != null
        ? '地址已校验 · BNB Smart Chain'
        : text.isEmpty
        ? null
        : !wellFormed && _addressTouched
        ? '地址格式不对：0x 开头，共 42 位'
        : null;
    final ready = !blocked && walletId != null && preflight != null;
    return LoopFocusPage(
      key: const ValueKey<String>('send-address-screen'),
      archetype: LoopPageArchetype.action,
      title: '发送',
      onBack: _back,
      primaryAction: blocked
          ? null
          : _nextWithReason(
              missing: walletId == null || ready || _checking
                  ? null
                  : wellFormed
                  ? (_preflightFailure == null ? '还差一步：等待地址校验。' : null)
                  : '还差一步：填写完整的收款地址（0x 开头，42 位）。',
              missingKey: 'send-recipient-missing',
              button: LoopButton(
                key: const ValueKey<String>('send-address-next'),
                label: '下一步',
                primary: true,
                block: true,
                onPressed: ready ? () => _toStep(2) : null,
              ),
            ),
      block: blocked
          ? sendCapabilityPageBlock(
              ref,
              key: const ValueKey<String>('send-capability-block'),
              title: '发送当前不可用',
            )
          : null,
      body: <Widget>[
        const LoopStepDots(step: 1, total: sendStepCount, label: '收款地址'),
        const SizedBox(height: 12),
        if (walletId == null)
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
        else ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: LoopSurfaceCard(
              child: TextField(
                key: const ValueKey<String>('send-recipient-field'),
                controller: _address,
                focusNode: _addressFocus,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                maxLength: 42,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                onChanged: (_) => _addressEdited(),
                onSubmitted: (_) {
                  setState(() => _addressTouched = true);
                  unawaited(_check());
                },
                decoration: InputDecoration(
                  labelText: '收款地址（BNB Smart Chain）',
                  hintText: '0x…',
                  counterText: '',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      LoopIconButton(
                        key: const ValueKey<String>('send-recipient-paste'),
                        icon: 'copy',
                        label: '粘贴',
                        onPressed: () => unawaited(_paste()),
                      ),
                      LoopIconButton(
                        key: const ValueKey<String>('send-recipient-scan'),
                        icon: 'camera',
                        label: '扫码',
                        onPressed: () => unawaited(_scan()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                status,
                key: const ValueKey<String>('send-recipient-status'),
                style: LoopTypography.label(
                  11,
                  color: preflight != null
                      ? LoopColors.lime
                      : _checking
                      ? LoopColors.text2
                      : LoopColors.warning,
                ),
              ),
            ),
          if (widget.recipientPrefill != null && text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                '收款地址来自扫码，已自动校验',
                key: const ValueKey<String>('send-recipient-prefill'),
                style: LoopTypography.label(11, color: LoopColors.text3),
              ),
            ),
          // An address check that never reached the server has not prepared
          // an intent, opened a wallet or submitted anything. It pauses; only
          // a server answer is an error.
          if (MoneyOfflinePause.covers(_preflightFailure))
            MoneyOfflinePause(
              blockKey: 'send-recipient-preflight-offline',
              failureKind: _preflightFailure?.kind,
              pausedActions: const <String>['校验地址', '下一步', '签名'],
              onRetry: _retryCheck,
            )
          // The server read the address and refused to answer for it. It is
          // a refusal, not a failed read: retrying cannot change it.
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
              onRetry: _retryCheck,
            ),
          if (preflight != null) _RecipientChecks(preflight: preflight),
        ],
      ],
    );
  }

  Widget _amountStep(BuildContext context, bool blocked, String walletId) {
    final preflight = _preflight!;
    final balancesState = ref.watch(walletBalancesControllerProvider(walletId));
    if (!blocked && balancesState.phase == LoopChainViewPhase.loading) {
      _loadBalances(walletId);
    }
    final balances = balancesState.value;
    final candidates =
        balances?.balances.where(moneyRowHasSpendable).toList() ??
        const <LoopAssetBalanceRow>[];
    // One asset with something to send needs no choice.
    if (_assetId == null && candidates.length == 1) {
      _assetId = candidates.single.assetId;
      _symbol = candidates.single.symbol;
    }
    final row = _assetId == null ? null : balances?.rowFor(_assetId!);
    final spendable = row?.balance is LoopBalanceAvailable
        ? (row!.balance as LoopBalanceAvailable).spendableBalance
        : null;
    final amount = TransferAmount.tryParse(_amount.text.trim());
    final overSpendable =
        amount != null &&
        spendable != null &&
        Decimal.parse(amount.wire) > spendable;
    final ready =
        !blocked &&
        _assetId != null &&
        _symbol != null &&
        amount != null &&
        spendable != null &&
        !overSpendable;
    final symbol = _symbol;
    return LoopFocusPage(
      key: const ValueKey<String>('send-amount-screen'),
      archetype: LoopPageArchetype.action,
      title: '发送',
      onBack: _back,
      keyboardAccessory: true,
      primaryAction: blocked
          ? null
          : _nextWithReason(
              missing: balances == null || !balancesState.isReady
                  ? null
                  : _assetId == null
                  ? '还差一步：选择要发送的资产。'
                  : amount == null
                  ? '还差一步：填写发送数量。'
                  : overSpendable
                  ? '发送数量超过了可动用余额，请改小。'
                  : null,
              missingKey: 'send-amount-missing',
              button: LoopButton(
                key: const ValueKey<String>('send-amount-next'),
                label: '下一步',
                primary: true,
                block: true,
                onPressed: ready
                    ? () => _open(
                        '/wallet/send/confirm',
                        extra: SendDraft(
                          walletId: walletId,
                          assetId: _assetId!,
                          symbol: symbol!,
                          recipientAddress: preflight.recipient.checksumAddress,
                          amount: amount.wire,
                        ),
                      )
                    : null,
              ),
            ),
      block: blocked
          ? sendCapabilityPageBlock(
              ref,
              key: const ValueKey<String>('send-amount-capability-block'),
              title: '发送当前不可用',
            )
          : null,
      body: <Widget>[
        const LoopStepDots(step: 2, total: sendStepCount, label: '金额与资产'),
        const SizedBox(height: 12),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('send-amount-recipient'),
              leading: const LoopRowIcon(icon: 'wallet'),
              title: loopTruncatedAddress(preflight.recipient.checksumAddress),
              subtitle: '收款地址 · 已校验',
              trailingCaption: '修改',
              chevron: false,
              onTap: () => _toStep(1),
            ),
          ],
        ),
        if (balances == null || !balancesState.isReady)
          LoopChainStateBlock(
            keyPrefix: 'send-balances',
            phase: balancesState.phase,
            failureKind: balancesState.failureKind,
            emptyMessage: '这个钱包还没有可读资产',
            onRetry: () => unawaited(
              ref
                  .read(walletBalancesControllerProvider(walletId).notifier)
                  .reload(),
            ),
          )
        else if (balances.balances.isEmpty)
          const LoopEmpty(
            key: ValueKey<String>('send-assets-empty'),
            message: '还没有可读取的资产',
            reason: '登记资产后，这里会为每一个资产恒定保留一行。',
          )
        else ...<Widget>[
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('send-asset-selector'),
                leading: row == null
                    ? const LoopRowIcon(icon: 'wallet')
                    : LoopTokenLogo(
                        assetSymbol: row.symbol,
                        logoUrl: row.logoUrl,
                        fallbackMonogram: row.symbol,
                      ),
                title: row?.symbol ?? '选择资产',
                subtitle: row == null
                    ? candidates.isEmpty
                          ? '没有可动用余额的资产'
                          : '${candidates.length} 个资产可发送'
                    : switch (row.balance) {
                        LoopBalanceAvailable(spendableBalance: final s) =>
                          '可动用 ${loopFormatDecimal(s)} ${row.symbol}'
                              '（已扣除手续费保留）',
                        LoopBalanceUnavailable(reasonCode: final reasonCode) =>
                          loopReasonCodeText(reasonCode),
                      },
                onTap: () => unawaited(_pickAsset(balances)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: LoopSurfaceCard(
              child: TextField(
                key: const ValueKey<String>('send-amount-field'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                // The amount stays the exact text all the way to the wire.
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                maxLength: TransferAmount.maxWireLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: symbol == null ? '发送数量' : '发送数量（$symbol）',
                  counterText: '',
                  errorText: overSpendable ? '超过可动用余额' : null,
                  suffixIcon: TextButton(
                    key: const ValueKey<String>('send-amount-max'),
                    onPressed: spendable != null && spendable > Decimal.zero
                        ? () => setState(
                            () => _amount.text = spendable.toString(),
                          )
                        : null,
                    child: const Text('全部'),
                  ),
                ),
              ),
            ),
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

  /// 下一步, with the one thing it is still waiting for said above it: a grey
  /// button with no sentence beside it reads as a broken control.
  Widget _nextWithReason({
    required String? missing,
    required String missingKey,
    required Widget button,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (missing != null) ...<Widget>[
        Text(
          missing,
          key: ValueKey<String>(missingKey),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
      ],
      button,
    ],
  );

  Future<void> _pickAsset(LoopWalletBalances balances) async {
    final picked = await showMoneyAssetPicker(
      context,
      balances: balances,
      rowKeyPrefix: 'send-asset',
      selectedAssetId: _assetId,
    );
    if (picked == null || !mounted) return;
    final row = balances.rowFor(picked);
    if (row == null) return;
    setState(() {
      if (picked != _assetId) _amount.clear();
      _assetId = picked;
      _symbol = row.symbol;
    });
  }
}

/// What the preflight said about one recipient, folded into a single line.
///
/// Expanded, three warning cards and a provenance footer pushed the amount
/// field onto a second screen while the pinned 下一步 stayed grey — the owner
/// had no way to see that anything was still missing. Every warning is still
/// here, still in full, and the summary states how many there are, so folding
/// never hides that the address has something to say. A dangerous check
/// (a contract recipient) opens the group by itself.
class _RecipientChecks extends StatelessWidget {
  const _RecipientChecks({required this.preflight});

  final LoopSendPreflight preflight;

  @override
  Widget build(BuildContext context) {
    final recipient = preflight.recipient;
    final firstTime = preflight.warnings.contains(
      LoopSendPreflight.firstTimeWarning,
    );
    final contract = preflight.warnings.contains(
      LoopSendPreflight.contractWarning,
    );
    final headlines = <String>[
      if (firstTime) '首次向该地址转账',
      if (contract) '收款方是合约地址',
      '恶意地址筛查不可用',
    ];
    return LoopDisclosure(
      key: const ValueKey<String>('send-recipient-checks'),
      // The count is the point of the closed line: 「地址核对结果」 alone
      // would not say that something needs reading.
      summary: '地址核对 · ${headlines.length} 项待确认 · ${headlines.first}',
      // A contract recipient can cost the whole transfer, so that one is
      // never folded away by default.
      initiallyOpen: contract,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (firstTime)
            const LoopNotice(
              key: ValueKey<String>('send-recipient-first-time'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '首次向该地址转账',
              body: '这个地址不在你自己的已索引转账历史中。请逐字核对完整地址后再继续。',
            ),
          if (contract)
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
          // The basis names the records that were searched, not the table
          // they live in: 「indexed_erc20_transfers」 was a schema name
          // printed to the person sending money.
          const LoopProvenanceFooter(
            key: ValueKey<String>('send-recipient-basis'),
            text: '首次收款方的判断依据：你自己在 LOOP 已索引的 ERC-20 转账记录',
          ),
        ],
      ),
    );
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

  /// The capability document is being re-read before the sheet opens.
  bool _checkingCapability = false;

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
      primaryAction: intent == null
          ? null
          : MoneyCountdown(
              expiresAt: intent.expiresAt,
              clock: widget.clock,
              builder: (context, remaining) => LoopButton(
                key: const ValueKey<String>('send-confirm-sign'),
                label: _checkingCapability
                    ? moneyCapabilityCheckingLabel
                    : remaining == Duration.zero
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
      block: blocked
          ? sendCapabilityPageBlock(
              ref,
              key: const ValueKey<String>('send-confirm-capability-block'),
              title: '发送当前不可用',
            )
          : null,
      body: <Widget>[
        // The prototype's FINAL REVIEW lists 收款方 / 数量 / 网络费 / 预估到账
        // before it asks for anything. Until the server answers, only the
        // first two are facts this device holds — but a page whose primary
        // promises 「全部确认后才请求签名」 and then lists nothing at all
        // (which is what a 403 on prepare left behind) confirms nothing. The
        // draft's own two lines stand until the intent replaces them.
        const LoopStepDots(step: 3, total: sendStepCount, label: '确认并签名'),
        const SizedBox(height: 12),
        if (intent == null) _SendDraftFacts(draft: widget.draft),
        if (other != null)
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
          const _SendArrivalEstimate(),
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
    setState(() {
      _busy = true;
      _checkingCapability = true;
    });
    // S88d: the server's current answer, not one up to a minute old, decides
    // whether the sheet opens. A closed gate takes the page's own block.
    await loopRefreshCapabilitiesBeforeSigning(ref);
    if (!mounted) return;
    final closed = moneyActionBlocks(
      ref.read(walletIntentsGatewayProvider).mode,
      ref.read(loopCapabilityProvider(LoopV2CapabilityId.sendApprovals)),
    );
    setState(() {
      _checkingCapability = false;
      if (closed) _busy = false;
    });
    if (closed) return;
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

/// The two lines this device already holds, shown while the server's own
/// review is still missing.
///
/// They are the draft — what the owner typed and what the preflight
/// checksummed — never a server fact, and the card says so. Network fee and
/// arrival are the server's to state, so they stand here as what they are:
/// not yet read.
class _SendDraftFacts extends StatelessWidget {
  const _SendDraftFacts({required this.draft});

  final SendDraft draft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LoopSurfaceCard(
        key: const ValueKey<String>('send-confirm-draft-facts'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopKeyValue(
              key: const ValueKey<String>('send-confirm-draft-recipient'),
              label: '收款方',
              value: draft.recipientAddress ?? '还没有填写',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('send-confirm-draft-amount'),
              label: '数量',
              value: draft.amount == null
                  ? '还没有填写'
                  : '${loopGroupedFigure(draft.amount!)} ${draft.symbol}',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('send-confirm-draft-fee'),
              label: '网络费',
              value: '还没有读到',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('send-confirm-draft-arrival'),
              label: '预估到账',
              value: '不预估',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            const SizedBox(height: 6),
            Text(
              '这两行是你在上一步填的内容，还不是服务端的事实。'
              '网络费、余额与试算会在准备好这一笔之后一起显示。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The prototype's 预估到账 row.
///
/// The prototype prints 「约 30 秒」. No read on this contract reports an
/// arrival time, and a client-side guess from a block interval would be a
/// number LOOP invented about somebody's money — so the row stands and says
/// what it does not have.
class _SendArrivalEstimate extends StatelessWidget {
  const _SendArrivalEstimate();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LoopSurfaceCard(
        key: const ValueKey<String>('send-confirm-arrival'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const LoopKeyValue(
              label: '预估到账',
              value: '不预估',
              padding: EdgeInsets.symmetric(vertical: 8),
            ),
            Text(
              '没有到账时间的来源，这里不给一个编出来的秒数。'
              '提交之后在结果页按确认数跟踪，那是唯一的进度。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

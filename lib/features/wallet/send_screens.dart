import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_capability_refresh.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_card.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/money_asset_picker.dart';
import 'package:loop_mobile/features/wallet/nft_send.dart';
import 'package:loop_mobile/features/wallet/transfer_amount.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

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
    this.nft,
  });

  /// S339 · decision 0267: a project NFT send. It has a recipient and no
  /// amount; the asset fields are the NFT contract and its ticker.
  SendDraft.nft(SendNftTarget target, {this.recipientAddress})
    : walletId = target.walletId,
      assetId = '${target.chainId}:erc721:${target.contractAddress}',
      symbol = target.ticker,
      amount = null,
      recipientPrefill = null,
      nft = target;

  final String walletId;
  final String assetId;
  final String symbol;

  /// The NFT this draft sends, or `null` for a fungible send.
  final SendNftTarget? nft;

  bool get isNft => nft != null;

  /// The EIP-55 checksum address the preflight returned.
  final String? recipientAddress;

  /// An address the recipient field starts with, from a scanned code
  /// (decision 0113). It is text in a field and nothing more: the reader
  /// still asks the preflight to check it, exactly as if they had pasted it.
  final String? recipientPrefill;

  /// The exact decimal string the owner typed, never a `double`.
  final String? amount;

  bool get isComplete =>
      (recipientAddress?.isNotEmpty ?? false) &&
      (isNft || (amount?.isNotEmpty ?? false));

  SendDraft copyWith({String? recipientAddress, String? amount}) => SendDraft(
    walletId: walletId,
    assetId: assetId,
    symbol: symbol,
    recipientAddress: recipientAddress ?? this.recipientAddress,
    amount: amount ?? this.amount,
    recipientPrefill: recipientPrefill,
    nft: nft,
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

/// The gate of an NFT send: the server's own `nftSend` capability, not the
/// fungible send's (S346 · M11), so an NFT can be sent while `sendApprovals`
/// is closed.
bool nftSendCapabilityBlocks(WidgetRef ref) => moneyActionBlocks(
  ref.watch(walletIntentsGatewayProvider).mode,
  ref.watch(loopCapabilityProvider(LoopV2CapabilityId.nftSend)),
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
  return LoopUnavailableLine(
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
  LoopV2CapabilityId capability = LoopV2CapabilityId.sendApprovals,
}) => LoopCapabilityPageBlock.of(
  key: key,
  title: title,
  capability: ref.watch(loopCapabilityProvider(capability)),
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

/// An NFT send's two steps (S339 · decision 0267): no amount.
const int sendNftStepCount = 2;

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

  /// S339 · decision 0267: the NFT this flow sends, or `null`.
  SendNftTarget? get _nft => widget.initialDraft?.nft;

  /// An NFT send has no amount step: 收款地址 → 确认并签名.
  int get _stepCount => _nft == null ? sendStepCount : sendNftStepCount;

  /// The chain the recipient is checked for.
  String get _chainName => loopChainName(_nft?.chainId ?? loopPrimaryChainId);

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
    final walletId =
        _nft?.walletId ??
        ref.read(walletDirectoryControllerProvider).value?.activeWalletId;
    if (walletId == null || _gateBlocks()) return;
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
          .preflightRecipient(
            walletId: walletId,
            address: address,
            chainId: _nft?.chainId,
          );
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

  bool _gateBlocks() =>
      _nft != null ? nftSendCapabilityBlocks(ref) : sendCapabilityBlocks(ref);

  @override
  Widget build(BuildContext context) {
    final blocked = _gateBlocks();
    // An NFT send is bound to the wallet that holds the NFT.
    final walletId =
        _nft?.walletId ?? watchActiveMoneyWalletId(ref, blocked: blocked);
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
        ? context.l10n.wallet_sendScreensRecipientStep
        : preflight != null
        ? context.l10n.wallet_sendScreensRecipientStep2(_chainName)
        : text.isEmpty
        ? null
        : !wellFormed && _addressTouched
        ? context.l10n.wallet_sendScreensRecipientStep3
        : null;
    final ready = !blocked && walletId != null && preflight != null;
    final nft = _nft;
    return LoopFocusPage(
      key: const ValueKey<String>('send-address-screen'),
      archetype: LoopPageArchetype.action,
      title: nft == null
          ? context.l10n.common_send
          : context.l10n.wallet_sendScreensSendAddressScreenTitle,
      onBack: _back,
      primaryAction: blocked
          ? null
          : _nextWithReason(
              missing: walletId == null || ready || _checking
                  ? null
                  : wellFormed
                  ? (_preflightFailure == null
                        ? context.l10n.wallet_sendScreensMissing
                        : null)
                  : context.l10n.wallet_sendScreensSendAddressNextMissing,
              missingKey: 'send-recipient-missing',
              button: LoopButton(
                key: const ValueKey<String>('send-address-next'),
                label: context.l10n.common_next,
                primary: true,
                block: true,
                onPressed: !ready
                    ? null
                    : nft == null
                    ? () => _toStep(2)
                    : () => _open(
                        '/wallet/send/confirm',
                        extra: SendDraft.nft(
                          nft,
                          recipientAddress: preflight.recipient.checksumAddress,
                        ),
                      ),
              ),
            ),
      block: blocked
          ? sendCapabilityPageBlock(
              ref,
              key: const ValueKey<String>('send-capability-block'),
              title: context.l10n.wallet_sendScreensSendCapabilityBlockTitle,
              capability: nft == null
                  ? LoopV2CapabilityId.sendApprovals
                  : LoopV2CapabilityId.nftSend,
            )
          : null,
      body: <Widget>[
        SendStepBar(
          step: 1,
          total: _stepCount,
          label: context.l10n.wallet_sendScreensLabel,
        ),
        const SizedBox(height: 12),
        if (nft != null) SendNftSummary(target: nft),
        if (walletId == null)
          LoopChainStateBlock(
            keyPrefix: 'send-directory',
            phase: directory.phase,
            failureKind: directory.failureKind,
            emptyMessage: context.l10n.wallet_sendScreensEmptyMessage,
            emptyReason: context.l10n.wallet_sendScreensEmptyReason,
            onRetry: () => unawaited(
              ref.read(walletDirectoryControllerProvider.notifier).reload(),
            ),
          )
        else ...<Widget>[
          // UX-016 (decision 0257): the field's name above it, and the
          // field itself one layer — no card around the input.
          SendFieldTitle(
            context.l10n.wallet_sendScreensLabel,
            key: ValueKey<String>('send-recipient-title'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              6,
            ),
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
                hintText: context.l10n.wallet_sendScreensRecipientHint(
                  _chainName,
                ),
                counterText: '',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    LoopIconButton(
                      key: const ValueKey<String>('send-recipient-paste'),
                      icon: 'copy',
                      label: context
                          .l10n
                          .wallet_sendScreensSendRecipientPasteLabel,
                      onPressed: () => unawaited(_paste()),
                    ),
                    LoopIconButton(
                      key: const ValueKey<String>('send-recipient-scan'),
                      icon: 'camera',
                      label:
                          context.l10n.wallet_sendScreensSendRecipientScanLabel,
                      onPressed: () => unawaited(_scan()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // A passed check is a Lime line and a running one a grey line; a
          // refused address is the shared warn notice (docs/33 L17), never
          // the v1 warning yellow.
          if (status != null && preflight == null && !_checking)
            LoopNotice(
              key: const ValueKey<String>('send-recipient-status'),
              tone: LoopNoticeTone.warn,
              icon: 'warn',
              body: status,
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                0,
                LoopSpacing.page,
                10,
              ),
            )
          else if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                status,
                key: const ValueKey<String>('send-recipient-status'),
                // R20 the note under a form field.
                style: LoopType.caption.copyWith(
                  color: preflight != null
                      ? LoopColors.yellow
                      : LoopColors.text2,
                ),
              ),
            ),
          if (widget.recipientPrefill != null && text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                context.l10n.wallet_sendScreensSendRecipientPrefill,
                key: const ValueKey<String>('send-recipient-prefill'),
                style: LoopType.caption.copyWith(color: LoopColors.text3),
              ),
            ),
          // An address check that never reached the server has not prepared
          // an intent, opened a wallet or submitted anything. It pauses; only
          // a server answer is an error.
          if (MoneyOfflinePause.covers(_preflightFailure))
            MoneyOfflinePause(
              blockKey: 'send-recipient-preflight-offline',
              failureKind: _preflightFailure?.kind,
              pausedActions: <String>[
                context.l10n.wallet_sendScreensMoneyOfflinePause,
                context.l10n.common_next,
                context.l10n.common_sign,
              ],
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
              title: context
                  .l10n
                  .wallet_sendScreensSendRecipientPreflightErrorTitle,
              // S339: an NFT send names its own refusals (发给自己 …).
              reason:
                  (nft == null
                      ? null
                      : nftSendFailureText(_preflightFailure!)) ??
                  loopChainFailureReason(_preflightFailure!.kind),
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
      title: context.l10n.common_send,
      onBack: _back,
      keyboardAccessory: true,
      primaryAction: blocked
          ? null
          : _nextWithReason(
              missing: balances == null || !balancesState.isReady
                  ? null
                  : _assetId == null
                  ? context.l10n.wallet_sendScreensSendAmountNextMissing
                  : amount == null
                  ? context.l10n.wallet_sendScreensSendAmountNextMissing2
                  : overSpendable
                  ? context.l10n.wallet_sendScreensSendAmountNextMissing3
                  : null,
              missingKey: 'send-amount-missing',
              button: LoopButton(
                key: const ValueKey<String>('send-amount-next'),
                label: context.l10n.common_next,
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
              title: context.l10n.wallet_sendScreensSendCapabilityBlockTitle,
            )
          : null,
      body: <Widget>[
        SendStepBar(
          step: 2,
          total: sendStepCount,
          label: context.l10n.wallet_sendScreensLabel2,
        ),
        const SizedBox(height: 12),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('send-amount-recipient'),
              leading: const LoopRowIcon(icon: 'wallet'),
              title: loopTruncatedAddress(preflight.recipient.checksumAddress),
              subtitle:
                  context.l10n.wallet_sendScreensSendAmountRecipientSubtitle,
              trailingCaption: context
                  .l10n
                  .wallet_sendScreensSendAmountRecipientTrailingCaption,
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
            emptyMessage: context.l10n.wallet_moneyAssetPickerTitle2,
            onRetry: () => unawaited(
              ref
                  .read(walletBalancesControllerProvider(walletId).notifier)
                  .reload(),
            ),
          )
        else if (balances.balances.isEmpty)
          LoopEmptyState(
            key: ValueKey<String>('send-assets-empty'),
            illustration: LoopIllustration.history,
            title: context.l10n.wallet_sendScreensSendAssetsEmptyTitle,
            message: context.l10n.wallet_sendScreensSendAssetsEmptyMessage,
            compact: true,
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
                title: row?.symbol ?? context.l10n.wallet_moneyAssetPickerTitle,
                subtitle: row == null
                    ? candidates.isEmpty
                          ? context.l10n.wallet_moneyAssetPickerTitle4
                          : context.l10n
                                .wallet_sendScreensSendAssetSelectorSubtitle(
                                  candidates.length,
                                )
                    : switch (row.balance) {
                        LoopBalanceAvailable(spendableBalance: final s) =>
                          context.l10n.wallet_sendScreensLoopBalanceAvailable(
                            loopFormatDecimal(s),
                            row.symbol,
                          ),
                        LoopBalanceUnavailable(reasonCode: final reasonCode) =>
                          loopReasonCodeText(reasonCode),
                      },
                onTap: () => unawaited(_pickAsset(balances)),
              ),
            ],
          ),
          SendFieldTitle(
            symbol == null
                ? context.l10n.wallet_sendScreensSendAmountTitle
                : context.l10n.wallet_sendScreensSendAmountTitle2(symbol),
            key: const ValueKey<String>('send-amount-title'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              12,
            ),
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
                hintText: context.l10n.wallet_sendScreensSendAmountMaxHintText,
                counterText: '',
                errorText: overSpendable
                    ? context.l10n.wallet_sendScreensSendAmountMaxErrorText
                    : null,
                suffixIcon: TextButton(
                  key: const ValueKey<String>('send-amount-max'),
                  onPressed: spendable != null && spendable > Decimal.zero
                      ? () =>
                            setState(() => _amount.text = spendable.toString())
                      : null,
                  child: Text(context.l10n.common_all),
                ),
              ),
            ),
          ),
          WalletSnapshotFooter(snapshot: balances.snapshot),
          LoopNotice(
            key: ValueKey<String>('send-power-notice'),
            icon: 'mine',
            tone: LoopNoticeTone.warn,
            title: context.l10n.wallet_sendScreensSendPowerNoticeTitle,
            body: context.l10n.wallet_sendScreensSendPowerNoticeBody,
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
        Text(missing, key: ValueKey<String>(missingKey), style: LoopType.label),
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

/// Where the send flow stands (UX-016, decision 0257): equal segments across
/// the top of the page, as the sign-in steps draw them — every reached step
/// Yellow, the rest Line2. The step's name is the field title under it.
class SendStepBar extends StatelessWidget {
  const SendStepBar({
    required this.step,
    required this.total,
    required this.label,
    super.key,
  }) : assert(step >= 1 && step <= total);

  /// One-based current step.
  final int step;
  final int total;
  final String label;

  static const double height = 4;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey<String>('send-step-bar'),
    label: context.l10n.wallet_sendScreensSendStepBarLabel(label, step, total),
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        4,
      ),
      child: Row(
        children: <Widget>[
          for (var index = 1; index <= total; index += 1) ...<Widget>[
            if (index > 1) const SizedBox(width: 6),
            Expanded(
              child: Container(
                key: ValueKey<String>('send-step-segment-$index'),
                height: height,
                decoration: BoxDecoration(
                  color: index <= step ? LoopColors.yellow : LoopColors.line2,
                  borderRadius: LoopRadius.badge,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// The name of a send field, above the field (UX-016, decision 0257).
class SendFieldTitle extends StatelessWidget {
  const SendFieldTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      8,
      LoopSpacing.page,
      8,
    ),
    child: Text(
      text,
      style: LoopTypography.withWeight(
        LoopType.body,
        FontWeight.w600,
      ).copyWith(color: LoopColors.chalk),
    ),
  );
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
      if (firstTime) context.l10n.wallet_sendScreensBuild,
      if (contract) context.l10n.wallet_sendScreensBuild2,
      context.l10n.wallet_sendScreensBuild3,
    ];
    return LoopDisclosure(
      key: const ValueKey<String>('send-recipient-checks'),
      // The count is the point of the closed line: 「地址核对结果」 alone
      // would not say that something needs reading.
      summary: context.l10n.wallet_sendScreensSendRecipientChecksSummary(
        headlines.first,
        headlines.length,
      ),
      // A contract recipient can cost the whole transfer, so that one is
      // never folded away by default.
      initiallyOpen: contract,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (firstTime)
            LoopNotice(
              key: ValueKey<String>('send-recipient-first-time'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: context.l10n.wallet_sendScreensBuild,
              body: context.l10n.wallet_sendScreensSendRecipientFirstTimeBody,
            ),
          if (contract)
            LoopNotice(
              key: ValueKey<String>('send-recipient-contract'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title: context.l10n.wallet_sendScreensBuild2,
              body: context.l10n.wallet_sendScreensSendRecipientContractBody,
            ),
          LoopNotice(
            key: const ValueKey<String>('send-recipient-screening'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: context.l10n.wallet_sendScreensBuild3,
            body: loopReasonCodeText(recipient.screening.reasonCode),
          ),
          // The basis names the records that were searched, not the table
          // they live in: 「indexed_erc20_transfers」 was a schema name
          // printed to the person sending money.
          LoopProvenanceFooter(
            key: ValueKey<String>('send-recipient-basis'),
            label: context.l10n.common_about,
            title: context.l10n.wallet_sendScreensSendRecipientBasisTitle,
            text: context.l10n.wallet_sendScreensSendRecipientBasisText,
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
    final blocked = widget.draft.nft != null
        ? nftSendCapabilityBlocks(ref)
        : sendCapabilityBlocks(ref);
    if (!blocked && !_started) {
      _started = true;
      scheduleMicrotask(() {
        if (mounted) unawaited(_prepare());
      });
    }
    final intent = _intent;
    final other = _pendingOther;
    final nft = widget.draft.nft;
    final failure = _failure;
    final nftFailure = nft == null || failure == null
        ? null
        : nftSendFailureText(failure);

    return LoopFocusPage(
      key: const ValueKey<String>('send-confirm-screen'),
      archetype: LoopPageArchetype.action,
      title: nft == null
          ? context.l10n.wallet_moneyActionsSigningSend
          : context.l10n.wallet_moneyActionsSigningSendNft,
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
                    ? context.l10n.wallet_approvalScreensApprovalGuardSignLabel
                    : context.l10n.wallet_sendScreensSendConfirmSignLabel(
                        moneyCountdownLabel(remaining),
                      ),
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
              title: context.l10n.wallet_sendScreensSendCapabilityBlockTitle,
              capability: nft == null
                  ? LoopV2CapabilityId.sendApprovals
                  : LoopV2CapabilityId.nftSend,
            )
          : null,
      body: <Widget>[
        // The prototype's FINAL REVIEW lists 收款方 / 数量 / 网络费 / 预估到账
        // before it asks for anything. Until the server answers, only the
        // first two are facts this device holds — but a page whose primary
        // promises 「全部确认后才请求签名」 and then lists nothing at all
        // (which is what a 403 on prepare left behind) confirms nothing. The
        // draft's own two lines stand until the intent replaces them.
        if (nft == null)
          SendStepBar(
            step: 3,
            total: sendStepCount,
            label: context.l10n.wallet_sendScreensLabel3,
          )
        else
          SendStepBar(
            step: sendNftStepCount,
            total: sendNftStepCount,
            label: context.l10n.wallet_sendScreensLabel3,
          ),
        const SizedBox(height: 12),
        if (intent == null && nft == null) _SendDraftFacts(draft: widget.draft),
        if (intent == null && nft != null)
          SendNftReviewCard(
            key: const ValueKey<String>('send-nft-draft'),
            target: nft,
            recipient: widget.draft.recipientAddress,
          ),
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
        else if (intent == null && nftFailure != null)
          LoopInlineUnavailable(
            key: ValueKey<String>(
              'send-nft-failure-${failure!.reasonCode ?? failure.kind.name}',
            ),
            message: nftFailure,
            maxLines: 2,
            onRetry: nftSendFailureRetryable(failure)
                ? () => unawaited(_prepare(force: true))
                : null,
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
        else if (nft != null) ...<Widget>[
          SendNftReviewCard(
            key: const ValueKey<String>('send-nft-review'),
            target: nft,
            intent: intent,
          ),
          if (!intent.simulation.passed)
            LoopNotice(
              key: const ValueKey<String>('send-confirm-simulation-failed'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title: context
                  .l10n
                  .wallet_sendScreensSendConfirmSimulationFailedTitle,
              body: loopReasonCodeText(intent.simulation.reasonCode),
            ),
          MoneyCountdown(
            expiresAt: intent.expiresAt,
            clock: widget.clock,
            builder: (context, remaining) => remaining == Duration.zero
                ? LoopNotice(
                    key: ValueKey<String>('send-confirm-expired'),
                    icon: 'clock',
                    tone: LoopNoticeTone.warn,
                    title:
                        context.l10n.wallet_sendScreensSendConfirmExpiredTitle,
                    body: context.l10n.wallet_sendScreensSendConfirmExpiredBody,
                  )
                : const SizedBox.shrink(),
          ),
          MoneyFactsFooter(intent: intent, now: widget.clock?.call()),
        ] else ...<Widget>[
          MoneyIntentReviewCard(intent: intent, clock: widget.clock),
          const _SendArrivalEstimate(),
          if (!intent.simulation.passed)
            LoopNotice(
              key: const ValueKey<String>('send-confirm-simulation-failed'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title: context
                  .l10n
                  .wallet_sendScreensSendConfirmSimulationFailedTitle,
              body: loopReasonCodeText(intent.simulation.reasonCode),
            ),
          MoneyCountdown(
            expiresAt: intent.expiresAt,
            clock: widget.clock,
            builder: (context, remaining) => remaining == Duration.zero
                ? LoopNotice(
                    key: ValueKey<String>('send-confirm-expired'),
                    icon: 'clock',
                    tone: LoopNoticeTone.warn,
                    title:
                        context.l10n.wallet_sendScreensSendConfirmExpiredTitle,
                    body:
                        context.l10n.wallet_sendScreensSendConfirmExpiredBody2,
                  )
                : const SizedBox.shrink(),
          ),
          // S278 · decision 0236: an explanation, behind (i).
          LoopProvenanceFooter(
            key: ValueKey<String>('send-confirm-signing-exit'),
            label: context.l10n.common_about,
            title: context.l10n.wallet_sendScreensSendConfirmSigningExitTitle,
            text: context.l10n.wallet_sendScreensSendConfirmSigningExitText,
          ),
          LoopNotice(
            key: ValueKey<String>('send-confirm-power'),
            icon: 'mine',
            tone: LoopNoticeTone.warn,
            title: context.l10n.wallet_sendScreensSendConfirmPowerTitle,
            body: context.l10n.wallet_sendScreensSendConfirmPowerBody,
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
    final nft = draft.nft;
    if (recipient == null || (nft == null && amount == null)) return;
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
      final LoopWalletIntent intent;
      if (nft == null) {
        intent = await gateway.prepareSend(
          walletId: draft.walletId,
          assetId: draft.assetId,
          amount: amount!,
          recipientAddress: recipient,
        );
      } else {
        intent = await gateway.prepareSendNft(
          walletId: nft.walletId,
          chainId: nft.chainId,
          contractAddress: nft.contractAddress,
          tokenId: nft.tokenIdText,
          recipientAddress: recipient,
        );
        // The intent must name the NFT this page asked for: another token or
        // contract is not the send the owner chose.
        if (!sendNftIntentMatches(intent, nft)) {
          throw const LoopChainException(LoopChainFailureKind.invalidData);
        }
        ref.read(nftSendDisabledProvider.notifier).set(false);
      }
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _busy = false;
      });
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      if (nft != null && nftSendIsDisabled(failure)) {
        ref.read(nftSendDisabledProvider.notifier).set(true);
        LoopToast.show(context, message: nftSendDisabledText);
      }
      // S346 · M11: the NFT left the wallet since the holdings were read
      // (the minted id stood in for a missing `heldTokenIds`); the holdings
      // are re-read so the page the owner returns to picks from the chain.
      if (nft != null && failure.reasonCode == NftSendReason.notOwned) {
        refreshLaunch2Holdings(ref, nft);
      }
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
      ref.read(
        loopCapabilityProvider(
          widget.draft.nft == null
              ? LoopV2CapabilityId.sendApprovals
              : LoopV2CapabilityId.nftSend,
        ),
      ),
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
    // S339 · decision 0267: whatever the wallet did with an NFT send, the
    // Launch holdings are re-read, so the NFT tab and the medal page follow
    // the chain rather than the read from before the send.
    final nft = widget.draft.nft;
    if (nft != null && outcome.opensResult) refreshLaunch2Holdings(ref, nft);
    // A locked outcome — including a broadcast the server did not accept —
    // has only one honest next screen.
    if (outcome.opensResult) {
      _open('/wallet/tx/result?intentId=${intent.intentId}');
    }
  }
}

/// Whether [intent] is the NFT send [target] asked for: its kind, chain,
/// contract and token id.
bool sendNftIntentMatches(LoopWalletIntent intent, SendNftTarget target) {
  final nft = intent.review.nft;
  return intent.kind == LoopIntentKind.sendNft &&
      intent.chainId == target.chainId &&
      nft != null &&
      nft.contractAddress == target.contractAddress &&
      nft.tokenId == target.tokenIdText;
}

/// The NFT a send moves, as one row (step 1): the picture, 「T #id」 and the
/// chain.
class SendNftSummary extends StatelessWidget {
  const SendNftSummary({required this.target, super.key});

  final SendNftTarget target;

  @override
  Widget build(BuildContext context) => LoopRecordGroup(
    key: const ValueKey<String>('send-nft-summary'),
    rows: <LoopRecordRow>[
      LoopRecordRow(
        leading: ClipRRect(
          borderRadius: LoopRadius.badge,
          child: Launch2NftCard(
            ticker: target.ticker,
            nftImageUrl: target.nftImageUrl,
            logoUrl: target.logoUrl,
            size: 40,
          ),
        ),
        title: target.label,
        subtitle: target.projectName == null
            ? loopChainName(target.chainId)
            : '${target.projectName} · ${loopChainName(target.chainId)}',
        chevron: false,
      ),
    ],
  );
}

/// The NFT send's review (S339 · decision 0267): the NFT's picture, project
/// name and `#tokenId` over the recipient, the network and the network fee.
///
/// With an [intent] every line is the server's, built by [moneyActionFields]
/// as the signing sheet builds it. Without one only what this device holds
/// is drawn: the NFT, the recipient the preflight checked and the network;
/// the fee is not read yet.
class SendNftReviewCard extends StatelessWidget {
  const SendNftReviewCard({
    required this.target,
    super.key,
    this.intent,
    this.recipient,
  });

  final SendNftTarget target;
  final LoopWalletIntent? intent;

  /// The checked recipient, before the intent exists.
  final String? recipient;

  static const double pictureSide = 96;

  @override
  Widget build(BuildContext context) {
    final intent = this.intent;
    final serverName = intent?.review.nft?.projectName;
    final name = serverName ?? target.projectName ?? target.ticker;
    final tokenId = intent?.review.nft?.tokenId ?? target.tokenIdText;
    final rows = intent == null
        ? <(String, String)>[
            (
              context.l10n.wallet_moneyActionsSigningLabel,
              recipient ?? context.l10n.wallet_sendScreensBuild4,
            ),
            (context.l10n.common_network, loopChainName(target.chainId)),
            (
              context.l10n.wallet_moneyActionsSigningLabel3,
              context.l10n.wallet_sendScreensBuild5,
            ),
          ]
        : <(String, String)>[
            for (final field in moneyActionFields(intent).skip(1))
              if (moneyFieldId(field.label) != 'nft')
                (field.label, field.value),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordCard(
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: LoopRadius.card,
                child: Launch2NftCard(
                  key: const ValueKey<String>('send-nft-picture'),
                  ticker: target.ticker,
                  nftImageUrl: target.nftImageUrl,
                  logoUrl: target.logoUrl,
                  size: pictureSide,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      key: const ValueKey<String>('send-nft-name'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.titleLg,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '#$tokenId',
                      key: const ValueKey<String>('send-nft-token-id'),
                      style: LoopType.figureMd.copyWith(
                        color: LoopColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: LoopSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (label, value) in rows)
                  LoopKeyValue(
                    key: ValueKey<String>(
                      'send-nft-review-${moneyFieldId(label)}',
                    ),
                    label: label,
                    value: value,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    valueUp: moneyFieldId(label) == 'simulation'
                        ? intent?.simulation.passed
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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
          title: context.l10n.wallet_sendScreensTitle,
          body: context.l10n.wallet_sendScreensBody(
            moneyActionTitle(intent.kind),
            moneyIntentStateLabel(intent.state),
          ),
        ),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('money-pending-open'),
              label: context.l10n.wallet_sendScreensMoneyPendingOpenLabel,
              onPressed: busy ? null : onReport,
            ),
            LoopButton(
              key: const ValueKey<String>('money-pending-cancel'),
              label: context.l10n.wallet_sendScreensMoneyPendingCancelLabel,
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
              label: context.l10n.wallet_moneyActionsSigningLabel,
              value:
                  draft.recipientAddress ??
                  context.l10n.wallet_sendScreensBuild4,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('send-confirm-draft-amount'),
              label: context.l10n.common_amount,
              value: draft.amount == null
                  ? context.l10n.wallet_sendScreensBuild4
                  : '${loopGroupedFigure(draft.amount!)} ${draft.symbol}',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('send-confirm-draft-fee'),
              label: context.l10n.wallet_sendScreensSendConfirmDraftFeeLabel,
              value: context.l10n.wallet_sendScreensBuild5,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('send-confirm-draft-arrival'),
              label:
                  context.l10n.wallet_sendScreensSendConfirmDraftArrivalLabel,
              value:
                  context.l10n.wallet_sendScreensSendConfirmDraftArrivalValue,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.wallet_sendScreensBuild6,
              style: LoopType.caption,
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
            LoopKeyValue(
              label:
                  context.l10n.wallet_sendScreensSendConfirmDraftArrivalLabel,
              value:
                  context.l10n.wallet_sendScreensSendConfirmDraftArrivalValue,
              padding: EdgeInsets.symmetric(vertical: 8),
            ),
            Text(
              context.l10n.wallet_sendScreensBuild7,
              style: LoopType.caption,
            ),
          ],
        ),
      ),
    );
  }
}

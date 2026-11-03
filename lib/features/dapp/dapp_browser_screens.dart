import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/security/loop_url_review.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/dapp/dapp_bridge.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/features/dapp/dapp_provider_script.dart';
import 'package:loop_mobile/features/dapp/dapp_signing.dart';
import 'package:loop_mobile/features/dapp/dapp_store.dart';
import 'package:loop_mobile/features/dapp/dapp_webview.dart';
import 'package:loop_mobile/features/wallet/deferred_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/browser/system_external_browser.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

// ---------------------------------------------------------------------------
// S342 · decision 0270 · 内置 DApp 浏览器 (docs/55 §一, §三)
// ---------------------------------------------------------------------------

/// What `/wallet/dapp/web` opens: one reviewed `https` URL. A URL the local
/// review flagged carries [acknowledged] only after the owner read the
/// findings and chose to open it anyway.
@immutable
final class DappOpenRequest {
  const DappOpenRequest({required this.url, this.acknowledged = false});

  final Uri url;
  final bool acknowledged;
}

/// The path of the opened page (manifest `dapp-web`).
const String dappWebPath = '/wallet/dapp/web';

/// The URL a review admits for navigation: the canonical form, with the
/// typed fragment kept (a DApp's own `#/` routes live there; the fragment is
/// never sent to the server).
Uri? dappNavigableUrl(LoopUrlReview review) {
  final canonical = review.canonical;
  if (canonical == null || review.isBlocked) return null;
  final typed = Uri.tryParse(
    review.findings.contains(LoopUrlFinding.schemeAssumed)
        ? 'https://${review.input}'
        : review.input,
  );
  final fragment = typed?.fragment ?? '';
  return fragment.isEmpty ? canonical : canonical.replace(fragment: fragment);
}

/// The browser opens only when the server opened `dappBrowser` and this
/// build has a WebView. Anything else keeps the local URL review.
bool dappBrowserAvailable(WidgetRef ref) =>
    ref
        .watch(loopCapabilityProvider(LoopV2CapabilityId.dappBrowser))
        .isAvailable &&
    ref.watch(dappWebViewFactoryProvider).available;

/// The wallet a page connects to: the active wallet when it is an embedded
/// one, else the first embedded wallet. An external wallet cannot sign here.
DappWalletIdentity? dappWalletFrom(LoopWalletDirectory? directory) {
  if (directory == null) return null;
  final embedded = directory.embedded
      .where((wallet) => wallet.status == LoopWalletStatus.active)
      .toList(growable: false);
  if (embedded.isEmpty) return null;
  final active = directory.active;
  final chosen = embedded.firstWhere(
    (wallet) => wallet.walletId == active?.walletId,
    orElse: () => embedded.first,
  );
  return DappWalletIdentity(
    walletId: chosen.walletId,
    address: chosen.address.toLowerCase(),
  );
}

/// The network names the switcher shows (see [DappChains.label]).
String dappChainLabel(String chainId) => DappChains.label(chainId);

/// `/wallet/dapp` · manifest `dapp`.
///
/// Decision 0270: with `dappBrowser` available it is the browser's first
/// page; otherwise it stays the local DApp 网址核对 page, unchanged.
class DappEntryScreen extends ConsumerWidget {
  const DappEntryScreen({super.key, this.onBack, this.onOpen});

  final VoidCallback? onBack;
  final ValueChanged<DappOpenRequest>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!dappBrowserAvailable(ref)) return DappReviewScreen(onBack: onBack);
    return DappBrowserHomeScreen(onBack: onBack, onOpen: onOpen);
  }
}

/// The browser's first page: address bar, 收藏, 最近访问.
///
/// Archetype `index`, layout `dashboard`. States: loading (the local store
/// is read), empty (nothing visited or saved), error and offline do not
/// apply to a device-local list — a store that cannot be read is an empty
/// list — and permission is the capability gate in [DappEntryScreen].
class DappBrowserHomeScreen extends ConsumerStatefulWidget {
  const DappBrowserHomeScreen({super.key, this.onBack, this.onOpen});

  final VoidCallback? onBack;
  final ValueChanged<DappOpenRequest>? onOpen;

  @override
  ConsumerState<DappBrowserHomeScreen> createState() =>
      _DappBrowserHomeScreenState();
}

class _DappBrowserHomeScreenState extends ConsumerState<DappBrowserHomeScreen> {
  final TextEditingController _address = TextEditingController();
  LoopUrlReview? _blocked;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit(String input) async {
    final review = LoopUrlReview.review(input);
    if (review.input.isEmpty) return;
    final url = dappNavigableUrl(review);
    if (url == null) {
      setState(() => _blocked = review);
      return;
    }
    setState(() => _blocked = null);
    if (review.verdict == LoopUrlVerdict.flagged) {
      final open = await showDappFindingsSheet(context, review: review);
      if (!open || !mounted) return;
      _open(DappOpenRequest(url: url, acknowledged: true));
      return;
    }
    _open(DappOpenRequest(url: url));
  }

  void _open(DappOpenRequest request) {
    FocusScope.of(context).unfocus();
    widget.onOpen?.call(request);
  }

  /// A saved or recent page opens through the same review as a typed one:
  /// a flagged address shows its findings first (S346 · M9).
  void _openEntry(DappPageEntry entry) {
    final review = LoopUrlReview.review(entry.url);
    if (dappNavigableUrl(review) == null) return;
    _open(DappOpenRequest(url: Uri.parse(entry.url)));
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(dappBrowserLocalProvider);
    final blocked = _blocked;
    return LoopDashboardPage(
      key: const ValueKey<String>('dapp-browser-home'),
      archetype: LoopPageArchetype.listing,
      title: 'DApp 浏览器',
      onBack: widget.onBack,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopOmnibox(
            key: const ValueKey<String>('dapp-browser-omnibox'),
            fieldKey: const ValueKey<String>('dapp-browser-address-field'),
            controller: _address,
            hintText: '输入网址',
            onChanged: (_) {
              if (_blocked != null) setState(() => _blocked = null);
            },
            onSubmitted: (value) => unawaited(_submit(value)),
          ),
          if (blocked != null)
            Padding(
              key: const ValueKey<String>('dapp-browser-blocked'),
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                0,
                LoopSpacing.page,
                LoopSpacing.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '这个网址不能打开',
                    style: LoopType.title.copyWith(color: LoopColors.fall),
                  ),
                  for (final finding in blocked.findings)
                    if (finding.isBlocking)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          finding.explanation,
                          key: ValueKey<String>(
                            'dapp-browser-blocked-${finding.name}',
                          ),
                          style: LoopType.caption,
                        ),
                      ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: LoopButton(
              key: const ValueKey<String>('dapp-browser-go'),
              label: '打开',
              primary: true,
              block: true,
              onPressed: () => unawaited(_submit(_address.text)),
            ),
          ),
        ],
      ),
      sections: <Widget>[
        ...switch (local) {
          AsyncData<DappBrowserLocalState>(value: final state) => _lists(state),
          AsyncError<DappBrowserLocalState>() => _lists(
            DappBrowserLocalState(),
          ),
          _ => <Widget>[
            const LoopSkeleton(
              key: ValueKey<String>('dapp-browser-loading'),
              type: LoopSkeletonType.list,
            ),
          ],
        },
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _lists(DappBrowserLocalState state) {
    if (state.bookmarks.isEmpty && state.recents.isEmpty) {
      return const <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('dapp-browser-empty'),
          illustration: LoopIllustration.search,
          title: '还没有访问记录',
          compact: true,
        ),
      ];
    }
    return <Widget>[
      if (state.bookmarks.isNotEmpty) ...<Widget>[
        const LoopLabel('收藏'),
        LoopRecordGroup(
          key: const ValueKey<String>('dapp-browser-bookmarks'),
          rows: <LoopRecordRow>[
            for (final entry in state.bookmarks)
              _row(entry, prefix: 'dapp-bookmark', icon: 'star'),
          ],
        ),
      ],
      if (state.recents.isNotEmpty) ...<Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            const Expanded(child: LoopLabel('最近访问')),
            Semantics(
              button: true,
              label: '清除最近访问',
              child: LoopPressable(
                key: const ValueKey<String>('dapp-browser-clear-recents'),
                onTap: () => unawaited(
                  ref.read(dappBrowserLocalProvider.notifier).clearRecents(),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: LoopTouch.minimum,
                    minWidth: LoopTouch.minimum,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: LoopSpacing.page),
                    child: Center(
                      child: Text(
                        '清除',
                        style: LoopType.label.copyWith(color: LoopColors.text2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        LoopRecordGroup(
          key: const ValueKey<String>('dapp-browser-recents'),
          rows: <LoopRecordRow>[
            for (final entry in state.recents)
              _row(entry, prefix: 'dapp-recent', icon: 'clock'),
          ],
        ),
      ],
    ];
  }

  LoopRecordRow _row(
    DappPageEntry entry, {
    required String prefix,
    required String icon,
  }) => LoopRecordRow(
    key: ValueKey<String>('$prefix-${entry.url}'),
    leading: LoopRowIcon(icon: icon),
    title: entry.title.isEmpty ? entry.host : entry.title,
    subtitle: entry.host,
    onTap: () => _openEntry(entry),
  );
}

/// The local review's findings for a flagged address, before it opens.
Future<bool> showDappFindingsSheet(
  BuildContext context, {
  required LoopUrlReview review,
}) async {
  final open = await showLoopSheet<bool>(
    context,
    builder: (context) => Padding(
      key: const ValueKey<String>('dapp-findings-sheet'),
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(review.host ?? review.input, style: LoopType.heading),
          const SizedBox(height: LoopSpacing.card),
          for (final finding in review.findings)
            if (finding != LoopUrlFinding.schemeAssumed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const LoopIcon('warn', size: 16, color: LoopColors.lime),
                    const SizedBox(width: LoopSpacing.tight),
                    Expanded(
                      child: Text(
                        finding.explanation,
                        key: ValueKey<String>('dapp-finding-${finding.name}'),
                        style: LoopType.body,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: LoopSpacing.card),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('dapp-findings-cancel'),
                label: '取消',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              LoopButton(
                key: const ValueKey<String>('dapp-findings-open'),
                label: '仍要打开',
                primary: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return open ?? false;
}

// ---------------------------------------------------------------------------
// the opened page
// ---------------------------------------------------------------------------

/// `/wallet/dapp/web` · manifest `dapp-web`.
///
/// Archetype `action`, layout `focus`. States: loading (the progress bar),
/// empty (a URL the local review blocks opens nothing), error (the page did
/// not load, with 重试), offline (no connection, with 重试) and permission
/// (no WebView or `dappBrowser` closed: the page is unavailable).
class DappBrowserPage extends ConsumerStatefulWidget {
  const DappBrowserPage({
    required this.request,
    super.key,
    this.onClose,
    this.clock,
  });

  final DappOpenRequest request;
  final VoidCallback? onClose;
  final DateTime Function()? clock;

  @override
  ConsumerState<DappBrowserPage> createState() => _DappBrowserPageState();
}

enum _PageGate { open, findings, blocked }

class _DappBrowserPageState extends ConsumerState<DappBrowserPage>
    implements DappBridgeHost {
  late final String _providerUuid = _uuidV4();
  final ValueNotifier<int> _dismissSigning = ValueNotifier<int>(0);
  late final DappBridge _bridge;
  late final LoopUrlReview _review = LoopUrlReview.review(
    widget.request.url.toString(),
  );
  late _PageGate _gate;

  DappWebViewController? _controller;
  Uri? _url;
  String _title = '';
  double _progress = 0;
  DappLoadFailure? _failure;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _chainId = loopLaunchTestnetChainId;

  static String _randomHex(int bytes) {
    final random = Random.secure();
    return List<String>.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _uuidV4() {
    final hex = _randomHex(16).split('');
    hex[12] = '4';
    hex[16] = '89ab'[int.parse(hex[16], radix: 16) % 4];
    final text = hex.join();
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-'
        '${text.substring(12, 16)}-${text.substring(16, 20)}-'
        '${text.substring(20)}';
  }

  @override
  void initState() {
    super.initState();
    _gate = dappNavigableUrl(_review) == null
        ? _PageGate.blocked
        : _review.verdict == LoopUrlVerdict.flagged &&
              !widget.request.acknowledged
        ? _PageGate.findings
        : _PageGate.open;
    _bridge = DappBridge(
      host: this,
      intents: ref.read(dappIntentsGatewayProvider),
      reader: ref.read(dappRpcReaderProvider),
      isConnected: (walletId, origin) =>
          ref
              .read(dappBrowserLocalProvider)
              .value
              ?.isConnected(walletId, origin) ??
          false,
      setConnected: (walletId, origin, {required bool connected}) => ref
          .read(dappBrowserLocalProvider.notifier)
          .setConnected(walletId, origin, connected: connected),
      chainId: _chainId,
    );
    scheduleMicrotask(() {
      if (!mounted) return;
      final directory = ref.read(walletDirectoryControllerProvider);
      if (directory.value == null) {
        unawaited(ref.read(walletDirectoryControllerProvider.notifier).load());
      }
    });
  }

  @override
  void dispose() {
    _bridge.dispose();
    _dismissSigning.dispose();
    super.dispose();
  }

  // ---- DappBridgeHost -----------------------------------------------------

  /// The origin of the document the WebView last reported loaded, while no
  /// navigation is under way.
  String? get topOrigin => _bridge.committedOrigin;

  @override
  DappWalletIdentity? get wallet =>
      dappWalletFrom(ref.read(walletDirectoryControllerProvider).value);

  String? get _favicon {
    final origin = topOrigin;
    return origin == null ? null : '$origin/favicon.ico';
  }

  @override
  Future<bool> confirmConnection({
    required String origin,
    required DappWalletIdentity wallet,
  }) async {
    if (!mounted) return false;
    return showDappConnectSheet(
      context,
      origin: origin,
      address: wallet.address,
      faviconUrl: _favicon,
    );
  }

  @override
  Future<DappSignOutcome> confirmIntent({
    required DappIntent intent,
    required DappWalletIdentity wallet,
    required String origin,
    DappTxRequest? tx,
    DappSignRequest? sign,
  }) async {
    if (!mounted) return const DappSignOutcome.rejected();
    // The bridge releases the server's intent for every outcome that is not
    // a produced hash or signature.
    final outcome = await showDappIntentSheet(
      context,
      intent: intent,
      signer: ref.read(dappSignerProvider),
      origin: origin,
      fromAddress: wallet.address,
      tx: tx,
      sign: sign,
      faviconUrl: _favicon,
      clock: widget.clock,
      dismiss: _dismissSigning,
    );
    if (outcome.status == DappSignStatus.produced && mounted) {
      LoopToast.show(
        context,
        message: intent.kind == DappIntentKind.transaction ? '已广播' : '已签名',
      );
    }
    return outcome;
  }

  @override
  void toast(String message) {
    if (!mounted) return;
    LoopToast.show(context, message: message, kind: LoopToastKind.warn);
  }

  @override
  void dismissSigning() => _dismissSigning.value += 1;

  @override
  Future<void> emit(String event, Object? data) async {
    final controller = _controller;
    final script = _bridge.emitScript(event, data);
    if (controller == null || script == null) return;
    try {
      await controller.evaluate(script);
    } on Object {
      // A page that navigated away no longer has the listener.
    }
  }

  @override
  void chainChanged(String chainId) {
    if (mounted) setState(() => _chainId = chainId);
  }

  @override
  void documentScriptChanged() {
    final controller = _controller;
    if (controller == null) return;
    unawaited(
      controller
          .setDocumentStartScript(_documentStartScript())
          .catchError((Object _) {}),
    );
  }

  String _documentStartScript() => dappProviderScript(
    bootNonce: _bridge.bootNonce,
    chainIdHex: DappChains.hexOf(_bridge.chainId),
    providerUuid: _providerUuid,
  );

  // ---- WebView ------------------------------------------------------------

  /// A main-frame URL the page may hold: `https` that the local review
  /// does not block.
  static bool _navigable(Uri url) =>
      url.scheme.toLowerCase() == 'https' &&
      !LoopUrlReview.review(url.toString()).isBlocked;

  bool _allowNavigation(Uri url) {
    final scheme = url.scheme.toLowerCase();
    if (scheme == 'about') return true;
    if (scheme == 'http') {
      toast('只能打开 HTTPS 网址');
      return false;
    }
    if (scheme != 'https') return false;
    final review = LoopUrlReview.review(url.toString());
    if (review.isBlocked) {
      toast('这个网址不能打开');
      return false;
    }
    return true;
  }

  /// A main-frame navigation started (S346 · M1): the bridge refuses every
  /// request until a document finishes loading. A navigation that reached
  /// here without the navigation check — an Android POST form — and is not
  /// allowed is stopped (M12).
  void _onLoadStart(Uri url) {
    _bridge.documentStarting(url);
    if (url.scheme.toLowerCase() != 'about' && !_navigable(url)) {
      unawaited(_controller?.stop().catchError((Object _) {}));
      toast('这个网址不能打开');
    }
    if (mounted) setState(() => _failure = null);
  }

  /// The main frame finished loading [url]: it becomes the page's address
  /// and the only origin the bridge acts for.
  void _onLoadStop(Uri url) {
    if (!mounted) return;
    if (!_navigable(url)) return;
    _bridge.documentLoaded(url);
    setState(() {
      _url = url;
      _failure = null;
    });
    unawaited(_refreshHistory());
    unawaited(
      ref
          .read(dappBrowserLocalProvider.notifier)
          .recordVisit(DappPageEntry(url: url.toString(), title: _title)),
    );
  }

  /// The address changed inside the same document (history API, hash).
  void _onUrlChanged(Uri url) {
    if (!mounted) return;
    final current = _url;
    if (current == null || url.origin != current.origin) return;
    if (_bridge.committedOrigin != url.origin) return;
    setState(() => _url = url);
    unawaited(_refreshHistory());
    unawaited(
      ref
          .read(dappBrowserLocalProvider.notifier)
          .recordVisit(DappPageEntry(url: url.toString(), title: _title)),
    );
  }

  void _onTitle(String title) {
    if (!mounted) return;
    final trimmed = title.trim();
    setState(
      () => _title = trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed,
    );
    final url = _url;
    if (url != null && url.scheme == 'https' && _title.isNotEmpty) {
      unawaited(
        ref
            .read(dappBrowserLocalProvider.notifier)
            .recordVisit(DappPageEntry(url: url.toString(), title: _title)),
      );
    }
  }

  Future<void> _refreshHistory() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final back = await controller.canGoBack();
      final forward = await controller.canGoForward();
      if (mounted) {
        setState(() {
          _canGoBack = back;
          _canGoForward = forward;
        });
      }
    } on Object {
      // History is a convenience; the buttons stay as they were.
    }
  }

  Future<void> _retry() async {
    setState(() {
      _failure = null;
      _progress = 0;
    });
    final controller = _controller;
    if (controller == null) return;
    final url = _url ?? widget.request.url;
    await controller.load(url);
  }

  // ---- menus --------------------------------------------------------------

  Future<void> _showUrlInfo() async {
    final url = _url ?? widget.request.url;
    final review = LoopUrlReview.review(url.toString());
    await showLoopSheet<void>(
      context,
      builder: (context) => Padding(
        key: const ValueKey<String>('dapp-url-sheet'),
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(url.host, style: LoopType.heading),
            const SizedBox(height: LoopSpacing.tight),
            SelectableText(
              url.toString(),
              key: const ValueKey<String>('dapp-url-full'),
              style: LoopType.code,
            ),
            const SizedBox(height: LoopSpacing.card),
            Row(
              children: <Widget>[
                LoopBadge(
                  switch (review.verdict) {
                    LoopUrlVerdict.normalized => '来源一致',
                    LoopUrlVerdict.flagged => '需注意',
                    LoopUrlVerdict.blocked => '已阻止',
                  },
                  key: const ValueKey<String>('dapp-url-verdict'),
                  kind: switch (review.verdict) {
                    LoopUrlVerdict.normalized => LoopBadgeKind.up,
                    LoopUrlVerdict.flagged => LoopBadgeKind.mining,
                    LoopUrlVerdict.blocked => LoopBadgeKind.mute,
                  },
                ),
              ],
            ),
            for (final finding in review.findings)
              if (finding != LoopUrlFinding.schemeAssumed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(finding.explanation, style: LoopType.body),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChains() async {
    final chosen = await showLoopSheet<String>(
      context,
      builder: (context) => Padding(
        key: const ValueKey<String>('dapp-chain-sheet'),
        padding: const EdgeInsets.only(bottom: 8),
        child: LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (final chainId in DappChains.supported)
              LoopRecordRow(
                key: ValueKey<String>('dapp-chain-$chainId'),
                leading: const LoopRowIcon(icon: 'globe'),
                title: dappChainLabel(chainId),
                selected: chainId == _chainId,
                chevron: false,
                onTap: () => Navigator.of(context).pop(chainId),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) await _bridge.switchChain(chosen);
  }

  Future<void> _showMenu() async {
    final url = _url ?? widget.request.url;
    final origin = topOrigin;
    final local = ref.read(dappBrowserLocalProvider).value;
    final bookmarked = local?.isBookmarked(url.toString()) ?? false;
    final walletId = wallet?.walletId;
    final connected =
        origin != null &&
        walletId != null &&
        (local?.isConnected(walletId, origin) ?? false);
    final action = await showLoopSheet<String>(
      context,
      builder: (context) => Padding(
        key: const ValueKey<String>('dapp-menu-sheet'),
        padding: const EdgeInsets.only(bottom: 8),
        child: LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('dapp-menu-bookmark'),
              leading: const LoopRowIcon(icon: 'star'),
              title: bookmarked ? '取消收藏' : '收藏',
              chevron: false,
              onTap: () => Navigator.of(context).pop('bookmark'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('dapp-menu-copy'),
              leading: const LoopRowIcon(icon: 'copy'),
              title: '复制链接',
              chevron: false,
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            LoopRecordRow(
              key: const ValueKey<String>('dapp-menu-external'),
              leading: const LoopRowIcon(icon: 'share'),
              title: '在外部浏览器打开',
              chevron: false,
              onTap: () => Navigator.of(context).pop('external'),
            ),
            if (connected)
              LoopRecordRow(
                key: const ValueKey<String>('dapp-menu-disconnect'),
                leading: const LoopRowIcon(icon: 'link'),
                title: '断开此站点',
                chevron: false,
                onTap: () => Navigator.of(context).pop('disconnect'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'bookmark':
        await ref
            .read(dappBrowserLocalProvider.notifier)
            .toggleBookmark(
              DappPageEntry(
                url: url.toString(),
                title: _title.isEmpty ? url.host : _title,
              ),
            );
        if (mounted) {
          LoopToast.show(context, message: bookmarked ? '已取消收藏' : '已收藏');
        }
      case 'copy':
        if (mounted) {
          await LoopCopy.text(context, url.toString(), message: '已复制链接');
        }
      case 'external':
        final opened = await ref.read(loopExternalBrowserProvider)(url);
        if (!opened && mounted) toast('无法打开外部浏览器');
      case 'disconnect':
        if (origin != null) await _bridge.disconnect(origin);
        if (mounted) LoopToast.show(context, message: '已断开');
    }
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final available = dappBrowserAvailable(ref);
    // Kept read and alive: the bridge asks it which origins are connected.
    ref.watch(dappBrowserLocalProvider);
    final directory = ref.watch(walletDirectoryControllerProvider);
    final identity = dappWalletFrom(directory.value);
    final url = _url ?? widget.request.url;
    final secure = url.scheme == 'https';
    return Scaffold(
      key: const ValueKey<String>('dapp-web-page'),
      backgroundColor: LoopColors.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _TopBar(
              host: url.host,
              secure: secure,
              chainLabel: dappChainLabel(_chainId),
              address: identity == null
                  ? null
                  : loopTruncatedAddress(identity.address),
              onClose: widget.onClose,
              onUrl: () => unawaited(_showUrlInfo()),
              onChain: () => unawaited(_showChains()),
              onMenu: () => unawaited(_showMenu()),
            ),
            _ProgressLine(
              progress: _gate == _PageGate.open && available && _failure == null
                  ? _progress
                  : 1,
            ),
            Expanded(child: _body(available)),
            _BottomBar(
              canGoBack: _canGoBack,
              canGoForward: _canGoForward,
              onBack: () => unawaited(_controller?.goBack()),
              onForward: () => unawaited(_controller?.goForward()),
              onReload: () => unawaited(
                _failure != null ? _retry() : _controller?.reload(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(bool available) {
    if (!available) {
      return const Center(
        child: LoopEmptyState(
          key: ValueKey<String>('dapp-web-unavailable'),
          illustration: LoopIllustration.search,
          title: 'DApp 浏览器暂不可用',
          compact: true,
        ),
      );
    }
    switch (_gate) {
      case _PageGate.blocked:
        return Center(
          child: LoopEmptyState(
            key: const ValueKey<String>('dapp-web-blocked'),
            illustration: LoopIllustration.search,
            title: '这个网址不能打开',
            message: _review.findings
                .where((finding) => finding.isBlocking)
                .map((finding) => finding.explanation)
                .join('\n'),
            compact: true,
          ),
        );
      case _PageGate.findings:
        return ListView(
          key: const ValueKey<String>('dapp-web-findings'),
          padding: const EdgeInsets.all(LoopSpacing.page),
          children: <Widget>[
            Text(_review.host ?? '', style: LoopType.heading),
            const SizedBox(height: LoopSpacing.card),
            for (final finding in _review.findings)
              if (finding != LoopUrlFinding.schemeAssumed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(finding.explanation, style: LoopType.body),
                ),
            const SizedBox(height: LoopSpacing.card),
            LoopButtonPair(
              padded: false,
              children: <Widget>[
                LoopButton(label: '返回', onPressed: widget.onClose),
                LoopButton(
                  key: const ValueKey<String>('dapp-web-findings-open'),
                  label: '仍要打开',
                  primary: true,
                  onPressed: () => setState(() => _gate = _PageGate.open),
                ),
              ],
            ),
          ],
        );
      case _PageGate.open:
        break;
    }
    final failure = _failure;
    final factory = ref.watch(dappWebViewFactoryProvider);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Offstage(
            offstage: failure != null,
            child: factory.build(
              DappWebViewConfig(
                initialUrl: dappNavigableUrl(_review) ?? widget.request.url,
                documentStartScript: _documentStartScript(),
                handlerName: DappBridgeProtocol.handlerName,
                onBridgeCall: _bridge.handle,
                readyHandlerName: DappBridgeProtocol.readyHandlerName,
                onReady: _bridge.ready,
                onCreated: (controller) => _controller = controller,
                onLoadStart: _onLoadStart,
                onLoadStop: _onLoadStop,
                onUrlChanged: _onUrlChanged,
                onTitleChanged: _onTitle,
                onProgress: (value) {
                  if (mounted) setState(() => _progress = value);
                },
                onLoadFailed: (kind) {
                  if (mounted) setState(() => _failure = kind);
                },
                shouldAllowNavigation: _allowNavigation,
              ),
            ),
          ),
        ),
        if (failure == DappLoadFailure.offline)
          Center(
            child: LoopOfflineState(
              key: const ValueKey<String>('dapp-web-offline'),
              pausedActions: const <String>['签名'],
              onRetry: () => unawaited(_retry()),
            ),
          ),
        if (failure == DappLoadFailure.error)
          Center(
            child: LoopErrorState(
              key: const ValueKey<String>('dapp-web-error'),
              title: '页面没有打开',
              reason: (_url ?? widget.request.url).host,
              onRetry: () => unawaited(_retry()),
            ),
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.host,
    required this.secure,
    required this.chainLabel,
    required this.address,
    required this.onClose,
    required this.onUrl,
    required this.onChain,
    required this.onMenu,
  });

  final String host;
  final bool secure;
  final String chainLabel;
  final String? address;
  final VoidCallback? onClose;
  final VoidCallback onUrl;
  final VoidCallback onChain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: <Widget>[
          LoopIconButton(
            key: const ValueKey<String>('dapp-web-close'),
            icon: 'close',
            label: '关闭',
            onPressed: onClose,
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: '查看网址 $host',
              child: LoopPressable(
                key: const ValueKey<String>('dapp-web-address'),
                onTap: onUrl,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: LoopTouch.minimum,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: LoopColors.input,
                    borderRadius: LoopRadius.control,
                  ),
                  child: Row(
                    children: <Widget>[
                      LoopIcon(
                        secure ? 'lock' : 'warn',
                        key: const ValueKey<String>('dapp-web-lock'),
                        size: 14,
                        color: secure ? LoopColors.text2 : LoopColors.fall,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          host,
                          key: const ValueKey<String>('dapp-web-host'),
                          style: LoopType.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: '切换网络 $chainLabel',
            child: LoopPressable(
              key: const ValueKey<String>('dapp-web-chain'),
              onTap: onChain,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: LoopTouch.minimum,
                  maxWidth: 110,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      chainLabel,
                      key: const ValueKey<String>('dapp-web-chain-label'),
                      style: LoopType.label.copyWith(color: LoopColors.lime),
                      maxLines: 1,
                    ),
                    Text(
                      address ?? '未连接钱包',
                      key: const ValueKey<String>('dapp-web-wallet'),
                      style: LoopType.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          LoopIconButton(
            key: const ValueKey<String>('dapp-web-menu'),
            icon: 'settings',
            label: '更多',
            onPressed: onMenu,
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final visible = progress < 1;
    return SizedBox(
      key: const ValueKey<String>('dapp-web-progress'),
      height: 2,
      child: visible
          ? Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.05, 1),
                child: const ColoredBox(color: LoopColors.lime),
              ),
            )
          : null,
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onReload,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 2, 8, 2 + bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            LoopIconButton(
              key: const ValueKey<String>('dapp-web-back'),
              icon: 'back',
              label: '后退',
              onPressed: canGoBack ? onBack : null,
            ),
            Transform.flip(
              flipX: true,
              child: LoopIconButton(
                key: const ValueKey<String>('dapp-web-forward'),
                icon: 'back',
                label: '前进',
                onPressed: canGoForward ? onForward : null,
              ),
            ),
            LoopIconButton(
              key: const ValueKey<String>('dapp-web-reload'),
              icon: 'refresh',
              label: '刷新',
              onPressed: onReload,
            ),
          ],
        ),
      ),
    );
  }
}

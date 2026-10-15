import 'dart:async';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/meme/meme_controllers.dart';
import 'package:loop_mobile/features/meme/meme_create_screen.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/meme/meme_token_screen.dart';
import 'package:loop_mobile/features/meme/meme_trade_panel.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_step_track.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

import 'support/loop_ground_probe.dart';
import 'support/meme_fixtures.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S117 · MEME curve launchpad pages (client decision 0120)
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _hash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';

/// One scripted answer: a value, a failure, or a read that never answers.
final class _Answer<T> {
  const _Answer.value(T this.value) : failure = null, pending = false;
  const _Answer.fail(LoopChainFailureKind kind, {String? reasonCode})
    : value = null,
      failure = (kind, reasonCode),
      pending = false;
  const _Answer.pending() : value = null, failure = null, pending = true;

  final T? value;
  final (LoopChainFailureKind, String?)? failure;
  final bool pending;

  Future<T> resolve() {
    if (pending) return Completer<T>().future;
    final f = failure;
    if (f != null) {
      return Future<T>.error(LoopChainException(f.$1, reasonCode: f.$2));
    }
    return Future<T>.value(value as T);
  }
}

final class _FakeMeme implements MemeGateway {
  _FakeMeme({
    this.list,
    List<_Answer<MemeTokenDetail>>? details,
    this.trades,
    this.holders,
    this.candles,
    this.quoteAnswer,
    this.createAnswer,
    this.prepareAnswer,
    this.reportAnswer,
    List<_Answer<MemeIntent>>? intentReads,
  }) : details = details ?? <_Answer<MemeTokenDetail>>[],
       intentReads = intentReads ?? <_Answer<MemeIntent>>[];

  _Answer<MemeTokenPage> Function(MemeListTab tab, String? cursor)? list;
  final List<_Answer<MemeTokenDetail>> details;
  _Answer<MemeTradePage> Function(String? cursor)? trades;
  _Answer<MemeHolderPage> Function(String? cursor)? holders;
  _Answer<MemeCandleSeries>? candles;
  _Answer<MemeQuote>? quoteAnswer;
  _Answer<MemeTokenDetail>? createAnswer;
  _Answer<MemeIntent>? prepareAnswer;
  _Answer<MemeIntent>? reportAnswer;
  final List<_Answer<MemeIntent>> intentReads;

  final List<(MemeListTab, String?)> listCalls = <(MemeListTab, String?)>[];
  final List<String?> tradeCalls = <String?>[];
  final List<String?> holderCalls = <String?>[];
  final List<(MemeTradeSide, String, String?)> quoteCalls =
      <(MemeTradeSide, String, String?)>[];
  final List<MemeCreateDraft> createCalls = <MemeCreateDraft>[];
  final List<Map<String, Object?>> prepareCalls = <Map<String, Object?>>[];
  final List<String> reportCalls = <String>[];
  int detailReads = 0;
  int intentReadCount = 0;
  int uploads = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<MemeTokenPage> listTokens(MemeListTab tab, {String? cursor}) {
    listCalls.add((tab, cursor));
    final answer = list;
    return answer == null ? _unavailable() : answer(tab, cursor).resolve();
  }

  @override
  Future<MemeTokenDetail> loadToken(String memeTokenId) {
    final index = detailReads;
    detailReads += 1;
    if (details.isEmpty) return _unavailable();
    return details[index < details.length ? index : details.length - 1]
        .resolve();
  }

  @override
  Future<MemeTradePage> loadTrades(String memeTokenId, {String? cursor}) {
    tradeCalls.add(cursor);
    final answer = trades;
    return answer == null ? _unavailable() : answer(cursor).resolve();
  }

  @override
  Future<MemeHolderPage> loadHolders(String memeTokenId, {String? cursor}) {
    holderCalls.add(cursor);
    final answer = holders;
    return answer == null ? _unavailable() : answer(cursor).resolve();
  }

  @override
  Future<MemeCandleSeries> loadCandles(
    String memeTokenId,
    MemeCandleInterval interval,
  ) => candles?.resolve() ?? _unavailable();

  @override
  Future<MemeQuote> quote({
    required String memeTokenId,
    required MemeTradeSide side,
    required String amount,
    String? walletId,
  }) {
    quoteCalls.add((side, amount, walletId));
    return quoteAnswer?.resolve() ?? _unavailable();
  }

  @override
  Future<MemeUploadedImage> uploadImage({
    required Uint8List bytes,
    required String contentType,
  }) {
    uploads += 1;
    return Future<MemeUploadedImage>.value(
      MemeUploadedImage(
        mediaId: memeMediaId,
        url: memeTestMediaUrl(memeMediaId)!,
      ),
    );
  }

  @override
  Future<MemeTokenDetail> createToken(MemeCreateDraft draft) {
    createCalls.add(draft);
    return createAnswer?.resolve() ?? _unavailable();
  }

  @override
  Future<MemeIntent> prepareIntent({
    required String memeTokenId,
    required MemeIntentKind kind,
    required String walletId,
    String? usd1Amount,
    String? tokenAmount,
    int? slippageBps,
  }) {
    prepareCalls.add(<String, Object?>{
      'memeTokenId': memeTokenId,
      'kind': kind.wireName,
      'walletId': walletId,
      'usd1Amount': usd1Amount,
      'tokenAmount': tokenAmount,
      'slippageBps': slippageBps,
    });
    return prepareAnswer?.resolve() ?? _unavailable();
  }

  @override
  Future<MemeIntent> reportBroadcast({
    required String memeTokenId,
    required String memeIntentId,
    required String txHash,
  }) {
    reportCalls.add(txHash);
    return reportAnswer?.resolve() ?? _unavailable();
  }

  @override
  Future<MemeIntent> loadIntent(String memeIntentId) {
    final index = intentReadCount;
    intentReadCount += 1;
    if (intentReads.isEmpty) return _unavailable();
    return intentReads[index < intentReads.length
            ? index
            : intentReads.length - 1]
        .resolve();
  }
}

/// Records every wallet handoff and answers each with a broadcast hash.
final class _RecordingWallet implements WalletSigningGateway {
  final List<SigningIntent> handed = <SigningIntent>[];

  @override
  WalletGatewayAvailability get availability =>
      WalletGatewayAvailability.available;

  @override
  String get label => 'test';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    handed.add(intent);
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return const WalletHandoffResult(
      accepted: true,
      code: 'wallet_accepted',
      value: _hash,
    );
  }
}

final class _Picker implements AvatarImagePicker {
  @override
  bool get available => true;

  @override
  Future<PickedAvatarImage?> pick() async =>
      PickedAvatarImage(bytes: Uint8List.fromList(<int>[1, 2, 3]));
}

LoopV2MetaSnapshot _meta({
  LoopV2CapabilityAvailability meme = LoopV2CapabilityAvailability.available,
}) {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.meme)
            LoopV2Capability(
              id: LoopV2CapabilityId.meme,
              availability: meme,
              reasonCode: meme == LoopV2CapabilityAvailability.available
                  ? null
                  : 'MEME_CONTRACT_NOT_CONFIGURED',
              evidence: meme == LoopV2CapabilityAvailability.available
                  ? const LoopV2CapabilityEvidence(
                      status: LoopV2CapabilityEvidenceStatus.confirmed,
                      reasonCode: 'MEME_CONTRACT_OBSERVED',
                    )
                  : const LoopV2CapabilityEvidence(
                      status: LoopV2CapabilityEvidenceStatus.pending,
                      reasonCode: 'MEME_CONTRACT_NOT_CONFIGURED',
                    ),
            )
          else
            capability,
      ],
    ),
  );
}

LoopWalletAccount _wallet() => LoopWalletAccount(
  walletId: memeWalletId,
  address: memeWalletAddress,
  kind: LoopWalletKind.embedded,
  status: LoopWalletStatus.active,
  isActive: true,
  firstSeenAt: DateTime.utc(2026, 9),
  lastSeenAt: DateTime.utc(2026, 10, 8),
);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required _FakeMeme meme,
  _RecordingWallet? wallet,
  LoopV2MetaSnapshot? meta,
  bool settle = true,
  List<Override> overrides = const <Override>[],
}) => pumpS7Page(
  tester,
  page,
  meta: meta ?? _meta(),
  settle: settle,
  wallet: FakeWalletDirectory(
    activeWalletId: memeWalletId,
    wallets: <LoopWalletAccount>[_wallet()],
  ),
  overrides: <Override>[
    memeGatewayProvider.overrideWithValue(meme),
    memePollingProvider.overrideWithValue(
      const MemePolling(
        intentInterval: Duration(milliseconds: 10),
        intentMaxAttempts: 5,
        tokenInterval: Duration(milliseconds: 50),
      ),
    ),
    if (wallet != null) walletSigningGatewayProvider.overrideWithValue(wallet),
    ...overrides,
  ],
);

/// 快买's memory as though a 42 USD1 buy had been confirmed this run.
final class _RememberedAmount extends MemeQuickBuyAmount {
  @override
  String? build() => '42';
}

/// Lets the pending timers of the page run out before teardown.
Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 30));
}

void main() {
  loopWatchGround();

  group('发射台 list', () {
    testWidgets('four chips ask for their own tab and render the rows', (
      tester,
    ) async {
      final meme = _FakeMeme(
        list: (tab, cursor) => _Answer<MemeTokenPage>.value(
          memePage(
            tab: tab.wireName,
            items: <Map<String, Object?>>[
              if (tab == MemeListTab.graduated)
                memeRowJson(
                  status: 'graduated',
                  price: null,
                  cap: null,
                  change: null,
                  pool: '0x7777777777777777777777777777777777777777',
                  graduatedAt: '2026-10-08T05:00:00.000Z',
                  quoteUnavailable: 'MEME_DEX_CHAIN_NOT_PRICED',
                )
              else
                memeRowJson(),
            ],
          ),
        ),
      );
      final opened = <String>[];
      await _pump(tester, MemeScreen(onNavigate: opened.add), meme: meme);

      expect(meme.listCalls.first, (MemeListTab.fresh, null));
      // Decision 0173 (design 35 列表 A): ticker + age over 交易量 · 名称,
      // 市值 over the 56 px bar on the right.
      expect(find.text('FROG'), findsOneWidget);
      expect(find.text('3 小时'), findsOneWidget);
      expect(find.text('\$1,980 交易量 · Frog'), findsOneWidget);
      expect(find.text('市值 \$9,891'), findsOneWidget);
      expect(_key('meme-row-price'), findsNothing);
      // The 「快打满」 strip shows the server's graduating list above it.
      expect(_key('meme-graduating-strip'), findsOneWidget);
      expect(_key('meme-hero-$memeTokenIdA'), findsOneWidget);
      expect(_key('meme-row-progress'), findsOneWidget);
      expect(_key('meme-graduated-tag'), findsNothing);
      expect(_key('meme-list-provenance'), findsOneWidget);

      for (final (index, tab) in <(int, MemeListTab)>[
        (1, MemeListTab.hot),
        (2, MemeListTab.graduating),
        (3, MemeListTab.graduated),
      ]) {
        // The chip, not the 「快打满」 strip's own heading.
        await tester.tap(find.text(MemeListTab.values[index].label).first);
        await tester.pumpAndSettle();
        // A tab the 「快打满」 strip already read is not asked again.
        expect(meme.listCalls, contains((tab, null)));
      }
      // 已毕业 replaces the progress bar with its tag, and an unpriced
      // graduated token says why.
      expect(_key('meme-graduated-tag'), findsOneWidget);
      expect(_key('meme-row-progress'), findsNothing);
      expect(find.text('暂无外盘报价'), findsOneWidget);

      await tester.tap(_key('meme-row-$memeTokenIdA'));
      expect(opened.last, '/meme/token?id=$memeTokenIdA');
      await tester.tap(_key('meme-create-entry'));
      expect(opened.last, '/meme/create');
      await tester.tap(_key('meme-search-entry'));
      expect(opened.last, '/search');
      await _drain(tester);
    });

    testWidgets('an empty chip invites the first token', (tester) async {
      final meme = _FakeMeme(
        list: (tab, cursor) => _Answer<MemeTokenPage>.value(
          memePage(items: const <Map<String, Object?>>[]),
        ),
      );
      final opened = <String>[];
      await _pump(tester, MemeScreen(onNavigate: opened.add), meme: meme);
      expect(find.text('还没有代币'), findsOneWidget);
      expect(_key('loop-empty-illustration-launchpad'), findsOneWidget);
      await tester.tap(_key('meme-empty-create'));
      expect(opened.single, '/meme/create');
      await _drain(tester);
    });

    testWidgets('a closed capability is one inline line, no request', (
      tester,
    ) async {
      final meme = _FakeMeme();
      await _pump(
        tester,
        const MemeScreen(),
        meme: meme,
        meta: _meta(meme: LoopV2CapabilityAvailability.unavailable),
      );
      expect(_key('meme-launchpad-unavailable'), findsOneWidget);
      expect(find.textContaining('发射台合约还没有配置'), findsOneWidget);
      expect(meme.listCalls, isEmpty);
      final create = tester.widget<LoopButton>(_key('meme-create-entry'));
      expect(create.onPressed, isNull);
      await _drain(tester);
    });

    for (final (name, answer, key)
        in <(String, _Answer<MemeTokenPage>, String)>[
          (
            'loading',
            const _Answer<MemeTokenPage>.pending(),
            'meme-list-new-loading',
          ),
          (
            'error',
            const _Answer<MemeTokenPage>.fail(LoopChainFailureKind.invalidData),
            'meme-list-new-state-error',
          ),
          (
            'offline',
            const _Answer<MemeTokenPage>.fail(LoopChainFailureKind.offline),
            'meme-list-new-state-offline',
          ),
          (
            'permission',
            const _Answer<MemeTokenPage>.fail(
              LoopChainFailureKind.permissionDenied,
            ),
            'meme-list-new-state-permission',
          ),
          (
            'unavailable',
            const _Answer<MemeTokenPage>.fail(LoopChainFailureKind.unavailable),
            'meme-list-new-unavailable',
          ),
        ]) {
      testWidgets('the list states $name', (tester) async {
        final meme = _FakeMeme(list: (tab, cursor) => answer);
        await _pump(
          tester,
          const MemeScreen(),
          meme: meme,
          settle: name != 'loading',
        );
        await tester.pump();
        expect(_key(key), findsOneWidget);
        await _drain(tester);
      });
    }

    testWidgets('the list reads the next page when its end shows', (
      tester,
    ) async {
      final meme = _FakeMeme(
        list: (tab, cursor) => _Answer<MemeTokenPage>.value(
          cursor == null
              ? memePage(nextCursor: 'page.two')
              : memePage(
                  items: <Map<String, Object?>>[
                    memeRowJson(id: memeTokenIdB, name: 'Toad', symbol: 'TOAD'),
                  ],
                ),
        ),
      );
      await _pump(tester, const MemeScreen(), meme: meme);
      // The 「快打满」 strip reads its own list once (decision 0122); the
      // chip's list reads on page by page.
      expect(
        meme.listCalls.where((call) => call.$1 == MemeListTab.fresh),
        <(MemeListTab, String?)>[
          (MemeListTab.fresh, null),
          (MemeListTab.fresh, 'page.two'),
        ],
      );
      expect(
        meme.listCalls.where((call) => call.$1 == MemeListTab.graduating),
        <(MemeListTab, String?)>[(MemeListTab.graduating, null)],
      );
      expect(find.text('TOAD'), findsOneWidget);
      expect(_key('meme-list-end'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('行情 reads the meme market category', (tester) async {
      final meme = _FakeMeme(
        list: (tab, cursor) => _Answer<MemeTokenPage>.value(memePage()),
      );
      await _pump(tester, const MemeScreen(), meme: meme);
      await tester.tap(_key('meme-segment-1'));
      await tester.pumpAndSettle();
      // Without a market transport the segment says so inline.
      expect(_key('meme-market'), findsOneWidget);
      expect(_key('meme-market-unavailable'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('创建', () {
    MemeTokenDetail draft({bool vanity = true}) => memeDetail(
      status: 'draft',
      vanity: vanity,
      tokenAddress: null,
      price: null,
      quoteUnavailable: 'MEME_TOKEN_NOT_ON_CHAIN',
      curve: memeFreshCurveJson(),
      change: null,
    );

    Future<void> fillProfile(WidgetTester tester) async {
      await tester.enterText(_key('meme-create-name'), 'Frog');
      await tester.enterText(_key('meme-create-symbol'), 'frog');
      await tester.enterText(_key('meme-create-description'), 'ribbit');
      await tester.pump();
    }

    testWidgets('step one refuses an empty name and a bad symbol', (
      tester,
    ) async {
      final meme = _FakeMeme();
      await _pump(tester, const MemeCreateScreen(), meme: meme);
      expect(_key('meme-create-step-1'), findsOneWidget);
      // Decision 0169: the same step track as the v2 发射 flow.
      final track = tester.widget<LoopStepTrack>(_key('meme-create-step-1'));
      expect(track.current, 0);
      expect(track.labels, hasLength(3));
      expect(track.milestones, isFalse);
      await tester.enterText(_key('meme-create-symbol'), 'X');
      await tester.tap(_key('meme-create-next'));
      await tester.pump();
      expect(find.text('名称 1–32 个字'), findsOneWidget);
      expect(find.text('符号 2–10 位字母或数字'), findsOneWidget);
      expect(_key('meme-create-step-1'), findsOneWidget);
      expect(meme.createCalls, isEmpty);
      await _drain(tester);
    });

    testWidgets('three steps: links checked, draft made, no-vanity notice', (
      tester,
    ) async {
      final meme = _FakeMeme(
        createAnswer: _Answer<MemeTokenDetail>.value(draft(vanity: false)),
      );
      await _pump(
        tester,
        const MemeCreateScreen(),
        meme: meme,
        overrides: <Override>[
          avatarImagePickerProvider.overrideWithValue(_Picker()),
        ],
      );
      debugMemeCropOverride = (context, bytes) async => bytes;
      addTearDown(() => debugMemeCropOverride = null);

      await fillProfile(tester);
      await tester.tap(_key('meme-create-next'));
      await tester.pumpAndSettle();
      expect(_key('meme-create-step-2'), findsOneWidget);

      await tester.tap(_key('meme-create-upload'));
      await tester.pumpAndSettle();
      expect(meme.uploads, 1);

      await tester.enterText(_key('meme-create-twitter'), 'http://x.com/frog');
      await tester.tap(_key('meme-create-next'));
      await tester.pump();
      expect(find.text('只支持 https:// 开头的链接'), findsOneWidget);
      expect(meme.createCalls, isEmpty);

      await tester.enterText(_key('meme-create-twitter'), 'https://x.com/frog');
      await tester.tap(_key('meme-create-next'));
      await tester.pumpAndSettle();
      final sent = meme.createCalls.single;
      expect(sent.name, 'Frog');
      expect(sent.symbol, 'FROG');
      expect(sent.imageMediaId, memeMediaId);
      expect(sent.links.twitter, 'https://x.com/frog');

      expect(_key('meme-create-step-3'), findsOneWidget);
      expect(_key('meme-create-no-vanity'), findsOneWidget);
      expect(find.textContaining('本次无法分配 6666 尾号'), findsOneWidget);
      expect(_key('meme-create-predicted'), findsOneWidget);
      expect(find.text('1,000,000,000 枚'), findsOneWidget);
      expect(find.text('800,000,000 枚（80%）'), findsOneWidget);
      expect(find.text('1%'), findsOneWidget);
      expect(find.textContaining('募满约 17,582 USD1'), findsOneWidget);

      // Back and forward again with the same content reuses the draft.
      await tester.tap(find.byTooltip('返回').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      if (find
          .byKey(const ValueKey<String>('meme-create-step-2'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(_key('meme-create-next'));
        await tester.pumpAndSettle();
        expect(meme.createCalls, hasLength(1));
      }
      await _drain(tester);
    });

    testWidgets('the daily limit reads 今天的创建次数用完了，明天再来', (tester) async {
      final meme = _FakeMeme(
        createAnswer: const _Answer<MemeTokenDetail>.fail(
          LoopChainFailureKind.rateLimited,
          reasonCode: 'MEME_CREATE_RATE_LIMITED',
        ),
      );
      await _pump(tester, const MemeCreateScreen(), meme: meme);
      await fillProfile(tester);
      await tester.tap(_key('meme-create-next'));
      await tester.pumpAndSettle();
      await tester.tap(_key('meme-create-next'));
      await tester.pumpAndSettle();
      expect(_key('meme-create-draft-failed'), findsOneWidget);
      expect(find.text('今天的创建次数用完了，明天再来'), findsOneWidget);
      expect(_key('meme-create-step-2'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a first buy over the wallet cap is refused before signing', (
      tester,
    ) async {
      final meme = _FakeMeme(
        createAnswer: _Answer<MemeTokenDetail>.value(draft()),
      );
      await _pump(tester, const MemeCreateScreen(), meme: meme);
      await fillProfile(tester);
      await tester.tap(_key('meme-create-next'));
      await tester.pumpAndSettle();
      await tester.tap(_key('meme-create-next'));
      await tester.pumpAndSettle();
      expect(_key('meme-create-no-vanity'), findsNothing);

      await tester.enterText(_key('meme-create-first-buy'), '10');
      await tester.pump();
      expect(_key('meme-create-first-buy-estimate'), findsOneWidget);
      expect(find.textContaining('约得 1,767,533.'), findsOneWidget);

      await tester.enterText(_key('meme-create-first-buy'), '1000');
      await tester.pump();
      expect(find.textContaining('超过单钱包上限'), findsOneWidget);
      expect(
        tester.widget<LoopButton>(_key('meme-create-submit')).onPressed,
        isNull,
      );

      await tester.enterText(_key('meme-create-first-buy'), '0.5');
      await tester.pump();
      expect(find.textContaining('最少买入'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets(
      '创建 signs the approval first, reports the main hash, opens the token',
      (tester) async {
        final wallet = _RecordingWallet();
        final meme = _FakeMeme(
          createAnswer: _Answer<MemeTokenDetail>.value(draft()),
          prepareAnswer: _Answer<MemeIntent>.value(
            memeIntent(kind: 'create', approval: true),
          ),
          reportAnswer: _Answer<MemeIntent>.value(
            memeIntent(kind: 'create', state: 'broadcast_reported'),
          ),
          intentReads: <_Answer<MemeIntent>>[
            _Answer<MemeIntent>.value(
              memeIntent(kind: 'create', state: 'broadcast_reported'),
            ),
            _Answer<MemeIntent>.value(
              memeIntent(kind: 'create', state: 'confirmed'),
            ),
          ],
        );
        final opened = <String>[];
        await _pump(
          tester,
          MemeCreateScreen(onOpenToken: opened.add),
          meme: meme,
          wallet: wallet,
        );
        await fillProfile(tester);
        await tester.tap(_key('meme-create-next'));
        await tester.pumpAndSettle();
        await tester.tap(_key('meme-create-next'));
        await tester.pumpAndSettle();
        await tester.enterText(_key('meme-create-first-buy'), '10');
        await tester.pump();

        await tester.tap(_key('meme-create-submit'));
        await tester.pumpAndSettle();
        expect(meme.prepareCalls.single, <String, Object?>{
          'memeTokenId': memeTokenIdA,
          'kind': 'create',
          'walletId': memeWalletId,
          'usd1Amount': '10',
          'tokenAmount': null,
          'slippageBps': 100,
        });
        // The shared signing exit, with the approval announced.
        expect(_key('meme-sign-sheet'), findsOneWidget);
        expect(find.byType(LoopSignSheet), findsOneWidget);
        expect(find.text('确认创建'), findsOneWidget);
        expect(find.text('先授权'), findsOneWidget);

        await tester.tap(find.text('确认签名'));
        await tester.pumpAndSettle();
        expect(wallet.handed, hasLength(2));
        expect(wallet.handed.first.kind, IntentKind.launchApproval);
        expect(wallet.handed.last.kind, IntentKind.launchPurchase);
        expect(wallet.handed.first.payloadDigest, isNotNull);
        expect(meme.reportCalls.single, _hash);
        expect(find.text('已广播'), findsOneWidget);

        await tester.tap(find.text('关闭'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        expect(opened, <String>[memeTokenIdA]);
        await _drain(tester);
      },
    );
  });

  group('代币页', () {
    Widget page({void Function(String)? onNavigate}) => MemeTokenScreen(
      memeTokenId: memeTokenIdA,
      onNavigate: onNavigate ?? (_) {},
    );

    _FakeMeme gateway(
      MemeTokenDetail detail, {
      _Answer<MemeQuote>? quote,
      List<_Answer<MemeTokenDetail>>? details,
    }) => _FakeMeme(
      details:
          details ??
          <_Answer<MemeTokenDetail>>[_Answer<MemeTokenDetail>.value(detail)],
      candles: _Answer<MemeCandleSeries>.value(memeCandles()),
      holders: (cursor) => _Answer<MemeHolderPage>.value(
        cursor == null
            ? memeHolders(next: 'holders.two')
            : memeHolders(
                items: <Map<String, Object?>>[
                  memeHolderJson(
                    wallet: '0x000000000000000000000000000000000000000b',
                    isCreator: false,
                    isViewer: false,
                  ),
                ],
              ),
      ),
      trades: (cursor) => _Answer<MemeTradePage>.value(
        cursor == null
            ? memeTrades(
                items: <Map<String, Object?>>[
                  memeTradeJson(),
                  memeTradeJson(txSuffix: '02', isBuy: false),
                ],
                next: 'trades.two',
              )
            : memeTrades(
                items: <Map<String, Object?>>[memeTradeJson(txSuffix: '03')],
              ),
      ),
      quoteAnswer: quote,
    );

    testWidgets('price, 1h move, cap, holding, progress and source lines', (
      tester,
    ) async {
      final meme = gateway(memeDetail());
      await _pump(tester, page(), meme: meme);
      // Decision 0174 · the bar: logo 36 r12, ticker, state badge, name ·
      // address with the copy target; no separate identity line.
      expect(find.text('FROG'), findsOneWidget);
      expect(
        tester.widget<LoopBadge>(_key('meme-token-status-badge')).text,
        '内盘',
      );
      expect(
        tester.widget<LoopBadge>(_key('meme-token-status-badge')).kind,
        LoopBadgeKind.mute,
      );
      expect(find.text('Frog · 0xac42…ca94'), findsOneWidget);
      expect(_key('meme-token-copy-address'), findsOneWidget);
      final logo = tester.widget<MemeLogo>(find.byType(MemeLogo).first);
      expect(logo.size, 36);
      expect(logo.radius, LoopRadius.innerValue);
      // The price head: figure, amount + percentage move, cap on the right.
      final figure = tester.widget<Text>(_key('meme-token-price-figure'));
      expect(figure.style, LoopType.figureXl);
      final change = tester.widget<Text>(_key('meme-token-change'));
      expect(change.data, startsWith(r'▲ $'));
      expect(change.data, endsWith(' (76.89%) · 1h'));
      expect(change.style?.color, LoopColors.rise);
      expect(find.text(r'$9,891'), findsOneWidget);
      expect(find.text('市值'), findsOneWidget);
      expect(
        tester.getCenter(_key('meme-token-cap')).dx,
        greaterThan(tester.getCenter(_key('meme-token-price-figure')).dx),
      );
      expect(_key('meme-token-holding'), findsOneWidget);
      expect(find.textContaining('持有 10 \$FROG'), findsOneWidget);
      // Two stats over the bar; the old paragraph is gone.
      expect(
        find.descendant(
          of: _key('meme-token-stat-progress'),
          matching: find.textContaining('33.27% · 还差 \$'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('meme-token-stat-volume'),
          matching: find.text(r'$1,980'),
        ),
        findsOneWidget,
      );
      final stats = tester.widget<LoopStatGrid>(_key('meme-token-stats'));
      expect(stats.stats, hasLength(2));
      expect(stats.stats.first.tone, LoopStatTone.up);
      // Decision 0169: the family's 6 px `.bar`.
      final bar = tester.widget<LoopProgressBar>(
        _key('meme-token-progress-bar'),
      );
      expect(bar.value, closeTo(0.3327, 1e-9));
      expect(tester.getSize(_key('meme-token-progress-bar')).height, 6);
      expect(find.textContaining('已募'), findsNothing);
      expect(find.text('打满后自动上 PancakeSwap'), findsNothing);
      expect(_key('meme-token-liquidity-low'), findsNothing);
      expect(_key('meme-token-price-provenance'), findsOneWidget);
      expect(find.textContaining('来源 LOOP 曲线'), findsWidgets);
      expect(_key('meme-chart-1m'), findsOneWidget);
      // The holder count is in its tab's title.
      expect(_key('meme-token-tab-持有者 12'), findsOneWidget);
      expect(find.text('持有者 12'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('S187-2 · the chart is full bleed, Lime, with a price tag', (
      tester,
    ) async {
      final meme = gateway(memeDetail());
      await _pump(tester, page(), meme: meme);
      final screen = tester.getSize(find.byType(MemeTokenScreen));
      final chart = tester.widget<LoopMarketChart>(
        find.byType(LoopMarketChart),
      );
      expect(chart.height, memeTokenChartHeight(screen.height));
      expect(chart.lineColor, LoopColors.lime);
      expect(chart.lastPriceTag, isTrue);
      expect(chart.showVolume, isFalse);
      final rect = tester.getRect(_key('loop-market-chart'));
      expect(rect.height, chart.height);
      expect(rect.left, 0);
      expect(rect.width, screen.width);
      // It follows the price head directly.
      expect(
        rect.top,
        greaterThanOrEqualTo(tester.getRect(_key('meme-token-price')).bottom),
      );
      expect(
        rect.top - tester.getRect(_key('meme-token-price')).bottom,
        lessThan(12),
      );
      final tag = _key('loop-market-chart-last-price-tag');
      expect(tag, findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: tag, matching: find.byType(DecoratedBox)),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, LoopColors.lime);
      expect(decoration.borderRadius, LoopRadius.badge);
      final label = tester.widget<Text>(
        find.descendant(of: tag, matching: find.byType(Text)),
      );
      expect(label.style?.color, LoopColors.ink);
      // LIVE / 1H / 4H / 1D quiet chips and K; no ALL.
      for (final label in <String>['LIVE', '1H', '4H', '1D', 'K']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('ALL'), findsNothing);
      expect(tester.widget<LoopSeg>(_key('meme-interval-1m')).selected, isTrue);
      expect(tester.widget<LoopSeg>(_key('meme-interval-1m')).quiet, isTrue);
      await tester.tap(_key('meme-interval-1h'));
      await tester.pumpAndSettle();
      expect(_key('meme-chart-1h'), findsOneWidget);
      await tester.tap(_key('meme-chart-style'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LoopMarketChart>(find.byType(LoopMarketChart)).style,
        LoopChartStyle.candles,
      );
      expect(tester.widget<LoopSeg>(_key('meme-chart-style')).selected, isTrue);
      await _drain(tester);
    });

    test('S187-2 · chart height and the one-hour amount', () {
      expect(memeTokenChartHeight(700), 210);
      expect(memeTokenChartHeight(400), 180);
      expect(memeTokenChartHeight(2000), 260);
      // 110 now after +10%: the price an hour ago was 100.
      expect(
        memeChange1hAmount(Decimal.fromInt(110), Decimal.fromInt(10)),
        Decimal.fromInt(10),
      );
      expect(memeChange1hAmount(null, Decimal.fromInt(10)), isNull);
      expect(memeChange1hAmount(Decimal.one, null), isNull);
      expect(memeChange1hAmount(Decimal.one, Decimal.fromInt(-100)), isNull);
    });

    testWidgets('S187-2 · a thin curve warns that large buys slip', (
      tester,
    ) async {
      final meme = gateway(memeDetail(curve: memeFreshCurveJson()));
      await _pump(tester, page(), meme: meme);
      final notice = tester.widget<LoopNotice>(
        _key('meme-token-liquidity-low'),
      );
      expect(notice.tone, LoopNoticeTone.warn);
      expect(notice.body, startsWith('流动性低 · 内盘储备 \$0'));
      expect(notice.body, endsWith('大额买入滑点高'));
      await _drain(tester);
    });

    testWidgets('S187-2 · without a price the move is the percentage only', (
      tester,
    ) async {
      final meme = gateway(
        memeDetail(price: null, quoteUnavailable: 'MEME_DEX_QUOTE_UNAVAILABLE'),
      );
      await _pump(tester, page(), meme: meme);
      expect(_key('meme-token-price-unavailable'), findsOneWidget);
      expect(find.text('外盘行情暂时取不到'), findsOneWidget);
      expect(find.text('▲ 76.89% · 1h'), findsOneWidget);
      expect(_key('meme-token-cap'), findsNothing);
      await _drain(tester);
    });

    for (final (status, key, label) in <(String, String, String)>[
      ('full', 'meme-token-full', '打满，毕业中…'),
      ('paused', 'meme-token-paused', '已暂停交易'),
      ('pending_chain', 'meme-token-pending', '创建中…'),
    ]) {
      testWidgets('the bottom bar for $status is disabled: $label', (
        tester,
      ) async {
        final meme = gateway(memeDetail(status: status));
        await _pump(tester, page(), meme: meme, settle: false);
        await tester.pump(const Duration(milliseconds: 10));
        expect(_key(key), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        expect(tester.widget<LoopButton>(_key(key)).onPressed, isNull);
        expect(_key('meme-token-buy'), findsNothing);
        await _drain(tester);
      });
    }

    testWidgets('trading shows 买入, 快买 and, while held, 卖出', (tester) async {
      final meme = gateway(memeDetail());
      await _pump(tester, page(), meme: meme);
      expect(_key('meme-token-buy'), findsOneWidget);
      expect(_key('meme-token-sell'), findsOneWidget);
      expect(_key('meme-token-quick-buy'), findsOneWidget);
      // Decision 0174: one full-Lime body in the bar — 买入.
      final bar = _key('loop-page-bottom-bar');
      expect(
        find.descendant(
          of: bar,
          matching: find.byKey(const ValueKey<String>('loop-button-primary')),
        ),
        findsOneWidget,
      );
      expect(tester.widget<LoopButton>(_key('meme-token-buy')).primary, isTrue);
      expect(
        tester.widget<LoopButton>(_key('meme-token-sell')).primary,
        isFalse,
      );
      final quick = tester.widget<Material>(
        _key('meme-token-quick-buy-surface'),
      );
      expect(quick.color, LoopColors.card2);
      expect(tester.getSize(_key('meme-token-quick-buy')).width, 52);
      final bolt = tester.widget<LoopIcon>(
        find.descendant(
          of: _key('meme-token-quick-buy'),
          matching: find.byType(LoopIcon),
        ),
      );
      expect(bolt.name, 'bolt');
      expect(bolt.color, LoopColors.chalk);
      expect(
        tester.getCenter(_key('meme-token-quick-buy')).dx,
        greaterThan(tester.getCenter(_key('meme-token-buy')).dx),
      );
      await _drain(tester);

      // Nothing held: no 卖出 in the bar (the panel still has its side).
      final empty = gateway(memeDetail(viewer: memeViewerJson(balance: '0')));
      await _pump(tester, page(), meme: empty);
      expect(_key('meme-token-sell'), findsNothing);
      expect(_key('meme-token-buy'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets(
      'S187-2 · 快买 opens the buy panel at 10 USD1 and remembers the amount',
      (tester) async {
        final wallet = _RecordingWallet();
        final meme =
            gateway(memeDetail(), quote: _Answer<MemeQuote>.value(memeQuote()))
              ..prepareAnswer = _Answer<MemeIntent>.value(memeIntent())
              ..reportAnswer = _Answer<MemeIntent>.value(
                memeIntent(state: 'broadcast_reported'),
              );
        await _pump(tester, page(), meme: meme, wallet: wallet);
        await tester.tap(_key('meme-token-quick-buy'));
        await tester.pumpAndSettle();
        // The pre-filled amount waits the same debounce a typed one does.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.text(r'买入 $FROG'), findsOneWidget);
        expect(
          tester.widget<TextField>(_key('meme-trade-amount')).controller!.text,
          '10',
        );
        // Quoted like a typed amount; nothing is prepared before 确认买入.
        expect(meme.quoteCalls.single, (MemeTradeSide.buy, '10', memeWalletId));
        expect(meme.prepareCalls, isEmpty);
        await tester.enterText(_key('meme-trade-amount'), '25');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await tester.tap(_key('meme-trade-confirm'));
        await tester.pumpAndSettle();
        // The same exit as 买入: one prepared intent, the signing sheet.
        expect(meme.prepareCalls.single['usd1Amount'], '25');
        expect(_key('meme-sign-sheet'), findsOneWidget);
        await tester.tap(find.text('确认签名'));
        await tester.pumpAndSettle();
        expect(wallet.handed, hasLength(1));
        // The amount just confirmed is what 快买 offers next.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MemeTokenScreen)),
        );
        expect(container.read(memeQuickBuyAmountProvider), '25');
        await _drain(tester);
      },
    );

    testWidgets('S187-2 · 快买 pre-fills the last amount used', (tester) async {
      final meme = gateway(
        memeDetail(),
        quote: _Answer<MemeQuote>.value(memeQuote()),
      );
      await _pump(
        tester,
        page(),
        meme: meme,
        overrides: <Override>[
          memeQuickBuyAmountProvider.overrideWith(_RememberedAmount.new),
        ],
      );
      await tester.tap(_key('meme-token-quick-buy'));
      await tester.pumpAndSettle();
      // The pre-filled amount waits the same debounce a typed one does.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(
        tester.widget<TextField>(_key('meme-trade-amount')).controller!.text,
        '42',
      );
      expect(meme.quoteCalls.single.$2, '42');
      await _drain(tester);
    });

    testWidgets(
      'graduated on the testnet: no in-app swap, the pool is offered',
      (tester) async {
        final opened = <String>[];
        final meme = gateway(
          memeDetail(
            status: 'graduated',
            graduation: memeGraduationJson(),
            price: null,
            quoteUnavailable: 'MEME_DEX_CHAIN_NOT_PRICED',
            change: null,
          ),
        );
        await _pump(tester, page(onNavigate: opened.add), meme: meme);
        expect(find.text('100% · 已毕业'), findsOneWidget);
        expect(
          tester.widget<LoopProgressBar>(_key('meme-token-progress-bar')).value,
          1,
        );
        expect(
          tester.widget<LoopBadge>(_key('meme-token-status-badge')).text,
          '已毕业',
        );
        expect(find.text('暂无外盘报价'), findsOneWidget);
        // S118: the testnet has no in-app swap.
        expect(_key('meme-token-swap'), findsNothing);
        expect(_key('meme-token-swap-testnet'), findsOneWidget);
        expect(find.text('测试网不支持站内兑换'), findsOneWidget);
        expect(_key('meme-token-copy-pool'), findsOneWidget);
        expect(opened, isEmpty);
        await _drain(tester);
      },
    );

    testWidgets('graduated on the main chain: 去兑换 pre-fills Swap', (
      tester,
    ) async {
      final opened = <String>[];
      final meme = gateway(
        memeDetail(
          status: 'graduated',
          graduation: memeGraduationJson(),
          mainnet: true,
          priceSource: 'pool_slot0',
          change: null,
        ),
      );
      await _pump(tester, page(onNavigate: opened.add), meme: meme);
      expect(find.textContaining('来源 池子推算'), findsWidgets);
      await tester.tap(_key('meme-token-swap'));
      expect(opened.single, '/wallet/swap?to=eip155%3A56%3A$memeTokenAddress');
      await _drain(tester);
    });

    testWidgets('a full curve is re-read until it graduates, marked once', (
      tester,
    ) async {
      final meme = gateway(
        memeDetail(status: 'full', progressBps: 10000),
        details: <_Answer<MemeTokenDetail>>[
          _Answer<MemeTokenDetail>.value(
            memeDetail(status: 'full', progressBps: 10000),
          ),
          _Answer<MemeTokenDetail>.value(
            memeDetail(
              status: 'graduated',
              progressBps: 10000,
              graduation: memeGraduationJson(),
            ),
          ),
        ],
      );
      await _pump(tester, page(), meme: meme, settle: false);
      await tester.pump(const Duration(milliseconds: 10));
      expect(_key('meme-token-full'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 400));
      expect(meme.detailReads, greaterThanOrEqualTo(2));
      expect(_key('meme-token-swap-testnet'), findsOneWidget);
      expect(_key('meme-token-graduated-banner'), findsOneWidget);
      await tester.tap(_key('meme-token-graduated-close'));
      await tester.pump();
      expect(_key('meme-token-graduated-banner'), findsNothing);
      await _drain(tester);
    });

    for (final (name, answer, key)
        in <(String, _Answer<MemeTokenDetail>, String)>[
          (
            'loading',
            const _Answer<MemeTokenDetail>.pending(),
            'meme-token-state-loading',
          ),
          (
            'error',
            const _Answer<MemeTokenDetail>.fail(
              LoopChainFailureKind.notFound,
              reasonCode: 'MEME_TOKEN_NOT_FOUND',
            ),
            'meme-token-state-error',
          ),
          (
            'offline',
            const _Answer<MemeTokenDetail>.fail(LoopChainFailureKind.offline),
            'meme-token-state-offline',
          ),
          (
            'permission',
            const _Answer<MemeTokenDetail>.fail(
              LoopChainFailureKind.permissionDenied,
            ),
            'meme-token-state-permission',
          ),
          (
            'unavailable',
            const _Answer<MemeTokenDetail>.fail(
              LoopChainFailureKind.unavailable,
            ),
            'meme-token-state-unavailable',
          ),
        ]) {
      testWidgets('the token page states $name', (tester) async {
        final meme = _FakeMeme(details: <_Answer<MemeTokenDetail>>[answer]);
        await _pump(tester, page(), meme: meme, settle: name != 'loading');
        await tester.pump();
        expect(_key(key), findsOneWidget);
        expect(_key('meme-token-buy'), findsNothing);
        await _drain(tester);
      });
    }

    testWidgets('a malformed id fails closed without a request', (
      tester,
    ) async {
      final meme = _FakeMeme();
      await _pump(
        tester,
        const MemeTokenScreen(memeTokenId: 'nope'),
        meme: meme,
      );
      expect(_key('meme-token-invalid-identity'), findsOneWidget);
      expect(meme.detailReads, 0);
      await _drain(tester);
    });

    testWidgets('holders read on, with creator / me and the frozen note', (
      tester,
    ) async {
      final meme = gateway(memeDetail());
      await _pump(tester, page(), meme: meme);
      expect(meme.holderCalls, <String?>[null, 'holders.two']);
      expect(find.text('创建者'), findsOneWidget);
      expect(find.text('我'), findsOneWidget);
      expect(find.text('10%'), findsWidgets);
      expect(_key('meme-holders-end'), findsOneWidget);
      await _drain(tester);

      final frozen = gateway(memeDetail(status: 'graduated'))
        ..holders = (cursor) => _Answer<MemeHolderPage>.value(
          memeHolders(frozenAt: '2026-10-08T05:00:00.000Z'),
        );
      await _pump(tester, page(), meme: frozen);
      expect(find.textContaining('分布冻结于毕业时'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('动态 reads on; a buy and a sell take rise and fall', (
      tester,
    ) async {
      final meme = gateway(memeDetail());
      await _pump(tester, page(), meme: meme);
      await tester.tap(_key('meme-token-tab-动态'));
      await tester.pumpAndSettle();
      expect(meme.tradeCalls, <String?>[null, 'trades.two']);
      final buy = tester.widget<Text>(_key('meme-trade-side-buy').first);
      final sell = tester.widget<Text>(_key('meme-trade-side-sell'));
      expect(buy.style?.color, const Color(0xFF22C55E));
      expect(sell.style?.color, const Color(0xFFEF4444));
      expect(_key('meme-trades-end'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('the buy panel quotes, and a cap is said before signing', (
      tester,
    ) async {
      final meme = gateway(
        memeDetail(),
        quote: _Answer<MemeQuote>.value(memeQuote(walletCapHit: true)),
      );
      await _pump(tester, page(), meme: meme);
      await tester.tap(_key('meme-token-buy'));
      await tester.pumpAndSettle();
      expect(_key('meme-trade-panel'), findsOneWidget);
      await tester.enterText(_key('meme-trade-amount'), '10');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(meme.quoteCalls.single, (MemeTradeSide.buy, '10', memeWalletId));
      expect(_key('meme-trade-quote'), findsOneWidget);
      expect(find.text('影响'), findsOneWidget);
      expect(find.text('0.24%'), findsOneWidget);
      expect(_key('meme-trade-blocking'), findsOneWidget);
      // Decision 0169: a warn `.notice`, not warning-yellow words.
      expect(
        tester.widget<LoopNotice>(_key('meme-trade-blocking')).tone,
        LoopNoticeTone.warn,
      );
      expect(find.textContaining('超过单钱包上限'), findsOneWidget);
      expect(
        tester.widget<LoopButton>(_key('meme-trade-confirm')).onPressed,
        isNull,
      );
      await _drain(tester);
    });

    testWidgets('S123e · one sheet, and 确认买入 is lifted above the keypad', (
      tester,
    ) async {
      final meme = gateway(
        memeDetail(),
        quote: _Answer<MemeQuote>.value(memeQuote()),
      );
      await _pump(tester, page(), meme: meme);
      await tester.tap(_key('meme-token-buy'));
      await tester.pumpAndSettle();
      // Decision 0131: showLoopSheet draws the one surface; the panel adds
      // none of its own.
      expect(find.byType(LoopSheet), findsOneWidget);
      expect(find.text(r'买入 $FROG'), findsOneWidget);
      // A phone-sized screen with a 340pt keypad up, as on the device in
      // audit 2026-10-09 73b.
      final ratio = tester.view.devicePixelRatio;
      tester.view.physicalSize = Size(390 * ratio, 760 * ratio);
      addTearDown(tester.view.resetPhysicalSize);
      final keypad = 340 * ratio;
      tester.view.viewInsets = FakeViewPadding(bottom: keypad);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(_key('meme-trade-amount'), '10');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(_key('meme-trade-quote'), findsOneWidget);
      final visibleBottom =
          (tester.view.physicalSize.height - keypad) /
          tester.view.devicePixelRatio;
      final confirm = tester.getRect(_key('meme-trade-confirm'));
      expect(confirm.bottom, lessThanOrEqualTo(visibleBottom + 0.5));
      await _drain(tester);
    });

    testWidgets('S187-2 · the chart periods sit under the chart', (
      tester,
    ) async {
      final meme = gateway(memeDetail());
      await _pump(tester, page(), meme: meme);
      final strip = tester.getTopLeft(_key('meme-interval-strip')).dy;
      final chart = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('meme-chart-') &&
            key.value != 'meme-chart-style' &&
            key.value != 'meme-chart-section';
      });
      expect(chart, findsWidgets);
      expect(strip, greaterThan(tester.getBottomLeft(chart.first).dy - 1));
      await _drain(tester);
    });

    testWidgets('25% fills from the balance; 确认买入 goes to the signing exit', (
      tester,
    ) async {
      final wallet = _RecordingWallet();
      final meme =
          gateway(memeDetail(), quote: _Answer<MemeQuote>.value(memeQuote()))
            ..prepareAnswer = _Answer<MemeIntent>.value(memeIntent())
            ..reportAnswer = _Answer<MemeIntent>.value(
              memeIntent(state: 'broadcast_reported'),
            );
      await _pump(tester, page(), meme: meme, wallet: wallet);
      await tester.tap(_key('meme-token-buy'));
      await tester.pumpAndSettle();
      await tester.tap(_key('meme-trade-fill-25'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      // 25% of 1,000 USD1, printed at display precision (decision 0121).
      expect(
        tester.widget<TextField>(_key('meme-trade-amount')).controller!.text,
        '250.00',
      );
      expect(meme.quoteCalls.single.$2, '250');
      await tester.tap(_key('meme-trade-slippage-300'));
      await tester.pump();
      await tester.tap(_key('meme-trade-confirm'));
      await tester.pumpAndSettle();
      expect(meme.prepareCalls.single['kind'], 'buy');
      expect(meme.prepareCalls.single['usd1Amount'], '250');
      expect(meme.prepareCalls.single['slippageBps'], 300);
      expect(_key('meme-sign-sheet'), findsOneWidget);
      expect(find.text('确认买入'), findsOneWidget);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.single.kind, IntentKind.launchPurchase);
      expect(meme.reportCalls.single, _hash);
      expect(find.text('已广播'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a chart with one candle says 「还没有成交」 and nothing else', (
      tester,
    ) async {
      final meme = gateway(memeDetail())
        ..candles = _Answer<MemeCandleSeries>.value(memeCandles(count: 1));
      await _pump(tester, page(), meme: meme);
      expect(_key('meme-chart-empty'), findsOneWidget);
      expect(find.text('还没有成交'), findsOneWidget);
      expect(find.textContaining('画不出走势'), findsNothing);
      expect(find.textContaining('补 0'), findsNothing);
      await _drain(tester);
    });

    test('a shortcut prints two decimals and never rounds up', () {
      BigInt raw(String units) => memeRawFromInput(units)!;
      expect(memeFillText(raw('250')), '250.00');
      expect(memeFillText(raw('10.129999999999999999')), '10.12');
      expect(memeFillText(raw('0.004')), '0.00');
      expect(memeFillText(raw('123456789012.5')), '123456789012.50');
    });

    testWidgets('100% shows two decimals and sells the exact holding', (
      tester,
    ) async {
      // Decision 0121: the field reads 「3.14」 while the quote and the
      // request carry every one of the 18 decimals held.
      const held = '3141592653589793238';
      final meme = gateway(
        memeDetail(viewer: memeViewerJson(balance: held)),
        quote: _Answer<MemeQuote>.value(memeQuote(side: 'sell')),
      );
      await _pump(tester, page(), meme: meme);
      await tester.tap(_key('meme-token-sell'));
      await tester.pumpAndSettle();
      // Four `.seg` shortcuts in one row (decision 0169; were outlined
      // pills, decision 0121). An action, so never drawn selected.
      final fills = <Rect>[
        for (final percent in <int>[25, 50, 75, 100])
          tester.getRect(_key('meme-trade-fill-$percent')),
      ];
      expect(fills.map((rect) => rect.top).toSet(), hasLength(1));
      expect(fills.first.height, greaterThanOrEqualTo(44));
      for (final percent in <int>[25, 50, 75, 100]) {
        final seg = tester.widget<LoopSeg>(_key('meme-trade-fill-$percent'));
        expect(seg.selected, isFalse);
        expect(seg.block, isTrue);
        expect(seg.onSelected, isNotNull);
      }
      await tester.tap(_key('meme-trade-fill-100'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final field = tester.widget<TextField>(_key('meme-trade-amount'));
      expect(field.controller!.text, '3.14');
      expect(field.maxLines, 1);
      expect(meme.quoteCalls.single.$2, '3.141592653589793238');
      expect(find.text('卖出数量超过持有'), findsNothing);

      // Typing over the shortcut sends what was typed.
      await tester.enterText(_key('meme-trade-amount'), '3.1');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(meme.quoteCalls.last.$2, '3.1');
      await _drain(tester);
    });

    testWidgets('the sell panel never asks for more than is held', (
      tester,
    ) async {
      final meme = gateway(
        memeDetail(),
        quote: _Answer<MemeQuote>.value(memeQuote(side: 'sell')),
      );
      await _pump(tester, page(), meme: meme);
      await tester.tap(_key('meme-token-sell'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('meme-trade-amount'), '11');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('卖出数量超过持有'), findsOneWidget);
      expect(
        tester.widget<LoopButton>(_key('meme-trade-confirm')).onPressed,
        isNull,
      );
      await _drain(tester);
    });
  });

  group('full lists', () {
    testWidgets('meme-token-holders reads on its own page', (tester) async {
      final meme = _FakeMeme(
        details: <_Answer<MemeTokenDetail>>[
          _Answer<MemeTokenDetail>.value(memeDetail()),
        ],
        holders: (cursor) => _Answer<MemeHolderPage>.value(memeHolders()),
      );
      await _pump(
        tester,
        const MemeTokenListScreen(memeTokenId: memeTokenIdA, holders: true),
        meme: meme,
      );
      expect(find.text(r'$FROG · 持有者'), findsOneWidget);
      expect(find.text('12 个持有者 · 按曲线买卖统计'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('meme-token-trades reads on its own page', (tester) async {
      final meme = _FakeMeme(
        details: <_Answer<MemeTokenDetail>>[
          _Answer<MemeTokenDetail>.value(memeDetail()),
        ],
        trades: (cursor) => _Answer<MemeTradePage>.value(memeTrades()),
      );
      await _pump(
        tester,
        const MemeTokenListScreen(memeTokenId: memeTokenIdA, holders: false),
        meme: meme,
      );
      expect(find.text(r'$FROG · 动态'), findsOneWidget);
      expect(_key('meme-trade-side-buy'), findsOneWidget);
      await _drain(tester);
    });
  });
}

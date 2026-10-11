import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_screen.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

import 'support/launch2_fixtures.dart';

// ---------------------------------------------------------------------------
// S150 · MEME v2 follow-ups (client decision 0148)
// ---------------------------------------------------------------------------
//
// The samples under `test/fixtures/s150-launch2/` and `l2HoldingJson` are
// handwritten from loop-api S150-api (Decision 0126, OpenAPI at fada8be); each file carries `_handwritten`.

const String _requestId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
const String _txHash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';

Map<String, Object?> _record(String dir, String name) =>
    jsonDecode(File('test/fixtures/$dir/$name.json').readAsStringSync())
        as Map<String, Object?>;

Map<String, Object?> _copy(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

Launch2PoolPrepared _prepared(String dir, String name) =>
    LoopV2Launch2PoolCodec.prepared(
      _record(dir, name)['body'],
      instanceId: l2InstanceA,
      side: Launch2Side.buy,
      mode: Launch2PoolMode.exactIn,
      walletId: l2WalletId,
    );

Launch2Intent _reviewed() =>
    _prepared('s146-launch2-pool', 'pool_prepare_buy_approval').intent;

Launch2Intent _fresh([String name = 'pool_prepare_buy_ready']) =>
    _prepared('s150-launch2', name).intent;

Map<String, Object?> _detailWith(Map<String, Object?> viewer) =>
    l2DetailJson(stage: 'graduated', noNextChange: true, viewer: viewer);

Launch2InstanceDetail _decode(Map<String, Object?> json) =>
    LoopV2Launch2Codec.detail(json, mediaUrl: (_) => null);

final class _ScriptAdapter implements HttpClientAdapter {
  _ScriptAdapter(this.responses);

  final List<(int, Object?)> responses;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A wallet that answers every hand-off and may move the clock.
final class _Wallet implements WalletSigningGateway {
  _Wallet({this.onHandoff});

  final void Function(SigningIntent intent)? onHandoff;
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
    onHandoff?.call(intent);
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return const WalletHandoffResult(
      accepted: true,
      code: 'wallet_accepted',
      value: _txHash,
    );
  }
}

/// Answers the list reads only.
final class _ListGateway implements Launch2Gateway {
  _ListGateway(this.pages);

  final List<Launch2InstancePage> pages;
  final List<String?> cursors = <String?>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) async {
    cursors.add(cursor);
    return pages.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> _row(String id, {int sold = 2}) =>
    l2RowJson(instanceId: id, soldCount: '$sold');

void main() {
  group('codec · viewer / positions holding group (S150-api)', () {
    test('a read balance decodes with its block and own pool count', () {
      final detail = _decode(
        _detailWith(l2ViewerJson(holding: l2HoldingJson())),
      );
      final holding = detail.viewer!.holding!;
      expect(holding.status, Launch2BalanceStatus.available);
      expect(holding.memeBalance, Decimal.parse('7333.18'));
      expect(holding.usd1Balance, Decimal.parse('195'));
      expect(holding.blockNumber, BigInt.from(1530));
      expect(holding.poolTradeCount, BigInt.one);
      expect(holding.lastPoolTradeAt, DateTime.utc(2027, 1, 20, 6, 50));
      expect(holding.balancesRead, isTrue);
    });

    test('not graduated and unavailable carry no balances; an older server '
        'sends no group at all', () {
      final curve = _decode(
        _detailWith(
          l2ViewerJson(holding: l2HoldingJson(status: 'not_graduated')),
        ),
      ).viewer!.holding!;
      expect(curve.status, Launch2BalanceStatus.notGraduated);
      expect(curve.memeBalance, isNull);
      final failed = _decode(
        _detailWith(
          l2ViewerJson(holding: l2HoldingJson(status: 'unavailable')),
        ),
      ).viewer!.holding!;
      expect(failed.reasonCode, 'LAUNCH2_CHAIN_READ_FAILED');
      expect(_decode(_detailWith(l2ViewerJson())).viewer!.holding, isNull);
    });

    test('half a group, a balance without its status, or an unknown status '
        'is refused', () {
      void refuses(void Function(Map<String, Object?> holding) edit) {
        final viewer = l2ViewerJson(holding: l2HoldingJson());
        edit(viewer);
        expect(
          () => _decode(_detailWith(viewer)),
          throwsA(isA<LoopBackendFailure>()),
        );
      }

      refuses((v) => v.remove('poolTradeCount'));
      refuses((v) => v['memeBalance'] = null);
      refuses((v) => v['balanceStatus'] = 'not_graduated');
      refuses((v) => v['balanceStatus'] = 'maybe');
      refuses((v) => v['balanceBlockNumber'] = null);
      refuses((v) => v['balanceReasonCode'] = 'LAUNCH2_CHAIN_READ_FAILED');
      refuses((v) => v['extra'] = 1);
    });

    test('positions carry the same group, optional', () {
      final read = l2Positions(stage: 'graduated', holding: l2HoldingJson());
      expect(read.items.single.holding!.memeBalance, Decimal.parse('7333.18'));
      expect(l2Positions().items.single.holding, isNull);
      final half = l2PositionsJson(holding: l2HoldingJson());
      ((half['positions']! as List<Object?>).single! as Map<String, Object?>)
          .remove('usd1Balance');
      expect(
        () => LoopV2Launch2Codec.positions(half, mediaUrl: (_) => null),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('codec + transport · pool/trades', () {
    Map<String, Object?> body() =>
        _copy(_record('s150-launch2', 'pool_trades')['body']);

    test('the wallet\'s own trades decode newest first', () {
      final trades = LoopV2Launch2PoolCodec.trades(
        body(),
        instanceId: l2InstanceA,
        walletId: l2WalletId,
      );
      expect(trades.poolTradeCount, BigInt.two);
      expect(trades.trades.map((t) => t.side).toList(), <Launch2Side>[
        Launch2Side.sell,
        Launch2Side.buy,
      ]);
      final sell = trades.trades.first;
      expect(sell.amountOut, Decimal.parse('1.3032'));
      expect(sell.taxToken, Launch2PoolTaxToken.usd1);
      expect(
        launch2PoolTradeFigure(sell, 'FROG'),
        r'2,000 $FROG · 得 1.3032 USD1',
      );
      expect(
        launch2PoolTradeFigure(trades.trades.last, 'FROG'),
        r'7,333.18 $FROG · 付 5 USD1',
      );
    });

    test('another wallet, a buy taxed in USD1, a wrong token pair or an '
        'unknown key is refused', () {
      void refuses(void Function(Map<String, Object?> root) edit) {
        final root = body();
        edit(root);
        expect(
          () => LoopV2Launch2PoolCodec.trades(
            root,
            instanceId: l2InstanceA,
            walletId: l2WalletId,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      }

      Map<String, Object?> buy(Map<String, Object?> root) =>
          (root['trades']! as List<Object?>).last! as Map<String, Object?>;

      refuses((r) => r['walletId'] = '00000000-0000-4000-8000-000000000001');
      refuses((r) => buy(r)['taxToken'] = 'usd1');
      refuses((r) => buy(r)['inputToken'] = 'meme');
      refuses((r) => buy(r)['extra'] = 1);
      refuses((r) => r.remove('lastPoolTradeAt'));
    });

    test(
      'GET …/pool/trades asks walletId and limit; 503 keeps its reason',
      () async {
        final adapter = _ScriptAdapter(<(int, Object?)>[
          (200, _record('s150-launch2', 'pool_trades')['body']),
          (
            503,
            <String, Object?>{
              'code': 'CAPABILITY_UNAVAILABLE',
              'category': 'availability',
              'retryable': true,
              'userMessageKey': 'errors.launch2.pool',
              'correlationId': _requestId,
              'detailsSafe': <String, Object?>{
                'reasonCode': 'LAUNCH2_CHAIN_READ_FAILED',
              },
              'providerReferenceSafe': null,
            },
          ),
        ]);
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter;
        final api = DioLoopV2Launch2Api(dio, mediaUrl: (_) => null);
        final trades = await api.getPoolTrades(
          accessToken: 'token',
          clientVersion: '1.0.0',
          instanceId: l2InstanceA,
          walletId: l2WalletId,
          limit: launch2PoolTradesShown,
        );
        expect(trades.trades, hasLength(2));
        final sent = adapter.requests.single;
        expect(sent.method, 'GET');
        expect(sent.path, '/v2/launch2/instances/$l2InstanceA/pool/trades');
        expect(sent.queryParameters, <String, Object?>{
          'walletId': l2WalletId,
          'limit': '5',
        });
        await expectLater(
          api.getPoolTrades(
            accessToken: 'token',
            clientVersion: '1.0.0',
            instanceId: l2InstanceA,
            walletId: l2WalletId,
            limit: 5,
          ),
          throwsA(
            isA<LoopBackendFailure>()
                .having((f) => f.statusCode, 'status', 503)
                .having(
                  (f) => f.detailsSafe?.reasonCode,
                  'reason',
                  'LAUNCH2_CHAIN_READ_FAILED',
                ),
          ),
        );
        await expectLater(
          api.getPoolTrades(
            accessToken: 'token',
            clientVersion: '1.0.0',
            instanceId: l2InstanceA,
            walletId: l2WalletId,
            limit: 51,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );
  });

  group('list refresh (decision 0148)', () {
    test('refreshHead lays a fresh first page over the deeper rows', () {
      const a = '1b2c3d4e-5f60-4a7b-8c9d-0e1f2a3b4c5d';
      const b = '2c3d4e5f-6071-4b8c-9d0e-1f2a3b4c5d6e';
      const c = '3d4e5f60-7182-4c9d-8e0f-2a3b4c5d6e7f';
      final scrolled = l2Page(<Map<String, Object?>>[
        _row(a),
        _row(b),
      ], next: 'page.2').append(l2Page(<Map<String, Object?>>[_row(c)]));
      final head = l2Page(<Map<String, Object?>>[
        _row(b, sold: 9),
        _row(a),
      ], next: 'page.2b');
      final merged = scrolled.refreshHead(head);
      expect(merged.items.map((r) => r.instanceId).toList(), <String>[b, a, c]);
      expect(merged.items.first.nftSale.soldCount, BigInt.from(9));
      expect(merged.nextCursor, scrolled.nextCursor);
      // A head that is the whole list replaces it.
      final whole = l2Page(<Map<String, Object?>>[_row(a)]);
      expect(scrolled.refreshHead(whole).items, hasLength(1));
    });

    test('the controller keeps the rows scrolled to on a refresh and starts '
        'over on a pull', () async {
      const a = '1b2c3d4e-5f60-4a7b-8c9d-0e1f2a3b4c5d';
      const c = '3d4e5f60-7182-4c9d-8e0f-2a3b4c5d6e7f';
      final gateway = _ListGateway(<Launch2InstancePage>[
        l2Page(<Map<String, Object?>>[_row(a)], next: 'page.2'),
        l2Page(<Map<String, Object?>>[_row(c)]),
        l2Page(<Map<String, Object?>>[_row(a, sold: 3)], next: 'page.2'),
        l2Page(<Map<String, Object?>>[_row(a, sold: 4)], next: 'page.2'),
      ]);
      final container = ProviderContainer(
        overrides: [launch2GatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final provider = launch2ListControllerProvider(Launch2ListScope.all);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final controller = container.read(provider.notifier);
      await controller.load();
      await controller.loadMore();
      expect(container.read(provider).value!.items, hasLength(2));
      await controller.refresh();
      final refreshed = container.read(provider).value!;
      expect(refreshed.items.map((r) => r.instanceId).toList(), <String>[a, c]);
      expect(refreshed.items.first.nftSale.soldCount, BigInt.from(3));
      expect(controller.valueObservedAt, isNotNull);
      await controller.reload();
      expect(container.read(provider).value!.items, hasLength(1));
      expect(gateway.cursors, <String?>[null, 'page.2', null, null]);
    });
  });

  group('holding in the pool panel (decision 0148)', () {
    Launch2InstanceDetail detail(Map<String, Object?> holding) =>
        _decode(_detailWith(l2ViewerJson(holding: holding)));

    test('the server balance wins over the quote; the quote is the '
        'fallback', () {
      final quote = _prepared(
        's146-launch2-pool',
        'pool_prepare_buy_approval',
      ).quote;
      final server = detail(l2HoldingJson()).viewer!.holding;
      expect(
        launch2PoolHoldingOf(server: server, quote: quote)!.balance,
        Decimal.parse('7333.18'),
      );
      final unread = detail(l2HoldingJson(status: 'unavailable'))
          .viewer!
          .holding;
      expect(
        launch2PoolHoldingOf(server: unread, quote: quote)!.balance,
        Decimal.fromInt(250000),
      );
      expect(launch2PoolHoldingOf(server: unread), isNull);
    });

    test('before any quote: 持有 / 可卖 from the server, or why not', () {
      Launch2PoolTradeView view(Launch2InstanceDetail d) =>
          launch2PoolTradeView(
            detail: d,
            walletId: l2WalletId,
            side: Launch2Side.sell,
            mode: Launch2PoolMode.exactIn,
            amount: null,
            slippageBps: 100,
            quote: null,
            quoting: false,
            preparing: false,
            locked: false,
            holding: launch2PoolHoldingOf(server: d.viewer?.holding),
          );
      final read = view(detail(l2HoldingJson()));
      expect(read.holdingLine, r'持有 7,333.18 $FROG · 可卖 7,333.18 $FROG');
      expect(read.showMax, isTrue);
      expect(
        view(detail(l2HoldingJson(status: 'unavailable'))).holdingLine,
        '钱包余额暂时读不到 · 报价后显示',
      );
    });
  });

  group('signing exit · refresh after the approval (decision 0148)', () {
    test('refreshRefusal: same trade, no approval, never worse', () {
      final reviewed = _reviewed();
      final now = DateTime.utc(2027, 1, 20, 7, 0, 45);
      expect(
        Launch2IntentSigner.refreshRefusal(
          reviewed,
          _fresh(),
          fromAddress: l2WalletAddress,
          now: now,
        ),
        isNull,
      );
      expect(
        Launch2IntentSigner.refreshRefusal(
          reviewed,
          reviewed,
          fromAddress: l2WalletAddress,
          now: now,
        ),
        launch2RefreshApprovalPendingCode,
      );
      expect(
        Launch2IntentSigner.refreshRefusal(
          reviewed,
          _fresh('pool_prepare_buy_moved'),
          fromAddress: l2WalletAddress,
          now: now,
        ),
        launch2RefreshOutOfRangeCode,
      );
      expect(
        Launch2IntentSigner.refreshRefusal(
          reviewed,
          _fresh(),
          fromAddress: '0x000000000000000000000000000000000000000b',
          now: now,
        ),
        'LAUNCH2_WALLET_ADDRESS_MISMATCH',
      );
      expect(
        Launch2IntentSigner.refreshRefusal(
          reviewed,
          _fresh(),
          fromAddress: l2WalletAddress,
          now: DateTime.utc(2027, 1, 20, 7, 5),
        ),
        'INTENT_EXPIRED',
      );
    });

    test('time left after the approval: the reviewed trade is signed, no '
        'refresh', () async {
      var asked = 0;
      final wallet = _Wallet();
      final outcome = await Launch2IntentSigner(wallet: wallet).sign(
        _reviewed(),
        fromAddress: l2WalletAddress,
        ticker: 'FROG',
        now: l2Now,
        clock: () => l2Now.add(const Duration(seconds: 30)),
        refresh: () async {
          asked += 1;
          return _fresh();
        },
      );
      expect(asked, 0);
      expect(outcome.broadcast, isTrue);
      expect(outcome.refreshed, isNull);
      expect(wallet.handed.last.revision, _reviewed().intentId);
    });

    test('under 20 s left: steps approving → refreshing → signingMain, the '
        'fresh intent is signed and reported', () async {
      var now = l2Now;
      final steps = <Launch2SignStep>[];
      Launch2Intent? told;
      final wallet = _Wallet(
        onHandoff: (intent) {
          if (intent.kind == IntentKind.launchApproval) {
            now = l2Now.add(const Duration(seconds: 41));
          }
        },
      );
      final outcome = await Launch2IntentSigner(wallet: wallet).sign(
        _reviewed(),
        fromAddress: l2WalletAddress,
        ticker: 'FROG',
        now: l2Now,
        clock: () => now,
        onStep: steps.add,
        refresh: () async => _fresh(),
        onRefreshed: (fresh) => told = fresh,
      );
      expect(steps, <Launch2SignStep>[
        Launch2SignStep.approving,
        Launch2SignStep.refreshing,
        Launch2SignStep.signingMain,
      ]);
      expect(outcome.status, MoneySignStatus.submitted);
      expect(outcome.refreshed?.intentId, _fresh().intentId);
      expect(told?.intentId, _fresh().intentId);
      expect(wallet.handed.last.revision, _fresh().intentId);
    });

    test(
      'an approval still pending is asked again, then stops at step 2',
      () async {
        var now = l2Now;
        var asked = 0;
        final wallet = _Wallet(
          onHandoff: (_) => now = l2Now.add(const Duration(seconds: 50)),
        );
        final outcome =
            await Launch2IntentSigner(
              wallet: wallet,
              refreshAttempts: 3,
              refreshRetryDelay: Duration.zero,
            ).sign(
              _reviewed(),
              fromAddress: l2WalletAddress,
              ticker: 'FROG',
              now: l2Now,
              clock: () => now,
              refresh: () async {
                asked += 1;
                return asked < 3 ? _reviewed() : _fresh();
              },
            );
        expect(asked, 3);
        expect(outcome.broadcast, isTrue);

        asked = 0;
        final stuck =
            await Launch2IntentSigner(
              wallet: _Wallet(
                onHandoff: (_) => now = l2Now.add(const Duration(seconds: 50)),
              ),
              refreshAttempts: 2,
              refreshRetryDelay: Duration.zero,
            ).sign(
              _reviewed(),
              fromAddress: l2WalletAddress,
              ticker: 'FROG',
              now: l2Now,
              clock: () => now,
              refresh: () async {
                asked += 1;
                return _reviewed();
              },
            );
        expect(asked, 2);
        expect(stuck.broadcast, isFalse);
        expect(stuck.approvalTxHash, _txHash);
        expect(stuck.reasonCode, launch2RefreshApprovalPendingCode);
        expect(launch2StoppedAtRefresh(stuck), isTrue);
        expect(
          launch2RefreshReasonText(stuck, '买入'),
          contains('授权还在链上确认，买入没有签名'),
        );
      },
    );

    test('a refresh read that fails says why, in the pool catalogue', () async {
      var now = l2Now;
      final outcome =
          await Launch2IntentSigner(
            wallet: _Wallet(
              onHandoff: (_) => now = l2Now.add(const Duration(seconds: 50)),
            ),
          ).sign(
            _reviewed(),
            fromAddress: l2WalletAddress,
            ticker: 'FROG',
            now: l2Now,
            clock: () => now,
            refresh: () => Future<Launch2Intent>.error(
              const LoopChainException(
                LoopChainFailureKind.validationFailed,
                reasonCode: 'POOL_INSUFFICIENT_LIQUIDITY',
              ),
            ),
          );
      expect(outcome.reasonCode, launch2RefreshFailedCode);
      expect(
        launch2RefreshReasonText(outcome, '买入'),
        contains('没有取到新报价（官方池流动性不足'),
      );
    });

    test(
      'without a refresher an expiring intent is signed as before',
      () async {
        final wallet = _Wallet();
        final outcome = await Launch2IntentSigner(wallet: wallet).sign(
          _reviewed(),
          fromAddress: l2WalletAddress,
          ticker: 'FROG',
          now: l2Now.add(const Duration(seconds: 50)),
        );
        expect(outcome.broadcast, isTrue);
        expect(wallet.handed, hasLength(2));
      },
    );

    test('the approval line is the amount alone; the address row names the '
        'spender', () {
      final fields = <String, String>{
        for (final f in launch2IntentFields(_reviewed(), ticker: 'FROG'))
          f.label: f.value,
      };
      expect(fields['先授权'], '100 USD1');
      expect(fields['授权给官方池路由'], isNotNull);
      final ready = <String, String>{
        for (final f in launch2IntentFields(_fresh(), ticker: 'FROG'))
          f.label: f.value,
      };
      expect(ready.containsKey('先授权'), isFalse);
      expect(ready['路由'], isNotNull);
    });
  });

  group('buyback hold in one line (decision 0148)', () {
    Launch2KeeperLine keeper(
      String code, {
      String? next = '2027-01-24T08:00:45.000Z',
    }) => launch2KeeperLine(
      l2Buybacks(
        keeper: l2KeeperJson(reasonCode: code, nextEligibleAt: next),
      ).summary,
    )!;

    test('the same reason from both sources says it once, sources and '
        'time on the second line (decision 0150)', () {
      final legacy = launch2BuybackHeldLine(
        liveBlockedReason: 'BUYBACK_LEGACY_PRICE_PROTECTION',
        keeper: keeper('LAUNCH2_BUYBACK_SPOT_OUTSIDE_PROTECTION'),
      )!;
      expect(legacy.reason, '下一笔暂缓：旧版合约价格保护生效');
      expect(legacy.detail, startsWith('来源：链上读数 · 自动回购 · '));
      expect(legacy.detail, endsWith(' 后再试'));
      final budget = launch2BuybackHeldLine(
        liveBlockedReason: 'BUYBACK_NO_BUDGET',
        keeper: keeper('LAUNCH2_BUYBACK_NO_BUDGET', next: null),
      )!;
      expect(budget.reason, '下一笔暂缓：托管余额不足一笔');
      expect(budget.detail, '来源：链上读数 · 自动回购');
    });

    test('different reasons are both named; a ready read or a running '
        'keeper is no merge', () {
      final both = launch2BuybackHeldLine(
        liveBlockedReason: 'BUYBACK_PRINCIPAL_INSUFFICIENT',
        keeper: keeper('LAUNCH2_BUYBACK_GAS_PRICE_ABOVE_CAP', next: null),
      )!;
      expect(
        both.reason,
        '下一笔暂缓：官方池本金保护：本金不足 10,000 USD1 或单笔超过 1%（链上读数）；'
        '链上手续费过高（自动回购）',
      );
      expect(both.detail, isNull);
      expect(
        launch2BuybackHeldLine(
          liveBlockedReason: 'BUYBACK_PRINCIPAL_INSUFFICIENT',
          keeper: keeper('LAUNCH2_BUYBACK_GAS_PRICE_ABOVE_CAP'),
        )!.detail,
        endsWith(' 后再试'),
      );
      expect(
        launch2BuybackHeldLine(
          liveBlockedReason: null,
          keeper: keeper('LAUNCH2_BUYBACK_NO_BUDGET'),
        ),
        isNull,
      );
      expect(
        launch2BuybackHeldLine(
          liveBlockedReason: 'BUYBACK_NO_BUDGET',
          keeper: keeper('LAUNCH2_BUYBACK_TOO_SOON'),
        ),
        isNull,
      );
    });
  });

  test('Meme 轨 exclusion reasons name no price and never the code', () {
    expect(
      miningExcludedReasonText('MINING_ASSET_GRADUATED_BALANCE_PENDING'),
      '已毕业，外盘持有数量还在同步',
    );
    expect(
      miningExcludedReasonText('MINING_ASSET_GRADUATED_UNREADABLE'),
      '已毕业，外盘持有数量暂读不到',
    );
    expect(
      miningExcludedReasonText('MINING_ASSET_WEIGHT_NOT_CONFIGURED'),
      '还没有配置挖矿权重',
    );
    expect(miningExcludedReasonText('MINING_SOMETHING_NEW'), '暂不计入');
    for (final code in <String>[
      'MINING_ASSET_GRADUATED_BALANCE_PENDING',
      'MINING_ASSET_GRADUATED_UNREADABLE',
      'MINING_SOMETHING_NEW',
    ]) {
      expect(miningExcludedReasonText(code), isNot(contains('价格')));
    }
  });
}

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/alerts/loop_v2_alerts_api.dart';
import 'package:loop_mobile/integrations/backend/v2/chain/loop_v2_chain_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/integrations/backend/v2/watchlist/loop_v2_watchlist_api.dart';

import 'support/s5_fixtures.dart';

const _accessToken = 'privy-access-token';

void main() {
  group('read headers and cache policy', () {
    test(
      'a read carries the contract headers and no idempotency key',
      () async {
        RequestOptions? captured;
        final api = DioLoopV2ChainApi(
          s5Dio((options, handler) {
            captured = options;
            handler.resolve(s5Response(options, s5ChainStatusBody()));
          }),
        );

        await api.getStatus(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        );

        final headers = captured!.headers;
        expect(headers['authorization'], 'Bearer $_accessToken');
        expect(headers['x-loop-contract-version'], '2.0');
        expect(headers['x-loop-client-version'], s5ClientVersion);
        expect(headers.containsKey('idempotency-key'), isFalse);
        expect(headers.containsKey('x-loop-platform'), isFalse);
      },
    );

    test('a response without exact no-store is rejected', () async {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5ChainStatusBody(),
              cacheControl: 'no-store, max-age=0',
            ),
          ),
        ),
      );

      await expectLater(
        api.getStatus(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidPayload,
          ),
        ),
      );
    });

    test(
      'an unknown field is an invalid payload, not a partial view',
      () async {
        final api = DioLoopV2ChainApi(
          s5Dio((options, handler) {
            final body = s5ChainStatusBody()..['surprise'] = true;
            handler.resolve(s5Response(options, body));
          }),
        );

        await expectLater(
          api.getStatus(
            accessToken: _accessToken,
            clientVersion: s5ClientVersion,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );

    // R3-2: the same transport failure means two different things on a GET
    // and on a command, and 网络与 RPC is a GET.
    test('an unparsable GET is a page that did not load, not a submission', () {
      final api = DioLoopV2ChainApi(
        s5Dio((options, handler) {
          final body = s5ChainStatusBody()..['surprise'] = true;
          handler.resolve(s5Response(options, body));
        }),
      );

      return api
          .getStatus(accessToken: _accessToken, clientVersion: s5ClientVersion)
          .then<void>(
            (_) => fail('the status read must be refused'),
            onError: (Object error) {
              final failure = error as LoopBackendFailure;
              expect(failure.kind, LoopBackendFailureKind.invalidPayload);

              final read = loopChainFailureKindForV2(failure, write: false);
              expect(read, LoopChainFailureKind.invalidData);
              expect(loopChainFailureReason(read), isNot(contains('重复提交')));
              expect(loopChainFailureReason(read), isNot(contains('结果未确认')));
              expect(loopChainOutcomeIsUnresolved(read), isFalse);
              // A read that failed is retryable: the page keeps its 重试.
              expect(loopChainPhaseForFailure(read), LoopChainViewPhase.error);

              // After a command the outcome is genuinely unresolved: the
              // server may already have applied it.
              expect(
                loopChainFailureKindForV2(failure, write: true),
                LoopChainFailureKind.outcomeUnknown,
              );
            },
          );
    });

    // The catalogue gives `PERMISSION_DENIED`, `POLICY_BLOCKED` and
    // `REGION_BLOCKED` the status 403 on every route, and `RATE_LIMITED` the
    // status 429. The read catalogues left all four out, so a refusal was
    // parsed as an unreadable payload and rendered as an unresolved
    // submission. A refusal is a refusal (R3-2).
    for (final row
        in <
          ({String code, LoopChainFailureKind kind, LoopChainViewPhase phase})
        >[
          (
            code: 'PERMISSION_DENIED',
            kind: LoopChainFailureKind.permissionDenied,
            phase: LoopChainViewPhase.permission,
          ),
          (
            code: 'POLICY_BLOCKED',
            kind: LoopChainFailureKind.permissionDenied,
            phase: LoopChainViewPhase.permission,
          ),
          (
            code: 'REGION_BLOCKED',
            kind: LoopChainFailureKind.regionBlocked,
            phase: LoopChainViewPhase.permission,
          ),
        ]) {
      test('a refused GET carrying ${row.code} is read as a refusal', () {
        final api = DioLoopV2ChainApi(
          s5Dio(
            (options, handler) => handler.reject(
              s5ErrorResponse(
                options,
                statusCode: 403,
                code: row.code,
                category: 'authorization',
                retryable: false,
                userMessageKey: 'errors.permission.denied',
              ),
            ),
          ),
        );

        return api
            .getStatus(
              accessToken: _accessToken,
              clientVersion: s5ClientVersion,
            )
            .then<void>(
              (_) => fail('the status read must be refused'),
              onError: (Object error) {
                final failure = error as LoopBackendFailure;
                // Not an invalid payload: the server answered, in contract.
                expect(failure.code, row.code);
                final kind = loopChainFailureKindForV2(failure, write: false);
                expect(kind, row.kind);
                expect(loopChainPhaseForFailure(kind), row.phase);
                expect(loopChainFailureReason(kind), isNot(contains('重复提交')));
              },
            );
      });
    }

    test('a rate-limited GET says so instead of blaming the payload', () {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(
              options,
              statusCode: 429,
              code: 'RATE_LIMITED',
              category: 'rateLimit',
              userMessageKey: 'errors.rate.limited',
            ),
          ),
        ),
      );

      return api
          .getStatus(accessToken: _accessToken, clientVersion: s5ClientVersion)
          .then<void>(
            (_) => fail('the status read must be refused'),
            onError: (Object error) {
              final failure = error as LoopBackendFailure;
              expect(failure.code, 'RATE_LIMITED');
              final kind = loopChainFailureKindForV2(failure, write: false);
              expect(kind, LoopChainFailureKind.rateLimited);
              // It is retryable, just not yet: the phase keeps the button.
              expect(loopChainPhaseForFailure(kind), LoopChainViewPhase.error);
              expect(loopChainFailureReason(kind), contains('请求过于频繁'));
              expect(loopChainFailureReason(kind), isNot(contains('重复提交')));
            },
          );
    });

    test('a GET with no server answer at all is a read failure', () {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) =>
              handler.reject(DioException(requestOptions: options)),
        ),
      );

      return api
          .getStatus(accessToken: _accessToken, clientVersion: s5ClientVersion)
          .then<void>(
            (_) => fail('the status read must be refused'),
            onError: (Object error) {
              final failure = error as LoopBackendFailure;
              expect(failure.kind, LoopBackendFailureKind.unexpected);

              final read = loopChainFailureKindForV2(failure, write: false);
              expect(read, LoopChainFailureKind.readFailed);
              expect(loopChainFailureReason(read), isNot(contains('重复提交')));
              expect(loopChainFailureReason(read), contains('读不到'));
              expect(loopChainOutcomeIsUnresolved(read), isFalse);
              expect(
                loopChainFailureKindForV2(failure, write: true),
                LoopChainFailureKind.unexpected,
              );
            },
          );
    });

    test(
      'a correlationId that differs from X-Request-ID is rejected',
      () async {
        final api = DioLoopV2ChainApi(
          s5Dio(
            (options, handler) => handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Object?>(
                  requestOptions: options,
                  statusCode: 503,
                  data: <String, Object?>{
                    'code': 'CAPABILITY_UNAVAILABLE',
                    'category': 'availability',
                    'retryable': true,
                    'userMessageKey': 'errors.capability.unavailable',
                    'correlationId': '99999999-9999-4999-8999-999999999999',
                    'detailsSafe': null,
                    'providerReferenceSafe': null,
                  },
                  headers: Headers.fromMap(<String, List<String>>{
                    'cache-control': const <String>['no-store'],
                    'x-request-id': const <String>[s5RequestId],
                  }),
                ),
              ),
            ),
          ),
        );

        await expectLater(
          api.getStatus(
            accessToken: _accessToken,
            clientVersion: s5ClientVersion,
          ),
          throwsA(
            isA<LoopBackendFailure>().having(
              (failure) => failure.kind,
              'kind',
              LoopBackendFailureKind.invalidPayload,
            ),
          ),
        );
      },
    );
  });

  group('chain status', () {
    test(
      'decodes both indexer lanes and keeps the endpoint reference opaque',
      () async {
        final api = DioLoopV2ChainApi(
          s5Dio(
            (options, handler) =>
                handler.resolve(s5Response(options, s5ChainStatusBody())),
          ),
        );

        final status = await api.getStatus(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        );

        expect(status.chain.confirmations, 15);
        expect(status.rpc.endpoints.single.endpointRef, 'rpc-2bd52ca6d267');
        // The displayable name is the host only.
        expect(status.rpc.endpoints.single.label, 'bsc-rpc.publicnode.com');
        expect(status.rpc.head!.blockNumber, BigInt.from(120628164));
        expect(status.indexer.map((lane) => lane.lane), <LoopIndexerLane>[
          LoopIndexerLane.erc20Transfer,
          LoopIndexerLane.poolEvent,
        ]);
        expect(status.indexer.first.available, isFalse);
        expect(status.indexer.first.reasonCode, 'BSC_INDEXER_NOT_STARTED');
        expect(status.chainIdMismatched, isFalse);
      },
    );

    test('an endpoint label carrying a URL is refused', () async {
      final api = DioLoopV2ChainApi(
        s5Dio((options, handler) {
          final body = s5ChainStatusBody();
          final rpc = body['rpc']! as Map<String, Object?>;
          final endpoints = rpc['endpoints']! as List<Object?>;
          // A scheme and a path are not a host name, and the page would put a
          // provider URL on screen.
          (endpoints.single as Map<String, Object?>)['label'] =
              'https://bsc-rpc.publicnode.com/v1/key';
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.getStatus(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a mismatched chain verification makes the page unusable', () async {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5ChainStatusBody(
                rpcStatus: 'unavailable',
                verification: 'mismatched',
                rpcReasonCode: 'BSC_CHAIN_ID_MISMATCH',
              ),
            ),
          ),
        ),
      );

      final status = await api.getStatus(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
      );

      expect(status.chainIdMismatched, isTrue);
    });

    test('a non-56 assetId maps onto the chainMismatch kind', () async {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(
              options,
              statusCode: 422,
              code: 'CHAIN_MISMATCH',
              category: 'validation',
              retryable: false,
              userMessageKey: 'errors.chain.mismatch',
            ),
          ),
        ),
      );

      try {
        await api.getAsset(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
        );
        fail('the asset read must not succeed');
      } on LoopBackendFailure catch (failure) {
        expect(failure.code, 'CHAIN_MISMATCH');
        expect(
          loopChainFailureKindForV2(failure, write: false),
          LoopChainFailureKind.chainMismatch,
        );
      }
    });
  });

  group('assets', () {
    test('a swappable capability of true is refused by the client', () async {
      final api = DioLoopV2ChainApi(
        s5Dio((options, handler) {
          final body = <String, Object?>{
            'asset': s5ChainAsset(),
            'capability': <String, Object?>{
              'viewable': true,
              // The contract pins this to false until Swap is delivered.
              'swappable': true,
              'value': 'swappable',
              'reasonCode': null,
            },
            'contractVersion': '2.0',
          };
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.getAsset(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('wallets', () {
    test('the active switch is a CAS write with no idempotency key', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, s5WalletDirectoryBody()));
        }),
      );

      await api.putActiveWallet(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
        expectedActiveWalletId: null,
      );

      expect(captured!.method, 'PUT');
      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      expect(captured!.data, <String, Object?>{
        'walletId': s5WalletId,
        'expectedActiveWalletId': null,
      });
    });

    test('the optional platform and device annotation is attached', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, s5WalletDirectoryBody()));
        }),
      );

      await api.putActiveWallet(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
        expectedActiveWalletId: null,
        origin: LoopV2WriteOrigin.tryCreate(
          platform: 'ios',
          deviceId: s5OtherWalletId,
        ),
      );

      expect(captured!.headers['x-loop-platform'], 'ios');
      expect(captured!.headers['x-loop-device-id'], s5OtherWalletId);
    });

    test('a malformed origin is dropped rather than sent', () {
      expect(
        LoopV2WriteOrigin.tryCreate(platform: 'web', deviceId: s5OtherWalletId),
        isNull,
      );
      expect(
        LoopV2WriteOrigin.tryCreate(platform: 'ios', deviceId: 'not-a-uuid'),
        isNull,
      );
    });

    test('an archived wallet can never be reported as active', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5WalletDirectoryBody(status: 'archived', isActive: true),
            ),
          ),
        ),
      );

      await expectLater(
        api.getWallets(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an activeWalletId outside the listed wallets is rejected', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5WalletDirectoryBody(activeWalletId: s5OtherWalletId),
            ),
          ),
        ),
      );

      await expectLater(
        api.getWallets(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('balances', () {
    test('every amount is parsed as an exact Decimal', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5BalancesBody())),
        ),
      );

      final balances = await api.getBalances(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      final row = balances.balances.single;
      final balance = row.balance as LoopBalanceAvailable;
      expect(balance.displayBalance, Decimal.parse('7'));
      expect(balance.spendableBalance, Decimal.parse('6.995'));
      expect(balance.gasReserve, Decimal.parse('0.005'));
      // The exact minor-unit string survives untouched for auditing.
      expect(balance.rawValue, '7000000000000000000');
      expect(balances.gasReservePolicy.nativeReserve, Decimal.parse('0.005'));
      expect(balances.snapshot.blockNumber, BigInt.from(120628164));
    });

    test('an unreadable row stays a row and never becomes zero', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5BalancesBody(
                balances: <Object?>[
                  s5BalanceRow(
                    balance: s5Unavailable('BSC_RPC_UNREACHABLE'),
                    valuation: s5Unavailable('BALANCE_UNAVAILABLE'),
                  ),
                ],
                netWorth: s5NetWorth(status: 'partial', unavailableCount: 1),
              ),
            ),
          ),
        ),
      );

      final balances = await api.getBalances(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      final row = balances.balances.single;
      expect(row.balance, isA<LoopBalanceUnavailable>());
      expect(
        (row.balance as LoopBalanceUnavailable).reasonCode,
        'BSC_RPC_UNREACHABLE',
      );
      final netWorth = balances.netWorth as LoopNetWorthValued;
      expect(netWorth.partial, isTrue);
      expect(netWorth.unavailableCount, 1);
      expect(netWorth.isSpendable, isFalse);
    });

    test('a proxied valuation must name the asset it borrowed', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5BalancesBody())),
        ),
      );

      final balances = await api.getBalances(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      final valuation =
          balances.balances.single.valuation as LoopValuationAvailable;
      expect(valuation.isProxied, isTrue);
      expect(valuation.proxyAsset, s5WbnbAssetId);
    });

    test('a proxied valuation without proxyAsset is rejected', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5BalancesBody(
                balances: <Object?>[
                  s5BalanceRow(
                    valuation: s5ValuationAvailable(quality: 'proxied'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await expectLater(
        api.getBalances(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          walletId: s5WalletId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'a partial net worth with a zero unavailable count is rejected',
      () async {
        final api = DioLoopV2WalletApi(
          s5Dio(
            (options, handler) => handler.resolve(
              s5Response(
                options,
                s5BalancesBody(netWorth: s5NetWorth(status: 'partial')),
              ),
            ),
          ),
        );

        await expectLater(
          api.getBalances(
            accessToken: _accessToken,
            clientVersion: s5ClientVersion,
            walletId: s5WalletId,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );
  });

  group('activity', () {
    test('the cursor is echoed verbatim with no limit alongside it', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, s5ActivityBody()));
        }),
      );

      await api.getActivity(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
        cursor: s5Cursor,
      );

      expect(captured!.queryParameters, <String, Object?>{'cursor': s5Cursor});
    });

    test('native and cross-chain segments arrive as unavailable', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5ActivityBody())),
        ),
      );

      final page = await api.getActivity(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      expect(page.items.single.confirmations, 101);
      expect(page.items.single.status, LoopConfirmationStatus.confirmed);
      expect(
        page.nativeTransfers.reasonCode,
        'NATIVE_TRANSFER_SCAN_NOT_SUPPORTED',
      );
      expect(page.crossChain.reasonCode, 'CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED');
      expect(page.freshness.lagBlocks, 33);
    });

    test(
      'an indexer that never ran is INDEXING_DELAYED, not an empty page',
      () async {
        final api = DioLoopV2WalletApi(
          s5Dio(
            (options, handler) => handler.reject(
              s5ErrorResponse(
                options,
                statusCode: 503,
                code: 'INDEXING_DELAYED',
                userMessageKey: 'errors.indexing.delayed',
              ),
            ),
          ),
        );

        try {
          await api.getActivity(
            accessToken: _accessToken,
            clientVersion: s5ClientVersion,
            walletId: s5WalletId,
          );
          fail('the activity read must not succeed');
        } on LoopBackendFailure catch (failure) {
          expect(
            loopChainFailureKindForV2(failure, write: false),
            LoopChainFailureKind.indexingDelayed,
          );
        }
      },
    );
  });

  group('receive', () {
    test('the EIP-681 uri must address the same wallet as the row', () async {
      final api = DioLoopV2WalletApi(
        s5Dio((options, handler) {
          final body = s5ReceiveBody();
          final network =
              (body['networks']! as List<Object?>).first
                  as Map<String, Object?>;
          network['uri'] =
              'ethereum:0x00000000000000000000000000000000000000b2@56';
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.getReceive(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          walletId: s5WalletId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('only BSC is listed', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5ReceiveBody())),
        ),
      );

      final receive = await api.getReceive(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      expect(receive.networks.single.chainId, 'eip155:56');
      expect(receive.networks.single.uri, 'ethereum:$s5Address@56');
    });
  });

  group('market', () {
    // S52: a contract pasted into a conversation may never have been
    // registered. The backend answers it with the same document and a status
    // of its own; the client decodes that status instead of discarding the
    // whole asset for carrying a word it had no branch for.
    test('an unregistered asset is decoded, not dropped', () async {
      final body = s5AssetDetailBody();
      body['asset'] = <String, Object?>{
        'assetId': s5WbnbAssetId,
        'chainId': 'eip155:56',
        'address': s5WbnbAssetId.substring(s5WbnbAssetId.lastIndexOf(':') + 1),
        // The DexScreener path reports neither a ticker nor a precision.
        'symbol': null,
        'name': null,
        'decimals': null,
        'status': 'unregistered',
        'source': <String, Object?>{
          'kind': 'provider_lookup',
          'provider': 'dexscreener',
          'fetchedAt': '2026-09-20T14:52:33.120Z',
          'ttlSeconds': 3600,
          'quality': 'stale',
          'blockNumber': null,
          'verifiedAt': null,
        },
        'updatedAt': '2026-09-20T14:52:33.120Z',
      };
      final api = DioLoopV2MarketApi(
        s5Dio((options, handler) => handler.resolve(s5Response(options, body))),
      );

      final detail = await api.getAsset(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        assetId: s5WbnbAssetId,
      );

      expect(detail.asset.status, LoopAssetStatus.unregistered);
      expect(detail.asset.status.label, '未登记');
      expect(detail.asset.symbol, isNull);
      expect(detail.asset.decimals, isNull);
      expect(detail.asset.hasPrecision, isFalse);
      expect(detail.asset.source.kind, LoopAssetSourceKind.providerLookup);
      expect(detail.asset.source.provider, LoopFactSource.dexscreener);
      expect(detail.asset.source.quality, LoopFactQuality.stale);
      // With no ticker the address is what a surface may print.
      expect(
        loopAssetSymbolLabel(detail.asset),
        loopTruncatedAssetId(s5WbnbAssetId),
      );
    });

    test('a provider name on a chain call is refused', () async {
      final body = s5AssetDetailBody();
      final asset = Map<String, Object?>.from(body['asset']! as Map);
      asset['source'] = <String, Object?>{
        'kind': 'chain_call',
        'provider': 'dexscreener',
        'blockNumber': '120628195',
        'verifiedAt': '2026-09-08T05:12:21.926Z',
      };
      body['asset'] = asset;
      final api = DioLoopV2MarketApi(
        s5Dio((options, handler) => handler.resolve(s5Response(options, body))),
      );

      await expectLater(
        api.getAsset(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('facts keep their own quality and provenance', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5OverviewBody())),
        ),
      );

      final overview = await api.getOverview(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
      );

      final watchlist = overview.watchlist as MarketWatchlistAvailable;
      expect(watchlist.items.single.price.quality, LoopFactQuality.fresh);
      expect(
        watchlist.items.single.priceChange24h.value,
        Decimal.parse('-3.2'),
      );

      final trending = overview.trending as MarketTrendingAvailable;
      expect(trending.items.single.price.quality, LoopFactQuality.stale);
      expect(
        trending.items.single.price.reasonCode,
        'MARKET_PROVIDER_RATE_LIMITED',
      );
      expect(trending.items.single.priceChange24h.isAvailable, isFalse);
      expect(trending.rules.ordering, 'dexscreener_volume_h24_desc');
      expect(
        overview.newPairs,
        isA<MarketOverviewNewPairsUnavailable>().having(
          (block) => block.reasonCode,
          'reasonCode',
          'MARKET_PROVIDER_GECKOTERMINAL_DISABLED',
        ),
      );
      expect(overview.smartMoney.reasonCode, 'SMART_MONEY_RUNTIME_DEFERRED');
    });

    test('the overview new-pairs card must say what it left out', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5OverviewBody(newPairsAvailable: true, newPairsOmittedCount: 3),
            ),
          ),
        ),
      );

      final overview = await api.getOverview(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
      );

      expect(
        overview.newPairs,
        isA<MarketOverviewNewPairsAvailable>().having(
          (block) => block.omittedCount,
          'omittedCount',
          3,
        ),
      );
    });

    test('an available card without its omitted count is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio((options, handler) {
          final body = s5OverviewBody()
            ..['newPairs'] = <String, Object?>{'status': 'available'};
          handler.resolve(s5Response(options, body));
        }),
      );

      // Decision 0053 made the count part of the answer: "readable" without
      // it would not say how much of the page is missing.
      await expectLater(
        api.getOverview(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'a provider that is on but unreadable arrives with its own reason',
      () async {
        final api = DioLoopV2MarketApi(
          s5Dio((options, handler) {
            final body = s5OverviewBody()
              ..['newPairs'] = <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'MARKET_PROVIDER_GECKOTERMINAL_UNREACHABLE',
              };
            handler.resolve(s5Response(options, body));
          }),
        );

        final overview = await api.getOverview(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        );

        // The card reports the same reason the new-pairs page would, instead of
        // claiming a readable page that is not there.
        expect(
          overview.newPairs,
          isA<MarketOverviewNewPairsUnavailable>().having(
            (block) => block.reasonCode,
            'reasonCode',
            'MARKET_PROVIDER_GECKOTERMINAL_UNREACHABLE',
          ),
        );
      },
    );

    test('a value without an unavailable quality is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio((options, handler) {
          final body = s5OverviewBody(
            watchlist: <String, Object?>{
              'status': 'available',
              'version': 3,
              'items': <Object?>[
                <String, Object?>{
                  'assetId': s5WbnbAssetId,
                  'asset': s5AssetSummary(),
                  // A null value with a `fresh` quality would render as an
                  // absent figure that still claims a provider.
                  'price': s5Fact(value: null),
                  'priceChange24h': s5Fact(),
                },
              ],
            },
          );
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.getOverview(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('candles keep isOpen only on the last bucket', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5CandlesBody())),
        ),
      );

      final series = await api.getCandles(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        assetId: s5WbnbAssetId,
        interval: LoopCandleInterval.oneHour,
      );

      final candles = series.candles as MarketCandlesAvailable;
      expect(candles.isDerived, isTrue);
      expect(candles.labelKey, 'market.candles.onChainSwapAggregate');
      expect(candles.priceUnit, 'USDT per WBNB');
      expect(candles.items.first.isOpen, isFalse);
      expect(candles.items.last.isOpen, isTrue);
      expect(candles.items.first.open, Decimal.parse('747.12'));
    });

    // S52: an unregistered address is charted from the provider's own pool,
    // whose dex id is the provider's word. The client prints it; it never
    // required it to be LOOP's own constant.
    test('a pool names its protocol in the source own words', () async {
      final body = s5CandlesBody(source: 'geckoterminal');
      final candles = Map<String, Object?>.from(body['candles']! as Map);
      final pool = Map<String, Object?>.from(candles['pool']! as Map);
      pool['protocol'] = 'pancakeswap-v3-bsc';
      pool['quoteAssetId'] = null;
      pool['quoteSymbol'] = 'USD';
      candles['pool'] = pool;
      body['candles'] = candles;
      final api = DioLoopV2MarketApi(
        s5Dio((options, handler) => handler.resolve(s5Response(options, body))),
      );

      final series = await api.getCandles(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        assetId: s5WbnbAssetId,
        interval: LoopCandleInterval.oneHour,
      );

      final available = series.candles as MarketCandlesAvailable;
      expect(available.pool.protocol, 'pancakeswap-v3-bsc');
      expect(available.pool.quoteAssetId, isNull);
      expect(available.source, LoopFactSource.geckoterminal);
    });

    test('proxied candles carry the asset whose pool was charted', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              // Native BNB has no pool of its own: the server charts WBNB and
              // says so (decision 0050).
              s5CandlesBody(
                assetId: s5NativeAssetId,
                quality: 'proxied',
                source: 'geckoterminal',
                labelKey: null,
                proxyAsset: s5WbnbAssetId,
                priceUnit: 'USD per WBNB',
              ),
            ),
          ),
        ),
      );

      final series = await api.getCandles(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        assetId: s5NativeAssetId,
        interval: LoopCandleInterval.oneHour,
      );

      final candles = series.candles as MarketCandlesAvailable;
      expect(candles.isProxied, isTrue);
      expect(candles.proxyAsset, s5WbnbAssetId);
      expect(candles.hasSourceLabel, isFalse);
      expect(candles.priceUnit, 'USD per WBNB');
    });

    test('a proxied series may also be an on-chain aggregate', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5CandlesBody(
                assetId: s5NativeAssetId,
                quality: 'proxied',
                proxyAsset: s5WbnbAssetId,
              ),
            ),
          ),
        ),
      );

      final series = await api.getCandles(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        assetId: s5NativeAssetId,
        interval: LoopCandleInterval.oneHour,
      );

      final candles = series.candles as MarketCandlesAvailable;
      expect(candles.isProxied, isTrue);
      expect(candles.hasSourceLabel, isTrue);
      expect(candles.labelKey, 'market.candles.onChainSwapAggregate');
    });

    test('proxied candles without a proxy asset are rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, s5CandlesBody(quality: 'proxied')),
          ),
        ),
      );

      await expectLater(
        api.getCandles(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
          interval: LoopCandleInterval.oneHour,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a non-proxied series naming a proxy asset is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, s5CandlesBody(proxyAsset: s5WbnbAssetId)),
          ),
        ),
      );

      await expectLater(
        api.getCandles(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
          interval: LoopCandleInterval.oneHour,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a candle block without the proxyAsset key is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio((options, handler) {
          final body = s5CandlesBody();
          (body['candles']! as Map<String, Object?>).remove('proxyAsset');
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.getCandles(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
          interval: LoopCandleInterval.oneHour,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an open bucket before the last one is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5CandlesBody(
                items: <Object?>[
                  s5Candle(isOpen: true),
                  s5Candle(
                    openTime: '2026-09-08T07:00:00.000Z',
                    closeTime: '2026-09-08T08:00:00.000Z',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await expectLater(
        api.getCandles(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
          interval: LoopCandleInterval.oneHour,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an interval the server did not echo back is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, s5CandlesBody(interval: '4h')),
          ),
        ),
      );

      await expectLater(
        api.getCandles(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          assetId: s5WbnbAssetId,
          interval: LoopCandleInterval.oneHour,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('trades carry isOwn and no counterparty address', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5TradesBody())),
        ),
      );

      final page = await api.getTrades(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        assetId: s5WbnbAssetId,
      );

      final trades = page.trades as MarketTradesAvailable;
      final trade = trades.items.single;
      expect(trade.isOwn, isTrue);
      expect(trade.direction, MarketTradeDirection.buy);
      expect(trade.amountQuote, Decimal.parse('934.35'));
      expect(trade.priceAfter, Decimal.parse('747.482453211647133359'));
    });

    test('holders expose only the count', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5HoldersBody())),
        ),
      );

      final holders = await api.getHolders(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        assetId: s5WbnbAssetId,
      );

      expect(holders.holderCount.value, Decimal.parse('8019338'));
      expect(
        holders.distribution.reasonCode,
        'HOLDER_DISTRIBUTION_NOT_SUPPORTED',
      );
    });

    test('security facts arrive with their own source and time', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5AssetDetailBody())),
        ),
      );

      final detail = await api.getAsset(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        assetId: s5WbnbAssetId,
      );

      final security = detail.security as MarketSecurityAvailable;
      expect(security.facts.map((fact) => fact.fact), <String>[
        'openSource',
        'sellTax',
      ]);
      expect(security.facts.first.source, LoopFactSource.goplus);
      expect(detail.capability.swappable, isFalse);
      expect(detail.marketCap.isAvailable, isFalse);
    });

    test(
      'a pool id row is decoded as a pool id, never as an address',
      () async {
        final api = DioLoopV2MarketApi(
          s5Dio(
            (options, handler) => handler.resolve(
              s5Response(
                options,
                s5NewPairsBody(
                  available: true,
                  items: <Object?>[
                    s5NewPair(
                      poolRef: <String, Object?>{
                        'kind': 'poolId',
                        'poolId': s5PoolId,
                      },
                      dexId: 'uniswap-v4-bsc',
                      name: 'priceless / U 0.163%',
                    ),
                    s5NewPair(),
                  ],
                ),
              ),
            ),
          ),
        );

        final page = await api.getNewPairs(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        );

        final block = page.newPairs as MarketNewPairsAvailable;
        expect(block.items.first.poolRef, isA<MarketPoolIdRef>());
        expect((block.items.first.poolRef as MarketPoolIdRef).poolId, s5PoolId);
        // A V4 pool has no page of its own, whatever its base token reads as.
        expect(block.items.first.opensDetail, isFalse);
        expect(block.items.last.poolRef, isA<MarketPoolAddressRef>());
        expect(block.items.last.opensDetail, isTrue);
      },
    );

    test('a pool ref of an unknown kind is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5NewPairsBody(
                available: true,
                items: <Object?>[
                  s5NewPair(
                    poolRef: <String, Object?>{
                      'kind': 'bucket',
                      'bucketId': '7',
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Two forms are read two ways; a third cannot be guessed into either.
      await expectLater(
        api.getNewPairs(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a pool id in the address slot is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5NewPairsBody(
                available: true,
                items: <Object?>[
                  s5NewPair(
                    poolRef: <String, Object?>{
                      'kind': 'address',
                      'address': s5PoolId,
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await expectLater(
        api.getNewPairs(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('new pairs count the rows that were neither form', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5NewPairsBody(
                available: true,
                omittedCount: 6,
                items: <Object?>[
                  // `dexId` is the provider's own string, not an enum, and a
                  // four.meme pool quotes in native BNB (the zero address).
                  s5NewPair(
                    dexId: 'four-meme',
                    name: 'MEME / BNB',
                    quoteTokenAddress: marketZeroAddress,
                    registryAssetId: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final page = await api.getNewPairs(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
      );

      final block = page.newPairs as MarketNewPairsAvailable;
      // Both known forms are listed now, so this counts malformed rows only.
      expect(block.omittedCount, 6);
      expect(block.items.single.dexId, 'four-meme');
      expect(block.items.single.quotesNativeCoin, isTrue);
      expect(block.items.single.registryAssetId, isNull);
    });

    test('new pairs without the omittedCount key are rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio((options, handler) {
          final body = s5NewPairsBody(available: true);
          (body['newPairs']! as Map<String, Object?>).remove('omittedCount');
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.getNewPairs(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a negative omittedCount is rejected', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              s5NewPairsBody(available: true, omittedCount: -1),
            ),
          ),
        ),
      );

      await expectLater(
        api.getNewPairs(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('new pairs without a provider stay an unavailable block', () async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5NewPairsBody())),
        ),
      );

      final page = await api.getNewPairs(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
      );

      expect(page.newPairs, isA<MarketNewPairsUnavailable>());
      expect(
        (page.newPairs as MarketNewPairsUnavailable).reasonCode,
        'MARKET_PROVIDER_GECKOTERMINAL_DISABLED',
      );
      expect(
        page.riskScreening.reasonCode,
        'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED',
      );
    });
  });

  group('watchlist', () {
    test('a PUT sends only assetIds and no idempotency key', () async {
      RequestOptions? captured;
      final api = DioLoopV2WatchlistApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, s5WatchlistBody(version: 2)));
        }),
      );

      await api.putWatchlist(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        expectedVersion: 1,
        groups: <WatchlistGroup>[
          WatchlistGroup(
            key: 'mining',
            name: 'Mining',
            items: <WatchlistItem>[WatchlistItem(assetId: s5WbnbAssetId)],
          ),
        ],
      );

      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      expect(captured!.data, <String, Object?>{
        'expectedVersion': 1,
        'groups': <Object?>[
          <String, Object?>{
            'key': 'mining',
            'name': 'Mining',
            'items': <Object?>[
              <String, Object?>{'assetId': s5WbnbAssetId},
            ],
          },
        ],
      });
    });

    test('an unreadable row keeps its place with a reason', () async {
      final api = DioLoopV2WatchlistApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s5WatchlistBody())),
        ),
      );

      final snapshot = await api.getWatchlist(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
      );

      expect(snapshot.groups.single.items.length, 2);
      expect(snapshot.groups.single.items.last.isReadable, isFalse);
      expect(
        snapshot.groups.single.items.last.reasonCode,
        'ASSET_NOT_READABLE',
      );
      expect(snapshot.orderedAssetIds, <String>[s5WbnbAssetId, s5UsdtAssetId]);
    });

    test('a row that is both readable and explained is rejected', () async {
      final api = DioLoopV2WatchlistApi(
        s5Dio((options, handler) {
          final body = s5WatchlistBody();
          final group =
              (body['groups']! as List<Object?>).first as Map<String, Object?>;
          final item =
              (group['items']! as List<Object?>).first as Map<String, Object?>;
          item['reasonCode'] = 'ASSET_NOT_READABLE';
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.getWatchlist(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a version conflict maps onto versionConflict', () async {
      final api = DioLoopV2WatchlistApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(
              options,
              statusCode: 409,
              code: 'VERSION_CONFLICT',
              category: 'conflict',
              retryable: false,
              userMessageKey: 'errors.version.conflict',
            ),
          ),
        ),
      );

      try {
        await api.putWatchlist(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          expectedVersion: 1,
          groups: const <WatchlistGroup>[],
        );
        fail('the watchlist write must not succeed');
      } on LoopBackendFailure catch (failure) {
        expect(
          loopChainFailureKindForV2(failure, write: true),
          LoopChainFailureKind.versionConflict,
        );
      }
    });
  });

  group('alerts', () {
    test('the threshold is sent as a JSON string, never a number', () async {
      RequestOptions? captured;
      final api = DioLoopV2AlertsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(
            s5Response(options, <String, Object?>{
              'alert': s5AlertBody(),
              'contractVersion': '2.0',
            }, statusCode: 201),
          );
        }),
      );

      await api.createAlert(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        idempotencyKey: s5OtherWalletId,
        draft: const LoopAlertDraft(
          assetId: s5WbnbAssetId,
          condition: LoopAlertCondition.atOrAbove,
          threshold: '800.5',
          expiresAt: null,
        ),
      );

      final body = captured!.data! as Map<String, Object?>;
      expect(body['threshold'], isA<String>());
      expect(body['threshold'], '800.5');
      expect(captured!.headers['idempotency-key'], s5OtherWalletId);
    });

    test('a triggered alert must say when it fired', () async {
      final api = DioLoopV2AlertsApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, <String, Object?>{
              'alert': s5AlertBody(state: 'triggered'),
              'contractVersion': '2.0',
            }),
          ),
        ),
      );

      await expectLater(
        api.listAlerts(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a delete is a CAS with the version in the query', () async {
      RequestOptions? captured;
      final api = DioLoopV2AlertsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, null, statusCode: 204));
        }),
      );

      await api.deleteAlert(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        alertId: s5AlertId,
        expectedVersion: 3,
      );

      expect(captured!.method, 'DELETE');
      expect(captured!.queryParameters, <String, Object?>{
        'expectedVersion': 3,
      });
      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
    });

    test('a draft outside the contract never reaches the wire', () async {
      var requested = false;
      final api = DioLoopV2AlertsApi(
        s5Dio((options, handler) {
          requested = true;
          handler.resolve(s5Response(options, null, statusCode: 204));
        }),
      );

      await expectLater(
        api.createAlert(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          idempotencyKey: s5OtherWalletId,
          draft: const LoopAlertDraft(
            assetId: s5WbnbAssetId,
            condition: LoopAlertCondition.above,
            // Scientific notation and zero are both refused by the server.
            threshold: '1e3',
            expiresAt: null,
          ),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(requested, isFalse);
    });
  });

  group('notifications', () {
    test('marking read carries an idempotency key and a readAt', () async {
      RequestOptions? captured;
      final api = DioLoopV2NotificationsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(
            s5Response(options, <String, Object?>{
              'notification': s5NotificationBody(
                readAt: '2026-09-08T08:00:00.000Z',
              ),
              'contractVersion': '2.0',
            }),
          );
        }),
      );

      final entry = await api.markRead(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        idempotencyKey: s5OtherWalletId,
        notificationId: s5NotificationId,
      );

      expect(captured!.headers['idempotency-key'], s5OtherWalletId);
      expect(entry.readAt, isNotNull);
      expect(entry.priceAlertId, s5AlertId);
      expect(entry.contextRoute, 'token');
      expect(entry.contextParams['assetId'], s5WbnbAssetId);
    });

    test('a read receipt without readAt is rejected', () async {
      final api = DioLoopV2NotificationsApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, <String, Object?>{
              'notification': s5NotificationBody(),
              'contractVersion': '2.0',
            }),
          ),
        ),
      );

      await expectLater(
        api.markRead(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          idempotencyKey: s5OtherWalletId,
          notificationId: s5NotificationId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'preferences always send the ten keys with security.event true',
      () async {
        RequestOptions? captured;
        final api = DioLoopV2NotificationsApi(
          s5Dio((options, handler) {
            captured = options;
            handler.resolve(s5Response(options, s5PreferencesBody(version: 1)));
          }),
        );

        await api.putPreferences(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          expectedVersion: 0,
          categories: <LoopNotificationCategory, bool>{
            for (final category in LoopNotificationCategory.values)
              category: category != LoopNotificationCategory.communityAll,
          },
        );

        final body = captured!.data! as Map<String, Object?>;
        final categories = body['categories']! as Map<String, Object?>;
        expect(categories.length, 10);
        expect(categories['security.event'], isTrue);
        expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      },
    );

    test(
      'a write that would disable security.event never leaves the device',
      () async {
        var requested = false;
        final api = DioLoopV2NotificationsApi(
          s5Dio((options, handler) {
            requested = true;
            handler.resolve(s5Response(options, s5PreferencesBody()));
          }),
        );

        await expectLater(
          api.putPreferences(
            accessToken: _accessToken,
            clientVersion: s5ClientVersion,
            expectedVersion: 0,
            categories: <LoopNotificationCategory, bool>{
              for (final category in LoopNotificationCategory.values)
                category: category != LoopNotificationCategory.securityEvent,
            },
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
        expect(requested, isFalse);
      },
    );

    test('an unlocked security category on the wire is rejected', () async {
      final api = DioLoopV2NotificationsApi(
        s5Dio((options, handler) {
          final body = s5PreferencesBody();
          final categories = body['categories']! as Map<String, Object?>;
          categories['security.event'] = <String, Object?>{
            'enabled': true,
            'locked': false,
          };
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.getPreferences(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });
}

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/chain/loop_v2_chain_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

import 'support/s5_fixtures.dart';

/// Decision 0038 gave LOOP exactly two named chain slots: `primary`, which
/// never moves, and `launch`, which may point at the BSC testnet. These tests
/// pin the three shapes that carry it — the chain status, the wallet balances
/// and the `launch` capability evidence — plus the rule that only a Launch
/// intent may ever be signed off the primary chain.
///
/// The absent case is the ordinary one: a backend whose Launch slot equals the
/// primary chain omits all three keys, and every parse below must then produce
/// exactly what it produced before S9.
void main() {
  const accessToken = 'privy-access-token';

  group('chain status · launchChain', () {
    test(
      'an omitted key is the primary-chain build, not a null slot',
      () async {
        final api = DioLoopV2ChainApi(
          s5Dio(
            (options, handler) =>
                handler.resolve(s5Response(options, s5ChainStatusBody())),
          ),
        );

        final status = await api.getStatus(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
        );

        expect(status.launchChain, isNull);
        expect(status.chain.chainId, loopPrimaryChainId);
      },
    );

    test('a published testnet slot carries its own head and depth', () async {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, _statusWithLaunchChain(_launchChainStatus())),
          ),
        ),
      );

      final status = await api.getStatus(
        accessToken: accessToken,
        clientVersion: s5ClientVersion,
      );

      final launchChain = status.launchChain!;
      expect(launchChain.chainId, loopLaunchTestnetChainId);
      expect(launchChain.chainReference, 97);
      expect(launchChain.isTestnet, isTrue);
      expect(launchChain.isHealthy, isTrue);
      expect(launchChain.verification, LoopChainVerification.verified);
      expect(launchChain.confirmations, 5);
      expect(launchChain.reorgDepthBlocks, 15);
      expect(launchChain.head!.blockNumber, BigInt.from(52000000));
      expect(launchChain.name, 'BSC 测试网');
      // The primary chain block is untouched by the second slot.
      expect(status.chain.chainId, loopPrimaryChainId);
      expect(status.rpc.endpoints, hasLength(1));
    });

    test('an unreachable slot keeps the reason and refuses a head', () async {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              _statusWithLaunchChain(
                _launchChainStatus(
                  verification: 'unreachable',
                  head: null,
                  reasonCode: 'LAUNCH_CHAIN_RPC_UNREACHABLE',
                ),
              ),
            ),
          ),
        ),
      );

      final status = await api.getStatus(
        accessToken: accessToken,
        clientVersion: s5ClientVersion,
      );

      expect(status.launchChain!.head, isNull);
      expect(status.launchChain!.isHealthy, isFalse);
      expect(status.launchChain!.reasonCode, 'LAUNCH_CHAIN_RPC_UNREACHABLE');
    });

    test('a third chain is an invalid payload, never a new network', () {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              _statusWithLaunchChain(
                _launchChainStatus(chainId: 'eip155:1', chainReference: 1),
              ),
            ),
          ),
        ),
      );

      expect(
        () => api.getStatus(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(_invalidPayload),
      );
    });

    test('a reference that disagrees with the chain id is refused', () {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              _statusWithLaunchChain(_launchChainStatus(chainReference: 56)),
            ),
          ),
        ),
      );

      expect(
        () => api.getStatus(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(_invalidPayload),
      );
    });

    test('a head on an unverified slot is refused', () {
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              _statusWithLaunchChain(
                _launchChainStatus(
                  verification: 'unknown',
                  reasonCode: 'LAUNCH_CHAIN_VERIFICATION_PENDING',
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        () => api.getStatus(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(_invalidPayload),
      );
    });

    test('an unknown key in the slot is refused', () {
      final slot = _launchChainStatus()..['endpoints'] = <Object?>[];
      final api = DioLoopV2ChainApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, _statusWithLaunchChain(slot)),
          ),
        ),
      );

      expect(
        () => api.getStatus(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(_invalidPayload),
      );
    });
  });

  group('wallet balances · launchChain', () {
    test(
      'an omitted key leaves the wallet page without a Launch block',
      () async {
        final api = DioLoopV2WalletApi(
          s5Dio(
            (options, handler) =>
                handler.resolve(s5Response(options, s5BalancesBody())),
          ),
        );

        final balances = await api.getBalances(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
          walletId: s5WalletId,
        );

        expect(balances.launchChain, isNull);
        expect(balances.balances, hasLength(1));
      },
    );

    test('a published slot carries one exact native balance', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              _balancesWithLaunchChain(_launchChainBalance()),
            ),
          ),
        ),
      );

      final balances = await api.getBalances(
        accessToken: accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      final launchChain = balances.launchChain!;
      expect(launchChain.isTestnet, isTrue);
      expect(launchChain.available, isTrue);
      expect(launchChain.reasonCode, isNull);
      final native = launchChain.nativeBalance!;
      expect(native.assetId, 'eip155:97:native');
      expect(native.symbol, 'tBNB');
      expect(native.rawValue, '2500000000000000000');
      expect(native.displayBalance, Decimal.parse('2.5'));
      expect(native.spendableBalance, Decimal.parse('2.495'));
      expect(native.gasReserve, Decimal.parse('0.005'));
      expect(native.snapshot.confirmations, 5);
      // The testnet figure is never folded into the main-chain projection.
      expect(balances.balances.single.assetId, s5NativeAssetId);
      expect(balances.netWorth, isA<LoopNetWorthValued>());
    });

    test('an unavailable slot states a reason and never a zero', () async {
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(
              options,
              _balancesWithLaunchChain(<String, Object?>{
                'chainId': loopLaunchTestnetChainId,
                'availability': 'unavailable',
                'reasonCode': 'LAUNCH_CHAIN_RPC_NOT_CONFIGURED',
                'nativeBalance': null,
              }),
            ),
          ),
        ),
      );

      final balances = await api.getBalances(
        accessToken: accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      expect(balances.launchChain!.available, isFalse);
      expect(balances.launchChain!.nativeBalance, isNull);
      expect(
        balances.launchChain!.reasonCode,
        'LAUNCH_CHAIN_RPC_NOT_CONFIGURED',
      );
      // The primary chain read is untouched by the testnet failure.
      expect(balances.balances, hasLength(1));
    });

    test('an unavailable slot may not carry a figure', () {
      final slot = _launchChainBalance()
        ..['availability'] = 'unavailable'
        ..['reasonCode'] = 'BSC_BALANCE_CALL_FAILED';
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, _balancesWithLaunchChain(slot)),
          ),
        ),
      );

      expect(
        () => api.getBalances(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
          walletId: s5WalletId,
        ),
        throwsA(_invalidPayload),
      );
    });

    test('a balance keyed to another chain is refused', () {
      final slot = _launchChainBalance();
      (slot['nativeBalance']! as Map<String, Object?>)['assetId'] =
          s5NativeAssetId;
      final api = DioLoopV2WalletApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, _balancesWithLaunchChain(slot)),
          ),
        ),
      );

      expect(
        () => api.getBalances(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
          walletId: s5WalletId,
        ),
        throwsA(_invalidPayload),
      );
    });
  });

  group('launch catalogue · chainId', () {
    test('a launch created on the testnet keeps its own chain', () async {
      final api = DioLoopV2LaunchApi(
        _launchDio(_overviewBody(chainId: loopLaunchTestnetChainId)),
      );

      final overview = await api.getOverview(
        accessToken: accessToken,
        clientVersion: s5ClientVersion,
      );

      final launch = overview.segments.awaitingSchedule.single;
      expect(launch.chainId, loopLaunchTestnetChainId);
      expect(launch.isTestnetChain, isTrue);
    });

    test('a primary-chain launch carries no testnet marker', () async {
      final api = DioLoopV2LaunchApi(_launchDio(_overviewBody()));

      final overview = await api.getOverview(
        accessToken: accessToken,
        clientVersion: s5ClientVersion,
      );

      expect(overview.segments.awaitingSchedule.single.isTestnetChain, isFalse);
    });

    test('a third chain is an invalid payload', () {
      final api = DioLoopV2LaunchApi(
        _launchDio(_overviewBody(chainId: 'eip155:1')),
      );

      expect(
        () => api.getOverview(
          accessToken: accessToken,
          clientVersion: s5ClientVersion,
        ),
        throwsA(_invalidPayload),
      );
    });
  });

  group('capabilities · launch.evidence.launchChainId', () {
    test('an omitted key is the S7 document unchanged', () async {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody()),
      );

      final capabilities = await repository.getCapabilities();

      final launch = capabilities[LoopV2CapabilityId.launch];
      expect(launch.evidence.launchChainId, isNull);
      expect(
        LoopCapabilityProjector.of(
          capabilities,
          LoopV2CapabilityId.launch,
        ).isTestnetLaunchChain,
        isFalse,
      );
    });

    test('the published slot reaches the capability projection', () async {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(launchChainId: loopLaunchTestnetChainId)),
      );

      final capabilities = await repository.getCapabilities();

      final projection = LoopCapabilityProjector.of(
        capabilities,
        LoopV2CapabilityId.launch,
      );
      expect(projection.launchChainId, loopLaunchTestnetChainId);
      expect(projection.isTestnetLaunchChain, isTrue);
      // No other capability may ever carry it.
      expect(
        LoopCapabilityProjector.of(
          capabilities,
          LoopV2CapabilityId.bscRead,
        ).launchChainId,
        isNull,
      );
    });

    test('the key on another capability is an invalid document', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(
          _capabilitiesBody(
            launchChainId: loopLaunchTestnetChainId,
            onCapability: LoopV2CapabilityId.bscRead,
          ),
        ),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('an unknown chain id is an invalid document', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(launchChainId: 'eip155:1')),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    // Absence is the only shape that means "Launch runs on the primary
    // chain". An explicit `null` is a published key that names no chain, so
    // reading it as absence would let a malformed document pass as the
    // ordinary one.
    test('an explicit null on launch is an invalid document', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(explicitNullLaunchChainId: true)),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('an explicit null on another capability is invalid too', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(
          _capabilitiesBody(
            explicitNullLaunchChainId: true,
            onCapability: LoopV2CapabilityId.bscRead,
          ),
        ),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });
  });

  group('chain identities', () {
    test('an unknown chain is never named or numbered as the primary', () {
      expect(loopChainName(loopPrimaryChainId), 'BNB Smart Chain');
      expect(loopChainName(loopLaunchTestnetChainId), 'BSC 测试网');
      expect(loopChainReference(loopPrimaryChainId), 56);
      expect(loopChainReference(loopLaunchTestnetChainId), 97);
      // Falling back to the primary chain would label an unpublished chain
      // "BNB Smart Chain" and compare a payload against a reference nobody
      // sent, so both throw instead.
      for (final unknown in const <String>[
        'eip155:1',
        'eip155:42161',
        'solana:mainnet',
        '',
      ]) {
        expect(
          () => loopChainName(unknown),
          throwsArgumentError,
          reason: '$unknown must not borrow the primary chain name',
        );
        expect(
          () => loopChainReference(unknown),
          throwsArgumentError,
          reason: '$unknown must not borrow the primary chain reference',
        );
      }
    });
  });

  group('signing · only a Launch intent may leave the primary chain', () {
    final now = DateTime.utc(2026, 9, 9, 8);

    SigningIntent intent({required IntentKind kind, required String chainId}) =>
        SigningIntent.backendCanonical(
          revision: '9a1f0b7c-2d4e-4a5b-8c9d-0e1f2a3b4c5d',
          payloadDigest: 'a' * 64,
          title: '确认发送',
          kind: kind,
          chainId: chainId,
          payload: DeviceTransactionPayload(
            fromAddress: '0x1111111111111111111111111111111111111111',
            transaction: <String, Object?>{
              // `loopChainReference` throws on an unknown chain, which is the
              // point of the identity guard; the fixture keeps a plain number
              // so the intent-level refusal is what the test observes.
              'chainId': loopKnownChainIds.contains(chainId)
                  ? loopChainReference(chainId)
                  : 0,
              'value': '0x0',
            },
          ),
          observedAt: now,
          expiresAt: now.add(const Duration(minutes: 2)),
          fields: const <IntentField>[IntentField(label: '资产', value: 'WBNB')],
        );

    test('a money intent on the testnet never reaches a wallet', () async {
      final signer = _RecordingSigner();
      final gateway = PrivyWalletSigningGateway(
        host: _Host(signer),
        credentialsConfigured: true,
      );
      final testnetTransfer = intent(
        kind: IntentKind.transfer,
        chainId: loopLaunchTestnetChainId,
      );

      expect(testnetTransfer.chainIsPermitted, isFalse);
      expect(testnetTransfer.allowsWalletHandoff, isFalse);
      expect(
        walletHandoffRefusal(testnetTransfer, now: now),
        'canonical_intent_required',
      );

      final result = await gateway.handoff(testnetTransfer, now: now);

      expect(result.accepted, isFalse);
      expect(signer.sendCalls, 0);
    });

    test('a swap and an approval are locked to the primary chain too', () {
      for (final kind in <IntentKind>[IntentKind.swap, IntentKind.approval]) {
        expect(
          intent(
            kind: kind,
            chainId: loopLaunchTestnetChainId,
          ).chainIsPermitted,
          isFalse,
          reason: '$kind must never be signed on the Launch testnet',
        );
        expect(
          intent(kind: kind, chainId: loopPrimaryChainId).chainIsPermitted,
          isTrue,
        );
      }
    });

    test('a Launch purchase is the one kind the testnet admits', () {
      final purchase = intent(
        kind: IntentKind.launchPurchase,
        chainId: loopLaunchTestnetChainId,
      );

      expect(purchase.chainIsPermitted, isTrue);
      expect(purchase.isTestnetChain, isTrue);
      expect(purchase.validateAt(now), isNull);
      expect(purchase.allowsWalletHandoff, isTrue);
    });

    test('an unknown chain is refused for every kind', () {
      for (final kind in IntentKind.values) {
        expect(
          intent(kind: kind, chainId: 'eip155:1').chainIsPermitted,
          isFalse,
        );
      }
    });

    test('the device signer refuses a chain it cannot select', () async {
      // privy_flutter 0.10.1 has no chain-selection call at all, so a
      // non-primary chain fails closed rather than being broadcast on
      // whichever chain the wallet happens to be on.
      const signer = SdkPrivyDeviceSigner(null);

      await expectLater(
        signer.sendTransaction(
          chainId: loopLaunchTestnetChainId,
          fromAddress: '0x1111111111111111111111111111111111111111',
          transaction: const <String, Object?>{'chainId': 97},
        ),
        throwsA(
          isA<PrivySigningException>().having(
            (failure) => failure.code,
            'code',
            'privy_chain_switch_unsupported',
          ),
        ),
      );
    });

    test('a payload that disagrees with the intent chain is refused', () async {
      const signer = SdkPrivyDeviceSigner(null);

      await expectLater(
        signer.sendTransaction(
          chainId: loopPrimaryChainId,
          fromAddress: '0x1111111111111111111111111111111111111111',
          transaction: const <String, Object?>{'chainId': 97},
        ),
        throwsA(
          isA<PrivySigningException>().having(
            (failure) => failure.code,
            'code',
            'privy_chain_mismatch',
          ),
        ),
      );
    });

    test('the primary chain still reaches the wallet with its chain', () async {
      final signer = _RecordingSigner();
      final gateway = PrivyWalletSigningGateway(
        host: _Host(signer),
        credentialsConfigured: true,
      );

      final result = await gateway.handoff(
        intent(kind: IntentKind.transfer, chainId: loopPrimaryChainId),
        now: now,
      );

      expect(result.accepted, isTrue);
      expect(signer.sendCalls, 1);
      expect(signer.lastChainId, loopPrimaryChainId);
    });
  });
}

// ---------------------------------------------------------------------------
// fixtures
// ---------------------------------------------------------------------------

final Matcher _invalidPayload = isA<LoopBackendFailure>().having(
  (failure) => failure.kind,
  'kind',
  LoopBackendFailureKind.invalidPayload,
);

Map<String, Object?> _launchChainStatus({
  String chainId = loopLaunchTestnetChainId,
  int chainReference = 97,
  String verification = 'verified',
  Object? head = _defaultHead,
  Object? reasonCode,
}) => <String, Object?>{
  'chainId': chainId,
  'chainReference': chainReference,
  'verification': verification,
  'confirmations': 5,
  'reorgDepthBlocks': 15,
  'head': head == _defaultHead
      ? <String, Object?>{
          'blockNumber': '52000000',
          'blockHash': s5BlockHash,
          'observedAt': '2026-09-09T10:45:05.000Z',
        }
      : head,
  'reasonCode': reasonCode,
};

const Object _defaultHead = Object();

Map<String, Object?> _statusWithLaunchChain(Map<String, Object?> slot) =>
    s5ChainStatusBody()..['launchChain'] = slot;

Map<String, Object?> _launchChainBalance() => <String, Object?>{
  'chainId': loopLaunchTestnetChainId,
  'availability': 'available',
  'reasonCode': null,
  'nativeBalance': <String, Object?>{
    'assetId': 'eip155:97:native',
    'symbol': 'tBNB',
    'decimals': 18,
    'rawValue': '2500000000000000000',
    'displayBalance': '2.5',
    'availableBalance': '2.5',
    'spendableBalance': '2.495',
    'gasReserve': '0.005',
    'snapshot': <String, Object?>{
      'blockNumber': '52000000',
      'blockHash': s5BlockHash,
      'observedAt': '2026-09-09T10:45:05.000Z',
      'confirmations': 5,
    },
  },
};

Map<String, Object?> _balancesWithLaunchChain(Map<String, Object?> slot) =>
    s5BalancesBody()..['launchChain'] = slot;

Map<String, Object?> _overviewBody({String chainId = loopPrimaryChainId}) =>
    <String, Object?>{
      'segments': <String, Object?>{
        'live': <Object?>[],
        'upcoming': <Object?>[],
        'awaitingSchedule': <Object?>[
          <String, Object?>{
            'launchId': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
            'projectId': '17f6a9b2-2f22-4c11-9f3a-1a2b3c4d5e6f',
            'name': 'MoonCat',
            'ticker': 'MCAT',
            'chainId': chainId,
            'contractAddress': null,
            'configDigest': null,
            'scheduleStatus': 'unscheduled',
            'onChainState': <String, Object?>{
              'saleState': 'unavailable',
              'entitlementState': 'unavailable',
              'liquidityState': 'unavailable',
              'operationalState': 'unavailable',
              'stateTupleDigest': null,
              'snapshotBlockNumber': null,
              'snapshotBlockHash': null,
              'source': 'unavailable',
              'reasonCode': 'LAUNCH_CONTRACT_BASELINE_PENDING',
            },
            'configVersion': null,
            'createdAt': '2026-09-08T01:00:00.000Z',
          },
        ],
        'ended': <Object?>[],
      },
      'graduated': <String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'LAUNCH_CONTRACT_BASELINE_PENDING',
      },
      'myEligibility': <String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'TIER_MODE_PENDING',
      },
      'staking': <String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'STAKING_CONTRACT_PENDING',
      },
      'catalog': <String, Object?>{
        'configVersion': 'launchCatalogV1',
        'source': 'loop_db',
        'observedAt': '2026-09-09T06:30:00.000Z',
      },
      'contractVersion': '2.0',
    };

Map<String, Object?> _capabilitiesBody({
  String? launchChainId,
  bool explicitNullLaunchChainId = false,
  LoopV2CapabilityId onCapability = LoopV2CapabilityId.launch,
}) => <String, Object?>{
  'contractVersion': '2.0',
  'configVersion': 'productPolicyV2.2026-09-01',
  'effectiveAt': '2026-09-01T00:00:00.000Z',
  'capabilities': <Object?>[
    for (final id in LoopV2CapabilityId.values)
      <String, Object?>{
        'capabilityId': id.wireName,
        'availability': 'available',
        'reasonCode': null,
        'evidence': <String, Object?>{
          'status': 'pending',
          'reasonCode': 'LAUNCH_CONTRACT_BASELINE_PENDING',
          if (id == onCapability && explicitNullLaunchChainId)
            'launchChainId': null
          else if (launchChainId != null && id == onCapability)
            'launchChainId': launchChainId,
        },
      },
  ],
};

Dio _launchDio(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _StubAdapter(body);
  return dio;
}

Dio _metaDio(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _StubAdapter(body);
  return dio;
}

final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>['11111111-2222-4333-8444-555555555555'],
      },
    );
  }
}

/// Records every wallet call so a refused intent can be proven never to have
/// reached the device.
final class _RecordingSigner implements PrivyDeviceSigner {
  int sendCalls = 0;
  String? lastChainId;

  @override
  bool get isReady => true;

  @override
  Future<String> sendTransaction({
    required String chainId,
    required String fromAddress,
    required Map<String, Object?> transaction,
  }) async {
    sendCalls += 1;
    lastChainId = chainId;
    return '0x${'ab' * 32}';
  }

  @override
  Future<String> authorizationSignature({
    required int version,
    required String method,
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
  }) async => 'authorization-signature';
}

final class _Host implements PrivyDeviceSigningHost {
  _Host(this.deviceSigner);

  @override
  final PrivyDeviceSigner deviceSigner;
}

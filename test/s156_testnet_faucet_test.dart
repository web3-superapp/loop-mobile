import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_gateway.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_models.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_sheet.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/testnet_faucet/loop_v2_testnet_faucet_api.dart';
import 'package:loop_mobile/integrations/backend/v2/testnet_faucet/loop_v2_testnet_faucet_codec.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/testnet_faucet_fakes.dart';

/// Decision 0154 · the testnet faucet.
void main() {
  Finder key(String value) => find.byKey(ValueKey<String>(value));

  // Docs/33 L17 (decision 0171): a faucet line is a warn `LoopNotice`; its
  // sentence is the notice's one body text.
  String? lineText(WidgetTester tester, String value) => tester
      .widget<Text>(
        find.descendant(of: key(value), matching: find.byType(Text)),
      )
      .data;

  Matcher invalid() => throwsA(
    isA<LoopBackendFailure>().having(
      (failure) => failure.kind,
      'kind',
      LoopBackendFailureKind.invalidPayload,
    ),
  );

  Map<String, Object?> statusBody() => <String, Object?>{
    'walletId': s5WalletId,
    'address': '0xABCDEFabcdefABCDEFabcdefABCDEFabcdef1234',
    'bnbAmount': '0.02',
    'usd1Amount': '500',
    'cooldownSeconds': 86400,
    'available': true,
    'nextAvailableAt': null,
    'lastGrant': null,
  };

  Map<String, Object?> grantBody() => <String, Object?>{
    'walletId': s5WalletId,
    'address': '0xabcdefabcdefabcdefabcdefabcdefabcdef1234',
    'bnb': <String, Object?>{
      'amount': '0.02',
      'transactionHash': faucetBnbHash,
    },
    'usd1': <String, Object?>{
      'amount': '500',
      'transactionHash': faucetUsd1Hash,
    },
    'grantedAt': '2026-10-12T08:00:00.000Z',
    'nextAvailableAt': '2026-10-13T08:00:00.000Z',
  };

  group('codec · GET /v2/testnet/faucet', () {
    test('an available wallet decodes; address kept lower-case, amounts '
        'exact', () {
      final status = LoopV2TestnetFaucetCodec.status(statusBody());
      expect(status.walletId, s5WalletId);
      expect(status.address, '0xabcdefabcdefabcdefabcdefabcdefabcdef1234');
      expect(status.bnbAmount, Decimal.parse('0.02'));
      expect(status.usd1Amount, Decimal.parse('500'));
      expect(status.cooldownSeconds, 86400);
      expect(status.available, isTrue);
      expect(status.nextAvailableAt, isNull);
      expect(status.lastGrant, isNull);
    });

    test('a cooling wallet carries its next time and its last grant', () {
      final status = LoopV2TestnetFaucetCodec.status(
        statusBody()
          ..['available'] = false
          ..['nextAvailableAt'] = '2026-10-13T08:00:00+08:00'
          ..['lastGrant'] = <String, Object?>{
            'grantedAt': '2026-10-12T08:00:00.000Z',
            'bnbTransactionHash': faucetBnbHash,
            'usd1TransactionHash': null,
          },
      );
      expect(status.available, isFalse);
      expect(status.nextAvailableAt, DateTime.utc(2026, 10, 13));
      expect(status.lastGrant!.bnbTransactionHash, faucetBnbHash);
      expect(status.lastGrant!.usd1TransactionHash, isNull);
    });

    test('a missing or an unknown key is refused', () {
      for (final name in statusBody().keys) {
        expect(
          () => LoopV2TestnetFaucetCodec.status(statusBody()..remove(name)),
          invalid(),
          reason: name,
        );
      }
      expect(
        () => LoopV2TestnetFaucetCodec.status(statusBody()..['extra'] = 1),
        invalid(),
      );
      expect(
        () => LoopV2TestnetFaucetCodec.status(
          statusBody()
            ..['available'] = false
            ..['nextAvailableAt'] = '2026-10-13T08:00:00.000Z'
            ..['lastGrant'] = <String, Object?>{
              'grantedAt': '2026-10-12T08:00:00.000Z',
              'bnbTransactionHash': faucetBnbHash,
            },
        ),
        invalid(),
      );
    });

    test('a bad value is refused', () {
      for (final MapEntry(:key, :value) in <MapEntry<String, Object?>>[
        const MapEntry<String, Object?>('bnbAmount', 0.02),
        const MapEntry<String, Object?>('bnbAmount', '0'),
        const MapEntry<String, Object?>('usd1Amount', '-5'),
        const MapEntry<String, Object?>('usd1Amount', '1e3'),
        const MapEntry<String, Object?>('cooldownSeconds', '86400'),
        const MapEntry<String, Object?>('cooldownSeconds', 0),
        const MapEntry<String, Object?>('walletId', 'wallet-1'),
        const MapEntry<String, Object?>('address', '0x1234'),
        const MapEntry<String, Object?>('available', 'true'),
        // Available with a next time, or cooling without one, contradicts.
        MapEntry<String, Object?>('nextAvailableAt', '2026-10-13T08:00:00Z'),
        const MapEntry<String, Object?>('lastGrant', <String, Object?>{
          'grantedAt': '2026-10-12T08:00:00.000Z',
          'bnbTransactionHash': null,
          'usd1TransactionHash': null,
        }),
        // tBNB is always recorded; only tUSD1 may be missing.
        const MapEntry<String, Object?>('lastGrant', <String, Object?>{
          'grantedAt': '2026-10-12T08:00:00.000Z',
          'bnbTransactionHash': null,
          'usd1TransactionHash': faucetUsd1Hash,
        }),
      ]) {
        expect(
          () => LoopV2TestnetFaucetCodec.status(statusBody()..[key] = value),
          invalid(),
          reason: '$key = $value',
        );
      }
      expect(
        () => LoopV2TestnetFaucetCodec.status(
          statusBody()..['available'] = false,
        ),
        invalid(),
      );
    });
  });

  group('codec · loop-api S156 samples (8c1927a, app.inject)', () {
    test('GET before the first grant', () {
      final status = LoopV2TestnetFaucetCodec.status(
        jsonDecode(
          '{"walletId":"$s5WalletId",'
          '"address":"0x8f3a2b1c4d5e6f708192a3b4c5d6e7f8091a2b3c",'
          '"bnbAmount":"0.02","usd1Amount":"500","cooldownSeconds":86400,'
          '"available":true,"nextAvailableAt":null,"lastGrant":null}',
        ),
      );
      expect(status.available, isTrue);
      expect(status.lastGrant, isNull);
      expect(status.bnbAmount, Decimal.parse('0.02'));
    });

    test('GET after a partial grant: tUSD1 hash null', () {
      final status = LoopV2TestnetFaucetCodec.status(
        jsonDecode(
          '{"walletId":"$s5WalletId",'
          '"address":"0x8f3a2b1c4d5e6f708192a3b4c5d6e7f8091a2b3c",'
          '"bnbAmount":"0.02","usd1Amount":"500","cooldownSeconds":86400,'
          '"available":false,"nextAvailableAt":"2026-10-13T08:00:00.000Z",'
          '"lastGrant":{"grantedAt":"2026-10-12T08:00:00.000Z",'
          '"bnbTransactionHash":"$faucetBnbHash","usd1TransactionHash":null}}',
        ),
      );
      expect(status.lastGrant!.bnbTransactionHash, faucetBnbHash);
      expect(status.lastGrant!.usd1TransactionHash, isNull);
    });

    test('POST 201', () {
      final granted = LoopV2TestnetFaucetCodec.granted(
        jsonDecode(
          '{"walletId":"$s5WalletId",'
          '"address":"0x8f3a2b1c4d5e6f708192a3b4c5d6e7f8091a2b3c",'
          '"bnb":{"amount":"0.02","transactionHash":"$faucetBnbHash"},'
          '"usd1":{"amount":"500","transactionHash":"$faucetUsd1Hash"},'
          '"grantedAt":"2026-10-12T08:00:00.000Z",'
          '"nextAvailableAt":"2026-10-13T08:00:00.000Z"}',
        ),
      );
      expect(granted.usd1.transactionHash, faucetUsd1Hash);
    });

    test('partial detailsSafe, with and without the tUSD1 hash', () {
      final both = LoopV2TestnetFaucetCodec.partial(
        jsonDecode(
          '{"reasonCode":"TESTNET_FAUCET_PARTIAL",'
          '"bnbTransactionHash":"$faucetBnbHash",'
          '"usd1TransactionHash":"$faucetUsd1Hash",'
          '"nextAvailableAt":"2026-10-13T08:00:00.000Z"}',
        ),
      );
      expect(both.usd1TransactionHash, faucetUsd1Hash);
      expect(both.nextAvailableAt, DateTime.utc(2026, 10, 13, 8));
      final bnbOnly = LoopV2TestnetFaucetCodec.partial(
        jsonDecode(
          '{"reasonCode":"TESTNET_FAUCET_PARTIAL",'
          '"bnbTransactionHash":"$faucetBnbHash",'
          '"nextAvailableAt":"2026-10-13T08:00:00.000Z"}',
        ),
      );
      expect(bnbOnly.bnbTransactionHash, faucetBnbHash);
      expect(bnbOnly.usd1TransactionHash, isNull);
      expect(bnbOnly.unconfirmed, isFalse);
    });
  });

  group('codec · POST /v2/testnet/faucet 201', () {
    test('a grant decodes both transfers', () {
      final granted = LoopV2TestnetFaucetCodec.granted(grantBody());
      expect(granted.bnb.amount, Decimal.parse('0.02'));
      expect(granted.bnb.transactionHash, faucetBnbHash);
      expect(granted.usd1.amount, Decimal.parse('500'));
      expect(granted.usd1.transactionHash, faucetUsd1Hash);
      expect(granted.nextAvailableAt, DateTime.utc(2026, 10, 13, 8));
    });

    test('a missing key, a transfer without its hash, or a next time not '
        'after the grant is refused', () {
      for (final name in grantBody().keys) {
        expect(
          () => LoopV2TestnetFaucetCodec.granted(grantBody()..remove(name)),
          invalid(),
          reason: name,
        );
      }
      expect(
        () => LoopV2TestnetFaucetCodec.granted(
          grantBody()
            ..['usd1'] = <String, Object?>{
              'amount': '500',
              'transactionHash': null,
            },
        ),
        invalid(),
      );
      expect(
        () => LoopV2TestnetFaucetCodec.granted(
          grantBody()..['bnb'] = <String, Object?>{'amount': '0.02'},
        ),
        invalid(),
      );
      expect(
        () => LoopV2TestnetFaucetCodec.granted(
          grantBody()..['nextAvailableAt'] = '2026-10-12T08:00:00.000Z',
        ),
        invalid(),
      );
      expect(
        () => LoopV2TestnetFaucetCodec.granted(
          grantBody()
            ..['bnb'] = <String, Object?>{
              'amount': 0.02,
              'transactionHash': faucetBnbHash,
            },
        ),
        invalid(),
      );
    });
  });

  group('transport', () {
    test('the claim carries an Idempotency-Key and the wallet id', () async {
      final adapter = _Adapter(201, grantBody());
      final api = _api(adapter);
      final result = await api.postClaim(
        accessToken: 'token',
        clientVersion: s5ClientVersion,
        idempotencyKey: s5RequestId,
        walletId: s5WalletId,
      );
      expect(result, isA<TestnetFaucetGranted>());
      final request = adapter.last!;
      expect(request.method, 'POST');
      expect(request.path, '/v2/testnet/faucet');
      expect(request.headers['Idempotency-Key'], s5RequestId);
      expect(request.data, <String, Object?>{'walletId': s5WalletId});
    });

    test('the read sends the wallet id as the query', () async {
      final adapter = _Adapter(200, statusBody());
      final status = await _api(adapter).getStatus(
        accessToken: 'token',
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );
      expect(status.available, isTrue);
      expect(adapter.last!.queryParameters, <String, Object?>{
        'walletId': s5WalletId,
      });
    });

    test('429 cooldown is a value with its next time', () async {
      final result =
          await _api(
            _Adapter(
              429,
              _error('RATE_LIMITED', 'rateLimit', <String, Object?>{
                'reasonCode': 'TESTNET_FAUCET_COOLDOWN',
                'nextAvailableAt': '2026-10-13T08:00:00.000Z',
              }),
            ),
          ).postClaim(
            accessToken: 'token',
            clientVersion: s5ClientVersion,
            idempotencyKey: s5RequestId,
            walletId: s5WalletId,
          );
      expect(
        (result as TestnetFaucetCoolingDown).nextAvailableAt,
        DateTime.utc(2026, 10, 13, 8),
      );
    });

    test('502 / 503 partial is a value with the hash that went out', () async {
      for (final status in <int>[502, 503]) {
        final result =
            await _api(
              _Adapter(
                status,
                _error(
                  status == 502
                      ? 'PROVIDER_UNREACHABLE'
                      : 'PROVIDER_DISCONNECTED',
                  'availability',
                  <String, Object?>{
                    'reasonCode': 'TESTNET_FAUCET_PARTIAL',
                    'bnbTransactionHash': faucetBnbHash,
                    'usd1TransactionHash': 'not-a-hash',
                  },
                ),
              ),
            ).postClaim(
              accessToken: 'token',
              clientVersion: s5ClientVersion,
              idempotencyKey: s5RequestId,
              walletId: s5WalletId,
            );
        final partial = result as TestnetFaucetPartial;
        expect(partial.bnbTransactionHash, faucetBnbHash);
        expect(partial.usd1TransactionHash, isNull);
      }
    });

    Future<TestnetFaucetClaimResult> claimWith(
      int status,
      String code,
      String category,
      Map<String, Object?> details,
    ) => _api(_Adapter(status, _error(code, category, details))).postClaim(
      accessToken: 'token',
      clientVersion: s5ClientVersion,
      idempotencyKey: s5RequestId,
      walletId: s5WalletId,
    );

    test('503 submission unknown is a partial, unconfirmed, with its hash and '
        'next time', () async {
      final result = await claimWith(
        503,
        'CAPABILITY_UNAVAILABLE',
        'availability',
        <String, Object?>{
          'reasonCode': 'TESTNET_FAUCET_SUBMISSION_UNKNOWN',
          'bnbTransactionHash': faucetBnbHash,
          'nextAvailableAt': '2026-10-13T08:00:00.000Z',
        },
      );
      final partial = result as TestnetFaucetPartial;
      expect(partial.unconfirmed, isTrue);
      expect(partial.bnbTransactionHash, faucetBnbHash);
      expect(partial.nextAvailableAt, DateTime.utc(2026, 10, 13, 8));
    });

    test('409 in flight and 503 request timeout are pending values', () async {
      expect(
        (await claimWith(
          409,
          'RESOURCE_CONFLICT',
          'conflict',
          <String, Object?>{'reasonCode': 'TESTNET_FAUCET_IN_FLIGHT'},
        ) as TestnetFaucetPending).reason,
        TestnetFaucetPendingReason.inFlight,
      );
      expect(
        (await claimWith(
          503,
          'REQUEST_TIMEOUT',
          'availability',
          <String, Object?>{},
        ) as TestnetFaucetPending).reason,
        TestnetFaucetPendingReason.timedOut,
      );
    });

    // Decision 0158 · a pending answer keeps its Idempotency-Key.
    test('a pending claim keeps its key and the retry replays it; a resolved '
        'one lets it go', () async {
      final adapter = _ScriptedAdapter(<(int, Map<String, Object?>)>[
        (
          409,
          _error('RESOURCE_CONFLICT', 'conflict', <String, Object?>{
            'reasonCode': 'TESTNET_FAUCET_IN_FLIGHT',
          }),
        ),
        (503, _error('REQUEST_TIMEOUT', 'availability', <String, Object?>{})),
        (201, grantBody()),
        (201, grantBody()),
      ]);
      final keyring = LoopV2CommandKeyring();
      final gateway = _gateway(adapter, keyring);

      expect(
        await gateway.claim(walletId: s5WalletId),
        isA<TestnetFaucetPending>(),
      );
      final first = adapter.keys.single;
      expect(keyring.peek('testnet:faucet:$s5WalletId'), first);

      expect(
        await gateway.claim(walletId: s5WalletId),
        isA<TestnetFaucetPending>(),
      );
      expect(
        await gateway.claim(walletId: s5WalletId),
        isA<TestnetFaucetGranted>(),
      );
      // Three requests, one logical claim, one key.
      expect(adapter.keys, <String?>[first, first, first]);
      expect(keyring.peek('testnet:faucet:$s5WalletId'), isNull);

      // The next claim is a new one.
      await gateway.claim(walletId: s5WalletId);
      expect(adapter.keys.last, isNot(first));
    });

    test(
      'a status read that shows the cooldown lets a pending key go',
      () async {
        final adapter = _ScriptedAdapter(<(int, Map<String, Object?>)>[
          (
            409,
            _error('RESOURCE_CONFLICT', 'conflict', <String, Object?>{
              'reasonCode': 'TESTNET_FAUCET_IN_FLIGHT',
            }),
          ),
          (200, statusBody()),
          (
            200,
            statusBody()
              ..['available'] = false
              ..['nextAvailableAt'] = '2026-10-13T08:00:00.000Z',
          ),
        ]);
        final keyring = LoopV2CommandKeyring();
        final gateway = _gateway(adapter, keyring);
        const signature = 'testnet:faucet:$s5WalletId';

        await gateway.claim(walletId: s5WalletId);
        final key = keyring.peek(signature);
        expect(key, isNotNull);
        // Still claimable: the grant is not recorded yet, the key stays.
        await gateway.loadStatus(walletId: s5WalletId);
        expect(keyring.peek(signature), key);
        // Cooling: the grant is recorded, so the key is let go.
        await gateway.loadStatus(walletId: s5WalletId);
        expect(keyring.peek(signature), isNull);
      },
    );

    test('502 transfer failed stays a refusal with its reason', () async {
      await expectLater(
        claimWith(
          502,
          'PROVIDER_UNREACHABLE',
          'availability',
          <String, Object?>{'reasonCode': 'TESTNET_FAUCET_TRANSFER_FAILED'},
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.detailsSafe?.reasonCode,
            'reasonCode',
            'TESTNET_FAUCET_TRANSFER_FAILED',
          ),
        ),
      );
    });

    test(
      'the read admits 409 RESOURCE_CONFLICT and 502 PROVIDER_UNREACHABLE',
      () {
        expect(
          DioLoopV2TestnetFaucetApi.readErrors[409],
          contains('RESOURCE_CONFLICT'),
        );
        expect(
          DioLoopV2TestnetFaucetApi.readErrors[502],
          contains('PROVIDER_UNREACHABLE'),
        );
        expect(
          DioLoopV2TestnetFaucetApi.writeErrors[409],
          contains('RESOURCE_CONFLICT'),
        );
        expect(
          DioLoopV2TestnetFaucetApi.writeErrors[502],
          contains('PROVIDER_UNREACHABLE'),
        );
      },
    );

    test('503 operator low and 403 not owned stay refusals with their '
        'reason', () async {
      for (final (status, code, category, reason)
          in <(int, String, String, String)>[
            (
              503,
              'CAPABILITY_UNAVAILABLE',
              'availability',
              'TESTNET_FAUCET_OPERATOR_LOW',
            ),
            (
              403,
              'PERMISSION_DENIED',
              'authorization',
              'TESTNET_FAUCET_WALLET_NOT_OWNED',
            ),
          ]) {
        await expectLater(
          _api(
            _Adapter(
              status,
              _error(code, category, <String, Object?>{'reasonCode': reason}),
            ),
          ).postClaim(
            accessToken: 'token',
            clientVersion: s5ClientVersion,
            idempotencyKey: s5RequestId,
            walletId: s5WalletId,
          ),
          throwsA(
            isA<LoopBackendFailure>()
                .having((failure) => failure.code, 'code', code)
                .having(
                  (failure) => failure.detailsSafe?.reasonCode,
                  'reasonCode',
                  reason,
                ),
          ),
        );
      }
    });
  });

  group('wallet tab entry', () {
    testWidgets('capability unavailable: no entry, no placeholder', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        overrides: [
          testnetFaucetGatewayProvider.overrideWithValue(
            FakeTestnetFaucetGateway(
              status: faucetStatus(walletId: s5WalletId),
            ),
          ),
        ],
      );
      expect(key('wallet-receive-entry'), findsOneWidget);
      expect(key('wallet-faucet-group'), findsNothing);
      expect(key('wallet-faucet-entry'), findsNothing);
      expect(find.text(testnetFaucetTitle), findsNothing);
    });

    testWidgets('capability available but no adapter mounted: no entry', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        meta: s5MetaSnapshot(
          testnetFaucet: LoopV2CapabilityAvailability.available,
        ),
      );
      expect(key('wallet-faucet-entry'), findsNothing);
    });

    testWidgets('available: the entry, the sheet, 正在发放, the two hashes and '
        'a balance refresh', (tester) async {
      final wallet = FakeWalletReadGateway();
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimResult: faucetGranted(
          walletId: s5WalletId,
          grantedAt: DateTime.now().toUtc(),
        ),
      )..claimGate = Completer<void>();
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: wallet,
        meta: s5MetaSnapshot(
          testnetFaucet: LoopV2CapabilityAvailability.available,
        ),
        overrides: [testnetFaucetGatewayProvider.overrideWithValue(faucet)],
      );
      expect(key('wallet-faucet-entry'), findsOneWidget);
      expect(find.text(testnetFaucetEntrySubtitle), findsOneWidget);
      // Under the balance block, above the asset list.
      expect(
        tester.getRect(key('wallet-faucet-entry')).top,
        greaterThan(tester.getRect(key('wallet-receive-entry')).bottom),
      );

      await tester.tap(key('wallet-faucet-entry'));
      await tester.pumpAndSettle();
      expect(key('testnet-faucet-sheet'), findsOneWidget);
      expect(faucet.statusReads, <String>[s5WalletId]);
      expect(find.text('0xabcd…1234'), findsOneWidget);
      expect(find.textContaining('0.02 tBNB 和 500 tUSD1'), findsOneWidget);
      final readsBefore = wallet.balanceReads;

      await tester.tap(key('testnet-faucet-claim'));
      await tester.pump();
      expect(find.text(testnetFaucetBusyLabel), findsOneWidget);
      expect(
        tester.widget<LoopButton>(key('testnet-faucet-claim')).onPressed,
        isNull,
      );
      faucet.claimGate!.complete();
      await tester.pumpAndSettle();

      expect(faucet.claims, <String>[s5WalletId]);
      expect(key('testnet-faucet-granted'), findsOneWidget);
      expect(key('testnet-faucet-tx-tBNB'), findsOneWidget);
      expect(key('testnet-faucet-tx-tUSD1'), findsOneWidget);
      expect(find.text('0x1111…1111'), findsOneWidget);
      expect(find.text('0x2222…2222'), findsOneWidget);
      expect(key('testnet-faucet-copy-link-tBNB'), findsOneWidget);
      expect(wallet.balanceReads, greaterThan(readsBefore));
      // The button is off until the server's next time.
      final next = faucet.claimResult! as TestnetFaucetGranted;
      expect(
        find.text('下次可领 ${testnetFaucetNextLabel(next.nextAvailableAt)}'),
        findsOneWidget,
      );
      expect(
        tester.widget<LoopButton>(key('testnet-faucet-claim')).onPressed,
        isNull,
      );
    });

    testWidgets('a cooling wallet: the button is grey with 下次可领 HH:mm', (
      tester,
    ) async {
      final next = DateTime.now().toUtc().add(const Duration(hours: 3));
      await _openSheet(
        tester,
        FakeTestnetFaucetGateway(
          status: faucetStatus(
            walletId: s5WalletId,
            available: false,
            nextAvailableAt: next,
          ),
        ),
      );
      final label = '下次可领 ${testnetFaucetNextLabel(next)}';
      expect(find.text(label), findsOneWidget);
      expect(RegExp(r'\d\d:\d\d$').hasMatch(label), isTrue);
      expect(
        tester.widget<LoopButton>(key('testnet-faucet-claim')).onPressed,
        isNull,
      );
    });

    testWidgets('429 cooldown: the sentence and the time', (tester) async {
      final next = DateTime.now().toUtc().add(const Duration(hours: 5));
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimResult: TestnetFaucetCoolingDown(nextAvailableAt: next),
      );
      await _openSheet(tester, faucet);
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      final time = testnetFaucetNextLabel(next);
      expect(
        lineText(tester, 'testnet-faucet-cooldown'),
        '这个钱包 24 小时内已经领过，下次可领 $time',
      );
      expect(find.text('下次可领 $time'), findsOneWidget);
      // The line is the shared warn notice, never the v1 warning yellow.
      final notice = tester.widget<LoopNotice>(key('testnet-faucet-cooldown'));
      expect(notice.tone, LoopNoticeTone.warn);
      final colours = tester
          .widgetList<Text>(
            find.descendant(
              of: key('testnet-faucet-cooldown'),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.style?.color);
      expect(colours, isNot(contains(LoopColors.warning)));
    });

    // Decision 0158 · the period on the sheet is the server's cooldown.
    testWidgets('a one-hour cooldown is said as one hour', (tester) async {
      final next = DateTime.now().toUtc().add(const Duration(minutes: 30));
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId, cooldownSeconds: 3600),
        claimResult: TestnetFaucetCoolingDown(nextAvailableAt: next),
      );
      await _openSheet(tester, faucet);
      expect(
        tester.widget<Text>(key('testnet-faucet-intro')).data,
        contains('每个内置钱包每 1 小时可以领一次'),
      );
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      expect(
        lineText(tester, 'testnet-faucet-cooldown'),
        '这个钱包 1 小时内已经领过，下次可领 ${testnetFaucetNextLabel(next)}',
      );
      // The sheet never says 24 hours (the balance rows' own 「24 小时」 move
      // line under the sheet is decision 0188's, not the faucet's period).
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('24 小时'),
        ),
        findsNothing,
      );
    });

    // Decision 0158 · the server grants only to the embedded wallet.
    testWidgets('an external active wallet has no faucet entry', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            value: s5Directory(activeWalletId: s5OtherWalletId),
          ),
        ),
        meta: s5MetaSnapshot(
          testnetFaucet: LoopV2CapabilityAvailability.available,
        ),
        overrides: [
          testnetFaucetGatewayProvider.overrideWithValue(
            FakeTestnetFaucetGateway(
              status: faucetStatus(walletId: s5OtherWalletId),
            ),
          ),
        ],
      );
      expect(key('wallet-screen'), findsOneWidget);
      expect(key('wallet-faucet-entry'), findsNothing);
    });

    testWidgets('partial: tBNB arrived, tUSD1 did not; its hash is shown', (
      tester,
    ) async {
      final wallet = FakeWalletReadGateway();
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimResult: const TestnetFaucetPartial(
          bnbTransactionHash: faucetBnbHash,
        ),
      );
      await _openSheet(tester, faucet, wallet: wallet);
      final readsBefore = wallet.balanceReads;
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      expect(
        lineText(tester, 'testnet-faucet-partial'),
        'tBNB 已到账，tUSD1 这次没成功，24 小时后可再领',
      );
      expect(key('testnet-faucet-tx-tBNB'), findsOneWidget);
      expect(key('testnet-faucet-tx-tUSD1'), findsNothing);
      expect(wallet.balanceReads, greaterThan(readsBefore));
    });

    testWidgets('operator low and not-owned refusals say their own sentence', (
      tester,
    ) async {
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimFailure: const LoopChainException(
          LoopChainFailureKind.unavailable,
          reasonCode: 'TESTNET_FAUCET_OPERATOR_LOW',
        ),
      );
      await _openSheet(tester, faucet);
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      expect(
        lineText(tester, 'testnet-faucet-failure'),
        testnetFaucetOperatorLowText,
      );

      faucet.claimFailure = const LoopChainException(
        LoopChainFailureKind.permissionDenied,
        reasonCode: 'TESTNET_FAUCET_WALLET_NOT_OWNED',
      );
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      expect(
        lineText(tester, 'testnet-faucet-failure'),
        testnetFaucetNotOwnedText,
      );
    });

    testWidgets('409 in flight: 正在发放 stays, the status is read every 3 s '
        'until the grant appears', (tester) async {
      final wallet = FakeWalletReadGateway();
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimResult: const TestnetFaucetPending(
          TestnetFaucetPendingReason.inFlight,
        ),
      );
      await _openSheet(tester, faucet, wallet: wallet);
      faucet.statusQueue.addAll(<TestnetFaucetStatus>[
        faucetStatus(walletId: s5WalletId),
        faucetStatusAfterGrant(
          walletId: s5WalletId,
          grantedAt: DateTime.now().toUtc(),
        ),
      ]);
      final readsBefore = wallet.balanceReads;
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pump();
      expect(find.text(testnetFaucetBusyLabel), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(faucet.statusReads, hasLength(2));
      expect(find.text(testnetFaucetBusyLabel), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(faucet.statusReads, hasLength(3));
      expect(faucet.claims, hasLength(1));
      expect(key('testnet-faucet-granted'), findsOneWidget);
      expect(key('testnet-faucet-tx-tUSD1'), findsOneWidget);
      expect(wallet.balanceReads, greaterThan(readsBefore));
    });

    testWidgets('409 in flight for 20 s: 结果稍后在这里查看, no second claim', (
      tester,
    ) async {
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimResult: const TestnetFaucetPending(
          TestnetFaucetPendingReason.inFlight,
        ),
      );
      await _openSheet(tester, faucet);
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pump();
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(seconds: 3));
      }
      await tester.pumpAndSettle();
      expect(faucet.claims, hasLength(1));
      // One read on opening, then six at 3 s and the last at 20 s.
      expect(faucet.statusReads, hasLength(8));
      expect(
        lineText(tester, 'testnet-faucet-pending'),
        testnetFaucetInFlightLaterText,
      );
      expect(find.text(testnetFaucetBusyLabel), findsNothing);
    });

    testWidgets('503 request timeout: read again, the grant shows as success; '
        'a partial read back says so', (tester) async {
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimResult: const TestnetFaucetPending(
          TestnetFaucetPendingReason.timedOut,
        ),
      );
      await _openSheet(tester, faucet);
      faucet.statusQueue.add(
        faucetStatusAfterGrant(
          walletId: s5WalletId,
          grantedAt: DateTime.now().toUtc(),
          usd1Hash: null,
        ),
      );
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      expect(faucet.statusReads, hasLength(2));
      expect(key('testnet-faucet-failure'), findsNothing);
      // Decision 0158: a record read back proves the tBNB was sent, not
      // that it arrived.
      expect(
        lineText(tester, 'testnet-faucet-partial'),
        'tBNB 已发出，tUSD1 这次没发；24 小时后可再领',
      );
      expect(find.textContaining('已到账'), findsNothing);
    });

    testWidgets('503 request timeout twice without a grant: 发放还在进行', (
      tester,
    ) async {
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimResult: const TestnetFaucetPending(
          TestnetFaucetPendingReason.timedOut,
        ),
      );
      await _openSheet(tester, faucet);
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pump();
      await tester.pump();
      expect(faucet.statusReads, hasLength(2));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(faucet.statusReads, hasLength(3));
      expect(faucet.claims, hasLength(1));
      expect(
        lineText(tester, 'testnet-faucet-pending'),
        testnetFaucetTimedOutLaterText,
      );
      expect(key('testnet-faucet-failure'), findsNothing);
    });

    testWidgets('submission unknown reads as an unconfirmed partial', (
      tester,
    ) async {
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimResult: TestnetFaucetPartial(
          bnbTransactionHash: faucetBnbHash,
          nextAvailableAt: DateTime.now().toUtc().add(const Duration(days: 1)),
          unconfirmed: true,
        ),
      );
      await _openSheet(tester, faucet);
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      expect(
        lineText(tester, 'testnet-faucet-partial'),
        'tBNB 已发出但还没确认，tUSD1 这次没发；24 小时后可再领',
      );
      expect(key('testnet-faucet-tx-tBNB'), findsOneWidget);
    });

    testWidgets('transfer failed: 这次没有发出，可以重试, and the button stays on', (
      tester,
    ) async {
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        claimFailure: const LoopChainException(
          LoopChainFailureKind.unexpected,
          reasonCode: 'TESTNET_FAUCET_TRANSFER_FAILED',
        ),
      );
      await _openSheet(tester, faucet);
      await tester.tap(key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      expect(lineText(tester, 'testnet-faucet-failure'), '这次没有发出，可以重试');
      expect(
        tester.widget<LoopButton>(key('testnet-faucet-claim')).onPressed,
        isNotNull,
      );
    });

    testWidgets('the status read: offline and permission each say so, retry '
        'reads again', (tester) async {
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: s5WalletId),
        statusFailure: const LoopChainException(LoopChainFailureKind.offline),
      );
      await _openSheet(tester, faucet);
      expect(key('testnet-faucet-offline'), findsOneWidget);
      expect(key('testnet-faucet-claim'), findsNothing);

      faucet.statusFailure = const LoopChainException(
        LoopChainFailureKind.permissionDenied,
        reasonCode: 'TESTNET_FAUCET_WALLET_NOT_OWNED',
      );
      await tester.tap(key('testnet-faucet-retry'));
      await tester.pumpAndSettle();
      expect(key('testnet-faucet-permission'), findsOneWidget);
      expect(find.text(testnetFaucetNotOwnedText), findsOneWidget);

      faucet.statusFailure = null;
      await tester.tap(key('testnet-faucet-retry'));
      await tester.pumpAndSettle();
      expect(faucet.statusReads, hasLength(3));
      expect(key('testnet-faucet-claim'), findsOneWidget);
    });
  });

  group('copy', () {
    test(
      'the next time is HH:mm in local time, with the day when not today',
      () {
        final now = DateTime(2026, 10, 12, 9);
        expect(
          testnetFaucetNextLabel(DateTime(2026, 10, 12, 18, 5), now: now),
          '18:05',
        );
        expect(
          testnetFaucetNextLabel(DateTime(2026, 10, 13, 7, 30), now: now),
          '明天 07:30',
        );
      },
    );

    test('every S156 reason code has its own sentence', () {
      String text(String code) => testnetFaucetFailureText(
        LoopChainException(LoopChainFailureKind.unavailable, reasonCode: code),
      );
      for (final code in <String>[
        'TESTNET_FAUCET_USD1_NOT_CONFIGURED',
        'TESTNET_FAUCET_RPC_NOT_CONFIGURED',
        'TESTNET_FAUCET_RUNTIME_UNAVAILABLE',
      ]) {
        expect(text(code), '测试币领取暂时不可用，稍后再试');
      }
      expect(text('TESTNET_FAUCET_USD1_UNAVAILABLE'), 'tUSD1 合约暂时不可用，稍后再试');
      expect(text('TESTNET_FAUCET_CHAIN_READ_FAILED'), '链上读数暂时取不到，稍后再试');
      expect(text('TESTNET_FAUCET_BUSY'), '正在给别人发放，几秒后再试');
      expect(text('TESTNET_FAUCET_TRANSFER_FAILED'), '这次没有发出，可以重试');
    });

    test('a partial grant is said by what did arrive', () {
      expect(
        testnetFaucetPartialText(
          const TestnetFaucetPartial(usd1TransactionHash: faucetUsd1Hash),
          cooldownSeconds: 86400,
        ),
        'tUSD1 已到账，tBNB 这次没成功，24 小时后可再领',
      );
      // Decision 0158: without the server's cooldown no period is named.
      expect(
        testnetFaucetPartialText(
          const TestnetFaucetPartial(usd1TransactionHash: faucetUsd1Hash),
        ),
        'tUSD1 已到账，tBNB 这次没成功，稍后可再领',
      );
      expect(
        testnetFaucetPartialText(
          const TestnetFaucetPartial(
            bnbTransactionHash: faucetBnbHash,
            readBack: true,
          ),
          cooldownSeconds: 86400,
        ),
        'tBNB 已发出，tUSD1 这次没发；24 小时后可再领',
      );
    });

    // Decision 0158 · the cooldown is the server's `cooldownSeconds`.
    test('the cooldown period is read from the server', () {
      expect(testnetFaucetCooldownText(86400), '24 小时');
      expect(testnetFaucetCooldownText(3 * 86400), '3 天');
      expect(testnetFaucetCooldownText(12 * 3600), '12 小时');
      expect(testnetFaucetCooldownText(1800), '30 分钟');
      expect(testnetFaucetCooldownText(45), '45 秒');
      expect(testnetFaucetClaimedText(3600), '这个钱包 1 小时内已经领过');
      expect(testnetFaucetClaimedText(null), '这个钱包最近已经领过');
      expect(
        testnetFaucetFailureText(
          const LoopChainException(
            LoopChainFailureKind.rateLimited,
            reasonCode: 'TESTNET_FAUCET_COOLDOWN',
          ),
          cooldownSeconds: 12 * 3600,
        ),
        '这个钱包 12 小时内已经领过，稍后再来',
      );
    });
  });
}

/// Opens the faucet sheet from the wallet tab.
Future<void> _openSheet(
  WidgetTester tester,
  FakeTestnetFaucetGateway faucet, {
  FakeWalletReadGateway? wallet,
}) async {
  await pumpS5Page(
    tester,
    const WalletScreen(),
    wallet: wallet ?? FakeWalletReadGateway(),
    meta: s5MetaSnapshot(testnetFaucet: LoopV2CapabilityAvailability.available),
    overrides: [testnetFaucetGatewayProvider.overrideWithValue(faucet)],
  );
  await tester.tap(find.byKey(const ValueKey<String>('wallet-faucet-entry')));
  await tester.pumpAndSettle();
}

DioLoopV2TestnetFaucetApi _api(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.example'));
  dio.httpClientAdapter = adapter;
  return DioLoopV2TestnetFaucetApi(dio);
}

Map<String, Object?> _error(
  String code,
  String category,
  Map<String, Object?> detailsSafe,
) => <String, Object?>{
  'code': code,
  'category': category,
  'retryable': false,
  'userMessageKey': 'errors.testnetFaucet.refused',
  'correlationId': s5RequestId,
  'detailsSafe': detailsSafe,
  'providerReferenceSafe': null,
};

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Map<String, Object?> body;
  RequestOptions? last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[s5RequestId],
        'content-type': <String>['application/json; charset=utf-8'],
      },
    );
  }
}

/// Answers each request with the next scripted response and records the
/// Idempotency-Key it carried.
final class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final List<(int, Map<String, Object?>)> script;
  final List<String?> keys = <String?>[];
  var _next = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST') {
      keys.add(options.headers['Idempotency-Key'] as String?);
    }
    final (status, body) = script[_next++];
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[s5RequestId],
        'content-type': <String>['application/json; charset=utf-8'],
      },
    );
  }
}

DioLoopV2TestnetFaucetGateway _gateway(
  _ScriptedAdapter adapter,
  LoopV2CommandKeyring keyring,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.example'));
  dio.httpClientAdapter = adapter;
  return DioLoopV2TestnetFaucetGateway(
    api: DioLoopV2TestnetFaucetApi(dio),
    clientMetadata: const LoopV2ClientMetadata(
      clientVersion: s5ClientVersion,
      platform: LoopV2Platform.android,
    ),
    session: LoopAuthenticatedSession(
      principalKey: 'did:privy:owner-1',
      bootstrapSession: LoopBootstrapSession(
        principalKey: 'did:privy:owner-1',
        accessTokens: _Tokens(),
        repository: _Bootstrap(),
      ),
      accessTokens: _Tokens(),
    ),
    keyring: keyring,
  );
}

final class _Tokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => 'token';
}

final class _Bootstrap implements LoopBootstrapRepository {
  @override
  Future<LoopBootstrapIdentity> bootstrap({
    required String accessToken,
  }) async => const LoopBootstrapIdentity(
    loopUserId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
    streamUserId: 'loop_6d12a86e413447e69312c5ef75a30f55',
  );
}

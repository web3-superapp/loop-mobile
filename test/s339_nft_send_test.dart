// S339 · decision 0267 (docs/53): 发送 LOOP 项目 NFT — the entry on the medal
// page, the reused recipient step, the confirm page, the send-nft codec, the
// refusal lines, the closed switch and the holdings refresh. Every value is
// 测试专用.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_screen.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/nft_send.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/tx_result_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_wallet_intents_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/launch2_fixtures.dart';
import 'support/s285_page.dart';
import 'support/s339_nft_send_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';
import 'support/s7_page_harness.dart';

const _accessToken = 'privy-access-token';
const _idempotencyKey = '9d0e1f2a-3b4c-4d5e-8f6a-7b8c9d0e1f2a';

DateTime _fresh() => DateTime.utc(2026, 9, 9, 13, 35, 45);

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Override _launch2Visible() => loopFeatureSwitchesProvider.overrideWithValue(
  const LoopFeatureSwitchValues(launch2Visible: true),
);

SendDraft _confirmDraft() =>
    SendDraft.nft(s339Target, recipientAddress: s6RecipientChecksum);

/// A 422 / 503 whose `detailsSafe` names [reasonCode].
DioException _refusal(
  RequestOptions options, {
  required int statusCode,
  required String code,
  required String reasonCode,
}) => DioException(
  requestOptions: options,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: <String, Object?>{
      'code': code,
      'category': statusCode == 503 ? 'availability' : 'validation',
      'retryable': statusCode == 503,
      'userMessageKey': 'errors.wallet.nftSend',
      'correlationId': s5RequestId,
      'detailsSafe': <String, Object?>{'reasonCode': reasonCode},
      'providerReferenceSafe': null,
    },
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': const <String>['no-store'],
      'x-request-id': const <String>[s5RequestId],
    }),
  ),
);

Future<LoopChainException> _sendNftFailure(DioException error) async {
  final api = DioLoopV2WalletIntentsApi(
    s5Dio((options, handler) => handler.reject(error.copyWith())),
  );
  try {
    await api.prepareSendNft(
      accessToken: _accessToken,
      clientVersion: s5ClientVersion,
      idempotencyKey: _idempotencyKey,
      walletId: s5WalletId,
      chainId: s339Chain,
      contractAddress: l2Nft,
      tokenId: s339TokenId,
      recipientAddress: s6RecipientChecksum,
    );
  } on LoopBackendFailure catch (failure) {
    return loopChainExceptionForV2(failure, write: true);
  }
  fail('expected a refusal');
}

/// The closed switch, as a session that already heard it.
final class _Disabled extends NftSendDisabled {
  @override
  bool build() => true;
}

/// Watches the positions read the way the wallet's NFT tab does, so a
/// refresh has somebody to re-read for.
class _PositionsWatcher extends ConsumerWidget {
  const _PositionsWatcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(launch2PositionsControllerProvider);
    return child;
  }
}

Launch2InstanceDetail _medalDetail({int held = 1}) => l2Detail(
  stage: 'public',
  viewer: l2ViewerJson(held: held),
);

Future<void> _pumpMedal(
  WidgetTester tester, {
  required Launch2InstanceDetail detail,
  required void Function(SendNftTarget) onSend,
  List<Override> extra = const <Override>[],
}) => pumpS7Page(
  tester,
  Launch2NftScreen(instanceId: l2InstanceA, onSendNft: onSend),
  meta: s285Meta(),
  size: const Size(390, 1600),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(S285Launch2(detail: detail)),
    launch2ClockProvider.overrideWithValue(() => l2Now),
    launch2PollingProvider.overrideWithValue(
      const Launch2Polling(
        detailInterval: Duration(hours: 1),
        tradingInterval: Duration(hours: 1),
      ),
    ),
    _launch2Visible(),
    ...extra,
  ],
);

void main() {
  group('codec · send_nft', () {
    test('decodes a Launch-chain NFT send whose payload is the reviewed '
        'safeTransferFrom', () {
      final intent = LoopV2IntentCodec.intent(s339IntentBody());
      expect(intent.kind, LoopIntentKind.sendNft);
      expect(intent.chainId, s339Chain);
      expect(intent.review.nft!.contractAddress, l2Nft);
      expect(intent.review.nft!.tokenId, s339TokenId);
      expect(intent.review.nft!.projectName, 'Frog Launch');
      expect(intent.review.recipient!.checksumAddress, s6RecipientChecksum);
      expect(intent.payloadMatchesReview, isTrue);
      final signing = MoneyActionSigner.toSigningIntent(intent)!;
      expect(signing.kind, IntentKind.nftTransfer);
      expect(signing.chainIsPermitted, isTrue);
      final fields = <String, String>{
        for (final field in moneyActionFields(intent)) field.label: field.value,
      };
      expect(fields['操作'], '确认发送 NFT');
      expect(fields['NFT'], 'Frog Launch #7');
      expect(fields['合约'], l2Nft);
      expect(fields['收款方'], s6RecipientChecksum);
      expect(fields['最高网络费'], '0.0000020775 BNB');
    });

    test('without an nft block the contract is the asset address and the '
        'token id the call argument; unknown review keys are ignored', () {
      final intent = LoopV2IntentCodec.intent(
        s339IntentBody(
          nftBlock: false,
          includeAsset: true,
          includeBalance: false,
          extraReview: <String, Object?>{'collection': 'later'},
        ),
      );
      expect(intent.review.nft!.contractAddress, l2Nft);
      expect(intent.review.nft!.tokenId, s339TokenId);
      expect(intent.review.balance, isNull);
      expect(intent.payloadMatchesReview, isTrue);
    });

    test('two token ids that disagree are an invalid payload', () {
      expect(
        () => LoopV2IntentCodec.intent(
          s339IntentBody(argsTokenId: '7', nftTokenId: '8'),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('call data for another token or contract never matches', () {
      expect(
        LoopV2IntentCodec.intent(
          s339IntentBody(data: s339TransferData(tokenId: '8')),
        ).payloadMatchesReview,
        isFalse,
      );
      expect(
        LoopV2IntentCodec.intent(s339IntentBody(to: l2Curve))
            .payloadMatchesReview,
        isFalse,
      );
    });

    test('safeTransferFrom in a fungible send review is refused', () {
      final body = s6IntentBody(
        decodedCall: <String, Object?>{
          'functionName': 'safeTransferFrom',
          'selector': '0x42842e0e',
          'args': <String, Object?>{'tokenId': '7'},
        },
      );
      expect(
        () => LoopV2IntentCodec.intent(body),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an intent list skips a kind this build does not know and keeps '
        'every known one, send_nft included', () {
      final unknown = s6IntentBody(intentId: s6OtherIntentId)
        ..['kind'] = 'send_bundle';
      (unknown['review']! as Map<String, Object?>)['kind'] = 'send_bundle';
      final page = LoopV2IntentCodec.intentPage(<String, Object?>{
        'items': <Object?>[unknown, s6IntentBody(), s339IntentBody()],
        'nextCursor': null,
        'contractVersion': '2.0',
      });
      expect(page.items.map((item) => item.kind), <LoopIntentKind>[
        LoopIntentKind.send,
        LoopIntentKind.sendNft,
      ]);
    });
  });

  group('transport · POST /v2/wallet-intents/send-nft', () {
    test('the body names wallet, chain, contract, decimal token id and '
        'recipient, with the write headers and one key', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletIntentsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(
            s5Response(options, s339IntentBody(), statusCode: 201),
          );
        }),
      );
      final intent = await api.prepareSendNft(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        idempotencyKey: _idempotencyKey,
        walletId: s5WalletId,
        chainId: s339Chain,
        contractAddress: l2Nft,
        tokenId: s339TokenId,
        recipientAddress: s6RecipientChecksum,
      );
      expect(intent.kind, LoopIntentKind.sendNft);
      expect(captured!.method, 'POST');
      expect(captured!.path, '/v2/wallet-intents/send-nft');
      expect(captured!.headers['authorization'], 'Bearer $_accessToken');
      expect(captured!.headers['x-loop-contract-version'], '2.0');
      expect(captured!.headers['idempotency-key'], _idempotencyKey);
      expect(captured!.data, <String, Object?>{
        'walletId': s5WalletId,
        'chainId': 'eip155:97',
        'contractAddress': l2Nft,
        'tokenId': '7',
        'recipientAddress': s6RecipientChecksum,
      });
      expect(
        (captured!.data as Map<String, Object?>)['tokenId'],
        isA<String>(),
      );
    });

    test('a replay (200) answers the original intent', () async {
      final api = DioLoopV2WalletIntentsApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s339IntentBody())),
        ),
      );
      final intent = await api.prepareSendNft(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        idempotencyKey: _idempotencyKey,
        walletId: s5WalletId,
        chainId: s339Chain,
        contractAddress: l2Nft,
        tokenId: s339TokenId,
        recipientAddress: s6RecipientChecksum,
      );
      expect(intent.intentId, s6IntentId);
    });

    test('a token id that is not a decimal string never leaves the client', () {
      var sent = false;
      final api = DioLoopV2WalletIntentsApi(
        s5Dio((options, handler) {
          sent = true;
          handler.resolve(s5Response(options, s339IntentBody()));
        }),
      );
      for (final bad in <String>['0x7', '07', '-1', '7.0', '']) {
        expect(
          () => api.prepareSendNft(
            accessToken: _accessToken,
            clientVersion: s5ClientVersion,
            idempotencyKey: _idempotencyKey,
            walletId: s5WalletId,
            chainId: s339Chain,
            contractAddress: l2Nft,
            tokenId: bad,
            recipientAddress: s6RecipientChecksum,
          ),
          throwsA(isA<LoopBackendFailure>()),
          reason: bad,
        );
      }
      expect(sent, isFalse);
    });

    test(
      'the four 422 refusals and the closed switch keep their reason',
      () async {
        for (final reason in <String>[
          NftSendReason.notOwned,
          NftSendReason.contractUnsupported,
          NftSendReason.recipientRejects,
          NftSendReason.recipientSelf,
        ]) {
          final failure = await _sendNftFailure(
            _refusal(
              RequestOptions(path: '/v2/wallet-intents/send-nft'),
              statusCode: 422,
              code: 'VALIDATION_FAILED',
              reasonCode: reason,
            ),
          );
          expect(failure.kind, LoopChainFailureKind.validationFailed);
          expect(failure.reasonCode, reason);
        }
        final closed = await _sendNftFailure(
          _refusal(
            RequestOptions(path: '/v2/wallet-intents/send-nft'),
            statusCode: 503,
            code: 'CAPABILITY_UNAVAILABLE',
            reasonCode: NftSendReason.disabled,
          ),
        );
        expect(closed.kind, LoopChainFailureKind.unavailable);
        expect(nftSendIsDisabled(closed), isTrue);
      },
    );
  });

  group('refusal lines', () {
    test('each NFT refusal is one short line', () {
      String? text(String? reason, [LoopChainFailureKind? kind]) =>
          nftSendFailureText(
            LoopChainException(
              kind ?? LoopChainFailureKind.validationFailed,
              reasonCode: reason,
            ),
          );
      expect(text(NftSendReason.notOwned), '这枚 NFT 已不在你的钱包');
      expect(text(NftSendReason.contractUnsupported), '暂不支持发送这个 NFT');
      expect(text(NftSendReason.recipientRejects), '收款地址不接收这枚 NFT');
      expect(text(NftSendReason.recipientSelf), '不能发送给自己');
      expect(
        text(NftSendReason.disabled, LoopChainFailureKind.unavailable),
        '暂不支持发送 NFT',
      );
      expect(
        text(null, LoopChainFailureKind.insufficientBalance),
        endsWith('手续费不足，充值后再试'),
      );
      expect(
        text(null, LoopChainFailureKind.idempotencyConflict),
        '这笔发送已提交过，请查看最新状态',
      );
      expect(text(null, LoopChainFailureKind.offline), isNull);
    });
  });

  group('entry · 共识勋章', () {
    testWidgets('a held NFT draws 发送 beside the page action and opens the '
        'flow with the NFT the read names', (tester) async {
      final sent = <SendNftTarget>[];
      await _pumpMedal(tester, detail: _medalDetail(), onSend: sent.add);
      expect(_key('launch2-nft-send'), findsOneWidget);
      expect(_key('launch2-nft-mint'), findsOneWidget);
      await tester.tap(_key('launch2-nft-send'));
      await tester.pump();
      expect(sent, hasLength(1));
      expect(sent.single.walletId, l2WalletId);
      expect(sent.single.chainId, 'eip155:97');
      expect(sent.single.contractAddress, l2Nft);
      expect(sent.single.tokenIdText, '1');
      expect(sent.single.instanceId, l2InstanceA);
      await drainS285(tester);
    });

    testWidgets('nothing held: no 发送', (tester) async {
      await _pumpMedal(
        tester,
        detail: _medalDetail(held: 0),
        onSend: (_) => fail('no send'),
      );
      expect(_key('launch2-nft-send'), findsNothing);
      expect(_key('launch2-nft-mint'), findsOneWidget);
      await drainS285(tester);
    });

    testWidgets('a closed switch answers the tap with a toast and opens '
        'nothing', (tester) async {
      final sent = <SendNftTarget>[];
      await _pumpMedal(
        tester,
        detail: _medalDetail(),
        onSend: sent.add,
        extra: <Override>[nftSendDisabledProvider.overrideWith(_Disabled.new)],
      );
      await tester.tap(_key('launch2-nft-send'));
      await tester.pump();
      expect(find.text('暂不支持发送 NFT'), findsOneWidget);
      expect(sent, isEmpty);
      await drainS285(tester);
    });
  });

  group('step 1 · the reused recipient step', () {
    testWidgets('the NFT row, two steps, the preflight, scan and paste — and '
        '下一步 opens the confirm page with the checked address', (tester) async {
      final routes = <(String, Object?)>[];
      await pumpS6Page(
        tester,
        SendFlowScreen(
          initialDraft: SendDraft.nft(s339Target),
          onNavigate: (location, {extra}) => routes.add((location, extra)),
          onScan: () async => s6RecipientChecksum,
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );
      expect(find.text('发送 NFT'), findsOneWidget);
      expect(_key('send-nft-summary'), findsOneWidget);
      expect(find.text('FROG #7'), findsOneWidget);
      expect(_key('send-step-segment-2'), findsOneWidget);
      expect(_key('send-step-segment-3'), findsNothing);
      expect(_key('send-recipient-paste'), findsOneWidget);
      await tester.tap(_key('send-recipient-scan'));
      await tester.pumpAndSettle();
      expect(_key('send-recipient-checks'), findsOneWidget);
      await tester.tap(_key('send-address-next'));
      await tester.pump();
      expect(routes.single.$1, '/wallet/send/confirm');
      final draft = routes.single.$2! as SendDraft;
      expect(draft.nft, same(s339Target));
      expect(draft.recipientAddress, s6RecipientChecksum);
      expect(draft.amount, isNull);
      expect(draft.isComplete, isTrue);
    });
  });

  group('confirm · 确认发送 NFT', () {
    testWidgets('loading: the NFT, the recipient and the network before the '
        'server answers', (tester) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _confirmDraft(), clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(preparePending: true),
        settle: false,
      );
      await tester.pump();
      expect(find.text('确认发送 NFT'), findsOneWidget);
      expect(_key('send-nft-draft'), findsOneWidget);
      expect(_key('send-nft-review-最高网络费'), findsOneWidget);
      expect(find.text('还没有读到'), findsOneWidget);
      expect(_key('send-confirm-sign'), findsNothing);
    });

    testWidgets('the review: picture, project name, #tokenId, recipient, '
        'network, fee; no amount; prepare got the NFT', (tester) async {
      final intents = FakeWalletIntentsGateway(prepared: s339Intent());
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _confirmDraft(), clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: intents,
      );
      expect(intents.nftSends.single, (
        walletId: s5WalletId,
        chainId: s339Chain,
        contractAddress: l2Nft,
        tokenId: '7',
        recipientAddress: s6RecipientChecksum,
      ));
      expect(_key('send-nft-review'), findsOneWidget);
      expect(_key('send-nft-picture'), findsOneWidget);
      expect(find.text('Frog Launch'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(_key('send-nft-review-收款方'), findsOneWidget);
      expect(_key('send-nft-review-网络'), findsOneWidget);
      expect(_key('send-nft-review-最高网络费'), findsOneWidget);
      expect(_key('send-nft-review-合约'), findsOneWidget);
      expect(find.text('数量'), findsNothing);
      expect(_key('send-confirm-arrival'), findsNothing);
      final sign = tester.widget<LoopButton>(_key('send-confirm-sign'));
      expect(sign.onPressed, isNotNull);
    });

    for (final (reason, line, retry) in <(String, String, bool)>[
      (NftSendReason.notOwned, '这枚 NFT 已不在你的钱包', false),
      (NftSendReason.contractUnsupported, '暂不支持发送这个 NFT', false),
      (NftSendReason.recipientRejects, '收款地址不接收这枚 NFT', false),
      (NftSendReason.recipientSelf, '不能发送给自己', false),
    ]) {
      testWidgets('422 $reason: 「$line」', (tester) async {
        await pumpS6Page(
          tester,
          SendConfirmScreen(draft: _confirmDraft(), clock: _fresh),
          wallet: FakeWalletReadGateway(),
          intents: FakeWalletIntentsGateway(
            prepareException: LoopChainException(
              LoopChainFailureKind.validationFailed,
              reasonCode: reason,
            ),
          ),
        );
        expect(_key('send-nft-failure-$reason'), findsOneWidget);
        expect(find.text(line), findsOneWidget);
        expect(find.text('重试'), retry ? findsOneWidget : findsNothing);
        expect(_key('send-confirm-sign'), findsNothing);
      });
    }

    testWidgets('not enough native coin for the fee, and an idempotency '
        'conflict, are short lines too', (tester) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _confirmDraft(), clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareException: const LoopChainException(
            LoopChainFailureKind.insufficientBalance,
          ),
        ),
      );
      expect(_key('send-nft-failure-insufficientBalance'), findsOneWidget);
      expect(find.textContaining('手续费不足，充值后再试'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _confirmDraft(), clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareException: const LoopChainException(
            LoopChainFailureKind.idempotencyConflict,
          ),
        ),
      );
      expect(find.text('这笔发送已提交过，请查看最新状态'), findsOneWidget);
    });

    testWidgets('503 NFT_SEND_DISABLED: the toast, the line, and the session '
        'remembers it for the entry', (tester) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _confirmDraft(), clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareException: const LoopChainException(
            LoopChainFailureKind.unavailable,
            reasonCode: NftSendReason.disabled,
          ),
        ),
      );
      expect(find.text('暂不支持发送 NFT'), findsNWidgets(2));
      final container = ProviderScope.containerOf(
        tester.element(_key('send-confirm-screen')),
      );
      expect(container.read(nftSendDisabledProvider), isTrue);
    });

    testWidgets('offline, refused by policy and unavailable keep the shared '
        'states', (tester) async {
      for (final (kind, key) in <(LoopChainFailureKind, String)>[
        (LoopChainFailureKind.offline, 'send-confirm-state-offline'),
        (LoopChainFailureKind.permissionDenied, 'send-confirm-permission'),
        (LoopChainFailureKind.unavailable, 'send-confirm-state-unavailable'),
        (LoopChainFailureKind.readFailed, 'send-confirm-state-error'),
      ]) {
        await pumpS6Page(
          tester,
          SendConfirmScreen(draft: _confirmDraft(), clock: _fresh),
          wallet: FakeWalletReadGateway(),
          intents: FakeWalletIntentsGateway(
            prepareException: LoopChainException(kind),
          ),
        );
        expect(_key(key), findsOneWidget, reason: kind.name);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('an intent for another token is not shown or signed', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(
          draft: SendDraft.nft(
            SendNftTarget(
              walletId: s5WalletId,
              chainId: s339Chain,
              contractAddress: l2Nft,
              tokenId: BigInt.from(8),
              ticker: 'FROG',
            ),
            recipientAddress: s6RecipientChecksum,
          ),
          clock: _fresh,
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(prepared: s339Intent()),
      );
      expect(_key('send-nft-review'), findsNothing);
      expect(_key('send-confirm-sign'), findsNothing);
    });

    testWidgets('signed: the device broadcasts, the result page opens and the '
        'shown Launch holdings are read again', (tester) async {
      final launch2 = S285Launch2(
        detail: _medalDetail(),
        positions: s285Value(l2Positions()),
      );
      final signing = RecordingSigningGateway();
      final intents = FakeWalletIntentsGateway(prepared: s339Intent());
      final routes = <String>[];
      await pumpS6Page(
        tester,
        _PositionsWatcher(
          child: SendConfirmScreen(
            draft: _confirmDraft(),
            clock: _fresh,
            onNavigate: (location, {extra}) => routes.add(location),
          ),
        ),
        wallet: FakeWalletReadGateway(),
        intents: intents,
        signing: signing,
        overrides: <Override>[
          launch2GatewayProvider.overrideWithValue(launch2),
          _launch2Visible(),
        ],
      );
      final readsBefore = launch2.positionReads;
      await tester.tap(_key('send-confirm-sign'));
      await tester.pumpAndSettle();
      expect(_key('money-sign-sheet'), findsOneWidget);
      expect(find.text('Frog Launch #7'), findsOneWidget);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(signing.handoffs.single.kind, IntentKind.nftTransfer);
      expect(signing.handoffs.single.chainId, s339Chain);
      expect(intents.reportCalls, 1);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(routes, <String>['/wallet/tx/result?intentId=$s6IntentId']);
      expect(launch2.positionReads, greaterThan(readsBefore));
    });
  });

  group('tx-result', () {
    testWidgets('a confirmed fungible send leaves the Launch holdings alone', (
      tester,
    ) async {
      final launch2 = S285Launch2(
        detail: _medalDetail(),
        positions: s285Value(l2Positions()),
      );
      await pumpS6Page(
        tester,
        const _PositionsWatcher(
          child: TransactionResultScreen(intentId: s6IntentId),
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          reported: s6Intent(state: 'confirmed'),
        ),
        overrides: <Override>[
          launch2GatewayProvider.overrideWithValue(launch2),
          _launch2Visible(),
        ],
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('发送已确认'), findsOneWidget);
      expect(launch2.positionReads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a confirmed NFT send re-reads the shown Launch holdings', (
      tester,
    ) async {
      final launch2 = S285Launch2(
        detail: _medalDetail(),
        positions: s285Value(l2Positions()),
      );
      final confirmed = LoopV2IntentCodec.intent(
        s339IntentBody(state: 'confirmed'),
      );
      await pumpS6Page(
        tester,
        const _PositionsWatcher(
          child: TransactionResultScreen(intentId: s6IntentId),
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(reported: confirmed),
        overrides: <Override>[
          launch2GatewayProvider.overrideWithValue(launch2),
          _launch2Visible(),
        ],
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('发送 NFT已确认'), findsOneWidget);
      // Nothing else reads the positions here: the one read is the refresh.
      expect(launch2.positionReads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/account/account_screens.dart'
    show walletAutomaticRecoveryEvidence;
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s8_fixtures.dart';
import 'support/s8_harness.dart';

/// Client decision 0156 §2: `GET /v2/security/capabilities?projection=current`
/// (loop-api decision 0129 §4) and what the security center makes of it.
void main() {
  group('codec', () {
    Future<LoopSecurityCapabilities> decode(
      Map<String, Object?> body, {
      void Function(RequestOptions options)? onRequest,
    }) =>
        DioLoopV2SecurityApi(
          s8Dio((options, handler) {
            onRequest?.call(options);
            handler.resolve(s8Response(options, body));
          }),
        ).getCapabilities(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
        );

    test('asks for the current projection, and only that', () async {
      RequestOptions? captured;
      await decode(_currentBody(), onRequest: (options) => captured = options);
      expect(captured!.uri.path, '/v2/security/capabilities');
      expect(captured!.uri.queryParameters, <String, String>{
        'projection': 'current',
      });
    });

    test('decodes the current projection', () async {
      final capabilities = await decode(_currentBody());
      final mfa = capabilities[LoopSecurityCapabilityId.mfa]!;
      expect(mfa.isAvailable, isTrue);
      expect(mfa.reasonCode, isNull);
      expect(mfa.evidenceReasonCode, 'PRIVY_MFA_CLIENT_TOTP');
      expect(mfa.evidenceReference, startsWith('S60a:'));
      final recovery = capabilities[LoopSecurityCapabilityId.autoRecovery]!;
      expect(recovery.isAvailable, isTrue);
      expect(recovery.evidenceReference, _autoRecoveryReference);
      final keyExport = capabilities[LoopSecurityCapabilityId.keyExport]!;
      expect(keyExport.isAvailable, isFalse);
      expect(keyExport.reasonCode, 'PRIVY_KEY_EXPORT_EVIDENCE_PENDING');
      expect(keyExport.evidenceReference, isNull);
    });

    test('still decodes the default (all-pending) projection', () async {
      final capabilities = await decode(s8CapabilitiesBody());
      expect(capabilities.items.every((item) => !item.isAvailable), isTrue);
      expect(
        capabilities[LoopSecurityCapabilityId.mfa]!.reasonCode,
        'PRIVY_MFA_EVIDENCE_PENDING',
      );
    });

    test('a passkey without a relying party stays unavailable', () async {
      final body = _currentBody(passkeyAvailable: false);
      final capabilities = await decode(body);
      final passkey = capabilities[LoopSecurityCapabilityId.passkey]!;
      expect(passkey.isAvailable, isFalse);
      expect(passkey.reasonCode, 'PASSKEY_RELYING_PARTY_NOT_CONFIGURED');
    });

    final badShapes = <String, void Function(Map<String, Object?> item)>{
      'available with a reason': (item) => item['reasonCode'] = 'X_PENDING',
      'available without the reason key': (item) => item.remove('reasonCode'),
      'available with pending evidence': (item) =>
          (item['evidence']! as Map<String, Object?>)['status'] = 'pending',
      'available without a reference': (item) =>
          (item['evidence']! as Map<String, Object?>).remove('reference'),
      'available with an empty reference': (item) =>
          (item['evidence']! as Map<String, Object?>)['reference'] = '',
      'available with a reference over 120 characters': (item) =>
          (item['evidence']! as Map<String, Object?>)['reference'] = 'x' * 121,
      'available with an extra evidence key': (item) =>
          (item['evidence']! as Map<String, Object?>)['extra'] = true,
      'an unknown status': (item) => item['status'] = 'enabled',
    };
    for (final entry in badShapes.entries) {
      test('refuses ${entry.key}', () async {
        final body = _currentBody();
        entry.value(_item(body, 'mfa'));
        await expectLater(decode(body), throwsA(s8InvalidPayload));
      });
    }

    test('refuses confirmed evidence on an unavailable method', () async {
      final body = _currentBody();
      final item = _item(body, 'keyExport');
      (item['evidence']! as Map<String, Object?>)['status'] = 'confirmed';
      await expectLater(decode(body), throwsA(s8InvalidPayload));
    });

    test('refuses a reference on an unavailable method', () async {
      final body = _currentBody();
      final item = _item(body, 'socialRecovery');
      (item['evidence']! as Map<String, Object?>)['reference'] = 'S60a: x';
      await expectLater(decode(body), throwsA(s8InvalidPayload));
    });

    test('refuses available on a method this client has no flow for', () async {
      for (final id in <String>[
        'recoveryPassword',
        'socialRecovery',
        'keyExport',
      ]) {
        final body = _currentBody();
        _item(body, id)
          ..['status'] = 'available'
          ..['reasonCode'] = null
          ..['evidence'] = <String, Object?>{
            'status': 'confirmed',
            'reasonCode': 'PRIVY_X_CONFIRMED',
            'reference': 'S1: x',
          };
        await expectLater(decode(body), throwsA(s8InvalidPayload), reason: id);
      }
    });
  });

  group('security center', () {
    Finder row(String id) =>
        find.byKey(ValueKey<String>('security-method-$id'));

    LoopRecordRow rowOf(WidgetTester tester, String id) =>
        tester.widget<LoopRecordRow>(row(id));

    Future<void> pumpCenter(
      WidgetTester tester, {
      LoopSecurityCapabilities? capabilities,
      LoopMfaGateway? mfa,
    }) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(
          capabilities: S8Answer<LoopSecurityCapabilities>(
            value: capabilities ?? _currentModel(),
          ),
        ),
        overrides: <Override>[
          if (mfa != null) loopMfaGatewayProvider.overrideWithValue(mfa),
        ],
      );
    }

    testWidgets('available: enrolled MFA, open passkey, auto recovery on', (
      tester,
    ) async {
      final gateway = _MfaGateway(
        enrollments: const <LoopMfaEnrollment>[
          LoopMfaEnrollment(kind: LoopMfaMethodKind.totp),
        ],
      );
      await pumpCenter(tester, mfa: gateway);
      expect(gateway.reads, 1);

      final mfa = rowOf(tester, 'mfa');
      expect(mfa.badgeText, '已开启');
      expect(mfa.subtitle, '验证器 App');
      expect(mfa.onTap, isNotNull);

      final passkey = rowOf(tester, 'passkey');
      expect(passkey.badgeText, '未开启');
      expect(passkey.onTap, isNotNull);

      final recovery = rowOf(tester, 'autoRecovery');
      // Decision 0158: available is not enrollment, so 自动恢复 is the
      // neutral default way with its source, never 已启用.
      expect(recovery.badgeText, '默认方式');
      expect(recovery.subtitle, walletAutomaticRecoveryEvidence);
      expect(find.text('已启用'), findsNothing);
      expect(recovery.onTap, isNull);

      // The two methods that are still not open keep their badge.
      expect(rowOf(tester, 'socialRecovery').badgeText, '还没有开放');
      expect(rowOf(tester, 'keyExport').badgeText, '还没有开放');
      expect(find.text('还没有开放'), findsNWidgets(2));

      // The guide lists only what is still not open.
      final guide = find.byKey(
        const ValueKey<String>('security-methods-guide'),
      );
      await scrollToS8Section(tester, guide);
      await tester.tap(guide);
      await tester.pumpAndSettle();
      for (final id in <String>['socialRecovery', 'keyExport']) {
        expect(
          find.byKey(ValueKey<String>('security-methods-guide-$id')),
          findsOneWidget,
          reason: id,
        );
      }
      for (final id in <String>['mfa', 'passkey', 'autoRecovery']) {
        expect(
          find.byKey(ValueKey<String>('security-methods-guide-$id')),
          findsNothing,
          reason: id,
        );
      }
      final notice = tester.widget<LoopNotice>(
        find.byKey(const ValueKey<String>('security-scope-notice')),
      );
      expect(notice.body, '这些保护由 Privy 提供。社交恢复、导出私钥开放后会在这里显示。');
    });

    testWidgets('available: MFA off opens the MFA sheet; passkey on', (
      tester,
    ) async {
      final gateway = _MfaGateway(
        passkeys: const <LoopPasskeyCredential>[
          LoopPasskeyCredential(credentialId: 'cred-1', label: 'iPhone'),
        ],
      );
      await pumpCenter(tester, mfa: gateway);
      final passkey = rowOf(tester, 'passkey');
      expect(passkey.badgeText, '已开启');
      expect(passkey.subtitle, 'iPhone');
      final mfa = rowOf(tester, 'mfa');
      expect(mfa.badgeText, '未开启');
      expect(mfa.semanticLabel, contains('点按开启'));
      await tester.tap(row('mfa'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('mfa-sheet-title')),
        findsOneWidget,
      );
    });

    testWidgets('available: the passkey row opens the passkey sheet', (
      tester,
    ) async {
      await pumpCenter(tester, mfa: _MfaGateway());
      await tester.tap(row('passkey'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-title')),
        findsOneWidget,
      );
    });

    testWidgets('available, but the provider did not answer: not 未开启', (
      tester,
    ) async {
      await pumpCenter(
        tester,
        mfa: _MfaGateway(
          failure: const LoopMfaException(LoopMfaFailureKind.unavailable),
        ),
      );
      expect(rowOf(tester, 'mfa').badgeText, '读不到');
      expect(rowOf(tester, 'passkey').badgeText, '读不到');
      expect(find.text('未开启'), findsNothing);
      expect(find.text('已开启'), findsOneWidget); // 安全事件通知 only.
      // 自动恢复 does not depend on the provider's answer.
      expect(rowOf(tester, 'autoRecovery').badgeText, '默认方式');
    });

    testWidgets('available, but this build has no passkey domain', (
      tester,
    ) async {
      await pumpCenter(tester, mfa: _MfaGateway(relyingParty: null));
      final passkey = rowOf(tester, 'passkey');
      expect(passkey.badgeText, '不可用');
      expect(passkey.onTap, isNull);
    });

    testWidgets('a server reference without a tag is shown as sent', (
      tester,
    ) async {
      await pumpCenter(
        tester,
        mfa: _MfaGateway(),
        capabilities: _currentModel(autoRecoveryReference: '来源：Privy 默认恢复'),
      );
      expect(rowOf(tester, 'autoRecovery').subtitle, '来源：Privy 默认恢复');
    });

    testWidgets('the default projection renders as before', (tester) async {
      final gateway = _MfaGateway();
      await pumpCenter(tester, capabilities: s8Capabilities(), mfa: gateway);
      // Nothing is available, so the provider is not asked.
      expect(gateway.reads, 0);
      for (final id in <String>[
        'mfa',
        'passkey',
        'autoRecovery',
        'socialRecovery',
        'keyExport',
      ]) {
        await scrollToS8Section(tester, row(id));
        expect(rowOf(tester, id).badgeText, '还没有开放', reason: id);
      }
      expect(find.text('已开启'), findsOneWidget); // 安全事件通知 only.
      expect(find.text('已启用'), findsNothing);
      final guide = find.byKey(
        const ValueKey<String>('security-methods-guide'),
      );
      await scrollToS8Section(tester, guide);
      await tester.tap(guide);
      await tester.pumpAndSettle();
      for (final id in <String>[
        'mfa',
        'passkey',
        'autoRecovery',
        'socialRecovery',
        'keyExport',
      ]) {
        expect(
          find.byKey(ValueKey<String>('security-methods-guide-$id')),
          findsOneWidget,
          reason: id,
        );
      }
      final notice = tester.widget<LoopNotice>(
        find.byKey(const ValueKey<String>('security-scope-notice')),
      );
      expect(notice.body, '多因素验证、Passkey、恢复与导出由 Privy 提供，开放后会在这里显示。');
    });
  });
}

const _autoRecoveryReference =
    'S60a: Privy 内置钱包默认由登录方式恢复；换设备后用同一邮箱登录即可（来源：Privy）';

Map<String, Object?> _item(Map<String, Object?> body, String id) =>
    (body['items']! as List<Object?>).cast<Map<String, Object?>>().firstWhere(
      (item) => item['capabilityId'] == id,
    );

/// The body loop-api decision 0129 §4 documents for `projection=current`.
Map<String, Object?> _currentBody({bool passkeyAvailable = true}) {
  final body = s8CapabilitiesBody();
  void confirm(String id, String reason, String reference) {
    _item(body, id)
      ..['status'] = 'available'
      ..['reasonCode'] = null
      ..['evidence'] = <String, Object?>{
        'status': 'confirmed',
        'reasonCode': reason,
        'reference': reference,
      };
  }

  confirm(
    'mfa',
    'PRIVY_MFA_CLIENT_TOTP',
    'S60a: privy_flutter TOTP enrolment in 安全设置 (docs/modules/S2-identity-account.md)',
  );
  if (passkeyAvailable) {
    confirm(
      'passkey',
      'PRIVY_PASSKEY_CLIENT_ENROLLMENT',
      'S64: privy_flutter passkey link/enroll; RP = the API domain (loop-api Decision 0063)',
    );
  } else {
    _item(body, 'passkey')
      ..['reasonCode'] = 'PASSKEY_RELYING_PARTY_NOT_CONFIGURED'
      ..['evidence'] = <String, Object?>{
        'status': 'pending',
        'reasonCode': 'PASSKEY_RELYING_PARTY_NOT_CONFIGURED',
      };
  }
  confirm(
    'autoRecovery',
    'PRIVY_EMBEDDED_WALLET_DEFAULT_RECOVERY',
    _autoRecoveryReference,
  );
  return body;
}

LoopSecurityCapabilities _currentModel({
  String autoRecoveryReference = _autoRecoveryReference,
}) => LoopSecurityCapabilities(
  items: <LoopSecurityCapability>[
    for (final item in s8Capabilities().items)
      switch (item.id) {
        LoopSecurityCapabilityId.mfa => LoopSecurityCapability.available(
          id: item.id,
          evidenceReasonCode: 'PRIVY_MFA_CLIENT_TOTP',
          evidenceReference: 'S60a: privy_flutter TOTP enrolment',
          guideKey: item.guideKey,
        ),
        LoopSecurityCapabilityId.passkey => LoopSecurityCapability.available(
          id: item.id,
          evidenceReasonCode: 'PRIVY_PASSKEY_CLIENT_ENROLLMENT',
          evidenceReference: 'S64: privy_flutter passkey link/enroll',
          guideKey: item.guideKey,
        ),
        LoopSecurityCapabilityId.autoRecovery =>
          LoopSecurityCapability.available(
            id: item.id,
            evidenceReasonCode: 'PRIVY_EMBEDDED_WALLET_DEFAULT_RECOVERY',
            evidenceReference: autoRecoveryReference,
            guideKey: item.guideKey,
          ),
        _ => item,
      },
  ],
);

extension on LoopRecordRow {
  String? get badgeText => (trailingBadge as LoopBadge?)?.text;
}

final class _MfaGateway implements LoopMfaGateway {
  _MfaGateway({
    this.enrollments = const <LoopMfaEnrollment>[],
    this.passkeys = const <LoopPasskeyCredential>[],
    this.failure,
    this.relyingParty = 'api-dev.quant-dinger.cc',
  });

  final List<LoopMfaEnrollment> enrollments;
  final List<LoopPasskeyCredential> passkeys;
  final LoopMfaException? failure;
  final String? relyingParty;
  int reads = 0;

  LoopSecondFactorFacts get _facts =>
      LoopSecondFactorFacts(enrollments: enrollments, passkeys: passkeys);

  @override
  String? get passkeyRelyingParty => relyingParty;

  @override
  Future<LoopSecondFactorFacts> readSecondFactor() async {
    reads += 1;
    final error = failure;
    if (error != null) throw error;
    return _facts;
  }

  @override
  Future<LoopTotpSecret> beginTotpEnrollment() =>
      throw const LoopMfaException(LoopMfaFailureKind.unavailable);

  @override
  Future<LoopSecondFactorFacts> completeTotpEnrollment(String code) async =>
      _facts;

  @override
  Future<LoopSecondFactorFacts> removeTotp() async => _facts;

  @override
  Future<LoopSecondFactorFacts> linkPasskey() async => _facts;

  @override
  Future<LoopSecondFactorFacts> unlinkPasskey(String credentialId) async =>
      _facts;

  @override
  Future<LoopSecondFactorFacts> enrollPasskeyMfa(
    List<String> credentialIds,
  ) async => _facts;

  @override
  Future<LoopSecondFactorFacts> removePasskeyMfa() async => _facts;
}

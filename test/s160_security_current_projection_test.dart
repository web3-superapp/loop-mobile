import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
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

    // S278 · decision 0236: the 「由 Privy 提供」 card is the (i) beside 验证.
    String scopeNote(WidgetTester tester) => tester
        .widget<LoopInfoButton>(
          find.byKey(const ValueKey<String>('security-scope-info')),
        )
        .notes
        .single
        .body;

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
      expect(mfa.badgeText, 'On');
      expect(mfa.subtitle, 'Authenticator app');
      expect(mfa.onTap, isNotNull);

      final passkey = rowOf(tester, 'passkey');
      expect(passkey.badgeText, 'Off');
      expect(passkey.onTap, isNotNull);

      final recovery = rowOf(tester, 'autoRecovery');
      // Decision 0158: available is not enrollment, so 自动恢复 is the
      // neutral default way with its source, never 已启用.
      expect(recovery.badgeText, 'Default method');
      expect(recovery.subtitle, isNull);
      // The fixture's server reference, with its tag stripped (server copy).
      expect(recovery.infoText, 'Privy 内置钱包默认由登录方式恢复；换设备后用同一邮箱登录即可（来源：Privy）');
      expect(find.text('Enabled'), findsNothing);
      expect(recovery.onTap, isNull);

      // The two methods that are still not open keep their badge.
      expect(rowOf(tester, 'socialRecovery').badgeText, 'Not open yet');
      expect(rowOf(tester, 'keyExport').badgeText, 'Not open yet');
      expect(find.text('Not open yet'), findsNWidgets(2));

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
      expect(
        scopeNote(tester),
        'These protections are provided by Privy. Social recovery, Export private key will show here once open.',
      );
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
      expect(passkey.badgeText, 'On');
      expect(passkey.subtitle, 'iPhone');
      final mfa = rowOf(tester, 'mfa');
      expect(mfa.badgeText, 'Off');
      expect(mfa.semanticLabel, contains('Tap to turn on'));
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
      expect(rowOf(tester, 'mfa').badgeText, 'Unreadable');
      expect(rowOf(tester, 'passkey').badgeText, 'Unreadable');
      expect(find.text('Off'), findsNothing);
      expect(find.text('On'), findsOneWidget); // 安全事件通知 only.
      // 自动恢复 does not depend on the provider's answer.
      expect(rowOf(tester, 'autoRecovery').badgeText, 'Default method');
    });

    testWidgets('available, but this build has no passkey domain', (
      tester,
    ) async {
      await pumpCenter(tester, mfa: _MfaGateway(relyingParty: null));
      final passkey = rowOf(tester, 'passkey');
      expect(passkey.badgeText, 'Unavailable');
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
      expect(rowOf(tester, 'autoRecovery').infoText, '来源：Privy 默认恢复');
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
        expect(rowOf(tester, id).badgeText, 'Not open yet', reason: id);
      }
      expect(find.text('On'), findsOneWidget); // 安全事件通知 only.
      expect(find.text('Enabled'), findsNothing);
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
      expect(
        scopeNote(tester),
        'Multi-factor authentication, passkeys, recovery and export are provided by Privy and will show here once open.',
      );
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
  /// S278 · decision 0236: a row whose explanation is behind (i) carries
  /// the (i) and the badge side by side.
  List<Widget> get _trailing => switch (trailingBadge) {
    final Row row => row.children,
    final Widget one => <Widget>[one],
    null => const <Widget>[],
  };

  String? get badgeText => _trailing.whereType<LoopBadge>().firstOrNull?.text;

  /// What the row's (i) says; null when the row has none.
  String? get infoText =>
      _trailing.whereType<LoopInfoButton>().firstOrNull?.notes.single.body;
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

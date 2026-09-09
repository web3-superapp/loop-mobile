import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/features/profile/settings/settings_models.dart';
import 'package:loop_mobile/features/profile/support/support_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s8_gateways.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_id_source.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';
import 'package:loop_mobile/integrations/backend/v2/meta/loop_v2_about_api.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';
import 'package:loop_mobile/integrations/backend/v2/settings/loop_v2_settings_api.dart';
import 'package:loop_mobile/integrations/backend/v2/support/loop_v2_support_api.dart';

import 'support/s8_fixtures.dart';

/// Wire contract for the S8 transports, decoded from the exact bodies in
/// `loop-api/docs/frontend-v2-security-settings-api.md`.
void main() {
  group('GET /v2/devices', () {
    test('carries the read headers plus the current session id', () async {
      RequestOptions? captured;
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          captured = options;
          handler.resolve(s8Response(options, s8DevicesBody()));
        }),
      );

      await api.getDevices(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        sessionId: s8CurrentSessionId,
      );

      final headers = captured!.headers;
      expect(headers['authorization'], 'Bearer $s8AccessToken');
      expect(headers['x-loop-contract-version'], '2.0');
      expect(headers['x-loop-session-id'], s8CurrentSessionId);
      expect(headers.containsKey('idempotency-key'), isFalse);
    });

    test('decodes the directory and its risk policy', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, s8DevicesBody())),
        ),
      );

      final directory = await api.getDevices(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        sessionId: s8CurrentSessionId,
      );

      expect(directory.devices, hasLength(2));
      expect(directory.currentSessionId, s8CurrentSessionId);
      expect(directory.current!.platform, LoopDevicePlatform.ios);
      expect(directory.deviceCount, 2);
      expect(directory.riskSignals.policy.newSessionThreshold, 2);
      expect(directory.revokeAll.reasonCode, 'AUTH_STEP_UP_REQUIRED');
      expect(directory.truncated, isFalse);
    });

    test('a current session the client never offered is refused', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, s8DevicesBody())),
        ),
      );

      // The header was omitted, so no row may come back marked current.
      await expectLater(
        api.getDevices(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test('a revoked row without a revocation time is refused', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          final body = s8DevicesBody();
          final devices = body['devices']! as List<Object?>;
          (devices[1]! as Map<String, Object?>)['status'] = 'revoked';
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(
        api.getDevices(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          sessionId: s8CurrentSessionId,
        ),
        throwsA(s8InvalidPayload),
      );
    });
  });

  group('POST /v2/devices/{sessionId}/revoke', () {
    test('carries the whole logout header set', () async {
      RequestOptions? captured;
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          captured = options;
          handler.resolve(s8Response(options, s8RevokeBody()));
        }),
      );

      await api.revokeDevice(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        sessionId: s8OtherSessionId,
        command: s8Command(),
      );

      final headers = captured!.headers;
      expect(captured!.method, 'POST');
      expect(captured!.path, '/v2/devices/$s8OtherSessionId/revoke');
      expect(headers['authorization'], 'Bearer $s8AccessToken');
      expect(headers['x-loop-contract-version'], '2.0');
      expect(headers['x-loop-client-version'], s8ClientVersion);
      expect(headers['x-loop-platform'], 'ios');
      expect(headers['x-loop-device-id'], s8CurrentDeviceId);
      expect(headers['x-loop-session-id'], s8CurrentSessionId);
      expect(headers['idempotency-key'], s8IdempotencyKey);
    });

    test(
      'the audit-only effect and the untouched provider are decoded',
      () async {
        final api = DioLoopV2SecurityApi(
          s8Dio(
            (options, handler) =>
                handler.resolve(s8Response(options, s8RevokeBody())),
          ),
        );

        final result = await api.revokeDevice(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          sessionId: s8OtherSessionId,
          command: s8Command(),
        );

        expect(result.sessionId, s8OtherSessionId);
        expect(result.effect, 'auditOnly');
        expect(result.providerAccessTerminated, isFalse);
      },
    );

    test(
      'a response claiming the provider was signed out is refused',
      () async {
        final api = DioLoopV2SecurityApi(
          s8Dio((options, handler) {
            final body = s8RevokeBody()..['providerAccessTerminated'] = true;
            handler.resolve(s8Response(options, body));
          }),
        );

        await expectLater(
          api.revokeDevice(
            accessToken: s8AccessToken,
            clientVersion: s8ClientVersion,
            sessionId: s8OtherSessionId,
            command: s8Command(),
          ),
          throwsA(s8InvalidPayload),
        );
      },
    );

    test('an effect other than auditOnly is refused', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          final body = s8RevokeBody()..['effect'] = 'providerRevoked';
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(
        api.revokeDevice(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          sessionId: s8OtherSessionId,
          command: s8Command(),
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test('a receipt for another session is refused', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          final body = s8RevokeBody();
          (body['session']! as Map<String, Object?>)['sessionId'] =
              s8CurrentSessionId;
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(
        api.revokeDevice(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          sessionId: s8OtherSessionId,
          command: s8Command(),
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test(
      'revoking the caller\'s own session never reaches the network',
      () async {
        var dispatched = false;
        final api = DioLoopV2SecurityApi(
          s8Dio((options, handler) {
            dispatched = true;
            handler.resolve(s8Response(options, s8RevokeBody()));
          }),
        );

        await expectLater(
          api.revokeDevice(
            accessToken: s8AccessToken,
            clientVersion: s8ClientVersion,
            sessionId: s8CurrentSessionId,
            command: s8Command(),
          ),
          throwsA(
            isA<LoopBackendFailure>().having(
              (failure) => failure.kind,
              'kind',
              LoopBackendFailureKind.invalidRequest,
            ),
          ),
        );
        expect(dispatched, isFalse);
      },
    );

    test('a step-up refusal is mapped, not retried', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio(
          (options, handler) => handler.reject(
            s8ErrorResponse(
              options,
              statusCode: 403,
              code: 'AUTH_STEP_UP_REQUIRED',
              category: 'authorization',
              retryable: false,
            ),
          ),
        ),
      );

      await expectLater(
        api.revokeDevice(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          sessionId: s8OtherSessionId,
          command: s8Command(),
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.code,
            'code',
            'AUTH_STEP_UP_REQUIRED',
          ),
        ),
      );
    });
  });

  group('GET /v2/security/capabilities', () {
    test('the six methods arrive in the frozen order', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, s8CapabilitiesBody())),
        ),
      );

      final capabilities = await api.getCapabilities(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
      );

      expect(
        capabilities.items.map((item) => item.id),
        LoopSecurityCapabilityId.values,
      );
      expect(
        capabilities[LoopSecurityCapabilityId.mfa]!.reasonCode,
        'PRIVY_MFA_EVIDENCE_PENDING',
      );
      expect(
        capabilities[LoopSecurityCapabilityId.keyExport]!.guideKey,
        'security.capability.keyExport.howToEnable',
      );
    });

    test('a reordered list is refused', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          final body = s8CapabilitiesBody();
          final items = body['items']! as List<Object?>;
          final first = items.removeAt(0);
          items.add(first);
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(
        api.getCapabilities(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test('a method reported as available is refused', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          final body = s8CapabilitiesBody();
          final items = body['items']! as List<Object?>;
          (items.first! as Map<String, Object?>)['status'] = 'available';
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(
        api.getCapabilities(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
        ),
        throwsA(s8InvalidPayload),
      );
    });
  });

  group('GET /v2/security/summary', () {
    test('decodes the approval coverage start block', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, s8SummaryBody())),
        ),
      );

      final summary = await api.getSummary(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
      );

      final approvals = summary.approvals as LoopSecurityApprovalsAvailable;
      expect(approvals.approvalCoverageFromBlockNumber, '120600000');
      expect(approvals.indexerBlockNumber, '120659683');
      expect(approvals.headBlockNumber, '120661145');
      expect(approvals.activeCount, 3);
      final devices = summary.devices as LoopSecurityDevicesAvailable;
      expect(devices.deviceCount, 2);
      expect(summary.securityEvents.locked, isTrue);
      expect(
        (summary.recentSecurityEvents as LoopSecurityEventsAvailable).items,
        isEmpty,
      );
    });

    test('freshness without the coverage start block is refused', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          final body = s8SummaryBody();
          final approvals = body['approvals']! as Map<String, Object?>;
          (approvals['freshness']! as Map<String, Object?>).remove(
            'approvalCoverageFromBlockNumber',
          );
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(
        api.getSummary(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test('an unavailable approvals block keeps its reason', () async {
      final api = DioLoopV2SecurityApi(
        s8Dio((options, handler) {
          final body = s8SummaryBody()
            ..['approvals'] = <String, Object?>{
              'status': 'unavailable',
              'reasonCode': 'SEND_APPROVALS_RUNTIME_DEFERRED',
            };
          handler.resolve(s8Response(options, body));
        }),
      );

      final summary = await api.getSummary(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
      );

      expect(
        (summary.approvals as LoopSecurityApprovalsUnavailable).fact.reasonCode,
        'SEND_APPROVALS_RUNTIME_DEFERRED',
      );
    });

    test(
      'a non-security notification in the events block is refused',
      () async {
        final api = DioLoopV2SecurityApi(
          s8Dio((options, handler) {
            final body = s8SummaryBody();
            final events =
                body['recentSecurityEvents']! as Map<String, Object?>;
            events['items'] = <Object?>[s8SecurityEvent(type: 'trade.result')];
            handler.resolve(s8Response(options, body));
          }),
        );

        await expectLater(
          api.getSummary(
            accessToken: s8AccessToken,
            clientVersion: s8ClientVersion,
          ),
          throwsA(s8InvalidPayload),
        );
      },
    );
  });

  group('GET/PUT /v2/settings', () {
    test('the fixed values and the local-only policy are decoded', () async {
      final api = DioLoopV2SettingsApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, s8SettingsBody())),
        ),
      );

      final settings = await api.getSettings(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
      );

      expect(settings.values.displayCurrency, 'USD');
      expect(settings.values.language, 'zh-CN');
      expect(settings.version, 0);
      expect(settings.updatedAt, isNull);
      expect(settings.policy.localOnly, <String>['reduceMotion', 'theme']);
    });

    test('the CAS write carries no idempotency key', () async {
      RequestOptions? captured;
      final api = DioLoopV2SettingsApi(
        s8Dio((options, handler) {
          captured = options;
          handler.resolve(s8Response(options, s8SettingsBody(version: 1)));
        }),
      );

      await api.putSettings(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        expectedVersion: 0,
        values: const LoopAccountSettingsValues(
          displayCurrency: 'USD',
          language: 'zh-CN',
        ),
      );

      expect(captured!.method, 'PUT');
      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      expect((captured!.data! as Map<String, Object?>)['expectedVersion'], 0);
    });

    test('version 0 with an update time is refused', () async {
      final api = DioLoopV2SettingsApi(
        s8Dio((options, handler) {
          final body = s8SettingsBody()
            ..['updatedAt'] = '2026-09-09T02:00:00.000Z';
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(
        api.getSettings(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test('a value the policy does not fix is never sent', () async {
      var dispatched = false;
      final api = DioLoopV2SettingsApi(
        s8Dio((options, handler) {
          dispatched = true;
          handler.resolve(s8Response(options, s8SettingsBody()));
        }),
      );

      await expectLater(
        api.putSettings(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          expectedVersion: 0,
          values: const LoopAccountSettingsValues(
            displayCurrency: 'EUR',
            language: 'zh-CN',
          ),
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidRequest,
          ),
        ),
      );
      expect(dispatched, isFalse);
    });
  });

  group('GET /v2/meta/about', () {
    test('is public and sends no Authorization header', () async {
      RequestOptions? captured;
      final api = DioLoopV2AboutApi(
        s8Dio((options, handler) {
          captured = options;
          handler.resolve(s8Response(options, s8AboutBody()));
        }),
      );

      final about = await api.getAbout();

      expect(captured!.headers.containsKey('authorization'), isFalse);
      expect(captured!.headers.containsKey('x-loop-session-id'), isFalse);
      expect(about.contractVersion, '2.0');
      expect(about.configVersions, hasLength(2));
      expect(about.termsGate.isAvailable, isFalse);
      expect(about.termsGate.reasonCode, 'TERMS_POLICY_UNAVAILABLE');
      expect(about.clientBuildReasonCode, 'CLIENT_BUILD_IS_DEVICE_LOCAL');
    });

    test('the register publishes no dependency version', () async {
      final api = DioLoopV2AboutApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, s8AboutBody())),
        ),
      );

      final about = await api.getAbout();
      final entry = about.openSource.entries.single;

      expect(entry.name, 'Fastify');
      expect(entry.license, 'MIT');
      // The model has no version field at all, so none can be rendered.
      expect(
        LoopOpenSourceEntry(
          name: entry.name,
          purpose: entry.purpose,
          license: entry.license,
        ).license,
        'MIT',
      );
    });

    test('a register entry carrying a version is an invalid payload', () async {
      final api = DioLoopV2AboutApi(
        s8Dio((options, handler) {
          final body = s8AboutBody();
          final register = body['openSource']! as Map<String, Object?>;
          final entries = register['entries']! as List<Object?>;
          (entries.first! as Map<String, Object?>)['version'] = '5.6.1';
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(api.getAbout(), throwsA(s8InvalidPayload));
    });

    test('a terms gate with both a version and a reason is refused', () async {
      final api = DioLoopV2AboutApi(
        s8Dio((options, handler) {
          final body = s8AboutBody()
            ..['termsGate'] = <String, Object?>{
              'status': 'available',
              'requiredVersion': 'terms-2026-09',
              'reasonCode': 'TERMS_POLICY_UNAVAILABLE',
            };
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(api.getAbout(), throwsA(s8InvalidPayload));
    });
  });

  group('support tickets', () {
    test(
      'the list echoes its cursor and keeps attachments unavailable',
      () async {
        RequestOptions? captured;
        final api = DioLoopV2SupportApi(
          s8Dio((options, handler) {
            captured = options;
            handler.resolve(
              s8Response(options, s8TicketPageBody(nextCursor: 'abc.def')),
            );
          }),
        );

        final page = await api.listTickets(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          cursor: 'ghi.jkl',
        );

        expect(captured!.queryParameters['cursor'], 'ghi.jkl');
        expect(page.nextCursor, 'abc.def');
        expect(page.attachments.reasonCode, 'SUPPORT_ATTACHMENTS_UNAVAILABLE');
        expect(page.policy.responseWindowHours, 24);
        expect(page.items.single.status, LoopSupportTicketStatus.open);
      },
    );

    test('a malformed cursor never reaches the network', () async {
      var dispatched = false;
      final api = DioLoopV2SupportApi(
        s8Dio((options, handler) {
          dispatched = true;
          handler.resolve(s8Response(options, s8TicketPageBody()));
        }),
      );

      await expectLater(
        api.listTickets(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          cursor: 'not a cursor',
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidRequest,
          ),
        ),
      );
      expect(dispatched, isFalse);
    });

    test(
      'a 201 create carries the idempotency key and echoes the draft',
      () async {
        RequestOptions? captured;
        final api = DioLoopV2SupportApi(
          s8Dio((options, handler) {
            captured = options;
            handler.resolve(
              s8Response(options, s8TicketResultBody(), statusCode: 201),
            );
          }),
        );

        final result = await api.createTicket(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          idempotencyKey: s8IdempotencyKey,
          draft: LoopSupportDraft(
            category: LoopSupportCategory.mining,
            body: s8TicketBody,
          ),
        );

        expect(captured!.headers['idempotency-key'], s8IdempotencyKey);
        expect((captured!.data! as Map<String, Object?>)['category'], 'mining');
        expect(result.ticket.category, LoopSupportCategory.mining);
        expect(result.ticket.events.first.actor, LoopSupportActor.user);
      },
    );

    test('a 200 replay of the same key is accepted', () async {
      final api = DioLoopV2SupportApi(
        s8Dio(
          (options, handler) =>
              handler.resolve(s8Response(options, s8TicketResultBody())),
        ),
      );

      final result = await api.createTicket(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
        idempotencyKey: s8IdempotencyKey,
        draft: LoopSupportDraft(
          category: LoopSupportCategory.mining,
          body: s8TicketBody,
        ),
      );

      expect(result.ticket.ticketId, s8TicketId);
    });

    test('an echo of a different body is refused', () async {
      final api = DioLoopV2SupportApi(
        s8Dio((options, handler) {
          final body = s8TicketResultBody();
          (body['ticket']! as Map<String, Object?>)['body'] = '别的内容';
          handler.resolve(s8Response(options, body, statusCode: 201));
        }),
      );

      await expectLater(
        api.createTicket(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
          idempotencyKey: s8IdempotencyKey,
          draft: LoopSupportDraft(
            category: LoopSupportCategory.mining,
            body: s8TicketBody,
          ),
        ),
        throwsA(s8InvalidPayload),
      );
    });

    test('a body of 2000 astral code points still decodes', () async {
      // The server counts code points; `String.length` counts UTF-16 units, so
      // a body it accepts can be 4000 units on the wire.
      final astral = '\u{1F300}' * LoopSupportPolicy.maximumBodyLength;
      final api = DioLoopV2SupportApi(
        s8Dio((options, handler) {
          final body = s8TicketPageBody();
          final items = body['items']! as List<Object?>;
          (items.first! as Map<String, Object?>)['body'] = astral;
          handler.resolve(s8Response(options, body));
        }),
      );

      final page = await api.listTickets(
        accessToken: s8AccessToken,
        clientVersion: s8ClientVersion,
      );

      expect(page.items.single.body.runes.length, 2000);
      expect(page.items.single.body.length, 4000);
    });

    test('an out-of-order event journal is refused', () async {
      final api = DioLoopV2SupportApi(
        s8Dio((options, handler) {
          final body = s8TicketPageBody();
          final ticket =
              (body['items']! as List<Object?>).first! as Map<String, Object?>;
          final events = ticket['events']! as List<Object?>;
          (events.first! as Map<String, Object?>)['eventVersion'] = 3;
          handler.resolve(s8Response(options, body));
        }),
      );

      await expectLater(
        api.listTickets(
          accessToken: s8AccessToken,
          clientVersion: s8ClientVersion,
        ),
        throwsA(s8InvalidPayload),
      );
    });
  });

  group('LoopV2SessionIdSource', () {
    test('reads the active session out of the owner journal', () async {
      final source = LoopV2SessionIdSource(
        principalKey: s8PrincipalKey,
        store: _JournalStore(),
      );

      expect(await source.resolve(), s8CurrentSessionId);
      expect(await source.resolveDeviceId(), s8CurrentDeviceId);
    });

    test('an unreadable journal degrades instead of throwing', () async {
      final source = LoopV2SessionIdSource(
        principalKey: s8PrincipalKey,
        store: _JournalStore(failing: true),
      );

      expect(await source.resolve(), isNull);
      expect(await source.resolveDeviceId(), isNull);
    });

    test('no active session means no header', () async {
      final source = LoopV2SessionIdSource(
        principalKey: s8PrincipalKey,
        store: _JournalStore(journal: const LoopV2OwnerJournal()),
      );

      expect(await source.resolve(), isNull);
    });
  });

  group('DioLoopV2SecurityGateway', () {
    test('the device list carries the journal session id', () async {
      final api = _RecordingSecurityApi();
      final gateway = DioLoopV2SecurityGateway(
        api: api,
        clientMetadata: s8ClientMetadata,
        session: s8ImmediateSession(),
        sessionIds: LoopV2SessionIdSource(
          principalKey: s8PrincipalKey,
          store: _JournalStore(),
        ),
      );

      await gateway.loadDevices();

      expect(api.listedSessionIds, <String?>[s8CurrentSessionId]);
    });

    test(
      'revoking this device is a step-up refusal, never a request',
      () async {
        final api = _RecordingSecurityApi();
        final gateway = DioLoopV2SecurityGateway(
          api: api,
          clientMetadata: s8ClientMetadata,
          session: s8ImmediateSession(),
          sessionIds: LoopV2SessionIdSource(
            principalKey: s8PrincipalKey,
            store: _JournalStore(),
          ),
        );

        await expectLater(
          gateway.revokeDevice(s8CurrentSessionId),
          throwsA(
            isA<LoopChainException>().having(
              (error) => error.kind,
              'kind',
              LoopChainFailureKind.stepUpRequired,
            ),
          ),
        );
        expect(api.commands, isEmpty);
      },
    );

    test('a revoke carries the whole logout command header set', () async {
      final api = _RecordingSecurityApi();
      final gateway = DioLoopV2SecurityGateway(
        api: api,
        clientMetadata: s8ClientMetadata,
        session: s8ImmediateSession(),
        sessionIds: LoopV2SessionIdSource(
          principalKey: s8PrincipalKey,
          store: _JournalStore(),
        ),
      );

      final result = await gateway.revokeDevice(s8OtherSessionId);

      expect(result.providerAccessTerminated, isFalse);
      final command = api.commands.single;
      expect(command.platform, LoopV2Platform.ios);
      expect(command.deviceId, s8CurrentDeviceId);
      expect(command.sessionId, s8CurrentSessionId);
      expect(command.headers.keys, <String>[
        'x-loop-platform',
        'x-loop-device-id',
        'x-loop-session-id',
        'idempotency-key',
      ]);
    });

    test(
      'without a journal session the command is unavailable, not guessed',
      () async {
        final api = _RecordingSecurityApi();
        final gateway = DioLoopV2SecurityGateway(
          api: api,
          clientMetadata: s8ClientMetadata,
          session: s8ImmediateSession(),
          sessionIds: LoopV2SessionIdSource(
            principalKey: s8PrincipalKey,
            store: _JournalStore(journal: const LoopV2OwnerJournal()),
          ),
        );

        await expectLater(
          gateway.revokeDevice(s8OtherSessionId),
          throwsA(
            isA<LoopChainException>().having(
              (error) => error.kind,
              'kind',
              LoopChainFailureKind.unavailable,
            ),
          ),
        );
        expect(api.commands, isEmpty);
      },
    );

    test(
      'a step-up refusal reaches the feature layer as its own kind',
      () async {
        final api = _RecordingSecurityApi(
          revokeFailure: const LoopBackendFailure(
            LoopBackendFailureKind.unavailable,
            statusCode: 403,
            code: 'AUTH_STEP_UP_REQUIRED',
          ),
        );
        final gateway = DioLoopV2SecurityGateway(
          api: api,
          clientMetadata: s8ClientMetadata,
          session: s8ImmediateSession(),
          sessionIds: LoopV2SessionIdSource(
            principalKey: s8PrincipalKey,
            store: _JournalStore(),
          ),
        );

        await expectLater(
          gateway.revokeDevice(s8OtherSessionId),
          throwsA(
            isA<LoopChainException>().having(
              (error) => error.kind,
              'kind',
              LoopChainFailureKind.stepUpRequired,
            ),
          ),
        );
      },
    );
  });

  group('LoopV2AboutRepository', () {
    test('a transport failure becomes a narrow feature failure', () async {
      final repository = LoopV2AboutRepository(
        DioLoopV2AboutApi(
          s8Dio(
            (options, handler) => handler.reject(
              s8ErrorResponse(
                options,
                statusCode: 503,
                code: 'REQUEST_TIMEOUT',
              ),
            ),
          ),
        ),
      );

      await expectLater(
        repository.load(),
        throwsA(
          isA<LoopChainException>().having(
            (error) => error.kind,
            'kind',
            LoopChainFailureKind.offline,
          ),
        ),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// doubles
// ---------------------------------------------------------------------------

final class _JournalStore implements LoopV2SessionJournalStore {
  _JournalStore({this.failing = false, LoopV2OwnerJournal? journal})
    : journal = journal ?? s8Journal();

  final bool failing;
  final LoopV2OwnerJournal journal;

  @override
  Future<String> loadOrCreateDeviceId() async {
    if (failing) throw const LoopV2SessionStorageException();
    return s8CurrentDeviceId;
  }

  @override
  Future<LoopV2OwnerJournal?> readOwnerJournal(String ownerPartition) async {
    if (failing) throw const LoopV2SessionStorageException();
    return journal;
  }

  @override
  Future<void> writeOwnerJournal(
    String ownerPartition,
    LoopV2OwnerJournal journal,
  ) async {}

  @override
  Future<void> deleteOwnerJournal(String ownerPartition) async {}
}

final class _RecordingSecurityApi implements LoopV2SecurityApi {
  _RecordingSecurityApi({this.revokeFailure});

  final Object? revokeFailure;
  final List<String?> listedSessionIds = <String?>[];
  final List<LoopV2SessionCommand> commands = <LoopV2SessionCommand>[];

  @override
  Future<LoopDeviceDirectory> getDevices({
    required String accessToken,
    required String clientVersion,
    String? sessionId,
  }) async {
    listedSessionIds.add(sessionId);
    return s8Directory();
  }

  @override
  Future<LoopDeviceRevocation> revokeDevice({
    required String accessToken,
    required String clientVersion,
    required String sessionId,
    required LoopV2SessionCommand command,
  }) async {
    commands.add(command);
    final failure = revokeFailure;
    if (failure != null) throw failure;
    return LoopDeviceRevocation(
      sessionId: sessionId,
      revokedAt: DateTime.utc(2026, 9, 9, 3),
      effect: LoopDeviceRevocation.auditOnlyEffect,
      providerAccessTerminated: false,
    );
  }

  @override
  Future<LoopSecurityCapabilities> getCapabilities({
    required String accessToken,
    required String clientVersion,
  }) async => s8Capabilities();

  @override
  Future<LoopSecuritySummary> getSummary({
    required String accessToken,
    required String clientVersion,
  }) async => s8Summary();
}

LoopAuthenticatedSession s8ImmediateSession() {
  return LoopAuthenticatedSession(
    principalKey: s8PrincipalKey,
    bootstrapSession: LoopBootstrapSession(
      principalKey: s8PrincipalKey,
      accessTokens: _StaticAccessTokens(),
      repository: _BootstrapRepository(),
    ),
    accessTokens: _StaticAccessTokens(),
  );
}

final class _StaticAccessTokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => s8AccessToken;
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    return const LoopBootstrapIdentity(
      loopUserId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
      streamUserId: 'loop_6d12a86e413447e69312c5ef75a30f55',
    );
  }
}

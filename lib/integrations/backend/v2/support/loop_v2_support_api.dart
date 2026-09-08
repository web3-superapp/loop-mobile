import 'package:dio/dio.dart';
import 'package:loop_mobile/features/profile/support/support_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for support tickets (decision 0037).
///
/// `POST` carries one canonical `Idempotency-Key`; the list is a keyset page
/// whose cursor is opaque and echoed verbatim.
abstract interface class LoopV2SupportApi {
  Future<LoopSupportTicketPage> listTickets({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  });

  Future<LoopSupportTicketResult> createTicket({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required LoopSupportDraft draft,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2SupportApi implements LoopV2SupportApi {
  DioLoopV2SupportApi(this._dio);

  static const ticketsPath = '/v2/support/tickets';
  static const listLimit = 50;

  /// A ticket create can also be refused for quota and for content length.
  static const createErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'VERSION_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;

  @override
  Future<LoopSupportTicketPage> listTickets({
    required String accessToken,
    required String clientVersion,
    String? cursor,
  }) async {
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ChainCodec.maximumCursorLength ||
            !LoopV2ChainCodec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        ticketsPath,
        queryParameters: cursor == null
            ? null
            : <String, Object?>{'cursor': cursor},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'items',
        'nextCursor',
        'attachments',
        'policy',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final items = <LoopSupportTicket>[];
      final seen = <String>{};
      for (final raw in LoopV2ChainCodec.requireList(
        root['items'],
        maximum: listLimit,
      )) {
        final ticket = _ticket(raw);
        if (!seen.add(ticket.ticketId)) LoopV2ChainCodec.invalid();
        items.add(ticket);
      }
      return LoopSupportTicketPage(
        items: items,
        nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
        attachments: LoopV2ChainCodec.unavailable(root['attachments']),
        policy: _policy(root['policy']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  @override
  Future<LoopSupportTicketResult> createTicket({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required LoopSupportDraft draft,
    LoopV2WriteOrigin? origin,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        ticketsPath,
        data: <String, Object?>{
          'category': draft.category.wireName,
          'body': draft.body,
        },
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
          origin: origin,
        ),
      );
      // `201` is a new ticket; `200` is the idempotent replay of the same one.
      final statusCode = response.statusCode;
      if (statusCode != 200 && statusCode != 201) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      LoopV2Contract.validateSuccess(response, statusCode: statusCode!);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'ticket',
        'attachments',
        'policy',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final ticket = _ticket(root['ticket']);
      // The echo must be the ticket that was asked for.
      if (ticket.category != draft.category || ticket.body != draft.body) {
        LoopV2ChainCodec.invalid();
      }
      return LoopSupportTicketResult(
        ticket: ticket,
        attachments: LoopV2ChainCodec.unavailable(root['attachments']),
        policy: _policy(root['policy']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: createErrors);
    }
  }

  static LoopSupportPolicy _policy(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'configVersion',
      'responseWindowHours',
      'businessDaysOnly',
      'escalationChannel',
    });
    final escalationChannel = map['escalationChannel'];
    // The urgent path is copy, never a second transport.
    if (escalationChannel != 'copy') LoopV2ChainCodec.invalid();
    return LoopSupportPolicy(
      configVersion: LoopV2ChainCodec.requireString(
        map,
        'configVersion',
        pattern: RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'),
        maxLength: 64,
      ),
      responseWindowHours: LoopV2ChainCodec.requireInt(
        map,
        'responseWindowHours',
        minimum: 1,
      ),
      businessDaysOnly: LoopV2ChainCodec.requireBool(map, 'businessDaysOnly'),
      escalationChannel: 'copy',
    );
  }

  static LoopSupportTicket _ticket(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'ticketId',
      'category',
      'body',
      'status',
      'createdAt',
      'updatedAt',
      'lastEventAt',
      'events',
    });
    final rawCategory = map['category'];
    if (rawCategory is! String) LoopV2ChainCodec.invalid();
    final category = LoopSupportCategory.tryParse(rawCategory);
    if (category == null) LoopV2ChainCodec.invalid();
    final rawStatus = map['status'];
    if (rawStatus is! String) LoopV2ChainCodec.invalid();
    final status = LoopSupportTicketStatus.tryParse(rawStatus);
    if (status == null) LoopV2ChainCodec.invalid();
    final events = <LoopSupportEvent>[];
    for (final rawEvent in LoopV2ChainCodec.requireList(
      map['events'],
      maximum: 64,
    )) {
      final event = _event(rawEvent);
      // The append-only journal is strictly ordered from version 0.
      if (event.eventVersion != events.length) LoopV2ChainCodec.invalid();
      events.add(event);
    }
    if (events.isEmpty ||
        events.first.eventType != LoopSupportEventType.created) {
      LoopV2ChainCodec.invalid();
    }
    return LoopSupportTicket(
      ticketId: LoopV2ChainCodec.requireString(
        map,
        'ticketId',
        pattern: LoopV2Contract.uuidPattern,
        maxLength: 36,
      ),
      category: category,
      body: LoopV2ChainCodec.requireText(
        map,
        'body',
        maxLength: LoopSupportPolicy.maximumBodyLength,
      ),
      status: status,
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
      updatedAt: LoopV2ChainCodec.requireTimestamp(map, 'updatedAt'),
      lastEventAt: LoopV2ChainCodec.requireTimestamp(map, 'lastEventAt'),
      events: events,
    );
  }

  static LoopSupportEvent _event(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'eventVersion',
      'eventType',
      'actor',
      'note',
      'occurredAt',
    });
    final rawType = map['eventType'];
    if (rawType is! String) LoopV2ChainCodec.invalid();
    final eventType = LoopSupportEventType.tryParse(rawType);
    if (eventType == null) LoopV2ChainCodec.invalid();
    final rawActor = map['actor'];
    if (rawActor is! String) LoopV2ChainCodec.invalid();
    final actor = LoopSupportActor.tryParse(rawActor);
    if (actor == null) LoopV2ChainCodec.invalid();
    final note = map['note'] == null
        ? null
        : LoopV2ChainCodec.requireText(
            map,
            'note',
            maxLength: LoopSupportPolicy.maximumBodyLength,
          );
    // Only an operator writes a note, and only after the first event.
    if (note != null && actor != LoopSupportActor.operator) {
      LoopV2ChainCodec.invalid();
    }
    return LoopSupportEvent(
      eventVersion: LoopV2ChainCodec.requireInt(map, 'eventVersion'),
      eventType: eventType,
      actor: actor,
      note: note,
      occurredAt: LoopV2ChainCodec.requireTimestamp(map, 'occurredAt'),
    );
  }
}

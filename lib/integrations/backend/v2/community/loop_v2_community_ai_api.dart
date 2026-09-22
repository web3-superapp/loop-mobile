import 'package:dio/dio.dart';
import 'package:loop_mobile/features/community/community_ai_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

/// Strict V2 transport for the three Community AI routes (decision 0066).
///
/// The overview is a read and carries no `Idempotency-Key`; `ask` and
/// `report` are idempotent writes and carry exactly one canonical lowercase
/// UUIDv4 the caller owns. Every response goes through
/// [LoopV2Contract.strictMap], so an unknown field is an invalid payload
/// rather than a partially trusted answer — which matters more here than
/// anywhere else, because the body is written by a model.
abstract interface class LoopV2CommunityAiApi {
  Future<CommunityAiOverview> getOverview({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  });

  Future<CommunityAiAnswer> ask({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String question,
  });

  Future<CommunityAiReportReceipt> report({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String answerId,
    required CommunityAiReportReason reason,
    String? note,
  });
}

final class DioLoopV2CommunityAiApi implements LoopV2CommunityAiApi {
  DioLoopV2CommunityAiApi(this._dio);

  static const communitiesPath = '/v2/communities';

  /// A question is 2–500 code points after trimming, with no control
  /// characters. The bound is the contract's, checked here so an impossible
  /// question is never spent on a request or on the community's daily budget.
  static const minimumQuestionLength = 2;
  static const maximumQuestionLength = 500;

  /// Free note on a report: 1–500 code points after trimming.
  static const maximumNoteLength = 500;

  /// The one source handle shape the contract publishes.
  static final RegExp _sourceIdPattern = RegExp(r'^s[1-9][0-9]{0,2}$');

  /// Model-written prose: any text but the control characters that would
  /// break a line into something it is not. A newline is allowed — an answer
  /// is a paragraph, not a label.
  static final RegExp _prosePattern = RegExp(
    r'^[^\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}\n]'
    r'[^\p{Cf}\p{Cs}\p{Zl}\p{Zp}]*$',
    unicode: true,
  );

  /// One line of server copy: a title, a label, a question chip.
  static final RegExp _linePattern = RegExp(
    r'^[^\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]+$',
    unicode: true,
  );

  final Dio _dio;

  static String _requireId(String value) {
    if (!LoopV2Contract.uuidPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static String _requireUuid(Map<String, Object?> source, String key) =>
      LoopV2Contract.requiredString(
        source,
        key,
        pattern: LoopV2Contract.uuidPattern,
      );

  static String _line(
    Map<String, Object?> source,
    String key, {
    int maxLength = 200,
  }) => LoopV2Contract.requiredString(
    source,
    key,
    pattern: _linePattern,
    minLength: 1,
    maxLength: maxLength,
  );

  static String _prose(
    Map<String, Object?> source,
    String key, {
    required int maxLength,
    int minLength = 1,
  }) => LoopV2Contract.requiredString(
    source,
    key,
    pattern: _prosePattern,
    minLength: minLength,
    maxLength: maxLength,
  );

  static String _requireReasonCode(Map<String, Object?> source, String key) {
    final value = LoopV2ProjectionCodec.reasonCode(source, key);
    if (value == null) LoopV2ProjectionCodec.invalid();
    return value;
  }

  static CommunityAiSource _source(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'sourceId',
      'kind',
      'label',
      'observedAt',
    });
    final sourceId = LoopV2Contract.requiredString(
      map,
      'sourceId',
      pattern: _sourceIdPattern,
    );
    final rawKind = map['kind'];
    if (rawKind is! String) LoopV2ProjectionCodec.invalid();
    final kind = CommunityAiSourceKind.tryParse(rawKind);
    // Announcements are never assembled, so a published source that claims to
    // be one is a payload the client refuses rather than renders.
    if (kind == null || !kind.isAssemblable) LoopV2ProjectionCodec.invalid();
    return CommunityAiSource(
      sourceId: sourceId,
      kind: kind,
      label: _line(map, 'label'),
      observedAt: LoopV2ProjectionCodec.requireTimestamp(map, 'observedAt'),
    );
  }

  /// Sources, with their handles required to be distinct: two rows sharing a
  /// handle would make `[s2]` ambiguous, and an ambiguous citation is not a
  /// citation.
  static List<CommunityAiSource> _sources(Object? raw) {
    final sources = <CommunityAiSource>[];
    final seen = <String>{};
    for (final entry in LoopV2ProjectionCodec.requireList(raw, maximum: 16)) {
      final source = _source(entry);
      if (!seen.add(source.sourceId)) LoopV2ProjectionCodec.invalid();
      sources.add(source);
    }
    return List<CommunityAiSource>.unmodifiable(sources);
  }

  static List<CommunityAiOmittedSource> _omittedSources(Object? raw) {
    final omitted = <CommunityAiOmittedSource>[];
    for (final entry in LoopV2ProjectionCodec.requireList(raw, maximum: 16)) {
      final map = LoopV2Contract.strictMap(entry, const <String>{
        'kind',
        'reasonCode',
      });
      final rawKind = map['kind'];
      if (rawKind is! String) LoopV2ProjectionCodec.invalid();
      final kind = CommunityAiSourceKind.tryParse(rawKind);
      if (kind == null) LoopV2ProjectionCodec.invalid();
      omitted.add(
        CommunityAiOmittedSource(
          kind: kind,
          reasonCode: _requireReasonCode(map, 'reasonCode'),
        ),
      );
    }
    return List<CommunityAiOmittedSource>.unmodifiable(omitted);
  }

  static CommunityAiCapability _capability(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'capabilityId',
      'title',
      'summary',
      'availability',
      'reasonCode',
      'adminOnly',
    });
    final rawId = map['capabilityId'];
    if (rawId is! String) LoopV2ProjectionCodec.invalid();
    final ability = CommunityAiAbility.tryParse(rawId);
    if (ability == null) LoopV2ProjectionCodec.invalid();
    final availability = map['availability'];
    if (availability != 'available' && availability != 'unavailable') {
      LoopV2ProjectionCodec.invalid();
    }
    final available = availability == 'available';
    final reasonCode = LoopV2ProjectionCodec.reasonCode(map, 'reasonCode');
    // A closed ability with no reason cannot be explained, and an open one
    // with a reason is two answers at once. Either is a contract break.
    if (available != (reasonCode == null)) LoopV2ProjectionCodec.invalid();
    return CommunityAiCapability(
      ability: ability,
      title: _line(map, 'title', maxLength: 40),
      summary: _line(map, 'summary'),
      available: available,
      reasonCode: reasonCode,
      adminOnly: LoopV2ProjectionCodec.requireBool(map, 'adminOnly'),
    );
  }

  static CommunityAiKnowledge _knowledge(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'sourceCount',
      'updatedAt',
      'sources',
      'omittedSources',
      'documents',
    });
    final documents = LoopV2Contract.strictMap(map['documents'], const <String>{
      'status',
      'reasonCode',
    });
    // There is no document corpus behind LOOP, so this branch has exactly one
    // legal value and the page can never print a document count.
    if (documents['status'] != 'unavailable') LoopV2ProjectionCodec.invalid();
    final sources = _sources(map['sources']);
    final updatedAt = map['updatedAt'] == null
        ? null
        : LoopV2ProjectionCodec.requireTimestamp(map, 'updatedAt');
    final sourceCount = LoopV2ProjectionCodec.requireCount(map, 'sourceCount');
    // The count is the count of the list it arrived with; a figure the rows
    // do not support would be a number with no source.
    if (sourceCount != sources.length) LoopV2ProjectionCodec.invalid();
    if ((sourceCount == 0) != (updatedAt == null)) {
      LoopV2ProjectionCodec.invalid();
    }
    return CommunityAiKnowledge(
      sourceCount: sourceCount,
      updatedAt: updatedAt,
      sources: sources,
      omittedSources: _omittedSources(map['omittedSources']),
      documentsReasonCode: _requireReasonCode(documents, 'reasonCode'),
    );
  }

  static CommunityAiBrief _brief(Object? raw) {
    if (raw is! Map) LoopV2ProjectionCodec.invalid();
    if (raw['status'] != 'available') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'reasonCode',
      });
      if (map['status'] != 'unavailable') LoopV2ProjectionCodec.invalid();
      return CommunityAiBriefUnavailable(_requireReasonCode(map, 'reasonCode'));
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'messageCount',
      'bounded',
      'windowHours',
      'summary',
      'model',
      'generatedAt',
    });
    final windowHours = LoopV2ProjectionCodec.requireCount(map, 'windowHours');
    if (windowHours < 1 || windowHours > 168) LoopV2ProjectionCodec.invalid();
    return CommunityAiBriefAvailable(
      messageCount: LoopV2ProjectionCodec.requireCount(map, 'messageCount'),
      bounded: LoopV2ProjectionCodec.requireBool(map, 'bounded'),
      windowHours: windowHours,
      summary: _prose(map, 'summary', maxLength: 2000),
      model: _line(map, 'model', maxLength: 128),
      generatedAt: LoopV2ProjectionCodec.requireTimestamp(map, 'generatedAt'),
    );
  }

  @override
  Future<CommunityAiOverview> getOverview({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  }) async {
    final id = _requireId(communityId);
    try {
      final response = await _dio.get<Object?>(
        '$communitiesPath/$id/ai/overview',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'capabilities',
        'knowledge',
        'exampleQuestions',
        'brief',
        'disclaimer',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      final capabilities = <CommunityAiCapability>[];
      final seen = <CommunityAiAbility>{};
      for (final entry in LoopV2ProjectionCodec.requireList(
        root['capabilities'],
        maximum: 8,
      )) {
        final capability = _capability(entry);
        // The list is the server's answer about this account; a repeated row
        // would make it two answers.
        if (!seen.add(capability.ability)) LoopV2ProjectionCodec.invalid();
        capabilities.add(capability);
      }
      final questions = <String>[];
      for (final entry in LoopV2ProjectionCodec.requireList(
        root['exampleQuestions'],
        maximum: 5,
      )) {
        if (entry is! String ||
            entry.isEmpty ||
            entry.length > 100 ||
            !_linePattern.hasMatch(entry)) {
          LoopV2ProjectionCodec.invalid();
        }
        questions.add(entry);
      }
      return CommunityAiOverview(
        capabilities: List<CommunityAiCapability>.unmodifiable(capabilities),
        knowledge: _knowledge(root['knowledge']),
        exampleQuestions: List<String>.unmodifiable(questions),
        brief: _brief(root['brief']),
        disclaimer: _prose(root, 'disclaimer', maxLength: 500),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  /// The question the contract accepts, or a refusal that costs no request.
  static String normalizeQuestion(String question) {
    final trimmed = question.trim();
    final length = trimmed.runes.length;
    if (length < minimumQuestionLength ||
        length > maximumQuestionLength ||
        !_linePattern.hasMatch(trimmed)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return trimmed;
  }

  static String? _normalizeNote(String? note) {
    if (note == null) return null;
    final trimmed = note.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.runes.length > maximumNoteLength ||
        !_prosePattern.hasMatch(trimmed)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return trimmed;
  }

  @override
  Future<CommunityAiAnswer> ask({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String question,
  }) async {
    final id = _requireId(communityId);
    final asked = normalizeQuestion(question);
    try {
      final response = await _dio.post<Object?>(
        '$communitiesPath/$id/ai/ask',
        data: <String, Object?>{'question': asked},
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'answerId',
        'answer',
        'refusal',
        'citations',
        'sources',
        'omittedSources',
        'model',
        'generatedAt',
        'disclaimer',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      final answer = root['answer'];
      if (answer is! String || answer.length > 8000) {
        LoopV2ProjectionCodec.invalid();
      }
      if (answer.isNotEmpty && !_prosePattern.hasMatch(answer)) {
        LoopV2ProjectionCodec.invalid();
      }
      final refusal = root['refusal'] == null
          ? null
          : _prose(root, 'refusal', maxLength: 2000);
      // A reply has to be *something*: an empty answer is only legal when the
      // refusal says why there is none.
      if (answer.isEmpty && refusal == null) LoopV2ProjectionCodec.invalid();
      final sources = _sources(root['sources']);
      final citations = <CommunityAiSource>[];
      final cited = <String>{};
      for (final entry in LoopV2ProjectionCodec.requireList(
        root['citations'],
        maximum: 12,
      )) {
        final citation = _source(entry);
        if (!cited.add(citation.sourceId)) LoopV2ProjectionCodec.invalid();
        // A citation carries its own label and observation time and is
        // rendered from those, never by looking its handle up in `sources`.
        // The two lists are not required to agree: a replayed answer (the
        // same question on the same idempotency key) returns the citations
        // that were stored with it beside a freshly assembled `sources`, so a
        // cross-check here would refuse a reply the server considers correct.
        citations.add(citation);
      }
      return CommunityAiAnswer(
        answerId: _requireUuid(root, 'answerId'),
        answer: answer,
        refusal: refusal,
        citations: List<CommunityAiSource>.unmodifiable(citations),
        sources: sources,
        omittedSources: _omittedSources(root['omittedSources']),
        model: _line(root, 'model', maxLength: 128),
        generatedAt: LoopV2ProjectionCodec.requireTimestamp(
          root,
          'generatedAt',
        ),
        disclaimer: _prose(root, 'disclaimer', maxLength: 500),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.communityAiWriteErrors,
      );
    }
  }

  @override
  Future<CommunityAiReportReceipt> report({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String answerId,
    required CommunityAiReportReason reason,
    String? note,
  }) async {
    final id = _requireId(communityId);
    final answer = _requireId(answerId);
    final trimmedNote = _normalizeNote(note);
    try {
      final response = await _dio.post<Object?>(
        '$communitiesPath/$id/ai/answers/$answer/report',
        data: <String, Object?>{
          'reason': reason.wireName,
          'note': ?trimmedNote,
        },
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 201);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'answerId',
        'reportId',
        'reason',
        'createdAt',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      final rawReason = root['reason'];
      if (rawReason is! String) LoopV2ProjectionCodec.invalid();
      final storedReason = CommunityAiReportReason.tryParse(rawReason);
      if (storedReason == null) LoopV2ProjectionCodec.invalid();
      final receiptAnswerId = _requireUuid(root, 'answerId');
      // The receipt has to be about the answer that was reported.
      if (receiptAnswerId != answer) LoopV2ProjectionCodec.invalid();
      return CommunityAiReportReceipt(
        answerId: receiptAnswerId,
        reportId: _requireUuid(root, 'reportId'),
        reason: storedReason,
        createdAt: LoopV2ProjectionCodec.requireTimestamp(root, 'createdAt'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.communityAiWriteErrors,
      );
    }
  }
}

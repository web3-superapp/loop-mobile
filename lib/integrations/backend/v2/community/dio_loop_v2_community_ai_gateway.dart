import 'package:loop_mobile/features/community/community_ai_gateway.dart';
import 'package:loop_mobile/features/community/community_ai_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/v2/community/dio_loop_v2_community_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_ai_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';

/// Authenticated V2 adapter for Community AI.
///
/// It owns the idempotency identity of the two writes, and only that:
///
/// * one question is one logical operation, so the key is bound to the
///   question's own text. Retrying the same question after a timeout replays
///   the stored answer and spends no second model call; a different question
///   is a different operation and takes a new key.
/// * one report is bound to the answer it is about, which is also how the
///   server stores it — one report per (answer, account).
final class DioLoopV2CommunityAiGateway implements CommunityAiGateway {
  DioLoopV2CommunityAiGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2CommunityAiApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2CommandKeyring _keyring;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  String get _clientVersion => _clientMetadata.clientVersion;

  /// Visible for tests: the key currently bound to one question.
  String? peekAskKey({required String communityId, required String question}) =>
      _keyring.peek(_askSignature(communityId, question));

  static String _askSignature(String communityId, String question) =>
      'community-ai-ask:$communityId:${question.trim()}';

  Future<T> _write<T>(
    String signature,
    Future<T> Function(String accessToken, String idempotencyKey) request,
  ) async {
    final key = _keyring.reserve(signature);
    try {
      final result = await executeCommunityRequest(
        _session,
        (accessToken) => request(accessToken, key),
        write: true,
      );
      _keyring.release(signature);
      return result;
    } on CommunityGatewayException catch (failure) {
      // Only an unresolved outcome keeps the key for an identical retry.
      if (!communityOutcomeIsUnresolved(failure.kind)) {
        _keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }

  @override
  Future<CommunityAiOverview> loadOverview(String communityId) =>
      executeCommunityRequest(
        _session,
        (accessToken) => _api.getOverview(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          communityId: communityId,
        ),
        write: false,
      );

  @override
  Future<CommunityAiAnswer> ask({
    required String communityId,
    required String question,
  }) => _write(
    _askSignature(communityId, question),
    (accessToken, key) => _api.ask(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      communityId: communityId,
      question: question,
    ),
  );

  @override
  Future<CommunityAiReportReceipt> report({
    required String communityId,
    required String answerId,
    required CommunityAiReportReason reason,
    String? note,
  }) => _write(
    'community-ai-report:$answerId:${reason.wireName}',
    (accessToken, key) => _api.report(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      communityId: communityId,
      answerId: answerId,
      reason: reason,
      note: note,
    ),
  );
}

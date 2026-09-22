import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_ai_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// Feature-facing port for Community AI (loop-api decision 0066).
///
/// It exposes no transport type, no `/v2/` literal and no idempotency detail:
/// the adapter owns the key of each write, including the rule that a retry of
/// the *same* question replays the same key and a new question takes a new
/// one.
abstract interface class CommunityAiGateway {
  CommunityGatewayMode get mode;

  /// The ability list, the knowledge snapshot, the example questions and
  /// today's brief, in one read.
  Future<CommunityAiOverview> loadOverview(String communityId);

  /// Asks one question. Retrying an identical question replays the stored
  /// answer instead of spending another model call.
  Future<CommunityAiAnswer> ask({
    required String communityId,
    required String question,
  });

  /// Reports one answer this account received.
  Future<CommunityAiReportReceipt> report({
    required String communityId,
    required String answerId,
    required CommunityAiReportReason reason,
    String? note,
  });
}

/// Production default: every call fails closed. There is no fixture answer
/// and no cached sentence — an answer the model did not produce is never
/// shown as one.
final class UnavailableCommunityAiGateway implements CommunityAiGateway {
  const UnavailableCommunityAiGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const CommunityGatewayException(CommunityFailureKind.unavailable),
  );

  @override
  Future<CommunityAiOverview> loadOverview(String communityId) =>
      _unavailable();

  @override
  Future<CommunityAiAnswer> ask({
    required String communityId,
    required String question,
  }) => _unavailable();

  @override
  Future<CommunityAiReportReceipt> report({
    required String communityId,
    required String answerId,
    required CommunityAiReportReason reason,
    String? note,
  }) => _unavailable();
}

/// Overridden by the composition root with the authenticated V2 adapter.
///
/// `main_preview.dart` deliberately leaves it closed: a Preview answer would
/// be a sentence no model wrote, which is exactly what decision 0066 forbids.
final communityAiGatewayProvider = Provider<CommunityAiGateway>(
  (ref) => const UnavailableCommunityAiGateway(),
);

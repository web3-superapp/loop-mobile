import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/search_models.dart';

/// Feature-facing port for the `search` module.
abstract interface class SearchGateway {
  CommunityGatewayMode get mode;

  Future<SearchPage> search({
    required SearchDomain domain,
    required String query,
    String? cursor,
  });
}

final class UnavailableSearchGateway implements SearchGateway {
  const UnavailableSearchGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  @override
  Future<SearchPage> search({
    required SearchDomain domain,
    required String query,
    String? cursor,
  }) => Future<SearchPage>.error(
    const CommunityGatewayException(CommunityFailureKind.unavailable),
  );
}

final searchGatewayProvider = Provider<SearchGateway>(
  (ref) => const UnavailableSearchGateway(),
);

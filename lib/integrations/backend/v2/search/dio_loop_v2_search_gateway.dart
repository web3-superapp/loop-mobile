import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/v2/community/dio_loop_v2_community_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/search/loop_v2_search_api.dart';

/// Authenticated V2 adapter for the `search` module. Search is a read: it
/// carries no idempotency key and issues no write.
final class DioLoopV2SearchGateway implements SearchGateway {
  DioLoopV2SearchGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final LoopV2SearchApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<SearchPage> search({
    required SearchDomain domain,
    required String query,
    String? cursor,
  }) => executeCommunityRequest(
    _session,
    (accessToken) => _api.search(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
      domain: domain,
      query: query,
      cursor: cursor,
    ),
  );
}

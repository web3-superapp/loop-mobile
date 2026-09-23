import 'package:flutter/foundation.dart';

enum SearchDomain {
  users('users', '用户'),
  communities('communities', '社区'),
  assets('assets', '资产'),
  launch('launch', 'Launch'),
  dapps('dapps', 'DApp');

  const SearchDomain(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// The only way to navigate a result. Routes are never assembled from copy,
/// a ticker or a domain name.
///
/// `assetDetail` is the one destination that carries a parameter, and it
/// carries the server's own CAIP `assetId` — never the row's symbol, which
/// two contracts may share.
sealed class SearchDestination {
  const SearchDestination();

  static const String publicProfileKind = 'publicProfile';
  static const String communityProfileKind = 'communityProfile';
  static const String assetDetailKind = 'assetDetail';

  String get kind;
}

@immutable
final class SearchPublicProfileDestination extends SearchDestination {
  const SearchPublicProfileDestination();

  @override
  String get kind => SearchDestination.publicProfileKind;
}

@immutable
final class SearchCommunityProfileDestination extends SearchDestination {
  const SearchCommunityProfileDestination();

  @override
  String get kind => SearchDestination.communityProfileKind;
}

@immutable
final class SearchAssetDestination extends SearchDestination {
  const SearchAssetDestination(this.assetId);

  /// The canonical CAIP id the token page is opened with.
  final String assetId;

  @override
  String get kind => SearchDestination.assetDetailKind;
}

enum SearchResultType {
  user('user'),
  community('community'),
  asset('asset');

  const SearchResultType(this.wireName);

  final String wireName;

  static SearchResultType? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

@immutable
final class SearchResult {
  const SearchResult({
    required this.resultType,
    required this.stableId,
    required this.title,
    required this.subtitle,
    required this.avatarRef,
    required this.memberCount,
    required this.verificationStatus,
    required this.destination,
    this.logoUrl,
  });

  final SearchResultType resultType;
  final String stableId;
  final String title;
  final String? subtitle;
  final String? avatarRef;

  /// The registry's published token artwork on an asset row, `null` on a user
  /// or community row (decision 0072). A logo is never an identity: only
  /// [stableId] addresses the result.
  final String? logoUrl;

  /// Present only for a community result; `null` renders nothing, never `0`.
  final int? memberCount;
  final String? verificationStatus;
  final SearchDestination destination;
}

@immutable
final class SearchPage {
  const SearchPage({
    required this.domain,
    required this.available,
    required this.reasonCode,
    required this.results,
    required this.nextCursor,
  });

  final SearchDomain domain;
  final bool available;

  /// Server-supplied cause for an unavailable domain.
  final String? reasonCode;
  final List<SearchResult> results;
  final String? nextCursor;
}

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
enum SearchDestinationKind {
  publicProfile('publicProfile'),
  communityProfile('communityProfile');

  const SearchDestinationKind(this.wireName);

  final String wireName;

  static SearchDestinationKind? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

enum SearchResultType {
  user('user'),
  community('community');

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
  });

  final SearchResultType resultType;
  final String stableId;
  final String title;
  final String? subtitle;
  final String? avatarRef;

  /// Present only for a community result; `null` renders nothing, never `0`.
  final int? memberCount;
  final String? verificationStatus;
  final SearchDestinationKind destination;
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

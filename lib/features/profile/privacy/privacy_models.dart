import 'package:flutter/foundation.dart';

const int privacyMaximumVersion = 2147483647;

/// Sanitized validation failure for data outside the backend Privacy contract.
final class InvalidPrivacyContractException implements Exception {
  const InvalidPrivacyContractException();

  String get code => 'invalid_privacy_contract';

  @override
  String toString() => 'The Privacy contract value is invalid';
}

/// Display preference only. It never grants an authorization, proves a social
/// relationship, or shares a holding.
enum PrivacyAudience {
  self('self'),
  everyone('everyone');

  const PrivacyAudience(this.wireValue);

  final String wireValue;

  static PrivacyAudience fromWire(String value) {
    for (final audience in values) {
      if (audience.wireValue == value) return audience;
    }
    throw const InvalidPrivacyContractException();
  }
}

/// The four V2 visibility facets. Copy-trade visibility is deliberately absent:
/// copytrade is retired and must not return.
enum PrivacyVisibilityFacet {
  totalAssets('totalAssets', '总资产'),
  miningPower('miningPower', '挖矿算力'),
  communities('communities', '加入的社区'),
  tradeHistory('tradeHistory', '交易记录');

  const PrivacyVisibilityFacet(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

@immutable
final class PrivacyVisibility {
  factory PrivacyVisibility({
    PrivacyAudience totalAssets = PrivacyAudience.self,
    PrivacyAudience miningPower = PrivacyAudience.self,
    PrivacyAudience communities = PrivacyAudience.self,
    PrivacyAudience tradeHistory = PrivacyAudience.self,
  }) =>
      PrivacyVisibility._(totalAssets, miningPower, communities, tradeHistory);

  const PrivacyVisibility._(
    this.totalAssets,
    this.miningPower,
    this.communities,
    this.tradeHistory,
  );

  /// Fail-closed default: nothing is visible to anyone but the owner.
  const PrivacyVisibility.defaults()
    : totalAssets = PrivacyAudience.self,
      miningPower = PrivacyAudience.self,
      communities = PrivacyAudience.self,
      tradeHistory = PrivacyAudience.self;

  final PrivacyAudience totalAssets;
  final PrivacyAudience miningPower;
  final PrivacyAudience communities;
  final PrivacyAudience tradeHistory;

  PrivacyAudience operator [](PrivacyVisibilityFacet facet) => switch (facet) {
    PrivacyVisibilityFacet.totalAssets => totalAssets,
    PrivacyVisibilityFacet.miningPower => miningPower,
    PrivacyVisibilityFacet.communities => communities,
    PrivacyVisibilityFacet.tradeHistory => tradeHistory,
  };

  PrivacyVisibility withFacet(
    PrivacyVisibilityFacet facet,
    PrivacyAudience audience,
  ) => PrivacyVisibility(
    totalAssets: facet == PrivacyVisibilityFacet.totalAssets
        ? audience
        : totalAssets,
    miningPower: facet == PrivacyVisibilityFacet.miningPower
        ? audience
        : miningPower,
    communities: facet == PrivacyVisibilityFacet.communities
        ? audience
        : communities,
    tradeHistory: facet == PrivacyVisibilityFacet.tradeHistory
        ? audience
        : tradeHistory,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyVisibility &&
          other.totalAssets == totalAssets &&
          other.miningPower == miningPower &&
          other.communities == communities &&
          other.tradeHistory == tradeHistory;

  @override
  int get hashCode =>
      Object.hash(totalAssets, miningPower, communities, tradeHistory);
}

/// The three social admission gates the server reads before it lets anyone
/// reach this account (decision 0070, 2026-09-23). Unlike the visibility
/// facets these are not display preferences: they are the admission rule
/// itself, applied by `POST /v2/message-requests`,
/// `POST /v2/chat/direct-channels` and `POST /v2/chat/groups`.
///
/// Each gate is binary but carries its own open value on the wire
/// (`enabled` for friend requests, `friends` for the two friend-scoped ones);
/// the closed value is `disabled` for all three.
enum PrivacySocialGate {
  friendRequests('friendRequests', 'enabled', '允许陌生人发消息请求'),
  directMessages('directMessages', 'friends', '允许好友发起私聊'),
  groupInvites('groupInvites', 'friends', '允许好友拉我进群');

  const PrivacySocialGate(this.wireValue, this.openWireValue, this.label);

  /// The field name inside the `privacy` object.
  final String wireValue;

  final String openWireValue;
  final String label;

  static const String closedWireValue = 'disabled';

  String wireFor({required bool open}) =>
      open ? openWireValue : closedWireValue;

  /// Strict: a value outside this gate's two-value enum is a contract
  /// violation, never a silent close.
  bool openFromWire(String value) {
    if (value == openWireValue) return true;
    if (value == closedWireValue) return false;
    throw const InvalidPrivacyContractException();
  }
}

/// Default open, because a missing server row means open (decision 0070).
/// A closed gate is only ever the owner's explicit choice.
@immutable
final class PrivacySocialGates {
  factory PrivacySocialGates({
    bool friendRequests = true,
    bool directMessages = true,
    bool groupInvites = true,
  }) => PrivacySocialGates._(friendRequests, directMessages, groupInvites);

  const PrivacySocialGates._(
    this.friendRequests,
    this.directMessages,
    this.groupInvites,
  );

  const PrivacySocialGates.defaults()
    : friendRequests = true,
      directMessages = true,
      groupInvites = true;

  /// A stranger may send a message request. The target must also be
  /// `discoverable` before anyone can find it.
  final bool friendRequests;

  /// An accepted friend may open a direct channel.
  final bool directMessages;

  /// An accepted friend may add this account to a small group.
  final bool groupInvites;

  bool operator [](PrivacySocialGate gate) => switch (gate) {
    PrivacySocialGate.friendRequests => friendRequests,
    PrivacySocialGate.directMessages => directMessages,
    PrivacySocialGate.groupInvites => groupInvites,
  };

  PrivacySocialGates withGate(PrivacySocialGate gate, {required bool open}) =>
      PrivacySocialGates(
        friendRequests: gate == PrivacySocialGate.friendRequests
            ? open
            : friendRequests,
        directMessages: gate == PrivacySocialGate.directMessages
            ? open
            : directMessages,
        groupInvites: gate == PrivacySocialGate.groupInvites
            ? open
            : groupInvites,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacySocialGates &&
          other.friendRequests == friendRequests &&
          other.directMessages == directMessages &&
          other.groupInvites == groupInvites;

  @override
  int get hashCode => Object.hash(friendRequests, directMessages, groupInvites);
}

@immutable
final class PrivacyValues {
  const PrivacyValues({
    required this.discoverable,
    required this.anonymousMode,
    this.visibility = const PrivacyVisibility.defaults(),
    this.social = const PrivacySocialGates.defaults(),
  });

  /// The server's version-0 projection: presentation fails closed, the three
  /// social gates are open (decision 0070). The client never writes these
  /// defaults on its own; it reports what the admission checks already apply.
  const PrivacyValues.defaults()
    : discoverable = false,
      anonymousMode = false,
      visibility = const PrivacyVisibility.defaults(),
      social = const PrivacySocialGates.defaults();

  factory PrivacyValues.copyOf(PrivacyValues source) => PrivacyValues(
    discoverable: source.discoverable,
    anonymousMode: source.anonymousMode,
    visibility: source.visibility,
    social: source.social,
  );

  /// Shows the LOOP ID and allows the owner to be found by search.
  final bool discoverable;

  /// Shows the alias only; the wallet address is never displayed.
  final bool anonymousMode;

  final PrivacyVisibility visibility;

  /// The admission gates. A display switch never grants access; these do.
  final PrivacySocialGates social;

  PrivacyValues withDiscoverable(bool value) => PrivacyValues(
    discoverable: value,
    anonymousMode: anonymousMode,
    visibility: visibility,
    social: social,
  );

  PrivacyValues withAnonymousMode(bool value) => PrivacyValues(
    discoverable: discoverable,
    anonymousMode: value,
    visibility: visibility,
    social: social,
  );

  PrivacyValues withVisibility(PrivacyVisibility value) => PrivacyValues(
    discoverable: discoverable,
    anonymousMode: anonymousMode,
    visibility: value,
    social: social,
  );

  PrivacyValues withSocial(PrivacySocialGates value) => PrivacyValues(
    discoverable: discoverable,
    anonymousMode: anonymousMode,
    visibility: visibility,
    social: value,
  );

  PrivacyValues withFacet(
    PrivacyVisibilityFacet facet,
    PrivacyAudience audience,
  ) => withVisibility(visibility.withFacet(facet, audience));

  PrivacyValues withSocialGate(PrivacySocialGate gate, {required bool open}) =>
      withSocial(social.withGate(gate, open: open));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyValues &&
          other.discoverable == discoverable &&
          other.anonymousMode == anonymousMode &&
          other.visibility == visibility &&
          other.social == social;

  @override
  int get hashCode =>
      Object.hash(discoverable, anonymousMode, visibility, social);
}

@immutable
final class PrivacyResource {
  factory PrivacyResource({
    required int version,
    required PrivacyValues values,
    required DateTime? updatedAt,
  }) {
    if (version < 0 ||
        version > privacyMaximumVersion ||
        ((version == 0) != (updatedAt == null))) {
      throw const InvalidPrivacyContractException();
    }
    return PrivacyResource._(
      version,
      PrivacyValues.copyOf(values),
      updatedAt?.toUtc(),
    );
  }

  const PrivacyResource._(this.version, this.values, this.updatedAt);

  factory PrivacyResource.empty() => PrivacyResource(
    version: 0,
    values: const PrivacyValues.defaults(),
    updatedAt: null,
  );

  factory PrivacyResource.copyOf(PrivacyResource source) => PrivacyResource(
    version: source.version,
    values: source.values,
    updatedAt: source.updatedAt,
  );

  final int version;
  final PrivacyValues values;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyResource &&
          other.version == version &&
          other.values == values &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(version, values, updatedAt);
}

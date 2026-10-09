import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/community/community_models.dart';

/// What a surface that only holds a community's id needs to draw its face
/// (decision 0122): the preset or uploaded `logoRef` and the first sentence
/// of its description.
@immutable
final class CommunityFace {
  const CommunityFace({required this.name, this.logoRef, this.description});

  final String name;
  final String? logoRef;
  final String? description;

  /// The description up to its first sentence end, or null when there is
  /// none. Used where a conversation has no message yet.
  String? get firstSentence {
    final text = description?.trim();
    if (text == null || text.isEmpty) return null;
    final end = RegExp('[。！？!?\n]').firstMatch(text);
    final sentence = end == null ? text : text.substring(0, end.start);
    final trimmed = sentence.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Every community face this account has already read, by `communityId`.
///
/// The Stream channel list, the Intel ranking and the voice-room strip name a
/// community by id alone; none of their payloads carries a `logoRef`, so each
/// drew initials. The community home aggregate and the directory pages do
/// carry one, and they write into this memory as they land. Nothing here is
/// read from the network on its own: a community this account has not seen
/// yet keeps its id-derived monogram, exactly as before.
final class CommunityFacesNotifier
    extends Notifier<Map<String, CommunityFace>> {
  @override
  Map<String, CommunityFace> build() {
    // One account, one memory.
    ref.watch(loopAccountScopeProvider);
    return const <String, CommunityFace>{};
  }

  /// Records [communities]; the state changes only when a face did.
  void remember(Iterable<CommunitySummary> communities) {
    Map<String, CommunityFace>? next;
    for (final community in communities) {
      final current = (next ?? state)[community.communityId];
      if (current != null &&
          current.name == community.name &&
          current.logoRef == community.logoRef &&
          current.description == community.description) {
        continue;
      }
      next ??= <String, CommunityFace>{...state};
      next[community.communityId] = CommunityFace(
        name: community.name,
        logoRef: community.logoRef,
        description: community.description,
      );
    }
    if (next != null) state = Map<String, CommunityFace>.unmodifiable(next);
  }

  /// Records every community the home aggregate carries.
  void rememberHome(CommunityHome home) => remember(<CommunitySummary>[
    for (final entry in home.joined) entry.community,
    for (final entry in home.owned) entry.community,
    ...home.discover,
  ]);
}

final communityFacesProvider =
    NotifierProvider<CommunityFacesNotifier, Map<String, CommunityFace>>(
      CommunityFacesNotifier.new,
    );

/// Hands [faces] to the rows under it that cannot reach a provider — the
/// Stream channel list items are plain widgets built by the SDK.
class CommunityFacesScope extends InheritedWidget {
  const CommunityFacesScope({
    required this.faces,
    required super.child,
    super.key,
  });

  final Map<String, CommunityFace> faces;

  static Map<String, CommunityFace> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CommunityFacesScope>()
          ?.faces ??
      const <String, CommunityFace>{};

  @override
  bool updateShouldNotify(CommunityFacesScope oldWidget) =>
      !identical(faces, oldWidget.faces);
}

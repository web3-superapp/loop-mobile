import 'package:flutter/widgets.dart';

/// The person a direct conversation is with, as LOOP itself records them.
///
/// A direct channel has no group-Alias namespace, and Stream carries no name
/// for a LOOP account at all — `User.name` is empty and `User.id` is the LOOP
/// row key (device report 2026-09-19 · F5). The only honest name for the peer
/// is the one the page's own header already shows: `alias ?? loopId` from
/// their public profile.
///
/// The `dm` page publishes it here so the Stream widgets underneath — today
/// the mention autocomplete row — can name the peer from the same source as
/// the header instead of from the provider. A page that has no trusted
/// identity (a deep link carries none) publishes nothing, and those widgets
/// fail closed rather than reaching for the id.
class LoopDirectPeerScope extends InheritedWidget {
  const LoopDirectPeerScope({
    required this.displayName,
    required super.child,
    super.key,
  });

  /// `alias ?? loopId`. Never an invented value, and never a Stream one.
  final String displayName;

  static String? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LoopDirectPeerScope>()
      ?.displayName;

  @override
  bool updateShouldNotify(LoopDirectPeerScope oldWidget) =>
      oldWidget.displayName != displayName;
}

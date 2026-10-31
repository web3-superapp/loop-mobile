import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

/// One member a group mosaic may draw (decision 0258).
///
/// [name] is the label the caller already resolved for this surface — the
/// account's own name in a real-identity room, the group-scoped Alias or
/// 「成员」 otherwise — and is only ever drawn as one initial. [imageUrl] is an
/// address the caller already validated; `null` draws the initial cell.
typedef GroupMosaicMember = ({String id, String name, String? imageUrl});

/// The most members one mosaic draws, as WeChat's group face does.
const int groupMosaicMaxMembers = 9;

/// The gap between two cells, and between the cells and the tile's edge.
const double groupMosaicGap = 2;

/// Row lengths, top to bottom, for [count] members (decision 0258).
///
/// WeChat's rule: one member fills the tile; up to four sit on a two-wide
/// grid; five to nine on a three-wide grid. Every row but the first is full,
/// and the first row takes what is left over, centred — so three is 1 + 2,
/// five is 2 + 3, seven is 1 + 3 + 3 and eight is 2 + 3 + 3.
List<int> groupMosaicRowCounts(int count) {
  final n = count.clamp(0, groupMosaicMaxMembers);
  if (n == 0) return const <int>[];
  final columns = groupMosaicColumns(n);
  final rows = (n / columns).ceil();
  final first = n - (rows - 1) * columns;
  return List<int>.unmodifiable(<int>[
    first,
    for (var row = 1; row < rows; row++) columns,
  ]);
}

/// The grid width [count] members are laid out on: 1, 2 or 3.
int groupMosaicColumns(int count) {
  final n = count.clamp(0, groupMosaicMaxMembers);
  if (n <= 1) return 1;
  if (n <= 4) return 2;
  return 3;
}

/// Where each of [count] cells sits inside a [size] square, row by row.
///
/// The cell side comes from the grid width alone, so a three-member mosaic
/// draws the same cells as a four-member one; each row is centred across, and
/// the block of rows is centred down.
@visibleForTesting
List<Rect> groupMosaicCellRects(int count, double size) {
  final rowCounts = groupMosaicRowCounts(count);
  if (rowCounts.isEmpty) return const <Rect>[];
  final columns = groupMosaicColumns(count);
  final cell = math.max(
    0.0,
    (size - groupMosaicGap * 2 - groupMosaicGap * (columns - 1)) / columns,
  );
  final blockHeight =
      rowCounts.length * cell + (rowCounts.length - 1) * groupMosaicGap;
  var top = (size - blockHeight) / 2;
  final rects = <Rect>[];
  for (final inRow in rowCounts) {
    final rowWidth = inRow * cell + (inRow - 1) * groupMosaicGap;
    var left = (size - rowWidth) / 2;
    for (var index = 0; index < inRow; index++) {
      rects.add(Rect.fromLTWH(left, top, cell, cell));
      left += cell + groupMosaicGap;
    }
    top += cell + groupMosaicGap;
  }
  return List<Rect>.unmodifiable(rects);
}

/// FNV-1a over [value]'s code units: a published, stable hash.
int _fnv1a(String value, [int seed = 0x811c9dc5]) {
  var hash = seed;
  for (final unit in value.codeUnits) {
    hash = (hash ^ unit) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// The cache key for one mosaic: the hash of its member ids in order, and
/// the tile's geometry (decision 0258).
@visibleForTesting
String groupMosaicCacheKey(
  List<GroupMosaicMember> members,
  double size,
  double radius,
) {
  var hash = 0x811c9dc5;
  for (final member in members) {
    hash = _fnv1a(member.id, hash);
    hash = _fnv1a('\u0000', hash);
  }
  return '${members.length}:${hash.toRadixString(16)}@$size/$radius';
}

final class _GroupMosaicEntry {
  _GroupMosaicEntry(this.members, this.tile);

  final List<GroupMosaicMember> members;
  final Widget tile;
}

/// Built mosaics, least recently used first. Memory only.
final LinkedHashMap<String, _GroupMosaicEntry> _groupMosaicCache =
    LinkedHashMap<String, _GroupMosaicEntry>();

const int _groupMosaicCacheCapacity = 256;

/// How many mosaics were laid out since the last [debugResetGroupMosaicCache].
@visibleForTesting
int debugGroupMosaicBuilds = 0;

/// Empties the mosaic cache. Tests only.
@visibleForTesting
void debugResetGroupMosaicCache() {
  _groupMosaicCache.clear();
  debugGroupMosaicBuilds = 0;
}

/// A group conversation's face: its own logo when it has one, otherwise its
/// members' faces in WeChat's grid (decision 0258).
///
/// Always a rounded square on a dark ground, so a group reads apart from a
/// one-to-one conversation, whose face stays a circle.
///
/// The grid is laid out once per member set: the cells for the same ids at
/// the same size are kept in memory and handed back as the same widget, so a
/// list row that rebuilds on every new message does not lay its face out
/// again. A member joining or leaving changes the id list, and with it the
/// key.
class GroupMosaicAvatar extends StatelessWidget {
  const GroupMosaicAvatar({
    required this.members,
    super.key,
    this.size = 44,
    this.label = '',
    this.logo,
    this.logoUrl,
    this.radius,
    this.semanticLabel,
  });

  /// In the order they should be drawn; only the first nine are.
  final List<GroupMosaicMember> members;
  final double size;

  /// The group's name, drawn as one initial when no member is known.
  final String label;

  /// The group's own face, drawn in the same rounded square instead of the
  /// grid (a community's logo).
  final Widget? logo;

  /// An uploaded group picture; the grid stays under it until it arrives.
  final String? logoUrl;

  /// Corner radius of the tile; defaults to the inner radius, capped at a
  /// quarter of [size].
  final double? radius;
  final String? semanticLabel;

  double get _corner =>
      radius ?? math.min(LoopRadius.innerValue, size / 4).toDouble();

  @override
  Widget build(BuildContext context) {
    final corner = _corner;
    final logo = this.logo;
    final Widget face;
    if (logo != null) {
      face = SizedBox.square(
        key: const ValueKey<String>('group-mosaic-logo'),
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(corner),
          child: logo,
        ),
      );
    } else {
      final mosaic = _mosaic(corner);
      final url = logoUrl;
      face = url == null
          ? mosaic
          : LoopRemoteAvatar(
              key: const ValueKey<String>('group-mosaic-logo-image'),
              url: url,
              size: size,
              shape: BoxShape.rectangle,
              radius: corner,
              fallback: mosaic,
            );
    }
    final semantic = semanticLabel;
    if (semantic == null) return ExcludeSemantics(child: face);
    return Semantics(image: true, label: semantic, child: face);
  }

  Widget _mosaic(double corner) {
    final shown = members.length > groupMosaicMaxMembers
        ? members.sublist(0, groupMosaicMaxMembers)
        : members;
    final drawn = shown.isEmpty
        ? <GroupMosaicMember>[(id: label, name: label, imageUrl: null)]
        : List<GroupMosaicMember>.unmodifiable(shown);
    final key = groupMosaicCacheKey(drawn, size, corner);
    final cached = _groupMosaicCache.remove(key);
    if (cached != null && listEquals(cached.members, drawn)) {
      _groupMosaicCache[key] = cached;
      return cached.tile;
    }
    final tile = _GroupMosaicTile(
      key: const ValueKey<String>('group-mosaic-avatar'),
      members: drawn,
      size: size,
      corner: corner,
    );
    debugGroupMosaicBuilds++;
    _groupMosaicCache[key] = _GroupMosaicEntry(drawn, tile);
    while (_groupMosaicCache.length > _groupMosaicCacheCapacity) {
      _groupMosaicCache.remove(_groupMosaicCache.keys.first);
    }
    return tile;
  }
}

class _GroupMosaicTile extends StatelessWidget {
  const _GroupMosaicTile({
    required this.members,
    required this.size,
    required this.corner,
    super.key,
  });

  final List<GroupMosaicMember> members;
  final double size;
  final double corner;

  @override
  Widget build(BuildContext context) {
    final rects = groupMosaicCellRects(members.length, size);
    final cellRadius = rects.isEmpty
        ? 0.0
        : (rects.first.width * 0.12).clamp(1.0, 4.0).toDouble();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: LoopColors.plateRaised,
        borderRadius: BorderRadius.circular(corner),
      ),
      child: Stack(
        children: <Widget>[
          for (var index = 0; index < rects.length; index++)
            Positioned.fromRect(
              rect: rects[index],
              child: _cell(
                index,
                members[index],
                rects[index].width,
                cellRadius,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(int index, GroupMosaicMember member, double side, double r) {
    final initials = _GroupMosaicInitialCell(
      key: ValueKey<String>('group-mosaic-initials-$index'),
      member: member,
      size: side,
      radius: r,
    );
    final url = member.imageUrl;
    return KeyedSubtree(
      key: ValueKey<String>('group-mosaic-cell-$index'),
      child: url == null
          ? initials
          : LoopRemoteAvatar(
              key: ValueKey<String>('group-mosaic-image-$index'),
              url: url,
              size: side,
              shape: BoxShape.rectangle,
              radius: r,
              fallback: initials,
            ),
    );
  }
}

/// One member's initial on the monogram ground their id was given.
class _GroupMosaicInitialCell extends StatelessWidget {
  const _GroupMosaicInitialCell({
    required this.member,
    required this.size,
    required this.radius,
    super.key,
  });

  final GroupMosaicMember member;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    const grounds = LoopMonogramPalette.grounds;
    final identity = member.id.trim().isEmpty ? member.name : member.id;
    final ground = grounds[_fnv1a(identity) % grounds.length];
    final monogram = loopMonogram(member.name).characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ground.fill,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        monogram,
        maxLines: 1,
        overflow: TextOverflow.clip,
        textScaler: TextScaler.noScaling,
        style: LoopTypography.figure(size * 0.5, color: ground.ink),
      ),
    );
  }
}

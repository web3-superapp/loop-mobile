/// The one face a community wears, everywhere it is named.
///
/// A community reaches the client with `logoRef`, a
/// `avatar:preset/community-01..12` reference into the server's preset
/// catalog. The frozen prototype drew **four** of those twelve — LOOP, PEPE,
/// BONK and MCAT, in a 2x2 sheet — so eight of every twelve communities had
/// no mark at all, and on the device a directory of them read as a column of
/// identical grey initials (real-device report 2026-09-21). The atlas is now
/// 4x3: the four prototype illustrations unchanged in row 0, and eight
/// geometric Lime badges for 05..12 (ruling 2026-09-21, plan A), whose SVG
/// sources are kept beside the sheet in `assets/communities/src` and are not
/// bundled. Every preset the server can publish therefore draws an image, and
/// no community is ever given the mark of another.
///
/// The initials are still drawn, for the one case that remains: a community
/// whose `logoRef` is absent or is a reference this build cannot resolve.
/// That tile is not neutral either. It takes one of six grounds from the LOOP
/// palette, chosen by a stable hash of the community's own id, so even a
/// community with no preset keeps one recognisable face across the home list,
/// discovery, its record, its member directory, search, the message centre,
/// forwarding and both mining boards.
///
/// The ground is picked from the id, never from the name: two communities may
/// be renamed into the same initials, and a colour that moved when an owner
/// edited the name would not be an identity.
library;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// `avatar:preset/community-01..12` — the server's community preset catalog.
const String communityLogoPresetPrefix = 'avatar:preset/community-';

/// How many presets the server's catalog publishes.
const int communityLogoPresetCount = 12;

/// The atlas cell for a one-based preset slot, or null when the local atlas
/// does not carry that preset.
///
/// Same rule as `LoopProfileAvatar.peopleSlotKey` for people: the catalog slot
/// is a row-major index into the atlas grid. The community atlas is 4x3, so
/// all twelve published presets resolve; a number outside the catalog does
/// not, and its community keeps its initials.
String? communityLogoSlotKey(int slot) {
  const atlas = LoopIdentityAtlas.communities;
  if (slot < 1 || slot > atlas.columns * atlas.rows) return null;
  final column = (slot - 1) % atlas.columns;
  final row = (slot - 1) ~/ atlas.columns;
  for (final entry in atlas.slots.entries) {
    if (entry.value.column == column && entry.value.row == row) {
      return entry.key;
    }
  }
  return null;
}

/// The atlas cell a `logoRef` names, or null for every other value.
String? communityLogoSlotFor(String? logoRef) {
  final reference = logoRef;
  if (reference == null || !reference.startsWith(communityLogoPresetPrefix)) {
    return null;
  }
  final slot = int.tryParse(
    reference.substring(communityLogoPresetPrefix.length),
  );
  return slot == null ? null : communityLogoSlotKey(slot);
}

/// Up to two characters of the community's own name.
String communityLogoMonogram(String name) => loopMonogram(name);

/// One monogram ground: a fill from the LOOP palette and the letter colour
/// that is legible on it.
@immutable
final class CommunityLogoGround {
  const CommunityLogoGround({
    required this.id,
    required this.fill,
    required this.ink,
  });

  /// Stable name, used by the tile's key so a test can read which ground a
  /// community was given without sampling pixels.
  final String id;
  final Color fill;
  final Color ink;
}

/// The six grounds, in catalog order.
///
/// Every one is Lime, Chalk or Muted — three of the five product colours — at
/// full strength or mixed with one of the other two. No new hue is introduced:
/// the palette forbids it, and a categorical colour wheel would have made a
/// community's identity look like a status.
///
/// All six are mid-to-bright on purpose. A community tile lands on the Ink
/// page, on a translucent card, on the elevated message panel, on a Chalk
/// folio and on the quiet folio's dark Lime — and a fill that matched any one
/// of those would be a tile that is simply not there on that page. The first
/// draft of this table held Lime at 24% over Ink, which is the quiet folio's
/// own fill, and the ground probe caught it on the community record before
/// any device did.
///
/// Each pair also clears 4.5:1 between the letters and the fill, which
/// `community_logo_test.dart` measures rather than asserts by eye.
const List<CommunityLogoGround> communityLogoGrounds = <CommunityLogoGround>[
  CommunityLogoGround(id: 'lime', fill: LoopColors.lime, ink: LoopColors.ink),

  /// Lime and Chalk, half each.
  CommunityLogoGround(
    id: 'lime-pale',
    fill: Color(0xFFD6FA88),
    ink: LoopColors.ink,
  ),

  /// Lime at 55% over Ink.
  CommunityLogoGround(
    id: 'lime-deep',
    fill: Color(0xFF678F13),
    ink: LoopColors.ink,
  ),

  /// Chalk at 75% over Ink — light, but never Chalk itself, which would
  /// disappear into a Chalk card.
  CommunityLogoGround(
    id: 'chalk-dim',
    fill: Color(0xFFB8B9B4),
    ink: LoopColors.ink,
  ),
  CommunityLogoGround(id: 'muted', fill: LoopColors.muted, ink: LoopColors.ink),

  /// Muted at 60% over Ink, the one ground dark enough to take Chalk letters.
  CommunityLogoGround(
    id: 'muted-deep',
    fill: Color(0xFF4E554B),
    ink: LoopColors.chalk,
  ),
];

/// FNV-1a over the id's code units.
///
/// `String.hashCode` is not a published, stable value, and a face that changed
/// between two runs of the same build would not be an identity.
int communityLogoHash(String identity) {
  var hash = 0x811c9dc5;
  for (final unit in identity.codeUnits) {
    hash = (hash ^ unit) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// The ground this identity always gets.
CommunityLogoGround communityLogoGroundFor(String identity) {
  final trimmed = identity.trim();
  if (trimmed.isEmpty) return communityLogoGrounds.first;
  return communityLogoGrounds[communityLogoHash(trimmed) %
      communityLogoGrounds.length];
}

/// The community's preset image, or — for a community whose `logoRef` is
/// absent or unresolvable — its initials on the ground its id was given.
///
/// [identity] is the stable key the face is derived from. It is the
/// `communityId` wherever one is in hand; a surface that only holds another
/// stable handle for the same community — a community channel CID, a search
/// result's `stableId` — passes that, and says so at the call site.
class CommunityLogo extends StatelessWidget {
  const CommunityLogo({
    required this.identity,
    required this.name,
    super.key,
    this.logoRef,
    this.size = 44,
    this.radius,
    this.bordered = false,
  });

  final String identity;
  final String name;

  /// `avatar:preset/community-01..12`, or null when the surface holds no
  /// reference for this community.
  final String? logoRef;
  final double size;

  /// Corner radius. The prototype draws this tile at three sizes with three
  /// radii — 12 in a row, 16 in the identity block, the shell radius on the
  /// folio — so the caller states it rather than the tile guessing from size.
  final double? radius;

  /// `.folio-media-identity{border:1px solid rgba(243,245,239,.2)}`: the edge
  /// the tile draws when it sits on the folio rather than inside a card.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final corner = radius ?? LoopRadius.innerValue;
    final monogram = communityLogoMonogram(name);
    final slot = communityLogoSlotFor(logoRef);
    if (slot != null) {
      return LoopIdentityAvatar(
        key: ValueKey<String>('community-logo-image-$logoRef'),
        atlas: LoopIdentityAtlas.communities,
        slot: slot,
        size: size,
        radius: corner,
        semanticLabel: '$name 社区图标',
        fallbackMonogram: monogram,
      );
    }
    final ground = communityLogoGroundFor(identity);
    return Semantics(
      image: true,
      label: '$name 社区图标',
      child: Container(
        key: ValueKey<String>('community-logo-monogram-${ground.id}'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ground.fill,
          borderRadius: BorderRadius.circular(corner),
          // The tile carries its own opaque fill, so it needs an edge only
          // where the prototype draws one.
          border: bordered
              ? Border.all(color: LoopGround.edgeOf(context))
              : null,
        ),
        child: ExcludeSemantics(
          child: Text(
            monogram,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: LoopTypography.figure(size / 3.4, color: ground.ink),
          ),
        ),
      ),
    );
  }
}

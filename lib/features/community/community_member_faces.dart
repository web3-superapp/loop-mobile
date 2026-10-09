import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';

/// How many faces the community record's 成员 strip draws (decision 0127).
const int communityMemberStripFaces = 12;

/// The first page of a community's member directory, for the record's 成员
/// strip (decision 0127).
///
/// It is the directory's own read (`GET …/members`), asked once per visit and
/// only by a member's page. The strip draws the faces the server listed and
/// nothing else: a failed read leaves the strip out and keeps 「查看全部」.
final communityMemberFacesProvider = FutureProvider.autoDispose
    .family<List<CommunityMemberEntry>, String>((ref, communityId) async {
      final directory = await ref
          .read(communityGatewayProvider)
          .listMembers(communityId);
      return directory.items
          .take(communityMemberStripFaces)
          .toList(growable: false);
    });

/// The 成员 strip on the community record: 48 faces with a name under each,
/// in one row that scrolls sideways.
class CommunityMemberStrip extends StatelessWidget {
  const CommunityMemberStrip({
    required this.members,
    super.key,
    this.onOpenProfile,
  });

  final List<CommunityMemberEntry> members;

  /// Opens one member's `user-profile`.
  final ValueChanged<String>? onOpenProfile;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey<String>('community-profile-member-strip'),
    height: 80,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final member = members[index];
        final id = member.profile.publicProfileId;
        final open = onOpenProfile;
        return Semantics(
          button: id != null && open != null,
          label: member.profile.displayName,
          excludeSemantics: true,
          child: GestureDetector(
            key: ValueKey<String>(
              'community-profile-member-${id ?? member.profile.loopId}',
            ),
            behavior: HitTestBehavior.opaque,
            onTap: id == null || open == null || member.isSelf
                ? null
                : () => open(id),
            child: SizedBox(
              width: 56,
              child: Column(
                children: <Widget>[
                  LoopProfileAvatar(
                    avatarRef: member.profile.avatarRef,
                    alias: member.profile.displayName,
                    size: 48,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    member.isSelf ? '我' : member.profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: LoopTypography.caption(11, color: LoopColors.text2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';

/// One community on a person's 社区 section (decision 0218): the logo at 40,
/// the name over one fact, an optional capsule on the right, the record one
/// tap away.
///
/// Another account's page and 我的 (S349) list their communities with this
/// one row, so the two sections look the same. [rowKey] sits on the record
/// row itself.
class CommunityRecordRow extends StatelessWidget {
  const CommunityRecordRow({
    required this.rowKey,
    required this.communityId,
    required this.name,
    required this.logoRef,
    required this.subtitle,
    required this.semanticLabel,
    required this.onTap,
    super.key,
    this.subtitleMaxLines = 1,
    this.trailingBadge,
    this.chevron = true,
  });

  final Key rowKey;
  final String communityId;
  final String name;
  final String? logoRef;
  final String subtitle;
  final int subtitleMaxLines;
  final Widget? trailingBadge;
  final bool chevron;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LoopFlat(
    child: LoopRecordRow(
      key: rowKey,
      leading: CommunityLogo(
        identity: communityId,
        name: name,
        logoRef: logoRef,
        size: 40,
        radius: 12,
      ),
      title: name,
      subtitle: subtitle,
      subtitleMaxLines: subtitleMaxLines,
      trailingBadge: trailingBadge,
      chevron: chevron,
      semanticLabel: semanticLabel,
      onTap: onTap,
    ),
  );
}

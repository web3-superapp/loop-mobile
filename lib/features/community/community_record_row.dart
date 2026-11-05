import 'package:flutter/material.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/social/secondary_row_metrics.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';

/// One community on a person's 社区 section (decision 0218): the logo, the
/// name over one fact, an optional capsule on the right, the record one tap
/// away.
///
/// S370b · decision 0294: the Figma's community row (docs/58 §3.2 / §9.4) —
/// a 56 square logo at r12, 86 high with its 1px white-5 % divider. The flat
/// row pads 8 above and below; the logo's own 6.5 makes up the 86.
///
/// Another account's page and 我的 (S349) list their communities with this
/// one row, so the two sections look the same. [rowKey] sits on the record
/// row itself.
/// The logo's own vertical inset, so the flat row (8 + 8) stands at
/// [LoopRowHeight.community] with its divider (S370b · decision 0294).
const double communityRowLogoInset =
    (SecondaryRowMetrics.communityRow -
        1 -
        SecondaryRowMetrics.communityLogo -
        16) /
    2;

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
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: communityRowLogoInset),
        child: CommunityLogo(
          identity: communityId,
          name: name,
          logoRef: logoRef,
          size: SecondaryRowMetrics.communityLogo,
          radius: SecondaryRowMetrics.communityLogoRadius,
        ),
      ),
      title: name,
      subtitle: subtitle,
      subtitleMaxLines: subtitleMaxLines,
      trailingBadge: trailingBadge,
      chevron: chevron,
      divider: true,
      semanticLabel: semanticLabel,
      onTap: onTap,
    ),
  );
}

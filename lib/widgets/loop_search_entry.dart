import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// Which page a [LoopSearchEntry] stands on: the Figma gives 聊天 and 广场
/// two placeholders (docs/58 §2 #19 / #25).
enum LoopSearchTone {
  /// 聊天: `#0e0f12` ground, a 15 / 500 tertiary placeholder.
  chat,

  /// 广场: `#111214` ground, a 14 / 400 secondary placeholder.
  square,
}

/// The search field a page opens its search from (decision 0277, docs/58
/// §3.1 / §4): 44 high at a 12 corner, a 1 px `#1d1f24` edge, a 20 glyph
/// and the placeholder. It is a button — the field itself lives on the
/// search page.
class LoopSearchEntry extends StatelessWidget {
  const LoopSearchEntry({
    required this.placeholder,
    required this.onTap,
    super.key,
    this.tone = LoopSearchTone.chat,
    this.inkKey,
    this.semanticLabel,
  });

  final String placeholder;
  final VoidCallback? onTap;
  final LoopSearchTone tone;

  /// The key of the tappable ink (a page's test handle).
  final Key? inkKey;
  final String? semanticLabel;

  TextStyle get _placeholderStyle => switch (tone) {
    LoopSearchTone.chat => LoopType.searchHint,
    LoopSearchTone.square => LoopType.body2Sm.copyWith(
      color: LoopColors.textSecondary,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final ground = tone == LoopSearchTone.chat
        ? LoopColors.searchBg
        : LoopColors.graphite;
    return Semantics(
      button: true,
      label: semanticLabel ?? placeholder,
      excludeSemantics: true,
      child: Material(
        color: ground,
        shape: const RoundedRectangleBorder(
          borderRadius: LoopRadius.control,
          side: BorderSide(color: LoopColors.cardEdge),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: inkKey,
          onTap: onTap,
          child: SizedBox(
            height: LoopTouch.searchField,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 14),
                const LoopIcon('search', size: 20, color: LoopColors.text3),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    placeholder,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: _placeholderStyle,
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

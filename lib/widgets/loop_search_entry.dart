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

/// The Figma's search field for a real [TextField] (S371 · decision 0297,
/// docs/58 §9.4): 44 high at a 12 corner on `searchBg`, a 1 px `cardEdge`
/// edge, the `searchHint` 15 / 500 placeholder and the 20 magnifier — the
/// same face as [LoopSearchEntry]. A focused field draws the Purple edge
/// every field has (decision 0254). Member search, group rename, the asset
/// picker and the chat / community search pages share it instead of each
/// writing one.
InputDecoration loopSearchFieldDecoration({
  required String hint,
  bool searchGlyph = true,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
  String? counterText,
}) {
  const edge = OutlineInputBorder(
    borderRadius: LoopRadius.control,
    borderSide: BorderSide(color: LoopColors.cardEdge),
  );
  const danger = OutlineInputBorder(
    borderRadius: LoopRadius.control,
    borderSide: BorderSide(color: LoopColors.danger),
  );
  final prefix =
      prefixIcon ??
      (searchGlyph
          ? const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 8, 0),
              child: LoopIcon('search', size: 20, color: LoopColors.text3),
            )
          : null);
  return InputDecoration(
    hintText: hint,
    hintStyle: LoopType.searchHint,
    errorText: errorText,
    counterText: counterText,
    filled: true,
    fillColor: LoopColors.searchBg,
    isDense: true,
    // 44 whatever step the caller types in; a field that can show an error
    // keeps room under it for the message.
    constraints: errorText == null
        ? const BoxConstraints(
            minHeight: LoopTouch.searchField,
            maxHeight: LoopTouch.searchField,
          )
        : const BoxConstraints(minHeight: LoopTouch.searchField),
    contentPadding: EdgeInsets.fromLTRB(prefix == null ? 14 : 0, 12, 14, 12),
    prefixIcon: prefix,
    prefixIconConstraints: prefix == null
        ? null
        : const BoxConstraints(
            minWidth: LoopTouch.searchField,
            minHeight: LoopTouch.searchField,
          ),
    suffixIcon: suffixIcon,
    border: edge,
    enabledBorder: edge,
    disabledBorder: edge,
    focusedBorder: const OutlineInputBorder(
      borderRadius: LoopRadius.control,
      borderSide: BorderSide(color: LoopColors.purple),
    ),
    errorBorder: danger,
    focusedErrorBorder: danger,
  );
}

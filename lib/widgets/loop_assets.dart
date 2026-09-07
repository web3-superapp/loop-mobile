import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// Line icon from the prototype SVG sprite (`i-<name>.svg`).
///
/// The sprite paths use `stroke: currentColor`; [color] is applied with a
/// source-in colour filter so the whole glyph takes one colour. Pass
/// [semanticLabel] for meaningful icons; decorative icons are excluded from
/// the semantics tree, which is the Flutter equivalent of an empty `alt`.
class LoopIcon extends StatelessWidget {
  const LoopIcon(
    this.name, {
    super.key,
    this.size = 21,
    this.color,
    this.semanticLabel,
  }) : assert(size > 0);

  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    assert(
      LoopIconNames.contains(name),
      'Unknown LOOP sprite icon: $name. Use a name from LoopIconNames.all.',
    );
    final resolved = color ?? IconTheme.of(context).color ?? LoopColors.chalk;
    return SvgPicture.asset(
      LoopAssetPaths.icon(name),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (context, error, stackTrace) => _MonogramFallback(
        text: loopMonogram(name),
        size: size,
        shape: BoxShape.rectangle,
        foreground: resolved,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

/// Token logo with monogram fallback (chapter 4.5).
///
/// Only the seven prototype tokens have artwork. Any other symbol, and any
/// load failure, renders [fallbackMonogram] (defaults to the symbol's first
/// two characters) so the ticker never disappears.
class LoopTokenLogo extends StatelessWidget {
  const LoopTokenLogo({
    required this.assetSymbol,
    super.key,
    this.fallbackMonogram,
    this.size = 36,
    this.semanticLabel,
  });

  final String assetSymbol;
  final String? fallbackMonogram;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? '$assetSymbol logo';
    final monogram = fallbackMonogram ?? loopMonogram(assetSymbol);
    final path = LoopTokenAssets.pathForSymbol(assetSymbol);
    if (path == null) {
      return _MonogramFallback(
        text: monogram,
        size: size,
        shape: BoxShape.circle,
        semanticLabel: label,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: SvgPicture.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticsLabel: label,
          errorBuilder: (context, error, stackTrace) => _MonogramFallback(
            text: monogram,
            size: size,
            shape: BoxShape.circle,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}

/// Network logo with monogram fallback.
class LoopNetworkLogo extends StatelessWidget {
  const LoopNetworkLogo({
    required this.network,
    super.key,
    this.size = 20,
    this.semanticLabel,
  });

  /// Network id: `base`, `bsc`/`bnb`, `ethereum`/`eth`, `solana`/`sol`.
  final String network;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? '$network network';
    final monogram = loopMonogram(network);
    final path = LoopNetworkAssets.pathForId(network);
    if (path == null) {
      return _MonogramFallback(
        text: monogram,
        size: size,
        shape: BoxShape.circle,
        semanticLabel: label,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: SvgPicture.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticsLabel: label,
          errorBuilder: (context, error, stackTrace) => _MonogramFallback(
            text: monogram,
            size: size,
            shape: BoxShape.circle,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}

/// Person or community avatar cropped from a WebP atlas.
///
/// [slot] is a key of [LoopIdentityAtlas.slots] (for communities the
/// `LoopIdentitySlots.communityAliases` table is consulted first). Unknown
/// slots and load failures render the monogram. The image is never cut into
/// loose files; the crop is computed at render time from the grid.
class LoopIdentityAvatar extends StatelessWidget {
  const LoopIdentityAvatar({
    required this.atlas,
    required this.slot,
    super.key,
    this.size = 40,
    this.radius,
    this.semanticLabel,
    this.fallbackMonogram,
  });

  final LoopIdentityAtlas atlas;
  final String slot;
  final double size;

  /// Corner radius; defaults to a circle for people and 12 for communities.
  final double? radius;
  final String? semanticLabel;
  final String? fallbackMonogram;

  LoopIdentitySlot? get _resolvedSlot {
    final key = atlas == LoopIdentityAtlas.communities
        ? (LoopIdentitySlots.communityAliases[slot.toLowerCase()] ?? slot)
        : slot;
    return atlas.slot(key);
  }

  @override
  Widget build(BuildContext context) {
    final cell = _resolvedSlot;
    final cornerRadius =
        radius ??
        (atlas == LoopIdentityAtlas.people ? size / 2 : LoopRadius.innerValue);
    final label = semanticLabel ?? cell?.label ?? '$slot 头像';
    final monogram = fallbackMonogram ?? cell?.fallback ?? loopMonogram(slot);
    if (cell == null) {
      return _MonogramFallback(
        text: monogram,
        size: size,
        shape: BoxShape.rectangle,
        radius: cornerRadius,
        semanticLabel: label,
      );
    }
    final alignment = Alignment(
      atlas.columns == 1 ? 0 : cell.column / (atlas.columns - 1) * 2 - 1,
      atlas.rows == 1 ? 0 : cell.row / (atlas.rows - 1) * 2 - 1,
    );
    return Semantics(
      image: true,
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: SizedBox(
          width: size,
          height: size,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: ClipRect(
              child: Align(
                alignment: alignment,
                widthFactor: 1 / atlas.columns,
                heightFactor: 1 / atlas.rows,
                child: Image.asset(
                  atlas.path,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stackTrace) =>
                      _MonogramFallback(
                        text: monogram,
                        size: size,
                        shape: BoxShape.rectangle,
                        radius: cornerRadius,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum LoopBrandMarkKind { appIcon, wordmark }

/// Brand mark: WebP first, SVG when the WebP fails to decode.
class LoopBrandMark extends StatelessWidget {
  const LoopBrandMark({
    required this.kind,
    super.key,
    this.height = 28,
    this.semanticLabel,
  });

  final LoopBrandMarkKind kind;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (webp, svg, label) = switch (kind) {
      LoopBrandMarkKind.appIcon => (
        LoopBrandAssets.appIconWebp,
        LoopBrandAssets.appIconSvg,
        'LOOP app icon',
      ),
      LoopBrandMarkKind.wordmark => (
        LoopBrandAssets.wordmarkWebp,
        LoopBrandAssets.wordmarkSvg,
        'LOOP',
      ),
    };
    return Image.asset(
      webp,
      height: height,
      semanticLabel: semanticLabel ?? label,
      errorBuilder: (context, error, stackTrace) => SvgPicture.asset(
        svg,
        height: height,
        semanticsLabel: semanticLabel ?? label,
        errorBuilder: (context, error, stackTrace) => _MonogramFallback(
          text: 'LO',
          size: height,
          shape: BoxShape.circle,
          semanticLabel: semanticLabel ?? label,
        ),
      ),
    );
  }
}

class _MonogramFallback extends StatelessWidget {
  const _MonogramFallback({
    required this.text,
    required this.size,
    required this.shape,
    this.radius,
    this.foreground,
    this.semanticLabel,
  });

  final String text;
  final double size;
  final BoxShape shape;
  final double? radius;
  final Color? foreground;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      key: const ValueKey<String>('loop-asset-monogram'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.card2,
        shape: shape,
        border: Border.all(color: LoopColors.line),
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(radius ?? LoopRadius.innerValue)
            : null,
      ),
      child: ExcludeSemantics(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: LoopTypography.mono(
            size: size * 0.34,
            weight: FontWeight.w600,
            color: foreground ?? LoopColors.chalk,
          ),
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: child);
    return Semantics(image: true, label: semanticLabel, child: child);
  }
}

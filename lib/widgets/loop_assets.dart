import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

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
class LoopIcon extends StatefulWidget {
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
  State<LoopIcon> createState() => _LoopIconState();
}

class _LoopIconState extends State<LoopIcon> {
  /// The raster this element is waiting for, so a finished rasterisation for
  /// an old name or size never repaints the current one.
  String? _awaiting;

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final size = widget.size;
    final semanticLabel = widget.semanticLabel;
    assert(
      LoopIconNames.contains(name),
      'Unknown LOOP sprite icon: $name. Use a name from LoopIconNames.all.',
    );
    final resolved =
        widget.color ?? IconTheme.of(context).color ?? LoopColors.chalk;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final raster = LoopIconRasters.lookup(name, pixels);
    if (raster != null) {
      // Decision 0101: the glyph is a shared raster tinted on the image draw
      // itself. The vector path recolours through a `saveLayer` per icon —
      // about nineteen offscreen passes a frame on 社区 alone.
      final image = RawImage(
        image: raster,
        width: size,
        height: size,
        color: resolved,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.low,
      );
      return semanticLabel == null
          ? ExcludeSemantics(child: image)
          : Semantics(label: semanticLabel, image: true, child: image);
    }
    final key = LoopIconRasters.keyFor(name, pixels);
    if (_awaiting != key) {
      _awaiting = key;
      unawaited(
        LoopIconRasters.rasterize(name, pixels).then((image) {
          if (image != null && mounted && _awaiting == key) setState(() {});
        }),
      );
    }
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

/// One raster per sprite icon and device-pixel size (decision 0101).
///
/// Every sprite path is `stroke: currentColor` on `fill: none`, so a glyph is
/// one alpha mask and the tint is a `srcIn` colour filter on the image draw —
/// identical to the vector path's filter, without its offscreen layer. The
/// first time a glyph is needed at a size it is still drawn as a vector while
/// its raster is made from the same compiled picture `svg.cache` holds.
/// Rasters live for the process; the set is bounded by glyphs × sizes, and
/// past [capacity] new sizes simply stay vectors.
abstract final class LoopIconRasters {
  static const int capacity = 512;

  static final Map<String, ui.Image> _ready = <String, ui.Image>{};
  static final Map<String, Future<ui.Image?>> _pending =
      <String, Future<ui.Image?>>{};

  static String keyFor(String name, int pixels) => '$name@$pixels';

  static ui.Image? lookup(String name, int pixels) =>
      _ready[keyFor(name, pixels)];

  static Future<ui.Image?> rasterize(String name, int pixels) {
    final key = keyFor(name, pixels);
    final ready = _ready[key];
    if (ready != null) return Future<ui.Image?>.value(ready);
    if (pixels <= 0 || _ready.length >= capacity) {
      return Future<ui.Image?>.value();
    }
    return _pending.putIfAbsent(key, () async {
      try {
        final info = await vg.loadPicture(
          SvgAssetLoader(LoopAssetPaths.icon(name)),
          null,
        );
        try {
          final width = info.size.width;
          final height = info.size.height;
          if (width <= 0 || height <= 0) return null;
          // `BoxFit.contain`, centred — what `SvgPicture` does with a square
          // box.
          final scale = math.min(pixels / width, pixels / height);
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)
            ..translate(
              (pixels - width * scale) / 2,
              (pixels - height * scale) / 2,
            )
            ..scale(scale);
          canvas.drawPicture(info.picture);
          final picture = recorder.endRecording();
          final image = picture.toImageSync(pixels, pixels);
          picture.dispose();
          _ready[key] = image;
          return image;
        } finally {
          info.picture.dispose();
        }
      } on Object {
        // The vector path keeps drawing the glyph; nothing is lost.
        return null;
      } finally {
        unawaited(_pending.remove(key));
      }
    });
  }

  /// Drops every raster. Tests only.
  @visibleForTesting
  static void debugReset() {
    for (final image in _ready.values) {
      image.dispose();
    }
    _ready.clear();
    _pending.clear();
  }
}

/// Compiles the sprite icons into `flutter_svg`'s byte cache ahead of use
/// (decision 0100).
///
/// In profile and release builds `flutter_svg` compiles each SVG the first
/// time it is drawn, in a freshly spawned isolate (`foundation.compute`), and
/// only then caches the result. A page that is the first to draw a glyph —
/// the 「我的资格」 row's `ticket` on `launch-detail` — shows its tile empty
/// until that isolate returns, and a revisit is instant because the bytes are
/// cached. Warming the cache one icon at a time after the first frame moves
/// that cost off the first visit. The loader is the one [LoopIcon] builds
/// (asset path, default bundle, default theme), so the cache keys match.
/// Failures are ignored: the widget then compiles on demand, as before.
Future<void> loopWarmIconCache({Iterable<String>? names}) async {
  for (final name in names ?? LoopIconNames.all) {
    try {
      await SvgAssetLoader(LoopAssetPaths.icon(name)).loadBytes(null);
    } catch (error) {
      debugPrint('LoopIcon warm-up skipped $name: $error');
    }
  }
}

/// The registry artwork address this app is willing to fetch, or `null`.
///
/// A logo is the one field of an asset row that is a URL, and it arrives from
/// a registry the client does not own. Only an absolute `https` address with a
/// host is fetched: a relative path, a `http://` address, a `data:` payload
/// and a malformed string all resolve to `null`, and the caller falls back to
/// the bundled artwork or the monogram. Nothing about the fetch is
/// authenticated and no LOOP header is attached, so this never travels through
/// `LoopDioFactory`; it is an image, not a call on the API.
Uri? loopRemoteLogoUri(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}

/// Token logo with monogram fallback (chapter 4.5).
///
/// Three sources, in order, each falling through to the next: the registry's
/// published artwork at [logoUrl] (contract §2a, decision 0072), the bundled
/// prototype artwork for the seven symbols that have it, and the monogram.
///
/// The monogram is always the *normalised* two characters of
/// [fallbackMonogram] (or of the symbol), never the raw string it was given —
/// 「OH / WBNB」 painted a slash and a space into a 32pt circle, and
/// four-letter tickers overflowed it (walkthrough 2026-09-23, d06).
///
/// **One attempt per process.** A failed fetch — or one that shows no frame
/// within [fetchBudget] — is remembered for the address, so a list that
/// scrolls, a pull-to-refresh, a rebuild and every other row with the same
/// artwork go straight to the monogram (decision 0101). Successful artwork
/// is held by Flutter's own [ImageCache], keyed by the address, so a symbol
/// in 自选 and again in 热门 is decoded once. There is no on-disk cache: that
/// needs a dependency, and the decision is not this widget's to take.
class LoopTokenLogo extends StatefulWidget {
  const LoopTokenLogo({
    required this.assetSymbol,
    super.key,
    this.logoUrl,
    this.fallbackMonogram,
    this.size = 36,
    this.semanticLabel,
  });

  final String assetSymbol;

  /// The registry's published artwork. Anything [loopRemoteLogoUri] refuses
  /// is treated as if the server had published nothing at all.
  final String? logoUrl;
  final String? fallbackMonogram;
  final double size;
  final String? semanticLabel;

  /// How long the registry artwork may take to show its first frame. Past it
  /// the address is given up on for the rest of the process (decision 0101).
  static const Duration fetchBudget = Duration(seconds: 3);

  @override
  State<LoopTokenLogo> createState() => _LoopTokenLogoState();
}

/// Addresses that failed or timed out in this process (decision 0101).
///
/// The registry artwork is served from `raw.githubusercontent.com`, which from
/// a Chinese network can hang for a minute before failing. One row learning
/// that is enough: every later row, page and rebuild with the same address
/// goes straight to the monogram instead of opening the same stalled fetch.
final Set<String> _loopFailedLogoUrls = <String>{};

/// Forgets every remembered logo failure. Tests only.
@visibleForTesting
void debugResetLoopTokenLogoFailures() => _loopFailedLogoUrls.clear();

/// Whether this process has given up on [url].
@visibleForTesting
bool debugLoopTokenLogoFailed(String url) => _loopFailedLogoUrls.contains(url);

class _LoopTokenLogoState extends State<LoopTokenLogo> {
  /// How long a logo may take to produce its first frame before the tile
  /// settles on the monogram for good (decision 0101).
  static const Duration fetchBudget = LoopTokenLogo.fetchBudget;

  bool _failed = false;
  bool _gotFrame = false;
  Timer? _budget;
  String? _budgetFor;

  @override
  void didUpdateWidget(LoopTokenLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different address is a different question, so it gets its own one
    // attempt. The same address that already failed is not asked again.
    if (oldWidget.logoUrl != widget.logoUrl) {
      _failed = false;
      _gotFrame = false;
      _budget?.cancel();
      _budget = null;
      _budgetFor = null;
    }
  }

  @override
  void dispose() {
    _budget?.cancel();
    super.dispose();
  }

  void _giveUp(String url) {
    _loopFailedLogoUrls.add(url);
    _budget?.cancel();
    _budget = null;
    if (mounted && !_failed) setState(() => _failed = true);
  }

  /// Starts the fetch budget once per address. A frame that arrives in time
  /// cancels nothing — the timer simply finds `_gotFrame` set.
  void _armBudget(String url) {
    if (_budgetFor == url) return;
    _budget?.cancel();
    _budgetFor = url;
    _budget = Timer(fetchBudget, () {
      _budget = null;
      if (!_gotFrame) _giveUp(url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final label = widget.semanticLabel ?? '${widget.assetSymbol} logo';
    final monogram = loopMonogram(
      widget.fallbackMonogram ?? widget.assetSymbol,
    );
    Widget bundled() {
      final path = LoopTokenAssets.pathForSymbol(widget.assetSymbol);
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

    final remote = _failed ? null : loopRemoteLogoUri(widget.logoUrl);
    if (remote == null) return bundled();
    final url = remote.toString();
    if (_loopFailedLogoUrls.contains(url)) return bundled();
    if (!_gotFrame) _armBudget(url);
    // Decoded at the pixels the tile shows, not the registry's 256 px source.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          url,
          key: const ValueKey<String>('loop-token-logo-remote'),
          width: size,
          height: size,
          cacheWidth: pixels,
          cacheHeight: pixels,
          fit: BoxFit.cover,
          semanticLabel: label,
          // The row keeps its shape for the whole of the fetch: the slot is
          // the monogram until a frame arrives, so nothing shifts and no
          // spinner appears in a 32pt circle.
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              _gotFrame = true;
              return child;
            }
            return bundled();
          },
          errorBuilder: (context, error, stackTrace) {
            // Remembered for the process: the CDN is asked once, not once per
            // row or frame. `setState` cannot run during build, so it is
            // scheduled.
            if (!_failed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _giveUp(url);
              });
            }
            return bundled();
          },
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
class LoopIdentityAvatar extends StatefulWidget {
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

  @override
  State<LoopIdentityAvatar> createState() => _LoopIdentityAvatarState();
}

class _LoopIdentityAvatarState extends State<LoopIdentityAvatar> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _failed = false;

  LoopIdentitySlot? get _resolvedSlot {
    final key = widget.atlas == LoopIdentityAtlas.communities
        ? (LoopIdentitySlots.communityAliases[widget.slot.toLowerCase()] ??
              widget.slot)
        : widget.slot;
    return widget.atlas.slot(key);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(LoopIdentityAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atlas != widget.atlas) {
      _failed = false;
      _resolveImage();
    }
  }

  /// Resolves the atlas through the ambient asset bundle so a decode or
  /// bundle failure swaps the whole crop tree for the monogram. Inside the
  /// crop tree an `errorBuilder` would be scaled and clipped with the cell.
  void _resolveImage() {
    _stopListening();
    if (_resolvedSlot == null) return;
    final provider = AssetImage(
      widget.atlas.path,
      bundle: DefaultAssetBundle.of(context),
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (image, synchronousCall) {},
      onError: (error, stackTrace) {
        if (!mounted || _failed) return;
        setState(() => _failed = true);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _stopListening() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atlas = widget.atlas;
    final size = widget.size;
    final cell = _resolvedSlot;
    final cornerRadius =
        widget.radius ??
        (atlas == LoopIdentityAtlas.people ? size / 2 : LoopRadius.innerValue);
    final label = widget.semanticLabel ?? cell?.label ?? '${widget.slot} 头像';
    final monogram =
        widget.fallbackMonogram ?? cell?.fallback ?? loopMonogram(widget.slot);
    if (cell == null || _failed) {
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
                  bundle: DefaultAssetBundle.of(context),
                  excludeFromSemantics: true,
                  // The stream listener above owns failure; this keeps the
                  // framework from painting an error glyph in the meantime.
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
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
        // Derived from the ground, not named: this tile stands in for an
        // identity image and appears inside Chalk cards as well as on the Ink
        // page, where a fixed Chalk-on-Chalk fill would vanish.
        color: LoopGround.fillOf(context),
        shape: shape,
        border: Border.all(color: LoopGround.hairlineOf(context)),
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(radius ?? LoopRadius.innerValue)
            : null,
      ),
      child: ExcludeSemantics(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: LoopTypography.figure(
            size * 0.34,
            color: foreground ?? LoopGround.inkOf(context),
          ),
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: child);
    return Semantics(image: true, label: semanticLabel, child: child);
  }
}

/// The prototype's `.msg-av` / `.row-ico` initials tile.
///
/// `.msg-av{width:34px;height:34px;border-radius:50%;background:var(--card2)}`
/// and `.row-ico{width:44px;height:44px;border-radius:15px;
/// background:var(--card2);font-family:var(--mono);color:var(--tx2)}`. Both
/// are the same tile at two sizes and two corner radii, and both take their
/// ground from [LoopGround] so the tile stays visible inside a Chalk card.
///
/// It exists because a LOOP surface has exactly one thing it may draw for a
/// person or a conversation it has no picture of: the initials of the label
/// that surface already resolved. A provider's own generated avatar is a
/// third-party palette and a third-party identity; neither belongs on a LOOP
/// page.
class LoopInitialsAvatar extends StatelessWidget {
  const LoopInitialsAvatar({
    required this.label,
    super.key,
    this.size = 34,
    this.shape = BoxShape.circle,
    this.radius,
    this.foreground,
    this.semanticLabel,
  });

  /// The already-resolved display label. Its first two runes are drawn.
  final String label;
  final double size;
  final BoxShape shape;

  /// Corner radius when [shape] is [BoxShape.rectangle].
  final double? radius;
  final Color? foreground;

  /// `null` excludes the tile from semantics: the row beside it already names
  /// the same person, and a screen reader does not need the initials twice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => _MonogramFallback(
    text: loopMonogram(label),
    size: size,
    shape: shape,
    radius: radius,
    foreground: foreground,
    semanticLabel: semanticLabel,
  );
}

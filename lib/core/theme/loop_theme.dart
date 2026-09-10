import 'package:flutter/material.dart';

/// Lime Ledger colour tokens (01 handover document, chapter 4.1).
///
/// The translucent tokens are expressed as ARGB with the alpha rounded from
/// the prototype `rgba(...)` values. Lime is the only accent; no blue or
/// rainbow status palette may be added here.
abstract final class LoopColors {
  static const Color ink = Color(0xFF050604);
  static const Color lime = Color(0xFFB8FF20);
  static const Color chalk = Color(0xFFF3F5EF);
  static const Color graphite = Color(0xFF171A16);
  static const Color muted = Color(0xFF7F897B);

  /// `--bg2` rgba(243,245,239,.025)
  static const Color bg2 = Color(0x06F3F5EF);

  /// Panel · rgba(243,245,239,.055)
  static const Color panel = Color(0x0EF3F5EF);

  /// Card · rgba(243,245,239,.06)
  static const Color card = Color(0x0FF3F5EF);

  /// Card 2 · rgba(243,245,239,.10) — stronger inset or pressed state.
  static const Color card2 = Color(0x1AF3F5EF);

  /// Line · rgba(243,245,239,.13) — default hairline.
  static const Color line = Color(0x21F3F5EF);

  /// Line 2 · rgba(243,245,239,.22) — strong edge.
  static const Color line2 = Color(0x38F3F5EF);

  /// Text 2 · rgba(243,245,239,.68) — secondary body.
  static const Color text2 = Color(0xADF3F5EF);

  /// Text 3 · rgba(243,245,239,.58) — auxiliary labels.
  static const Color text3 = Color(0x94F3F5EF);

  /// Lime soft · rgba(184,255,32,.13) — hints, badges, soft emphasis ground.
  static const Color limeSoft = Color(0x21B8FF20);

  /// Selected tab gradient start (`#c6ff45` in the prototype tab bar).
  static const Color limeHighlight = Color(0xFFC6FF45);

  /// Ink at 62% — unselected tab icon and label on the Chalk bar.
  static const Color inkMuted = Color(0x9E050604);

  /// Ink at 72% / 62% — secondary text on Lime or Chalk grounds.
  static const Color inkText2 = Color(0xB8050604);
  static const Color inkText3 = Color(0x9E050604);

  /// Sheet veil · rgba(5,6,4,.76)
  static const Color veil = Color(0xC2050604);

  // Semantic aliases retained for existing widgets.
  static const Color textSecondary = text2;
  static const Color textTertiary = text3;
  static const Color hairline = Color(0xFF242523);
  static const Color abyss = ink;
  static const Color basalt = graphite;
  static const Color elevated = Color(0xFF1D1E1C);
  static const Color vapor = muted;
  static const Color mint = lime;

  // Legacy categorical accents used by not-yet-migrated feature slices. The
  // prototype maps red/amber/cyan to Chalk or Lime; new surfaces must not use
  // these and no further colour may be added to this group.
  static const Color market = Color(0xFF68B9FF);
  static const Color chat = Color(0xFFF2B562);
  static const Color danger = Color(0xFFFF6B82);
  static const Color warning = Color(0xFFFFC75F);
}

/// Spacing semantics (chapter 4.3).
abstract final class LoopSpacing {
  /// 紧凑 · 8
  static const double tight = 8;

  /// 卡内 · 14
  static const double card = 14;

  /// 组间 · 22
  static const double group = 22;

  /// 章节间 · 30
  static const double section = 30;

  /// 页面左右内容基线 · 16
  static const double page = 16;

  // Existing aliases.
  static const double compact = tight;
  static const double regular = card;
  static const double spacious = section;

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
}

/// Corner radii (chapter 4.3): shell 24 / card 20 / control 16 / inner 12.
abstract final class LoopRadius {
  static const double shellValue = 24;
  static const double cardValue = 20;
  static const double controlValue = 16;
  static const double innerValue = 12;

  /// Floating Chalk tab bar radius (chapter 5.4).
  static const double tabBarValue = 23;

  /// Chat bubble tail corner (`.msg-txt` in `docs/prototype/style-v2.css`:
  /// `border-radius:5px 16px 16px 16px`). The other three corners are
  /// [controlValue].
  static const double bubbleTailValue = 5;

  static const BorderRadius shell = BorderRadius.all(
    Radius.circular(shellValue),
  );
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardValue));
  static const BorderRadius control = BorderRadius.all(
    Radius.circular(controlValue),
  );
  static const BorderRadius inner = BorderRadius.all(
    Radius.circular(innerValue),
  );
  static const BorderRadius tabBar = BorderRadius.all(
    Radius.circular(tabBarValue),
  );
  static const Radius bubbleTail = Radius.circular(bubbleTailValue);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  // Existing aliases.
  static const BorderRadius container = shell;
  static const BorderRadius large = shell;
  static const BorderRadius medium = control;
  static const BorderRadius small = inner;
}

/// Depth (chapter 4.4). Flutter has no inset box shadow; the prototype's
/// inset top light edge is reproduced with [innerEdge] drawn as a 1px top
/// border or gradient by the card widgets.
abstract final class LoopDepth {
  /// `--lift-primary`: 0 18px 48px rgba(5,6,4,.62), 0 4px 12px rgba(5,6,4,.4).
  static const List<BoxShadow> liftPrimary = <BoxShadow>[
    BoxShadow(color: Color(0x9E050604), offset: Offset(0, 18), blurRadius: 48),
    BoxShadow(color: Color(0x66050604), offset: Offset(0, 4), blurRadius: 12),
  ];

  /// Top light edge for [liftPrimary] on dark grounds: rgba(243,245,239,.1).
  static const Color liftPrimaryEdge = Color(0x1AF3F5EF);

  /// `--lift-primary-light`: primary cards on Lime / Chalk grounds.
  static const List<BoxShadow> liftPrimaryLight = <BoxShadow>[
    BoxShadow(color: Color(0x80050604), offset: Offset(0, 18), blurRadius: 48),
    BoxShadow(color: Color(0x4D050604), offset: Offset(0, 4), blurRadius: 12),
  ];

  /// Top light edge for [liftPrimaryLight]: rgba(255,255,255,.42).
  static const Color liftPrimaryLightEdge = Color(0x6BFFFFFF);

  /// `--lift-card`: 0 6px 20px rgba(5,6,4,.42).
  static const List<BoxShadow> liftCard = <BoxShadow>[
    BoxShadow(color: Color(0x6B050604), offset: Offset(0, 6), blurRadius: 20),
  ];

  /// Top light edge for [liftCard]: rgba(243,245,239,.055).
  static const Color liftCardEdge = Color(0x0EF3F5EF);

  /// `--lift-inner`: inset only, no outer shadow.
  static const List<BoxShadow> liftInner = <BoxShadow>[];

  /// Top light edge for [liftInner]: rgba(243,245,239,.04).
  static const Color innerEdge = Color(0x0AF3F5EF);

  /// Floating Chalk tab bar (chapter 5.4).
  static const List<BoxShadow> tabBar = <BoxShadow>[
    BoxShadow(color: Color(0x80050604), offset: Offset(0, -2), blurRadius: 24),
    BoxShadow(color: Color(0x99050604), offset: Offset(0, 16), blurRadius: 40),
  ];

  /// Top light edge of the tab bar: rgba(255,255,255,.6).
  static const Color tabBarEdge = Color(0x99FFFFFF);

  /// Selected tab cell: 0 2px 8px rgba(5,6,4,.22).
  static const List<BoxShadow> tabSelected = <BoxShadow>[
    BoxShadow(color: Color(0x38050604), offset: Offset(0, 2), blurRadius: 8),
  ];

  /// Top light edge of the selected tab: rgba(255,255,255,.5).
  static const Color tabSelectedEdge = Color(0x80FFFFFF);
}

/// z-axis baseline (chapter 4.4). Flutter stacks by widget order; these
/// values document the required ordering for overlays and tests.
abstract final class LoopZ {
  static const int content = 1;
  static const int stickyHeader = 8;
  static const int disclosure = 20;
  static const int communityPanel = 45;
  static const int tabBar = 50;
  static const int statusBar = 55;
  static const int notch = 60;
  static const int veil = 70;
  static const int sheet = 80;
  static const int toast = 90;
}

/// Touch targets and fixed control sizes (chapter 4.3 / 5.4).
abstract final class LoopTouch {
  /// Minimum hit target for every tappable element.
  static const double minimum = 44;

  /// Primary button height.
  static const double primaryButton = 53;

  /// Floating tab bar height and its minimum cell height.
  static const double tabBarHeight = 70;
  static const double tabCellMinHeight = 55;
}

/// Page layout reserves (chapter 5.3 / 5.4).
abstract final class LoopLayout {
  /// Design baseline width/height.
  static const Size designBaseline = Size(390, 844);

  /// Top-level tab pages reserve `90 + safe-area-bottom` under the bar.
  static const double tabPageBottomReserve = 90;

  /// Child pages keep `max(24, safe-area-bottom)`.
  static const double childPageBottomMinimum = 24;

  /// Tab bar side and bottom inset on mobile (`8 + safe area`).
  static const double tabBarInset = 8;

  /// Tab bar inner padding.
  static const double tabBarPadding = 7;

  /// Width from which the desktop navigation rail replaces the bar.
  static const double railBreakpoint = 900;

  /// Topbar reserve. Derived from the type ladder, not chosen: 6 top padding
  /// + one 11px eyebrow line at 1.25 + two 24px title lines at the heading
  /// band's 1.22 leading (6 + 13.75 + 58.56 = 78.31), rounded to 80. A page
  /// title wraps to two lines in Chinese far more often than in English, so
  /// the second line is reserved rather than clipped.
  static const double topbarHeight = 80;

  /// Content box inside [topbarHeight], after the bar's own top padding.
  static const double topbarContentHeight = 74;
}

/// Font families (chapter 4.2). Sora ships as a variable font and carries the
/// Latin/figure voice; Noto Sans SC ships as three static weights (Regular /
/// Medium / Bold, GB2312-complete subset) and carries every CJK glyph. Because
/// Sora has no CJK coverage, a mixed 中英 line resolves per glyph: Latin from
/// Sora, Han from Noto Sans SC — the same order the prototype declares in
/// `body{font-family:var(--body),'Noto Sans SC',…}`.
abstract final class LoopFonts {
  static const String display = 'Sora';
  static const String body = 'Sora';
  static const String mono = 'IBM Plex Mono';

  /// The bundled CJK family. It leads every fallback list so Chinese renders
  /// in the shipped file instead of whatever the device happens to install.
  static const String cjk = 'Noto Sans SC';

  /// Fallback chain for the proportional bands. Bundled CJK first, then the
  /// platform stacks for scripts we do not ship (Japanese kana, Korean,
  /// Cyrillic beyond the subset, emoji-adjacent symbols).
  static const List<String> cjkFallback = <String>[
    cjk,
    'PingFang SC',
    'Source Han Sans SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'sans-serif',
  ];

  /// Fallback chain for the fixed-width band. IBM Plex Mono has no Han
  /// coverage, so a Chinese eyebrow label still resolves to the bundled CJK
  /// file rather than the system monospace face.
  static const List<String> monoFallback = <String>[
    cjk,
    'PingFang SC',
    'Menlo',
    'monospace',
  ];
}

/// Type builders. Weight is applied twice on purpose: `fontWeight` for
/// matching/semantics and `fontVariations` so the variable Sora file renders
/// the exact weight instead of synthesising it. The Noto Sans SC statics are
/// matched by `fontWeight` alone and ignore the variation axis.
///
/// Leading is distributed evenly ([TextLeadingDistribution.even]) because a
/// mixed 中英 line resolves two files with different ascent/descent ratios;
/// proportional leading would shift the baseline whenever a run switches
/// script.
abstract final class LoopTypography {
  static TextStyle sora({
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color color = LoopColors.chalk,
  }) {
    return TextStyle(
      fontFamily: LoopFonts.body,
      fontFamilyFallback: LoopFonts.cjkFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: <FontVariation>[FontVariation.weight(weight.value * 1.0)],
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Numbers, addresses, tickers, timestamps and status stamps.
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w500,
    double? height,
    double? letterSpacing,
    Color color = LoopColors.chalk,
  }) {
    return TextStyle(
      fontFamily: LoopFonts.mono,
      fontFamilyFallback: LoopFonts.monoFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  // ---------------------------------------------------------------------
  // The seven bands. Every band fixes weight, line height and a tracking
  // ratio expressed in `em`; a call site may only choose a step size from the
  // band's documented ladder. Feature code never writes `fontSize`,
  // `fontWeight` or `fontFamily` — see `scripts/check_harness.py`.
  // ---------------------------------------------------------------------

  /// Band 1 · display — brand statements and hero figures.
  /// Prototype `.hero-num` / `.folio-heading` / `.mining-power-value`
  /// (`800 32px/1.1 -1.5px`, `800 27px/.96 -1.25px`, `800 44px/.95 -2px`).
  /// Line height is lifted to 1.15: the prototype values are Latin-only and a
  /// two-line Chinese heading overlaps below ~1.1.
  static TextStyle display(double size, {Color color = LoopColors.chalk}) =>
      sora(
        size: size,
        weight: FontWeight.w800,
        height: 1.15,
        letterSpacing: size * -0.046,
        color: color,
      );

  /// Band 2 · heading — page titles and section headings.
  /// Prototype `.topbar h2` (`800 24px/1.12 -.65px`) and `.sheet-head h3`.
  static TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = LoopColors.chalk,
  }) => sora(
    size: size,
    weight: weight,
    height: 1.22,
    letterSpacing: size * -0.027,
    color: color,
  );

  /// Band 3 · title — card and row titles (`.row-t`, `.tcard-id b`).
  static TextStyle title(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.chalk,
  }) => sora(
    size: size,
    weight: weight,
    height: 1.35,
    letterSpacing: size * -0.012,
    color: color,
  );

  /// Band 4 · body — running prose. Prototype `[data-primary-body]`
  /// (`14px/1.5`) at the document weight 500; 1.55 gives Han glyphs, which
  /// fill their em box, the extra leading Latin does not need.
  static TextStyle body(double size, {Color color = LoopColors.chalk}) =>
      sora(size: size, weight: FontWeight.w500, height: 1.55, color: color);

  /// Band 5 · caption — supporting copy. Prototype `[data-support-copy]`
  /// (`12px/1.45`) with the on-screen floor of 11px
  /// (`.scr :is(.label,.badge,…,small){font-size:11px}`).
  static TextStyle caption(double size, {Color color = LoopColors.text3}) =>
      sora(size: size, weight: FontWeight.w500, height: 1.45, color: color);

  /// Band 6 · label — controls and inline labels. Prototype
  /// `[data-primary-control]` (`14px`) and `.tab` (`700 11px .015em`).
  static TextStyle label(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = LoopColors.text3,
  }) => sora(
    size: size,
    weight: weight,
    height: 1.25,
    letterSpacing: size * 0.008,
    color: color,
  );

  /// Band 6b · eyebrow — the one fixed-width label. Prototype `.label`
  /// (`600 10px/1.2 var(--mono)`, `letter-spacing:.15em`, uppercase) raised to
  /// the 11px screen floor.
  static TextStyle eyebrow(double size, {Color color = LoopColors.text3}) =>
      mono(
        size: size,
        weight: FontWeight.w600,
        height: 1.25,
        letterSpacing: size * 0.15,
        color: color,
      );

  /// Band 7 · mono — figures, amounts, addresses, IDs and timestamps only.
  static TextStyle figure(
    double size, {
    FontWeight weight = FontWeight.w600,
    double height = 1.35,
    Color color = LoopColors.chalk,
  }) => mono(
    size: size,
    weight: weight,
    height: height,
    letterSpacing: size * -0.008,
    color: color,
  );

  /// Restate [style] at [weight]. Sora is variable, so `copyWith(fontWeight:)`
  /// alone leaves `fontVariations` pinned to the old axis value and the file
  /// keeps rendering the previous weight. Always go through this.
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    if (style.fontFamily == LoopFonts.mono) {
      return style.copyWith(fontWeight: weight);
    }
    return style.copyWith(
      fontWeight: weight,
      fontVariations: <FontVariation>[FontVariation.weight(weight.value * 1.0)],
    );
  }
}

/// The named steps of the seven bands. This is the whole vocabulary available
/// to pages: `lib/features/**` and `lib/widgets/**` take a step from here (or
/// the `TextTheme` slot that mirrors it) and never a raw number.
///
/// | band | step | size | weight | height | tracking |
/// | --- | --- | --- | --- | --- | --- |
/// | display | `displayXl` | 42 | 800 | 1.15 | -0.046em |
/// | display | `display` | 32 | 800 | 1.15 | -0.046em |
/// | display | `displaySm` | 27 | 800 | 1.15 | -0.046em |
/// | heading | `headingLg` | 24 | 800 | 1.22 | -0.027em |
/// | heading | `heading` | 21 | 700 | 1.22 | -0.027em |
/// | heading | `headingSm` | 18 | 700 | 1.22 | -0.027em |
/// | title | `titleLg` | 17 | 700 | 1.35 | -0.012em |
/// | title | `title` | 15 | 600 | 1.35 | -0.012em |
/// | title | `titleSm` | 13 | 600 | 1.35 | -0.012em |
/// | body | `bodyLg` | 15 | 500 | 1.55 | 0 |
/// | body | `body` | 14 | 500 | 1.55 | 0 |
/// | body | `bodySm` | 13 | 500 | 1.55 | 0 |
/// | caption | `caption` | 12 | 500 | 1.45 | 0 |
/// | caption | `captionSm` | 11 | 500 | 1.45 | 0 |
/// | label | `action` | 14 | 700 | 1.25 | +0.008em |
/// | label | `label` | 12 | 600 | 1.25 | +0.008em |
/// | label | `eyebrow` | 11 | 600 | 1.25 | +0.15em, mono |
/// | mono | `monoDisplay` | 32 | 600 | 1.05 | -0.008em |
/// | mono | `monoTitle` | 20 | 600 | 1.15 | -0.008em |
/// | mono | `monoQuote` | 17 | 600 | 1.15 | -0.008em |
/// | mono | `monoValue` | 13 | 600 | 1.35 | -0.008em |
/// | mono | `monoBody` | 12 | 500 | 1.5 | -0.008em |
/// | mono | `monoStamp` | 11 | 500 | 1.35 | -0.008em |
abstract final class LoopType {
  // Band 1 · display.
  static final TextStyle displayXl = LoopTypography.display(42);
  static final TextStyle display = LoopTypography.display(32);
  static final TextStyle displaySm = LoopTypography.display(27);

  // Band 2 · heading.
  static final TextStyle headingLg = LoopTypography.heading(24);
  static final TextStyle heading = LoopTypography.heading(
    21,
    weight: FontWeight.w700,
  );
  static final TextStyle headingSm = LoopTypography.heading(
    18,
    weight: FontWeight.w700,
  );

  // Band 3 · title.
  static final TextStyle titleLg = LoopTypography.title(17);
  static final TextStyle title = LoopTypography.title(
    15,
    weight: FontWeight.w600,
  );
  static final TextStyle titleSm = LoopTypography.title(
    13,
    weight: FontWeight.w600,
  );

  // Band 4 · body.
  static final TextStyle bodyLg = LoopTypography.body(15);
  static final TextStyle body = LoopTypography.body(14);
  static final TextStyle bodySm = LoopTypography.body(
    13,
    color: LoopColors.text2,
  );

  // Band 5 · caption.
  static final TextStyle caption = LoopTypography.caption(12);
  static final TextStyle captionSm = LoopTypography.caption(11);

  // Band 6 · label.
  static final TextStyle action = LoopTypography.label(
    14,
    weight: FontWeight.w700,
    color: LoopColors.chalk,
  );
  static final TextStyle label = LoopTypography.label(12);
  static final TextStyle eyebrow = LoopTypography.eyebrow(11);

  // Band 7 · mono.
  static final TextStyle monoDisplay = LoopTypography.figure(32, height: 1.05);
  static final TextStyle monoTitle = LoopTypography.figure(20, height: 1.15);
  static final TextStyle monoQuote = LoopTypography.figure(17, height: 1.15);
  static final TextStyle monoValue = LoopTypography.figure(13);
  static final TextStyle monoBody = LoopTypography.figure(
    12,
    weight: FontWeight.w500,
    height: 1.5,
    color: LoopColors.text2,
  );
  static final TextStyle monoStamp = LoopTypography.figure(
    11,
    weight: FontWeight.w500,
    color: LoopColors.text2,
  );
}

/// `LoopMono` styles: the fixed-width set every number, address, ticker and
/// time must use. These are band 7 (plus the mono eyebrow) under the names the
/// feature slices already call; new code should prefer [LoopType].
abstract final class LoopMono {
  /// Main figure (balance, price).
  static final TextStyle display = LoopType.monoDisplay;

  /// Card headline figure.
  static final TextStyle headline = LoopType.monoTitle;

  /// Row trailing value.
  static final TextStyle value = LoopType.monoValue;

  /// Body-sized figure inside prose.
  static final TextStyle body = LoopType.monoBody;

  /// Uppercase mono eyebrow (`.label` in the prototype).
  static final TextStyle label = LoopType.eyebrow;

  /// Address / hash / timestamp stamp.
  static final TextStyle stamp = LoopType.monoStamp;
}

abstract final class LoopTheme {
  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: LoopColors.lime,
      onPrimary: LoopColors.ink,
      secondary: LoopColors.chalk,
      onSecondary: LoopColors.ink,
      surface: LoopColors.graphite,
      onSurface: LoopColors.chalk,
      outline: LoopColors.line,
      error: LoopColors.danger,
    ).copyWith(tertiary: LoopColors.lime, onTertiary: LoopColors.ink);

    final base = ThemeData.dark(useMaterial3: true);
    // The Material slots are a view onto the seven bands; nothing here invents
    // a size. `.apply` is deliberately not used — it would overwrite the mono
    // band's family on the slots that carry figures.
    final textTheme = base.textTheme.copyWith(
      // Band 1 · display.
      displayLarge: LoopType.displayXl,
      displayMedium: LoopType.display,
      displaySmall: LoopType.displaySm,
      // Band 2 · heading.
      headlineLarge: LoopType.headingLg,
      headlineMedium: LoopType.heading,
      headlineSmall: LoopType.headingSm,
      // Band 3 · title.
      titleLarge: LoopType.titleLg,
      titleMedium: LoopType.title,
      titleSmall: LoopType.titleSm,
      // Band 4 · body.
      bodyLarge: LoopType.body,
      bodyMedium: LoopType.bodySm,
      // Band 5 · caption.
      bodySmall: LoopType.caption,
      // Band 6 · label.
      labelLarge: LoopType.action,
      labelMedium: LoopType.label,
      labelSmall: LoopType.captionSm,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LoopColors.ink,
      canvasColor: LoopColors.ink,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: LoopPushTransitionsBuilder(),
          TargetPlatform.iOS: LoopPushTransitionsBuilder(),
          TargetPlatform.fuchsia: LoopPushTransitionsBuilder(),
          TargetPlatform.linux: LoopPushTransitionsBuilder(),
          TargetPlatform.macOS: LoopPushTransitionsBuilder(),
          TargetPlatform.windows: LoopPushTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: LoopColors.ink,
        foregroundColor: LoopColors.chalk,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: LoopLayout.topbarHeight,
        titleTextStyle: textTheme.headlineLarge,
      ),
      dividerTheme: const DividerThemeData(
        color: LoopColors.line,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: LoopTouch.tabBarHeight,
        elevation: 0,
        backgroundColor: LoopColors.chalk,
        indicatorColor: LoopColors.lime,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected)
                ? LoopColors.ink
                : LoopColors.inkMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? LoopColors.ink
                : LoopColors.inkMuted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: LoopColors.ink,
        indicatorColor: LoopColors.lime,
        selectedIconTheme: const IconThemeData(color: LoopColors.ink, size: 21),
        unselectedIconTheme: const IconThemeData(
          color: LoopColors.text2,
          size: 21,
        ),
        selectedLabelTextStyle: textTheme.labelLarge,
        unselectedLabelTextStyle: LoopTypography.withWeight(
          textTheme.labelLarge!,
          FontWeight.w600,
        ).copyWith(color: LoopColors.text2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LoopColors.card,
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.lime, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.line2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LoopColors.lime,
          foregroundColor: LoopColors.ink,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LoopColors.chalk,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: LoopColors.line2),
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.control),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LoopColors.chalk,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.minimum),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: LoopColors.chalk,
          minimumSize: const Size.square(LoopTouch.minimum),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: LoopColors.line),
        backgroundColor: LoopColors.card,
        selectedColor: LoopColors.limeSoft,
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: LoopRadius.pill),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LoopColors.graphite,
        modalBackgroundColor: LoopColors.graphite,
        modalBarrierColor: LoopColors.veil,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LoopRadius.shellValue),
          ),
          side: BorderSide(color: LoopColors.line),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: LoopColors.graphite,
        surfaceTintColor: Colors.transparent,
        barrierColor: LoopColors.veil,
        shape: RoundedRectangleBorder(
          borderRadius: LoopRadius.shell,
          side: BorderSide(color: LoopColors.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LoopColors.graphite,
        contentTextStyle: textTheme.bodyLarge,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: LoopRadius.control,
          side: BorderSide(color: LoopColors.line2),
        ),
      ),
      focusColor: LoopColors.limeSoft,
    );
  }
}

/// Detail push transition (chapter 7): child pages slide in from the right
/// with a fade, the outgoing page drifts slightly left. Peer tab switches use
/// a plain fade instead (see `LoopTabPage`). Reduced motion disables both.
class LoopPushTransitionsBuilder extends PageTransitionsBuilder {
  const LoopPushTransitionsBuilder();

  static const Curve curve = Cubic(0.22, 0.9, 0.3, 1);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final enter = CurvedAnimation(parent: animation, curve: curve);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: curve);
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.06, 0),
      ).animate(exit),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

extension LoopTextStyles on BuildContext {
  /// Existing alias used by feature slices for tabular figures.
  TextStyle get dataStyle => LoopMono.value;

  TextTheme get loopText => Theme.of(this).textTheme;
}

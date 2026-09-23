import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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

/// The ink of the ground a widget was actually placed on.
///
/// Every soft token in [LoopColors] — `card`, `card2`, `line`, `text2`,
/// `text3` — is Chalk at a low alpha, because the palette is authored for the
/// Ink page. Painted on a Chalk card or a Lime folio they are Chalk on Chalk:
/// the widget still lays out, still takes its 200px, and is simply not there.
/// A shared widget that can land on either ground therefore derives its
/// colours from the ambient [DefaultTextStyle] — which the light grounds
/// already set to Ink — instead of naming a fixed token.
///
/// Each weight is read off the token it stands for, so on the Ink page every
/// derived colour is the token itself and nothing about the dark rendering
/// moves.
///
/// This only works because a light ground *declares itself*: the container
/// that paints Chalk or Lime wraps its children in a [DefaultTextStyle] and an
/// [IconTheme] carrying that ground's ink. A container that paints a light
/// fill and declares nothing leaves every descendant reading the page's Chalk,
/// and the derivation is silently wrong — which is why
/// `scripts/check_harness.py` holds the declaration itself.
abstract final class LoopGround {
  /// The ground's own ink at full strength: Chalk on Ink, Ink on Chalk/Lime.
  static Color inkOf(BuildContext context) =>
      (DefaultTextStyle.of(context).style.color ?? LoopColors.chalk).withValues(
        alpha: 1,
      );

  /// [LoopColors.card2]'s weight in the ground's ink — a filled inset or a
  /// placeholder. The alpha is taken from the token itself, so on the Ink page
  /// the result is the token, exactly.
  static Color fillOf(BuildContext context) =>
      inkOf(context).withValues(alpha: LoopColors.card2.a);

  /// [LoopColors.card]'s weight in the ground's ink — the softer panel tint a
  /// placeholder or an inset panel sits on.
  static Color tintOf(BuildContext context) =>
      inkOf(context).withValues(alpha: LoopColors.card.a);

  /// [LoopColors.line]'s weight in the ground's ink — a hairline edge.
  static Color hairlineOf(BuildContext context) =>
      inkOf(context).withValues(alpha: LoopColors.line.a);

  /// [LoopColors.line2]'s weight in the ground's ink — a strong edge, the one
  /// a control draws around itself.
  static Color edgeOf(BuildContext context) =>
      inkOf(context).withValues(alpha: LoopColors.line2.a);

  /// [LoopColors.text2]'s weight in the ground's ink — secondary copy.
  static Color secondaryOf(BuildContext context) =>
      inkOf(context).withValues(alpha: LoopColors.text2.a);

  /// [LoopColors.text3]'s weight in the ground's ink — auxiliary copy and
  /// glyphs.
  static Color auxiliaryOf(BuildContext context) =>
      inkOf(context).withValues(alpha: LoopColors.text3.a);
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
  /// + one 12px eyebrow line at 1.25 + two 22px title lines at the heading
  /// band's 1.25 leading (6 + 15 + 55 = 76), kept at 80 so the reserve did
  /// not move when decision 0080 lowered the ladder — the 4px it gains is
  /// cushion, not a gap a page has to fill. A page title wraps to two lines in
  /// Chinese far more often than in English, so the second line is reserved
  /// rather than clipped.
  static const double topbarHeight = 80;

  /// Content box inside [topbarHeight], after the bar's own top padding.
  static const double topbarContentHeight = 74;
}

/// Font families (decision 0080, which replaces the display voice of chapter
/// 4.2). LOOP ships no display face any more: every proportional band asks the
/// platform for its own UI sans — SF Pro on iOS/macOS through the engine's
/// `CupertinoSystem*` aliases, Roboto on Android — and Chinese resolves
/// through the fallback chain, Apple's PingFang SC beside SF Pro and the
/// bundled Noto Sans SC everywhere else. Both halves of a 中英 line therefore
/// come from one vendor's stack.
///
/// IBM Plex Mono survives for one job: addresses, hashes and code, where a
/// fixed advance is the point. **Figures are no longer fixed-width.** They are
/// the same system sans asked for `tabularFigures`, which is what a price
/// column actually needs — equal digit advances inside the page's one voice.
abstract final class LoopFonts {
  /// The system UI sans at text optical size. On iOS/macOS the engine maps it
  /// to SF Pro Text; on every other platform it does not resolve and the head
  /// of [systemFallback] takes the primary position.
  static const String system = 'CupertinoSystemText';

  /// The system UI sans at display optical size (SF Pro Display on Apple).
  static const String systemDisplay = 'CupertinoSystemDisplay';

  /// The size at which Apple switches from the text cut to the display cut.
  static const double displayOpticalSize = 20;

  /// Android's own UI sans. The `CupertinoSystem*` aliases resolve on Apple
  /// platforms only; a family list whose primary name is unknown falls
  /// through to the next entry, so Roboto has to lead the fallback chain.
  static const String android = 'Roboto';

  static const String mono = 'IBM Plex Mono';

  /// The bundled CJK family — the controlled Chinese face for every device
  /// whose platform stack we do not trust.
  static const String cjk = 'Noto Sans SC';

  /// Names kept for the call sites that ask for "the body face" or "the
  /// display face" rather than a band step.
  static const String body = system;
  static const String display = systemDisplay;

  /// The optical cut a band step of [size] asks for.
  static String familyFor(double size) =>
      size >= displayOpticalSize ? systemDisplay : system;

  /// Fallback chain for the proportional bands: Android's Latin face, then
  /// Apple's CJK companion to SF Pro, then the bundled file, then the OEM
  /// stacks for scripts none of those carry.
  static const List<String> systemFallback = <String>[
    android,
    'PingFang SC',
    cjk,
    'HarmonyOS Sans SC',
    'Source Han Sans SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  /// Retained name for the same chain (Stream's theme adapter calls it).
  static const List<String> cjkFallback = systemFallback;

  /// Fallback chain for the fixed-width band. IBM Plex Mono has no Han
  /// coverage, so a Chinese run inside an address line still lands on a real
  /// CJK face instead of the system monospace.
  static const List<String> monoFallback = <String>[
    'SF Mono',
    'Menlo',
    cjk,
    'PingFang SC',
    'monospace',
  ];
}

/// Type builders. Every band is the platform's own sans; weight is matched by
/// `fontWeight` alone, because neither the system face (which the engine
/// instances itself) nor the bundled Noto Sans SC statics take a variation
/// axis from us.
///
/// Leading is distributed evenly ([TextLeadingDistribution.even]) because a
/// mixed 中英 line resolves two files with different ascent/descent ratios;
/// proportional leading would shift the baseline whenever a run switches
/// script.
abstract final class LoopTypography {
  /// The proportional builder behind bands 1–6 and, with [tabularFigures],
  /// band 7.
  static TextStyle sans({
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color color = LoopColors.chalk,
    bool tabularFigures = false,
  }) {
    return TextStyle(
      fontFamily: LoopFonts.familyFor(size),
      fontFamilyFallback: LoopFonts.systemFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      // Explicit, never null: a null tracking lets Material's own 2021
      // typography (+0.5 on a label, +0.3 on a title) leak through the merge
      // that builds a `Text`'s style, and the ladder stops being the ladder.
      letterSpacing: letterSpacing ?? 0,
      color: color,
      fontFeatures: tabularFigures
          ? const <FontFeature>[FontFeature.tabularFigures()]
          : null,
    );
  }

  /// Fixed width. Addresses, transaction hashes, contract identifiers and
  /// code — never an amount, a price or a percentage: those are band 7, which
  /// is the page's own voice with equal digit advances.
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
      letterSpacing: letterSpacing ?? 0,
      color: color,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  // ---------------------------------------------------------------------
  // The seven bands. Every band fixes weight and line height; tracking is 0
  // everywhere, because a system UI sans is already spaced for the screen and
  // Han glyphs have no business being tracked. A call site may only choose a
  // step size from the band's documented ladder. Feature code never writes
  // `fontSize`, `fontWeight` or `fontFamily` — see `scripts/check_harness.py`.
  //
  // Hierarchy is carried by weight and by the grey of the token, not by size:
  // the whole ladder spans 11 → 28, where it used to span 11 → 42.
  // ---------------------------------------------------------------------

  /// Band 1 · display — the one big statement on a page: a hero figure, a
  /// folio heading. 26–28 semibold, not 32–42 extrabold.
  static TextStyle display(double size, {Color color = LoopColors.chalk}) =>
      sans(size: size, weight: FontWeight.w600, height: 1.2, color: color);

  /// Band 2 · heading — page titles and section headings. 20–22 semibold.
  static TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = LoopColors.chalk,
  }) => sans(size: size, weight: weight, height: 1.25, color: color);

  /// Band 3 · title — card and row titles. 15–16 at medium/semibold.
  static TextStyle title(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = LoopColors.chalk,
  }) => sans(size: size, weight: weight, height: 1.3, color: color);

  /// Band 4 · body — running prose at 14 regular. 1.4 is the loose end of the
  /// ladder's range, kept for prose because Han glyphs fill their em box.
  static TextStyle body(double size, {Color color = LoopColors.chalk}) =>
      sans(size: size, weight: FontWeight.w400, height: 1.4, color: color);

  /// Band 5 · caption — supporting copy at 12, with the on-screen floor of 11
  /// (`.scr :is(.label,.badge,…,small){font-size:11px}`).
  static TextStyle caption(double size, {Color color = LoopColors.text3}) =>
      sans(size: size, weight: FontWeight.w400, height: 1.35, color: color);

  /// Band 6 · label — controls and inline labels.
  static TextStyle label(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = LoopColors.text3,
  }) => sans(size: size, weight: weight, height: 1.25, color: color);

  /// Band 6b · eyebrow — the small subheading over a group. It used to be an
  /// uppercase, letter-spaced, fixed-width Latin stamp (`MARKET SIGNALS`); it
  /// is now a 12px Chinese subheading in the page's own voice, told apart by
  /// weight and grey. The strings themselves are each page's to restate.
  static TextStyle eyebrow(double size, {Color color = LoopColors.text3}) =>
      sans(size: size, weight: FontWeight.w500, height: 1.25, color: color);

  /// Band 7 · figure — every number the product shows: amounts, prices,
  /// percentages, counts, timestamps. The page's own sans with
  /// [FontFeature.tabularFigures], so a right-aligned column lines up without
  /// leaving the one voice. Addresses and hashes are [code], not this.
  static TextStyle figure(
    double size, {
    FontWeight weight = FontWeight.w600,
    double height = 1.3,
    Color color = LoopColors.chalk,
  }) => sans(
    size: size,
    weight: weight,
    height: height,
    color: color,
    tabularFigures: true,
  );

  /// Band 7b · code — the fixed-width band, and the only one: an address, a
  /// transaction hash, a contract identifier, a raw payload. A fixed advance
  /// is what makes two hashes comparable by eye; nothing else needs it.
  static TextStyle code(
    double size, {
    FontWeight weight = FontWeight.w500,
    double height = 1.4,
    Color color = LoopColors.chalk,
  }) => mono(size: size, weight: weight, height: height, color: color);

  /// Restate [style] at [weight]. Kept as the single sanctioned way to move a
  /// weight: the bands no longer carry a variation axis, so this is now a
  /// plain restatement, and call sites do not have to know that.
  static TextStyle withWeight(TextStyle style, FontWeight weight) =>
      style.copyWith(fontWeight: weight);
}

/// The named steps of the seven bands. This is the whole vocabulary available
/// to pages: `lib/features/**` and `lib/widgets/**` take a step from here (or
/// the `TextTheme` slot that mirrors it) and never a raw number.
///
/// | band | step | size | weight | height | family |
/// | --- | --- | --- | --- | --- | --- |
/// | display | `displayXl` | 28 | 600 | 1.2 | system display |
/// | display | `display` | 26 | 600 | 1.2 | system display |
/// | display | `displaySm` | 24 | 600 | 1.2 | system display |
/// | heading | `headingLg` | 22 | 600 | 1.25 | system display |
/// | heading | `heading` | 20 | 600 | 1.25 | system display |
/// | heading | `headingSm` | 17 | 600 | 1.3 | system text |
/// | title | `titleLg` | 16 | 600 | 1.3 | system text |
/// | title | `title` | 15 | 600 | 1.3 | system text |
/// | title | `titleSm` | 13 | 500 | 1.3 | system text |
/// | body | `bodyLg` | 15 | 400 | 1.4 | system text |
/// | body | `body` | 14 | 400 | 1.4 | system text |
/// | body | `bodySm` | 13 | 400 | 1.4 | system text |
/// | caption | `caption` | 12 | 400 | 1.35 | system text |
/// | caption | `captionSm` | 11 | 400 | 1.35 | system text |
/// | label | `action` | 14 | 600 | 1.25 | system text |
/// | label | `label` | 12 | 500 | 1.25 | system text |
/// | label | `eyebrow` | 12 | 500 | 1.25 | system text |
/// | figure | `figureXl` (`monoDisplay`) | 28 | 600 | 1.2 | system display, tnum |
/// | figure | `figureLg` (`monoTitle`) | 20 | 600 | 1.25 | system display, tnum |
/// | figure | `figureMd` (`monoQuote`) | 17 | 600 | 1.3 | system text, tnum |
/// | figure | `figure` (`monoValue`) | 13 | 500 | 1.3 | system text, tnum |
/// | figure | `figureSm` (`monoBody`) | 12 | 400 | 1.4 | system text, tnum |
/// | figure | `figureXs` (`monoStamp`) | 11 | 400 | 1.35 | system text, tnum |
/// | code | `code` | 13 | 500 | 1.4 | IBM Plex Mono |
/// | code | `codeSm` | 11 | 500 | 1.35 | IBM Plex Mono |
///
/// Tracking is 0 on every step. The `mono*` names are kept because the
/// feature slices call them; they are band 7 — tabular figures in the page's
/// own sans — and no longer a fixed-width face.
abstract final class LoopType {
  // Band 1 · display.
  static final TextStyle displayXl = LoopTypography.display(28);
  static final TextStyle display = LoopTypography.display(26);
  static final TextStyle displaySm = LoopTypography.display(24);

  // Band 2 · heading.
  static final TextStyle headingLg = LoopTypography.heading(22);
  static final TextStyle heading = LoopTypography.heading(20);
  static final TextStyle headingSm = LoopTypography.heading(17);

  // Band 3 · title.
  static final TextStyle titleLg = LoopTypography.title(16);
  static final TextStyle title = LoopTypography.title(15);
  static final TextStyle titleSm = LoopTypography.title(
    13,
    weight: FontWeight.w500,
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
    weight: FontWeight.w600,
    color: LoopColors.chalk,
  );
  static final TextStyle label = LoopTypography.label(12);
  static final TextStyle eyebrow = LoopTypography.eyebrow(12);

  // Band 7 · figure — tabular numbers in the page's own voice.
  static final TextStyle figureXl = LoopTypography.figure(28, height: 1.2);
  static final TextStyle figureLg = LoopTypography.figure(20, height: 1.25);
  static final TextStyle figureMd = LoopTypography.figure(17);
  static final TextStyle figure = LoopTypography.figure(
    13,
    weight: FontWeight.w500,
  );
  static final TextStyle figureSm = LoopTypography.figure(
    12,
    weight: FontWeight.w400,
    height: 1.4,
    color: LoopColors.text2,
  );
  static final TextStyle figureXs = LoopTypography.figure(
    11,
    weight: FontWeight.w400,
    height: 1.35,
    color: LoopColors.text2,
  );

  // The names the feature slices already call, over the same steps.
  static final TextStyle monoDisplay = figureXl;
  static final TextStyle monoTitle = figureLg;
  static final TextStyle monoQuote = figureMd;
  static final TextStyle monoValue = figure;
  static final TextStyle monoBody = figureSm;
  static final TextStyle monoStamp = figureXs;

  // Band 7b · code — the only fixed-width steps.
  static final TextStyle code = LoopTypography.code(13);
  static final TextStyle codeSm = LoopTypography.code(11, height: 1.35);
}

/// `LoopMono` styles: the set every number, ticker and time must use. Since
/// decision 0080 these are band 7 — the page's own sans with tabular figures
/// — under the names the feature slices already call; only [address] is still
/// fixed-width. New code should prefer [LoopType].
abstract final class LoopMono {
  /// Main figure (balance, price).
  static final TextStyle display = LoopType.figureXl;

  /// Card headline figure.
  static final TextStyle headline = LoopType.figureLg;

  /// Row trailing value.
  static final TextStyle value = LoopType.figure;

  /// Body-sized figure inside prose.
  static final TextStyle body = LoopType.figureSm;

  /// The small subheading over a group (the former uppercase eyebrow).
  static final TextStyle label = LoopType.eyebrow;

  /// Timestamp / count stamp.
  static final TextStyle stamp = LoopType.figureXs;

  /// Address, hash, contract identifier — the fixed-width band.
  static final TextStyle address = LoopType.code;
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
      pageTransitionsTheme: loopPageTransitionsTheme,
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

/// The push transition every LOOP detail page takes.
///
/// Decision 0085. Chapter 7 asked for "slide in from the right with a fade",
/// and until this build LOOP answered it with one hand-written builder
/// (`LoopPushTransitionsBuilder`) installed on all six platforms. That builder
/// drew the right picture and removed the gesture: on iOS the edge-swipe-back
/// is not a separate feature of the navigator, it lives *inside*
/// [CupertinoPageTransitionsBuilder] — `CupertinoRouteTransitionMixin
/// .buildPageTransitions` is what wraps the page in the back-gesture
/// detector. Replace the builder and the whole right edge of every detail page
/// goes dead. Android's own back animation (predictive back on U and above)
/// was replaced the same way.
///
/// So the transition is the platform's, not ours:
///
/// - **iOS / macOS** — [CupertinoPageTransitionsBuilder]: the native parallax,
///   and with it the edge-swipe-back that a phone user reaches for first.
/// - **Android and the rest** — [PredictiveBackPageTransitionsBuilder]:
///   animates with the system back gesture on Android U and above, and falls
///   back to [FadeForwardsPageTransitionsBuilder] (a horizontal slide with a
///   fade — chapter 7's own description) everywhere else.
///
/// Reduced motion needs no branch here and must not have one. A branch that
/// returns the bare `child` would drop the gesture detector with the
/// animation, and it is not needed: [AnimationController] already reads the
/// platform's own "disable animations" flag and runs every route controller at
/// 0.05× its duration, so a 500ms Cupertino push takes 25ms and the swipe
/// still works. LOOP's own reduced-motion branches stay where they belong —
/// the tab-bar indicator and `LoopTabPage`'s peer fade, neither of which is a
/// route gesture.
const PageTransitionsTheme loopPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.linux: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: PredictiveBackPageTransitionsBuilder(),
  },
);

extension LoopTextStyles on BuildContext {
  /// Existing alias used by feature slices for tabular figures.
  TextStyle get dataStyle => LoopMono.value;

  TextTheme get loopText => Theme.of(this).textTheme;
}

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
}

/// Font families (chapter 4.2). Sora ships as a variable font; Noto Sans SC is
/// not bundled and CJK falls back to the platform stack.
abstract final class LoopFonts {
  static const String display = 'Sora';
  static const String body = 'Sora';
  static const String mono = 'IBM Plex Mono';

  static const List<String> cjkFallback = <String>[
    'PingFang SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'sans-serif',
  ];
}

/// Type builders. Weight is applied twice on purpose: `fontWeight` for
/// matching/semantics and `fontVariations` so the variable Sora file renders
/// the exact weight instead of synthesising it.
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
      fontFamilyFallback: const <String>['Menlo', 'monospace'],
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }
}

/// `LoopMono` styles: the fixed-width set every number, address, ticker and
/// time must use. Feature code takes these instead of `fontFamily: 'monospace'`.
abstract final class LoopMono {
  /// Main figure (balance, price) — up to 32px.
  static final TextStyle display = LoopTypography.mono(
    size: 32,
    weight: FontWeight.w600,
    height: 1.05,
    letterSpacing: -0.8,
  );

  /// Card headline figure.
  static final TextStyle headline = LoopTypography.mono(
    size: 22,
    weight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.4,
  );

  /// Row trailing value.
  static final TextStyle value = LoopTypography.mono(
    size: 14,
    weight: FontWeight.w500,
    height: 1.3,
    letterSpacing: -0.2,
  );

  /// Body-sized figure inside prose.
  static final TextStyle body = LoopTypography.mono(
    size: 12,
    weight: FontWeight.w400,
    height: 1.5,
  );

  /// Uppercase mono label (`.label` in the prototype): 10px / 600 / .15em.
  static final TextStyle label = LoopTypography.mono(
    size: 10,
    weight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1.5,
    color: LoopColors.text3,
  );

  /// Address / hash / timestamp stamp.
  static final TextStyle stamp = LoopTypography.mono(
    size: 11,
    weight: FontWeight.w400,
    height: 1.3,
    color: LoopColors.text2,
  );
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
    final textTheme = base.textTheme
        .copyWith(
          // Brand-scale display figures.
          displayLarge: LoopTypography.sora(
            size: 42,
            weight: FontWeight.w800,
            height: 0.98,
            letterSpacing: -1.8,
          ),
          // Main data 32.
          displayMedium: LoopTypography.sora(
            size: 32,
            weight: FontWeight.w800,
            height: 1.02,
            letterSpacing: -1.1,
          ),
          displaySmall: LoopTypography.sora(
            size: 28,
            weight: FontWeight.w800,
            height: 1.06,
            letterSpacing: -0.9,
          ),
          // Page title 24 / 800 / tight.
          headlineLarge: LoopTypography.sora(
            size: 24,
            weight: FontWeight.w800,
            height: 1.12,
            letterSpacing: -0.65,
          ),
          headlineMedium: LoopTypography.sora(
            size: 21,
            weight: FontWeight.w700,
            height: 1.16,
            letterSpacing: -0.4,
          ),
          headlineSmall: LoopTypography.sora(
            size: 18,
            weight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.3,
          ),
          titleLarge: LoopTypography.sora(
            size: 17,
            weight: FontWeight.w700,
            height: 1.24,
            letterSpacing: -0.2,
          ),
          titleMedium: LoopTypography.sora(
            size: 14,
            weight: FontWeight.w600,
            height: 1.3,
          ),
          titleSmall: LoopTypography.sora(
            size: 13,
            weight: FontWeight.w600,
            height: 1.3,
          ),
          bodyLarge: LoopTypography.sora(
            size: 14,
            weight: FontWeight.w400,
            height: 1.5,
          ),
          // Body baseline 12 / 1.5.
          bodyMedium: LoopTypography.sora(
            size: 12,
            weight: FontWeight.w400,
            height: 1.5,
            color: LoopColors.text2,
          ),
          bodySmall: LoopTypography.sora(
            size: 11,
            weight: FontWeight.w400,
            height: 1.45,
            color: LoopColors.text3,
          ),
          labelLarge: LoopTypography.sora(
            size: 13,
            weight: FontWeight.w700,
            height: 1.2,
          ),
          labelMedium: LoopTypography.sora(
            size: 11,
            weight: FontWeight.w700,
            height: 1.2,
            letterSpacing: 0.17,
            color: LoopColors.text3,
          ),
          labelSmall: LoopTypography.sora(
            size: 10,
            weight: FontWeight.w600,
            height: 1.2,
            letterSpacing: 0.3,
            color: LoopColors.text3,
          ),
        )
        .apply(
          fontFamily: LoopFonts.body,
          fontFamilyFallback: LoopFonts.cjkFallback,
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
        toolbarHeight: 68,
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
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: LoopColors.text2,
          fontWeight: FontWeight.w600,
        ),
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

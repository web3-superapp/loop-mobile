import 'package:flutter/material.dart';

abstract final class LoopColors {
  // V2 Lime Ledger foundation. Keep the semantic aliases below while the
  // existing surfaces migrate in bounded slices.
  static const Color ink = Color(0xFF050604);
  static const Color lime = Color(0xFFB8FF20);
  static const Color chalk = Color(0xFFF3F5EF);
  static const Color graphite = Color(0xFF171A16);
  static const Color panel = Color(0xFF0E100D);
  static const Color muted = Color(0xFF7F897B);
  static const Color textSecondary = Color(0xADF3F5EF);
  static const Color textTertiary = Color(0x94F3F5EF);
  static const Color hairline = Color(0xFF242523);

  static const Color abyss = ink;
  static const Color basalt = graphite;
  static const Color elevated = Color(0xFF1D1E1C);
  static const Color vapor = muted;
  static const Color mint = lime;
  // Legacy categorical accents. New V2 surfaces use Lime, Chalk and Muted;
  // existing feature slices migrate away from these aliases independently.
  static const Color market = Color(0xFF68B9FF);
  static const Color chat = Color(0xFFF2B562);
  static const Color danger = Color(0xFFFF6B82);
  static const Color warning = Color(0xFFFFC75F);
  static const Color line = hairline;
}

abstract final class LoopSpacing {
  static const double compact = 8;
  static const double regular = 14;
  static const double page = 16;
  static const double group = 22;
  static const double section = 22;
  static const double spacious = 30;

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
}

abstract final class LoopRadius {
  static const BorderRadius control = BorderRadius.all(Radius.circular(16));
  static const BorderRadius card = BorderRadius.all(Radius.circular(20));
  static const BorderRadius container = BorderRadius.all(Radius.circular(24));
  static const BorderRadius small = BorderRadius.all(Radius.circular(12));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(16));
  static const BorderRadius large = BorderRadius.all(Radius.circular(24));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
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
    final textTheme = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontSize: 42,
        height: 0.98,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.8,
        color: LoopColors.chalk,
      ),
      displayMedium: const TextStyle(
        fontSize: 32,
        height: 1.02,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        color: LoopColors.chalk,
      ),
      headlineLarge: const TextStyle(
        fontSize: 26,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: LoopColors.chalk,
      ),
      headlineMedium: const TextStyle(
        fontSize: 21,
        height: 1.16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
        color: LoopColors.chalk,
      ),
      titleLarge: const TextStyle(
        fontSize: 17,
        height: 1.24,
        fontWeight: FontWeight.w600,
        color: LoopColors.chalk,
      ),
      titleMedium: const TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: LoopColors.chalk,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        height: 1.48,
        fontWeight: FontWeight.w400,
        color: LoopColors.chalk,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13,
        height: 1.46,
        fontWeight: FontWeight.w400,
        color: LoopColors.textSecondary,
      ),
      labelLarge: const TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: LoopColors.chalk,
      ),
      labelMedium: const TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        color: LoopColors.textTertiary,
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LoopColors.abyss,
      canvasColor: LoopColors.abyss,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: LoopColors.abyss,
        foregroundColor: LoopColors.chalk,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: LoopColors.line,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: LoopColors.chalk,
        indicatorColor: LoopColors.lime,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? LoopColors.ink
                : LoopColors.graphite.withValues(alpha: 0.64),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? LoopColors.ink
                : LoopColors.graphite.withValues(alpha: 0.68),
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LoopColors.basalt,
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: const OutlineInputBorder(
          borderRadius: LoopRadius.medium,
          borderSide: BorderSide(color: LoopColors.line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.medium,
          borderSide: BorderSide(color: LoopColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.medium,
          borderSide: BorderSide(color: LoopColors.mint, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.medium,
          borderSide: BorderSide(color: LoopColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.medium),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: LoopColors.line),
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.medium),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: LoopColors.line),
        backgroundColor: LoopColors.basalt,
        selectedColor: LoopColors.mint.withValues(alpha: 0.12),
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: LoopRadius.pill),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LoopColors.basalt,
        modalBackgroundColor: LoopColors.basalt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: LoopColors.line),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: LoopColors.basalt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: LoopRadius.large,
          side: BorderSide(color: LoopColors.line),
        ),
      ),
      focusColor: LoopColors.mint.withValues(alpha: 0.2),
    );
  }
}

extension LoopTextStyles on BuildContext {
  TextStyle get dataStyle => Theme.of(this).textTheme.titleMedium!.copyWith(
    fontFamily: 'monospace',
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    letterSpacing: -0.2,
  );
}

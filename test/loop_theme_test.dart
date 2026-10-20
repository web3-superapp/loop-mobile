import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

void main() {
  test('colour tokens are the looplabs palette (decision 0210)', () {
    expect(LoopColors.ink, const Color(0xFF09090B));
    expect(LoopColors.yellow, const Color(0xFFFFD600));
    expect(LoopColors.yellowHighlight, const Color(0xFFFFE34D));
    expect(LoopColors.purple, const Color(0xFF9C36FF));
    expect(LoopColors.purpleSoft, const Color(0x189C36FF));
    expect(LoopColors.purpleLine, const Color(0x709C36FF));
    expect(LoopColors.input, const Color(0xFF16111C));
    expect(LoopColors.inputLine, const Color(0xFF3B3045));
    expect(LoopColors.chalk, const Color(0xFFF2F2F4));
    expect(LoopColors.graphite, const Color(0xFF111114));
    expect(LoopColors.card, const Color(0xFF111114));
    expect(LoopColors.text2, const Color(0xFFB8B4C0));
    expect(LoopColors.text3, const Color(0xFFAEACB6));
    expect(LoopColors.muted, const Color(0xFF8E8A98));
    expect(LoopColors.line, const Color(0xFF2A292F));
    expect(LoopColors.line2, const Color(0xFF38333E));
    expect(LoopColors.line3, const Color(0xFF4A4754));
    expect(LoopColors.warning, const Color(0xFFFF9F1C));
    // Price movement keeps its own two hues.
    expect(LoopColors.rise, const Color(0xFF22C55E));
    expect(LoopColors.fall, const Color(0xFFEF4444));
    // The retired Lime names are the Yellow tokens.
    expect(LoopColors.lime, LoopColors.yellow);
    expect(LoopColors.limeSoft, LoopColors.yellowSoft);
    expect(LoopColors.limeHighlight, LoopColors.yellowHighlight);
    expect(LoopColors.yellowSoft.withValues(alpha: 1), LoopColors.yellow);
    expect(LoopColors.veil.a, closeTo(0.76, 0.004));
  });

  test('legacy market/chat accents gain no new consumers in lib/', () {
    // The blue/amber aliases are unmigrated history. This guard records the
    // files that still use them; the list may only shrink. Remove the guard
    // together with the aliases when the Market slice migrates.
    const legacyAccentConsumers = <String>{
      'lib/features/chat/chat_inbox_page.dart',
      'lib/features/chat/chat_secondary_pages.dart',
      'lib/features/chat/conversation_pages.dart',
      'lib/features/chat/voice_room_page.dart',
      'lib/features/chat/widgets/chat_components.dart',
      'lib/widgets/loop_ui.dart',
    };
    final pattern = RegExp(r'LoopColors\.(?:market|chat)\b');
    final consumers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => pattern.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toSet();
    expect(
      consumers.difference(legacyAccentConsumers),
      isEmpty,
      reason: 'new code must not use the legacy blue/amber accents',
    );
    final scheme = LoopTheme.dark.colorScheme;
    expect(scheme.primary, LoopColors.yellow);
    expect(scheme.secondary, LoopColors.purple);
    expect(scheme.tertiary, LoopColors.purple);
    expect(scheme.surface, LoopColors.graphite);
    expect(scheme.outline, LoopColors.line);
  });

  test('spacing, radius, depth, z and touch tokens are complete', () {
    expect(LoopSpacing.tight, 8);
    expect(LoopSpacing.card, 20);
    expect(LoopSpacing.group, 22);
    expect(LoopSpacing.section, 40);
    expect(LoopSpacing.page, 20);

    // Decision 0210: every surface corner is square; only `pill` is round.
    for (final value in <double>[
      LoopRadius.shellValue,
      LoopRadius.cardValue,
      LoopRadius.controlValue,
      LoopRadius.innerValue,
      LoopRadius.tabBarValue,
      LoopRadius.tileValue,
      LoopRadius.buttonValue,
      LoopRadius.toolValue,
      LoopRadius.badgeValue,
      LoopRadius.wideButtonValue,
    ]) {
      expect(value, 0);
    }
    expect(LoopRadius.card, BorderRadius.zero);
    expect(LoopRadius.pill, const BorderRadius.all(Radius.circular(999)));

    // Flat: no lift anywhere, a coloured glow for emphasis.
    expect(LoopDepth.liftPrimary, isEmpty);
    expect(LoopDepth.liftPrimaryLight, isEmpty);
    expect(LoopDepth.liftCard, isEmpty);
    expect(LoopDepth.liftInner, isEmpty);
    expect(LoopDepth.tabBar, isEmpty);
    expect(LoopDepth.glowPurple.single.blurRadius, 24);
    expect(LoopDepth.glowYellow.single.blurRadius, 17);

    expect(LoopZ.content, 1);
    expect(LoopZ.stickyHeader, 8);
    expect(LoopZ.disclosure, 20);
    expect(LoopZ.communityPanel, 45);
    expect(LoopZ.tabBar, 50);
    expect(LoopZ.statusBar, 55);
    expect(LoopZ.notch, 60);
    expect(LoopZ.veil, 70);
    expect(LoopZ.sheet, 80);
    expect(LoopZ.toast, 90);

    expect(LoopTouch.minimum, 44);
    expect(LoopTouch.primaryButton, 52);
    expect(LoopTouch.tabBarHeight, 70);
    expect(LoopLayout.tabPageBottomReserve, 90);
    expect(LoopLayout.childPageBottomMinimum, 24);
    expect(LoopLayout.designBaseline, const Size(390, 844));
  });

  test('headings are Anton, body is Arimo, figures are tabular', () {
    final text = LoopTheme.dark.textTheme;
    final title = text.headlineLarge!;
    expect(title.fontFamily, 'Anton');
    expect(title.fontSize, 24);
    expect(title.fontWeight, FontWeight.w400);
    expect(title.letterSpacing, closeTo(-0.24, 0.001));
    // A Chinese run inside an Anton heading lands on bold Han.
    expect(title.fontFamilyFallback!.first, LoopFonts.cjkDisplay);
    expect(title.fontFamilyFallback, contains('Noto Sans SC'));

    expect(text.displayMedium!.fontSize, 32);
    expect(text.bodyLarge, same(LoopType.bodyLg));
    expect(text.bodyLarge!.fontFamily, 'Arimo');
    expect(text.bodyMedium!.fontSize, 13);
    expect(text.bodyMedium!.height, 1.7);

    for (final figure in <TextStyle>[
      LoopMono.display,
      LoopMono.headline,
      LoopMono.value,
      LoopMono.body,
      LoopMono.stamp,
    ]) {
      expect(figure.fontFamily, LoopFonts.body);
      expect(figure.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(figure.fontFamilyFallback!.first, LoopFonts.cjk);
    }
    expect(LoopMono.display.fontSize, 28);

    // Fixed width survives for one job: addresses, hashes, code.
    expect(LoopMono.address.fontFamily, LoopFonts.mono);
    expect(LoopType.code.fontFamily, LoopFonts.mono);
    expect(LoopType.codeSm.fontFamily, LoopFonts.mono);
    expect(LoopTypography.mono(size: 12).fontFamily, 'IBM Plex Mono');
  });

  test('the seven bands are the whole vocabulary', () {
    final condensed = <String, TextStyle>{
      'heroDisplay': LoopType.heroDisplay,
      'displayXl': LoopType.displayXl,
      'display': LoopType.display,
      'displaySm': LoopType.displaySm,
      'statFigure': LoopType.statFigure,
      'stepTitle': LoopType.stepTitle,
      'headingLg': LoopType.headingLg,
      'flatTitle': LoopType.flatTitle,
      'heading': LoopType.heading,
      'headingSm': LoopType.headingSm,
    };
    condensed.forEach((name, style) {
      expect(style.fontFamily, LoopFonts.display, reason: name);
      expect(style.fontWeight, FontWeight.w400, reason: name);
      expect(style.fontFamilyFallback!.first, LoopFonts.cjkDisplay);
      // Anton is tracked in, never out.
      expect(style.letterSpacing, lessThan(0), reason: name);
      expect(style.fontSize, greaterThanOrEqualTo(18), reason: name);
      expect(style.height, inInclusiveRange(1.0, 1.15), reason: name);
    });

    final body = <String, TextStyle>{
      'titleLg': LoopType.titleLg,
      'title': LoopType.title,
      'titleSm': LoopType.titleSm,
      'bodyLg': LoopType.bodyLg,
      'body': LoopType.body,
      'bodySm': LoopType.bodySm,
      'caption': LoopType.caption,
      'captionSm': LoopType.captionSm,
      'action': LoopType.action,
      'label': LoopType.label,
    };
    body.forEach((name, style) {
      expect(style.fontFamily, LoopFonts.body, reason: name);
      expect(style.fontFamilyFallback!.first, LoopFonts.cjk, reason: name);
      expect(style.letterSpacing, 0, reason: name);
      expect(
        style.leadingDistribution,
        TextLeadingDistribution.even,
        reason: name,
      );
      expect(style.fontSize, greaterThanOrEqualTo(11), reason: name);
      expect(style.fontFeatures, isNull, reason: name);
    });
    expect(LoopType.body.height, 1.7);
    expect(LoopType.action.fontSize, 13);
    expect(LoopType.action.fontWeight, FontWeight.w800);
    expect(LoopType.title.fontWeight, FontWeight.w700);

    // Kicker / eyebrow: 800, +0.15em (uppercased by the widget).
    expect(LoopType.kicker.fontSize, 11);
    expect(LoopType.kicker.fontWeight, FontWeight.w800);
    expect(LoopType.kicker.letterSpacing, closeTo(1.65, 0.001));
    expect(LoopType.eyebrow.fontSize, 12);
    expect(LoopType.caps('loop 星夜'), 'LOOP 星夜');

    for (final MapEntry<String, TextStyle> entry in <String, TextStyle>{
      'figureXl': LoopType.figureXl,
      'figureLg': LoopType.figureLg,
      'figureMd': LoopType.figureMd,
      'figure': LoopType.figure,
      'figureSm': LoopType.figureSm,
      'figureXs': LoopType.figureXs,
    }.entries) {
      expect(entry.value.fontFamily, LoopFonts.body, reason: entry.key);
      expect(
        entry.value.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: entry.key,
      );
      expect(entry.value.fontSize, greaterThanOrEqualTo(11), reason: entry.key);
      expect(entry.value.fontSize, lessThanOrEqualTo(28), reason: entry.key);
    }
    expect(LoopType.figureSm.fontWeight, FontWeight.w400);
    expect(LoopType.figureXs.fontWeight, FontWeight.w400);
    expect(LoopType.monoTitle, LoopType.figureLg);
    expect(LoopType.monoStamp, LoopType.figureXs);

    // Restating a weight moves a body step; an Anton step has one weight.
    final bold = LoopTypography.withWeight(LoopType.body, FontWeight.w700);
    expect(bold.fontWeight, FontWeight.w700);
    expect(bold.fontSize, LoopType.body.fontSize);
    expect(
      LoopTypography.withWeight(LoopType.headingLg, FontWeight.w700),
      same(LoopType.headingLg),
    );
  });

  test('the shipped font assets are registered with their licences', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Anton'));
    expect(pubspec, contains('family: Arimo'));
    expect(pubspec, contains('family: Noto Sans SC Display'));
    expect(pubspec, contains('family: Noto Sans SC'));
    expect(pubspec, contains('family: IBM Plex Mono'));
    expect(pubspec, isNot(contains('family: Sora')));
    expect(File('assets/fonts/Sora-Variable.ttf').existsSync(), isFalse);
    for (final asset in <String>[
      'assets/fonts/Anton-Regular.ttf',
      'assets/fonts/OFL-Anton.txt',
      'assets/fonts/Arimo-Regular.ttf',
      'assets/fonts/Arimo-Bold.ttf',
      'assets/fonts/OFL-Arimo.txt',
      'assets/fonts/NotoSansSC-Regular.ttf',
      'assets/fonts/NotoSansSC-Medium.ttf',
      'assets/fonts/NotoSansSC-Bold.ttf',
      'assets/fonts/IBMPlexMono-Regular.ttf',
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  test('buttons and sheets take the token sizes and veil', () {
    final theme = LoopTheme.dark;
    final filled = theme.filledButtonTheme.style!;
    expect(
      filled.minimumSize!.resolve(<WidgetState>{})!.height,
      LoopTouch.primaryButton,
    );
    expect(filled.backgroundColor!.resolve(<WidgetState>{}), LoopColors.yellow);
    expect(
      theme.iconButtonTheme.style!.minimumSize!.resolve(<WidgetState>{}),
      const Size.square(LoopTouch.minimum),
    );
    expect(theme.bottomSheetTheme.modalBarrierColor, LoopColors.veil);
    // Decision 0085: the push is the platform's own, because the iOS
    // edge-swipe-back lives inside the Cupertino builder.
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.macOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
  });
}

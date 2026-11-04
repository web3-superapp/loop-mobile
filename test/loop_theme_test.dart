import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

void main() {
  test('colour tokens are the Figma palette (decision 0277)', () {
    // docs/58 §9.3: the ground, three greys, Yellow, Purple.
    expect(LoopColors.ink, const Color(0xFF070809));
    expect(LoopColors.bg, LoopColors.ink);
    expect(LoopColors.chalk, const Color(0xFFF4F5F7));
    expect(LoopColors.textPrimary, LoopColors.chalk);
    expect(LoopColors.text2, const Color(0xFFA2A4AD));
    expect(LoopColors.textSecondary, LoopColors.text2);
    expect(LoopColors.text3, const Color(0xFF6F717A));
    expect(LoopColors.textTertiary, LoopColors.text3);
    expect(LoopColors.yellow, const Color(0xFFFFD21C));
    expect(LoopColors.onYellow, const Color(0xFF090A0C));
    expect(LoopColors.purple, const Color(0xFFA62EFF));
    expect(LoopColors.podiumGlow, const Color(0xFF8E22FF));
    expect(LoopColors.yellowSoft, const Color(0xFF30280C));
    expect(LoopColors.tagGreen, const Color(0xFF1AD68C));
    expect(LoopColors.tagGreenBg, const Color(0xFF053324));
    expect(LoopColors.tagPurple, const Color(0xFFC957FF));
    expect(LoopColors.tagPurpleBg, const Color(0xFF290A3B));
    expect(LoopColors.bronze, const Color(0xFFCD8032));
    expect(LoopColors.copper, LoopColors.bronze);
    // Grounds and lines (docs/58 §1.2): white at 3 / 4 / 5 / 8 / 10 / 15 %.
    expect(LoopColors.white3, const Color(0x08FFFFFF));
    expect(LoopColors.white4, const Color(0x0AFFFFFF));
    expect(LoopColors.white5, const Color(0x0DFFFFFF));
    expect(LoopColors.white8, const Color(0x14FFFFFF));
    expect(LoopColors.white10, const Color(0x1AFFFFFF));
    expect(LoopColors.white15, const Color(0x26FFFFFF));
    expect(LoopColors.divider, LoopColors.white5);
    expect(LoopColors.line, LoopColors.divider);
    expect(LoopColors.chipIdle, LoopColors.white4);
    expect(LoopColors.chipActive, LoopColors.white10);
    expect(LoopColors.navEdge, const Color(0xFF34353B));
    expect(LoopColors.cardEdge, const Color(0xFF1D1F24));
    expect(LoopColors.line2, LoopColors.cardEdge);
    expect(LoopColors.dividerSolid, const Color(0xFF24262C));
    expect(LoopColors.surfaceElevated, const Color(0xFF1A1B20));
    expect(LoopColors.cardInset, const Color(0xFF0B0C0F));
    expect(LoopColors.card, const Color(0xFF121318));
    expect(LoopColors.plate, LoopColors.card);
    expect(LoopColors.searchBg, const Color(0xFF0E0F12));
    expect(LoopColors.progressTrack, const Color(0xFF22232A));
    expect(LoopColors.progressFill, const Color(0xCCFFFFFF));
    expect(LoopColors.powerCardGradient.colors, const <Color>[
      Color(0xFF14151A),
      Color(0xFF1B1028),
    ]);
    expect(LoopColors.graphite, const Color(0xFF111214));
    expect(LoopColors.card2, LoopColors.plateRaised);
    expect(LoopColors.input, LoopColors.plateRaised);
    // A selection is white now: a white word on white 10 %.
    expect(LoopColors.purpleSelected, LoopColors.chipActive);
    expect(LoopColors.onPurple, const Color(0xFFFFFFFF));
    expect(LoopColors.warning, const Color(0xFFFF9F1C));
    // Price movement keeps its own two hues.
    expect(LoopColors.rise, const Color(0xFF22C982));
    expect(LoopColors.riseSoft, const Color(0xFF123025));
    expect(LoopColors.fall, const Color(0xFFEF4444));
    // The retired Lime names are the Yellow tokens.
    expect(LoopColors.lime, LoopColors.yellow);
    expect(LoopColors.limeSoft, LoopColors.yellowSoft);
    expect(LoopColors.limeHighlight, LoopColors.yellowHighlight);
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
    expect(scheme.outline, LoopColors.divider);
    expect(scheme.onPrimary, LoopColors.onYellow);
  });

  test('spacing, radius, depth, z and touch tokens are complete', () {
    expect(LoopSpacing.tight, 8);
    // Decision 0277 (docs/58 §9.4): page 20, 24 from a card to a section
    // heading and 12 under it, 16 from a banner, 12 between blocks.
    expect(LoopSpacing.card, 16);
    expect(LoopSpacing.group, 24);
    expect(LoopSpacing.section, 24);
    expect(LoopSpacing.sectionTop, 24);
    expect(LoopSpacing.sectionBottom, 12);
    expect(LoopSpacing.headingGap, 12);
    expect(LoopSpacing.page, 20);
    expect(LoopSpacing.rowGap, 12);
    expect(LoopSpacing.rowMin, 72);
    expect(LoopSpacing.rowMinWithSub, 80);
    expect(LoopSpacing.bannerGap, 16);
    expect(LoopSpacing.segmentGap, 16);
    expect(LoopSpacing.chipGap, 12);
    expect(LoopSpacing.chipSpacing, 8);

    // Decision 0277: the Figma's corners.
    expect(LoopRadius.shellValue, 20);
    expect(LoopRadius.tabBarValue, 12);
    expect(LoopRadius.cardValue, 12);
    expect(LoopRadius.bubbleValue, 16);
    expect(LoopRadius.controlValue, 12);
    expect(LoopRadius.buttonValue, 8);
    expect(LoopRadius.toolValue, 8);
    expect(LoopRadius.wideButtonValue, 8);
    expect(LoopRadius.innerValue, 10);
    expect(LoopRadius.tileValue, 10);
    expect(LoopRadius.badgeValue, 6);
    expect(LoopRadius.chipValue, 8);
    expect(LoopRadius.tagValue, 5);
    expect(LoopRadius.stageValue, 4);
    expect(LoopRadius.countValue, 2);
    expect(LoopRadius.compactButtonValue, 6);
    expect(LoopRadius.card, const BorderRadius.all(Radius.circular(12)));
    expect(
      LoopRadius.sheetTop,
      const BorderRadius.vertical(top: Radius.circular(20)),
    );
    // A capsule is an 8 rectangle; what is round says so.
    expect(LoopRadius.pill, const BorderRadius.all(Radius.circular(8)));
    expect(LoopRadius.round, const BorderRadius.all(Radius.circular(999)));
    expect(LoopRadius.pillRound, LoopRadius.round);

    // Flat, except the two floating layers: `0 8 20 rgba(0,0,0,.38)`.
    expect(LoopDepth.liftPrimary, isEmpty);
    expect(LoopDepth.liftPrimaryLight, isEmpty);
    expect(LoopDepth.liftCard, isEmpty);
    expect(LoopDepth.liftInner, isEmpty);
    final lift = LoopDepth.tabBar.single;
    expect(lift.blurRadius, 20);
    expect(lift.offset, const Offset(0, 8));
    expect(lift.color.a, closeTo(0.38, 0.004));
    expect(LoopDepth.ticker, LoopDepth.tabBar);
    expect(LoopDepth.tabBarEdge, LoopColors.navEdge);
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
    expect(LoopTouch.primaryButton, 48);
    expect(LoopTouch.tabBarHeight, 68);
    expect(LoopTouch.chipHeight, 32);
    expect(LoopTouch.chipMinWidth, 54);
    expect(LoopTouch.buttonCompact, 30);
    expect(LoopTouch.buttonMedium, 36);
    expect(LoopTouch.buttonJoin, 28);
    expect(LoopTouch.searchField, 44);
    expect(LoopLayout.tabBarInset, 24);
    expect(LoopLayout.tabBarSideInset, 20);
    expect(LoopLayout.tabPageBottomReserve, 92);
    expect(LoopLayout.childPageBottomMinimum, 24);
    expect(LoopLayout.designBaseline, const Size(390, 844));
  });

  test(
    'every step is Inter with Noto Sans SC behind it, figures are tabular',
    () {
      final text = LoopTheme.dark.textTheme;
      final title = text.headlineLarge!;
      // Decision 0277: a page title is Inter 700 with Noto Sans SC behind
      // it, in sentence case and untracked.
      expect(title.fontFamily, 'Inter');
      // Decision 0229: title1, 28.
      expect(title.fontSize, 28);
      expect(title.fontWeight, FontWeight.w700);
      expect(title.letterSpacing, 0);
      expect(title.fontFamilyFallback!.first, LoopFonts.cjk);

      expect(text.displayMedium!.fontSize, 28);
      expect(text.bodyLarge, same(LoopType.bodyLg));
      expect(text.bodyLarge!.fontFamily, 'Inter');
      // bodyMedium is bodySm: body2Sm 14 / 22 in textSecondary.
      expect(text.bodyMedium!.fontSize, 14);
      expect(text.bodyMedium!.height, closeTo(22 / 14, 0.001));

      for (final figure in <TextStyle>[
        LoopMono.display,
        LoopMono.headline,
        LoopMono.value,
        LoopMono.body,
        LoopMono.stamp,
      ]) {
        expect(figure.fontFamily, LoopFonts.body);
        expect(
          figure.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(figure.fontFamilyFallback!.first, LoopFonts.cjk);
      }
      expect(LoopMono.display.fontSize, 28);

      // Decision 0277: an address or a link is Inter 400 (the Figma's
      // wallet address 14 / 400, invite link 13 / 400); IBM Plex Mono stays
      // registered for a real code block.
      expect(LoopMono.address.fontFamily, LoopFonts.sans);
      expect(LoopType.code.fontFamily, LoopFonts.sans);
      expect(LoopType.code.fontWeight, FontWeight.w400);
      expect(LoopType.codeSm.fontFamily, LoopFonts.sans);
      expect(
        LoopType.code.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(LoopTypography.mono(size: 12).fontFamily, 'IBM Plex Mono');
    },
  );

  test('the seven bands are the whole vocabulary', () {
    // Decision 0277: Anton is gone — the big figures are Inter Bold.
    final big = <String, TextStyle>{
      'heroDisplay': LoopType.heroDisplay,
      'heroFigure': LoopType.heroFigure,
      'plateFigure': LoopType.plateFigure,
      'sectionIndex': LoopType.sectionIndex,
      'tabIndex': LoopType.tabIndex,
    };
    for (final style in <TextStyle>[LoopType.statFigure, LoopType.keyFigure]) {
      expect(style.fontFamily, LoopFonts.body);
      expect(style.fontWeight, FontWeight.w700);
    }
    expect(LoopType.keyFigure.fontSize, 32);
    big.forEach((name, style) {
      expect(style.fontFamily, LoopFonts.sans, reason: name);
      expect(style.fontWeight, FontWeight.w700, reason: name);
      expect(style.fontFamilyFallback!.first, LoopFonts.cjk, reason: name);
      // Inter is never tracked out.
      expect(style.letterSpacing, lessThanOrEqualTo(0), reason: name);
      expect(style.height, inInclusiveRange(1.0, 1.25), reason: name);
    });
    final headings = <String, TextStyle>{
      'displayXl': LoopType.displayXl,
      'display': LoopType.display,
      'displaySm': LoopType.displaySm,
      'stepTitle': LoopType.stepTitle,
      'headingLg': LoopType.headingLg,
      'flatTitle': LoopType.flatTitle,
      'heading': LoopType.heading,
      'headingSm': LoopType.headingSm,
    };
    headings.forEach((name, style) {
      expect(style.fontFamily, LoopFonts.body, reason: name);
      expect(style.fontWeight, FontWeight.w700, reason: name);
      expect(style.fontFamilyFallback!.first, LoopFonts.cjk, reason: name);
      expect(style.letterSpacing, 0, reason: name);
      expect(style.fontSize, greaterThanOrEqualTo(17), reason: name);
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
      // Decision 0277: nothing on the ladder is under 10.
      expect(style.fontSize, greaterThanOrEqualTo(10), reason: name);
      expect(style.fontFeatures, isNull, reason: name);
    });
    // Decision 0277: prose 16 on 25, a button 16 / 600, a row title body1
    // 14 / 500, a row's second line 12 / 300.
    expect(LoopType.body.height, closeTo(25 / 16, 0.001));
    expect(LoopType.action.fontSize, 16);
    expect(LoopType.action.fontWeight, FontWeight.w600);
    expect(LoopType.title.fontSize, 14);
    expect(LoopType.title.fontWeight, FontWeight.w500);
    expect(LoopType.caption.fontSize, 12);
    expect(LoopType.caption.fontWeight, FontWeight.w300);

    // Kicker / eyebrow: 13 / 500 textSecondary, untracked, in its own case
    // (聊天's 「置顶 / 最近消息」).
    expect(LoopType.kicker.fontSize, 13);
    expect(LoopType.kicker.fontWeight, FontWeight.w500);
    expect(LoopType.kicker.letterSpacing, 0);
    expect(LoopType.eyebrow.fontSize, 13);
    expect(LoopType.caps('loop 星夜'), 'loop 星夜');

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
      expect(entry.value.fontSize, greaterThanOrEqualTo(13), reason: entry.key);
      expect(entry.value.fontSize, lessThanOrEqualTo(28), reason: entry.key);
    }
    // Decision 0277: figureSm 14 / 600, figureXs 13 / 600.
    expect(LoopType.figureSm.fontSize, 14);
    expect(LoopType.figureSm.fontWeight, FontWeight.w600);
    expect(LoopType.figureXs.fontSize, 13);
    expect(LoopType.figureXs.fontWeight, FontWeight.w600);
    expect(LoopType.monoTitle, LoopType.figureLg);
    expect(LoopType.monoStamp, LoopType.figureXs);

    // Restating a weight moves any step: Inter carries every weight.
    final bold = LoopTypography.withWeight(LoopType.body, FontWeight.w700);
    expect(bold.fontWeight, FontWeight.w700);
    expect(bold.fontSize, LoopType.body.fontSize);
    expect(
      LoopTypography.withWeight(
        LoopType.heroFigure,
        FontWeight.w600,
      ).fontWeight,
      FontWeight.w600,
    );
  });

  test('the Figma steps hold their documented values (docs/58 §9.2)', () {
    void step(
      TextStyle style,
      double size,
      FontWeight weight, {
      Color? color,
      double? height,
      String reason = '',
    }) {
      expect(style.fontFamily, LoopFonts.sans, reason: reason);
      expect(style.fontSize, size, reason: reason);
      expect(style.fontWeight, weight, reason: reason);
      if (color != null) expect(style.color, color, reason: reason);
      if (height != null) {
        expect(style.height, closeTo(height, 0.001), reason: reason);
      }
    }

    step(LoopType.title1, 28, FontWeight.w700, height: 1.2);
    step(
      LoopType.segmentTitleIdle,
      24,
      FontWeight.w600,
      color: LoopColors.textTertiary,
    );
    step(LoopType.plateFigure, 40, FontWeight.w700, height: 46 / 40);
    step(LoopType.heroFigure, 30, FontWeight.w700);
    step(LoopType.sectionIndex, 30, FontWeight.w700);
    step(LoopType.inviteCode, 23, FontWeight.w600, color: LoopColors.yellow);
    step(LoopType.headline, 19, FontWeight.w700);
    step(LoopType.headlineSm, 16, FontWeight.w700);
    step(LoopType.body1, 14, FontWeight.w500, height: 22 / 14);
    step(LoopType.rowTitleLg, 16, FontWeight.w500);
    step(LoopType.postAuthor, 18, FontWeight.w600);
    step(LoopType.figure, 16, FontWeight.w600, height: 23 / 16);
    step(LoopType.figureSm, 14, FontWeight.w600);
    step(LoopType.figureXs, 13, FontWeight.w600);
    step(LoopType.rankFigure, 16, FontWeight.w900);
    expect(LoopType.rankFigure.fontStyle, FontStyle.italic);
    step(LoopType.body2, 16, FontWeight.w400, height: 25 / 16);
    step(LoopType.body2Sm, 14, FontWeight.w400, height: 22 / 14);
    step(
      LoopType.caption,
      12,
      FontWeight.w300,
      color: LoopColors.textTertiary,
      height: 16 / 12,
    );
    step(
      LoopType.captionMd,
      14,
      FontWeight.w300,
      color: LoopColors.textSecondary,
    );
    step(LoopType.label, 14, FontWeight.w500, height: 20 / 14);
    step(LoopType.chip, 13, FontWeight.w600, color: LoopColors.textOnSelected);
    step(
      LoopType.chipIdle,
      13,
      FontWeight.w500,
      color: LoopColors.textSecondary,
    );
    step(LoopType.tab, 16, FontWeight.w600, color: LoopColors.textOnSelected);
    step(
      LoopType.tabIdle,
      16,
      FontWeight.w500,
      color: LoopColors.textSecondary,
    );
    step(LoopType.count, 11, FontWeight.w500);
    step(LoopType.navLabel, 12, FontWeight.w500, height: 16 / 12);
    step(LoopType.navLabelLatin, 11, FontWeight.w600, height: 15 / 11);
    step(LoopType.meta, 12, FontWeight.w500, color: LoopColors.textTertiary);
    step(LoopType.metaSm, 10, FontWeight.w400);
    step(LoopType.tag, 12, FontWeight.w600);
    step(LoopType.stageTag, 11, FontWeight.w400, color: LoopColors.yellow);
    step(LoopType.buyTag, 10, FontWeight.w600, color: LoopColors.rise);
    step(LoopType.unreadCount, 10, FontWeight.w700, color: LoopColors.onYellow);
    step(LoopType.progress, 10, FontWeight.w300);
    step(LoopType.button, 16, FontWeight.w600);
    step(LoopType.buttonSm, 13, FontWeight.w600);
    step(LoopType.buttonXs, 12, FontWeight.w600, color: LoopColors.yellow);
    step(LoopType.emptyTitle, 17, FontWeight.w700, height: 24 / 17);
    step(LoopType.code, 14, FontWeight.w400);
    step(LoopType.codeSm, 13, FontWeight.w400);
  });

  test('the shipped font assets are registered with their licences', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // Decision 0277: Inter replaces Anton, Arimo and the Noto Sans SC
    // Display face that sat behind Anton.
    expect(pubspec, contains('family: Inter'));
    expect(pubspec, isNot(contains('family: Anton')));
    expect(pubspec, isNot(contains('family: Arimo')));
    expect(pubspec, isNot(contains('family: Noto Sans SC Display')));
    expect(pubspec, contains('family: Noto Sans SC'));
    expect(pubspec, contains('family: IBM Plex Mono'));
    expect(pubspec, isNot(contains('family: Sora')));
    expect(File('assets/fonts/Sora-Variable.ttf').existsSync(), isFalse);
    for (final retired in <String>[
      'assets/fonts/Anton-Regular.ttf',
      'assets/fonts/Arimo-Regular.ttf',
      'assets/fonts/Arimo-Bold.ttf',
    ]) {
      expect(File(retired).existsSync(), isFalse, reason: retired);
    }
    for (final asset in <String>[
      'assets/fonts/Inter-Light.ttf',
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
      'assets/fonts/Inter-BlackItalic.ttf',
      'assets/fonts/OFL-Inter.txt',
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

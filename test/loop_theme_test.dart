import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

void main() {
  test('colour tokens match the 01 handover chapter 4.1 values', () {
    expect(LoopColors.ink, const Color(0xFF050604));
    expect(LoopColors.lime, const Color(0xFFB8FF20));
    expect(LoopColors.chalk, const Color(0xFFF3F5EF));
    expect(LoopColors.graphite, const Color(0xFF171A16));
    expect(LoopColors.muted, const Color(0xFF7F897B));

    Color chalkAt(double alpha) => LoopColors.chalk.withValues(alpha: alpha);
    expect(LoopColors.panel.a, closeTo(0.055, 0.004));
    expect(LoopColors.card.a, closeTo(0.06, 0.004));
    expect(LoopColors.card2.a, closeTo(0.10, 0.004));
    expect(LoopColors.line.a, closeTo(0.13, 0.004));
    expect(LoopColors.line2.a, closeTo(0.22, 0.004));
    expect(LoopColors.text2.a, closeTo(0.68, 0.004));
    expect(LoopColors.text3.a, closeTo(0.58, 0.004));
    expect(LoopColors.limeSoft.a, closeTo(0.13, 0.004));
    expect(LoopColors.veil.a, closeTo(0.76, 0.004));
    expect(LoopColors.inkMuted.a, closeTo(0.62, 0.004));
    for (final token in <Color>[
      LoopColors.panel,
      LoopColors.card,
      LoopColors.card2,
      LoopColors.line,
      LoopColors.line2,
      LoopColors.text2,
      LoopColors.text3,
    ]) {
      expect(token.withValues(alpha: 1), chalkAt(1));
    }
    expect(LoopColors.limeSoft.withValues(alpha: 1), LoopColors.lime);
  });

  test('legacy market/chat accents gain no new consumers in lib/', () {
    // The blue/amber aliases are unmigrated history. This guard records the
    // files that still use them; the list may only shrink. Remove the guard
    // together with the aliases when the Market slice migrates.
    const legacyAccentConsumers = <String>{
      'lib/features/chat/calls/stream_foreground_call_view.dart',
      'lib/features/chat/calls/stream_voice_room_page.dart',
      'lib/features/chat/chat_inbox_page.dart',
      'lib/features/chat/chat_secondary_pages.dart',
      'lib/features/chat/conversation_pages.dart',
      'lib/features/chat/friends/chat_create_menu_button.dart',
      'lib/features/chat/stream_chat_inbox_page.dart',
      'lib/features/chat/voice_room_page.dart',
      'lib/features/chat/widgets/chat_components.dart',
      'lib/features/chat/widgets/token_card_view.dart',
      'lib/features/home/home_screens.dart',
      'lib/features/launchpad/launchpad_screen.dart',
      'lib/features/perp/perp_account_screens.dart',
      'lib/features/perp/perp_models.dart',
      'lib/features/profile/profile_screens.dart',
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
    expect(scheme.primary, LoopColors.lime);
    expect(scheme.secondary, LoopColors.chalk);
    expect(scheme.tertiary, LoopColors.lime);
    expect(scheme.surface, LoopColors.graphite);
    expect(scheme.outline, LoopColors.line);
  });

  test('spacing, radius, depth, z and touch tokens are complete', () {
    expect(LoopSpacing.tight, 8);
    expect(LoopSpacing.card, 14);
    expect(LoopSpacing.group, 22);
    expect(LoopSpacing.section, 30);
    expect(LoopSpacing.page, 16);

    expect(LoopRadius.shellValue, 24);
    expect(LoopRadius.cardValue, 20);
    expect(LoopRadius.controlValue, 16);
    expect(LoopRadius.innerValue, 12);
    expect(LoopRadius.tabBarValue, 23);

    expect(LoopDepth.liftPrimary, hasLength(2));
    expect(LoopDepth.liftPrimary.first.blurRadius, 48);
    expect(LoopDepth.liftPrimaryLight, hasLength(2));
    expect(LoopDepth.liftCard, hasLength(1));
    expect(LoopDepth.liftInner, isEmpty);
    expect(LoopDepth.tabBar, hasLength(2));

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
    expect(LoopTouch.primaryButton, 53);
    expect(LoopTouch.tabBarHeight, 70);
    expect(LoopLayout.tabPageBottomReserve, 90);
    expect(LoopLayout.childPageBottomMinimum, 24);
    expect(LoopLayout.designBaseline, const Size(390, 844));
  });

  test('the text theme is the platform sans; figures are tabular', () {
    final text = LoopTheme.dark.textTheme;
    final title = text.headlineLarge!;
    // 22 semibold, the display optical cut, no tracking (decision 0080).
    expect(title.fontFamily, LoopFonts.systemDisplay);
    expect(title.fontSize, 22);
    expect(title.fontWeight, FontWeight.w600);
    expect(title.letterSpacing, 0);
    expect(title.fontVariations, isNull);
    expect(title.fontFamilyFallback, contains('Noto Sans SC'));
    expect(title.fontFamilyFallback!.first, LoopFonts.android);

    expect(text.displayMedium!.fontSize, 26);
    expect(text.bodyLarge!.fontSize, 14);
    expect(text.bodyLarge!.fontWeight, FontWeight.w400);
    expect(text.bodyMedium!.fontSize, 13);
    expect(text.bodyMedium!.height, 1.4);

    // Every figure step is the page's own sans with equal digit advances, so
    // a right-aligned price column lines up without a second voice.
    for (final figure in <TextStyle>[
      LoopMono.display,
      LoopMono.headline,
      LoopMono.value,
      LoopMono.body,
      LoopMono.stamp,
    ]) {
      expect(figure.fontFamily, LoopFonts.familyFor(figure.fontSize!));
      expect(figure.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(figure.fontFamilyFallback, contains('Noto Sans SC'));
    }
    expect(LoopMono.display.fontSize, 28);

    // Fixed width survives for one job: addresses, hashes, code.
    expect(LoopMono.address.fontFamily, LoopFonts.mono);
    expect(LoopType.code.fontFamily, LoopFonts.mono);
    expect(LoopType.codeSm.fontFamily, LoopFonts.mono);
    expect(LoopTypography.mono(size: 12).fontFamily, 'IBM Plex Mono');
  });

  test('the seven bands are the whole vocabulary', () {
    // Bands 1-6 are the platform's own UI sans: SF Pro through the engine's
    // Cupertino aliases, Roboto at the head of the fallback chain, and
    // Chinese from PingFang SC or the bundled Noto Sans SC.
    final proportional = <String, TextStyle>{
      'displayXl': LoopType.displayXl,
      'display': LoopType.display,
      'displaySm': LoopType.displaySm,
      'headingLg': LoopType.headingLg,
      'heading': LoopType.heading,
      'headingSm': LoopType.headingSm,
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
      'eyebrow': LoopType.eyebrow,
    };
    proportional.forEach((name, style) {
      expect(
        style.fontFamily,
        LoopFonts.familyFor(style.fontSize!),
        reason: name,
      );
      expect(style.fontFamilyFallback?.first, LoopFonts.android, reason: name);
      expect(style.fontFamilyFallback, contains(LoopFonts.cjk), reason: name);
      // Nothing carries a variation axis any more: the system face instances
      // itself and the bundled Noto Sans SC statics are matched by weight.
      expect(style.fontVariations, isNull, reason: name);
      // Hierarchy is weight and grey, not tracking — and the 0 is written,
      // not left null, so Material's own tracking cannot leak into a merge.
      expect(style.letterSpacing, 0, reason: name);
      expect(
        style.leadingDistribution,
        TextLeadingDistribution.even,
        reason: name,
      );
      // The ladder spans 11 to 28: nothing under the prototype's 11px screen
      // floor, nothing shouting above 28.
      expect(style.fontSize, greaterThanOrEqualTo(11), reason: name);
      expect(style.fontSize, lessThanOrEqualTo(28), reason: name);
      expect(style.height, inInclusiveRange(1.2, 1.4), reason: name);
      expect(style.fontFeatures, isNull, reason: name);
    });

    // The eyebrow is no longer an uppercase fixed-width Latin stamp.
    expect(LoopType.eyebrow.fontSize, 12);
    expect(LoopType.eyebrow.fontWeight, FontWeight.w500);
    expect(LoopType.eyebrow.color, LoopColors.text3);

    // Band 7 is the same voice with tabular figures; band 7b is the only
    // fixed-width one.
    for (final MapEntry<String, TextStyle> entry in <String, TextStyle>{
      'figureXl': LoopType.figureXl,
      'figureLg': LoopType.figureLg,
      'figureMd': LoopType.figureMd,
      'figure': LoopType.figure,
      'figureSm': LoopType.figureSm,
      'figureXs': LoopType.figureXs,
    }.entries) {
      expect(
        entry.value.fontFamily,
        LoopFonts.familyFor(entry.value.fontSize!),
        reason: entry.key,
      );
      expect(
        entry.value.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: entry.key,
      );
      expect(entry.value.fontSize, greaterThanOrEqualTo(11), reason: entry.key);
      expect(entry.value.fontSize, lessThanOrEqualTo(28), reason: entry.key);
    }
    // The `mono*` names the feature slices call are those steps.
    expect(LoopType.monoDisplay, LoopType.figureXl);
    expect(LoopType.monoTitle, LoopType.figureLg);
    expect(LoopType.monoQuote, LoopType.figureMd);
    expect(LoopType.monoValue, LoopType.figure);
    expect(LoopType.monoBody, LoopType.figureSm);
    expect(LoopType.monoStamp, LoopType.figureXs);

    // Restating a weight is still the only sanctioned way to move one.
    final bold = LoopTypography.withWeight(LoopType.body, FontWeight.w600);
    expect(bold.fontWeight, FontWeight.w600);
    expect(bold.fontSize, LoopType.body.fontSize);
  });

  test('the shipped font assets are the CJK face and the code face', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Noto Sans SC'));
    expect(pubspec, contains('family: IBM Plex Mono'));
    expect(pubspec, isNot(contains('family: Sora')));
    expect(File('assets/fonts/Sora-Variable.ttf').existsSync(), isFalse);
    for (final asset in <String>[
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
    expect(filled.backgroundColor!.resolve(<WidgetState>{}), LoopColors.lime);
    expect(
      theme.iconButtonTheme.style!.minimumSize!.resolve(<WidgetState>{}),
      const Size.square(LoopTouch.minimum),
    );
    expect(theme.bottomSheetTheme.modalBarrierColor, LoopColors.veil);
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<LoopPushTransitionsBuilder>(),
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<LoopPushTransitionsBuilder>(),
    );
  });
}

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

  test('text theme uses Sora with weights and IBM Plex Mono for figures', () {
    final text = LoopTheme.dark.textTheme;
    final title = text.headlineLarge!;
    expect(title.fontFamily, 'Sora');
    expect(title.fontSize, 24);
    expect(title.fontWeight, FontWeight.w800);
    expect(title.letterSpacing, lessThan(0));
    expect(title.fontVariations, contains(const FontVariation.weight(800)));
    expect(title.fontFamilyFallback, contains('Noto Sans SC'));

    expect(text.displayMedium!.fontSize, 32);
    expect(text.bodyMedium!.fontSize, 12);
    expect(text.bodyMedium!.height, 1.5);

    for (final mono in <TextStyle>[
      LoopMono.display,
      LoopMono.headline,
      LoopMono.value,
      LoopMono.body,
      LoopMono.label,
      LoopMono.stamp,
    ]) {
      expect(mono.fontFamily, 'IBM Plex Mono');
      expect(mono.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
    expect(LoopMono.display.fontSize, 32);
    expect(LoopTypography.mono(size: 12).fontFamily, 'IBM Plex Mono');
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

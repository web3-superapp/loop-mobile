import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_locale.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// 设置 · Language (decision 0281): the two languages LOOP ships, each named
/// in itself. A pick applies at once and closes the sheet.
Future<void> showLoopLanguageSheet(BuildContext context) => showLoopSheet<void>(
  context,
  barrierLabel: context.l10n.common_close,
  builder: (context) => const LoopLanguageSheet(),
);

class LoopLanguageSheet extends ConsumerWidget {
  const LoopLanguageSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(loopLocaleProvider);
    final locales = LoopL10n.supportedLocales;
    return Column(
      key: const ValueKey<String>('settings-language-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            8,
          ),
          child: Text(context.l10n.common_language, style: LoopType.headline),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
          child: LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (var index = 0; index < locales.length; index++)
                LoopRecordRow(
                  key: ValueKey<String>(
                    'settings-language-${LoopL10n.tagOf(locales[index])}',
                  ),
                  title: LoopL10n.nativeName(locales[index]),
                  selected: locales[index] == current,
                  position: locales.length == 1
                      ? LoopRowPosition.single
                      : index == 0
                      ? LoopRowPosition.first
                      : index == locales.length - 1
                      ? LoopRowPosition.last
                      : LoopRowPosition.middle,
                  onTap: () {
                    unawaited(
                      ref
                          .read(loopLocaleProvider.notifier)
                          .setLocale(locales[index]),
                    );
                    Navigator.of(context).maybePop();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

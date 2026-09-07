import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

Future<void> _pump(WidgetTester tester, Widget child, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('LoopTopbar renders a 44px back button and a 24/800 title', (
    tester,
  ) async {
    var backs = 0;
    await _pump(
      tester,
      LoopTopbar(
        title: '无网络',
        kicker: 'SYSTEM',
        onBack: () => backs += 1,
        actions: <Widget>[
          LoopIconButton(icon: 'search', label: '搜索', onPressed: () {}),
        ],
      ),
    );
    final back = find.byKey(const ValueKey<String>('loop-topbar-back'));
    expect(tester.getSize(back), const Size(44, 44));
    await tester.tap(back);
    expect(backs, 1);
    final title = tester.widget<Text>(find.text('无网络'));
    expect(title.style?.fontSize, 24);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(find.text('SYSTEM'), findsOneWidget);
    expect(find.bySemanticsLabel('搜索'), findsOneWidget);
  });

  testWidgets('LoopFolioPrimary variants use Lime / quiet / Chalk grounds', (
    tester,
  ) async {
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          LoopFolioPrimary(
            kicker: 'LAST SYNC',
            heading: '当前设备离线',
            caption: '缓存仍可查看。',
            stamp: 'OFFLINE',
            archetype: LoopFolioArchetype.state,
          ),
          LoopFolioPrimary(heading: 'Lime', variant: LoopFolioVariant.lime),
          LoopFolioPrimary(heading: 'Chalk', variant: LoopFolioVariant.chalk),
        ],
      ),
      size: const Size(390, 1200),
    );
    final folios = tester
        .widgetList<Container>(
          find.byKey(const ValueKey<String>('loop-folio-primary')),
        )
        .toList();
    expect(folios, hasLength(3));
    final quiet = folios[0].decoration! as BoxDecoration;
    expect(quiet.border, isNotNull);
    expect(quiet.boxShadow, LoopDepth.liftPrimary);
    expect((folios[1].decoration! as BoxDecoration).color, LoopColors.lime);
    expect((folios[2].decoration! as BoxDecoration).color, LoopColors.chalk);
    expect(
      tester.getSize(find.byWidget(folios[0])).height,
      greaterThanOrEqualTo(LoopFolioArchetype.state.minHeight),
    );
    final heading = tester.widget<Text>(find.text('当前设备离线'));
    expect(heading.style?.color, LoopColors.lime);
    expect(heading.style?.fontSize, 29);
    expect(find.text('LAST SYNC'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
    final limeHeading = tester.widget<Text>(find.text('Lime'));
    expect(limeHeading.style?.color, LoopColors.ink);
  });

  testWidgets('cards map to their CSS grounds and depth', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      Column(
        children: <Widget>[
          const LoopLedgerCard(child: Text('ledger')),
          const LoopLedgerCard(quiet: true, child: Text('quiet')),
          LoopChalkCard(
            onTap: () => taps += 1,
            semanticLabel: '打开',
            child: const Text('chalk'),
          ),
          const LoopSurfaceCard(child: Text('card')),
          const LoopRecordCard(child: Text('record')),
        ],
      ),
      size: const Size(390, 1200),
    );
    DecoratedBox boxOf(String text) => tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text(text), matching: find.byType(DecoratedBox))
          .first,
    );
    final ledger = boxOf('ledger').decoration as BoxDecoration;
    expect(ledger.color, LoopColors.lime);
    expect(ledger.borderRadius, LoopRadius.shell);
    expect(ledger.boxShadow, LoopDepth.liftPrimaryLight);
    final quiet = boxOf('quiet').decoration as BoxDecoration;
    expect(quiet.boxShadow, LoopDepth.liftPrimary);
    expect(quiet.border, isNotNull);
    final chalk = boxOf('chalk').decoration as BoxDecoration;
    expect(chalk.color, LoopColors.chalk);
    expect(chalk.borderRadius, LoopRadius.card);
    final card = boxOf('card').decoration as BoxDecoration;
    expect(card.color, LoopColors.card);
    expect(card.boxShadow, LoopDepth.liftCard);
    expect(
      tester.widget<Text>(find.text('ledger')).style?.color ??
          DefaultTextStyle.of(tester.element(find.text('ledger'))).style.color,
      isNotNull,
    );
    expect(
      DefaultTextStyle.of(tester.element(find.text('chalk'))).style.color,
      LoopColors.ink,
    );
    expect(
      DefaultTextStyle.of(tester.element(find.text('quiet'))).style.color,
      LoopColors.chalk,
    );
    await tester.tap(find.text('chalk'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('打开'), findsOneWidget);
  });

  testWidgets('LoopRecordGroup assigns first/middle/last radii and taps', (
    tester,
  ) async {
    var opened = '';
    await _pump(
      tester,
      LoopRecordGroup(
        rows: <LoopRecordRow>[
          LoopRecordRow(
            title: 'PEPE',
            subtitle: '128,420 成员',
            trailing: '\$0.0000082',
            trailingCaption: '+4.8%',
            trailingCaptionUp: true,
            onTap: () => opened = 'PEPE',
            leading: const LoopTokenLogo(assetSymbol: 'PEPE', size: 40),
          ),
          const LoopRecordRow(title: 'Middle', trailing: '—'),
          const LoopRecordRow(
            title: 'Last',
            trailingCaption: '-1.2%',
            trailingCaptionUp: false,
          ),
        ],
      ),
      size: const Size(390, 844),
    );
    final rows = tester
        .widgetList<LoopRecordRow>(find.byType(LoopRecordRow))
        .toList();
    expect(rows.map((row) => row.position), <LoopRowPosition>[
      LoopRowPosition.first,
      LoopRowPosition.middle,
      LoopRowPosition.last,
    ]);
    expect(
      tester.getSize(find.byType(LoopRecordRow).first).height,
      greaterThanOrEqualTo(LoopTouch.minimum),
    );
    final up = tester.widget<Text>(find.text('+4.8%'));
    expect(up.style?.color, LoopColors.lime);
    expect(up.style?.fontFamily, LoopFonts.mono);
    final down = tester.widget<Text>(find.text('-1.2%'));
    expect(down.style?.color, LoopColors.chalk);
    await tester.tap(find.text('PEPE'));
    expect(opened, 'PEPE');
    expect(find.byType(LoopIcon), findsWidgets);
  });

  testWidgets('LoopNotice tones and the structured three-part risk notice', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          LoopNotice(title: '为什么区分这两种', body: '完全断网时所有操作都要拦。'),
          LoopNotice(
            tone: LoopNoticeTone.warn,
            icon: 'warn',
            title: 'BSC 网络暂时不可用',
            body: '其他链正常。',
          ),
          LoopNotice(
            tone: LoopNoticeTone.danger,
            icon: 'offline',
            title: '完全离线',
            body: '检查 Wi-Fi 或蜂窝数据。',
          ),
          LoopNotice.structured(
            title: '风险事实',
            happened: '合约含 mint 函数',
            impact: '发行方可增发',
            next: '确认事实后再买入',
            tone: LoopNoticeTone.danger,
          ),
        ],
      ),
      size: const Size(390, 1000),
    );
    BoxDecoration deco(String key) =>
        tester
                .widget<Container>(find.byKey(ValueKey<String>(key)).first)
                .decoration!
            as BoxDecoration;
    expect(deco('loop-notice-normal').color, LoopColors.card);
    expect(deco('loop-notice-warn').color, LoopColors.limeSoft);
    expect(deco('loop-notice-danger').color, LoopColors.card2);
    expect(find.textContaining('发生了什么'), findsOneWidget);
    expect(find.textContaining('影响什么'), findsOneWidget);
    expect(find.textContaining('下一步'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('风险事实.*发生了什么：合约含 mint 函数.*影响什么：发行方可增发.*下一步：确认事实后再买入'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('LoopBadge kinds and LoopSeg selection', (tester) async {
    var selected = 0;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Column(
          children: <Widget>[
            const Row(
              children: <Widget>[
                LoopBadge('GRADUATED', kind: LoopBadgeKind.launch),
                LoopBadge('MUTED'),
                LoopBadge('ON LEDGER', onLedger: true),
              ],
            ),
            LoopSegBar(
              labels: const <String>['全部', '社区', '资产'],
              selectedIndex: selected,
              onSelected: (index) => setState(() => selected = index),
            ),
          ],
        ),
      ),
      size: const Size(390, 844),
    );
    Color badgeGround(String text) =>
        (tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: find.text(text),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    expect(badgeGround('GRADUATED'), LoopColors.limeSoft);
    expect(badgeGround('MUTED'), LoopColors.card2);
    expect(
      tester.widget<Text>(find.text('GRADUATED')).style?.color,
      LoopColors.lime,
    );
    expect(
      tester.widget<Text>(find.text('ON LEDGER')).style?.color,
      LoopColors.ink,
    );

    final segs = tester.widgetList<LoopSeg>(find.byType(LoopSeg)).toList();
    expect(segs.map((seg) => seg.selected), <bool>[true, false, false]);
    expect(
      tester.getSize(find.byType(LoopSeg).first).height,
      greaterThanOrEqualTo(LoopTouch.minimum),
    );
    final selectedMaterial = tester.widget<Material>(
      find.ancestor(of: find.text('全部'), matching: find.byType(Material)).first,
    );
    expect(selectedMaterial.color, LoopColors.lime);
    await tester.tap(find.text('资产'));
    await tester.pump();
    expect(selected, 2);
  });

  testWidgets('LoopButton primary/secondary sizes, disabled semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var pressed = 0;
    await _pump(
      tester,
      Column(
        children: <Widget>[
          LoopButtonPair(
            children: <Widget>[
              const LoopButton(label: '取消'),
              LoopButton(
                label: '确认',
                primary: true,
                onPressed: () => pressed += 1,
              ),
            ],
          ),
          LoopButton(label: '前往系统设置', block: true, onPressed: () {}),
        ],
      ),
      size: const Size(390, 844),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('loop-button-primary')))
          .height,
      greaterThanOrEqualTo(LoopTouch.primaryButton),
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('loop-button-secondary')).first,
          )
          .height,
      greaterThanOrEqualTo(LoopTouch.primaryButton),
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('loop-button-secondary')).last,
          )
          .width,
      390,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('取消')),
      matchesSemantics(
        label: '取消',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('确认')),
      matchesSemantics(
        label: '确认',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    await tester.tap(find.text('确认'));
    expect(pressed, 1);
    final disabled = tester.widget<Opacity>(
      find.ancestor(of: find.text('取消'), matching: find.byType(Opacity)).first,
    );
    expect(disabled.opacity, 0.4);
    semantics.dispose();
  });

  testWidgets('LoopComposer keeps input and send reachable and fails closed', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'gm');
    addTearDown(controller.dispose);
    String? sent;
    await _pump(
      tester,
      Column(
        children: <Widget>[
          LoopComposer(controller: controller, onSend: (value) => sent = value),
          const LoopComposer(),
        ],
      ),
      size: const Size(390, 844),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('loop-composer-send')).first,
      ),
      const Size(44, 44),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('loop-composer-send')).first,
    );
    expect(sent, 'gm');
    final disabledField = tester.widget<TextField>(find.byType(TextField).last);
    expect(disabledField.enabled, isFalse);
  });

  testWidgets('LoopPowerHint states and LoopKeyValue mono alignment', (
    tester,
  ) async {
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          LoopPowerHint(text: '买入后计入算力', figure: '+0.35×'),
          LoopPowerHint(text: '未加入社区，无算力', state: LoopPowerHintState.none),
          LoopPowerHint(text: '权重待审核', state: LoopPowerHintState.pending),
          LoopKeyValue(label: '操作', value: 'Swap'),
          LoopKeyValue(label: '模拟结果', value: '失败 · 无法预演', valueUp: false),
        ],
      ),
      size: const Size(390, 844),
    );
    final hints = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(LoopPowerHint),
            matching: find.byType(Container),
          ),
        )
        .where((c) => c.decoration is BoxDecoration)
        .toList();
    expect((hints[0].decoration! as BoxDecoration).color, LoopColors.limeSoft);
    expect((hints[1].decoration! as BoxDecoration).color, LoopColors.card);
    expect((hints[2].decoration! as BoxDecoration).color, LoopColors.card);
    expect(
      tester.getSize(find.byType(LoopPowerHint).first).height,
      greaterThanOrEqualTo(LoopTouch.minimum),
    );
    final value = tester.widget<Text>(find.text('Swap'));
    expect(value.style?.fontFamily, LoopFonts.mono);
    expect(value.textAlign, TextAlign.right);
  });

  testWidgets(
    'LoopSkeleton keeps three layouts, live-region label, no claims',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          children: <Widget>[
            LoopSkeleton(type: LoopSkeletonType.list, rows: 3),
            LoopSkeleton(type: LoopSkeletonType.detail),
            LoopSkeleton(type: LoopSkeletonType.chart),
          ],
        ),
        size: const Size(390, 1400),
      );
      expect(
        find.byKey(const ValueKey<String>('loop-skeleton-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-skeleton-detail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-skeleton-chart')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('列表加载中'), findsOneWidget);
      expect(find.bySemanticsLabel('图表加载中'), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(LoopSkeletonBlock), findsNWidgets(3 * 3 + 6 + 4));
      final block = tester.widget<Container>(
        find.descendant(
          of: find.byType(LoopSkeletonBlock).first,
          matching: find.byType(Container),
        ),
      );
      expect((block.decoration! as BoxDecoration).color, LoopColors.card2);
      await tester.pump(const Duration(milliseconds: 700));
      final pulsing = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(LoopSkeletonBlock).first,
          matching: find.byType(Opacity),
        ),
      );
      expect(pulsing.opacity, lessThan(1));
      semantics.dispose();
    },
  );

  testWidgets('skeleton pulse is static under reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: LoopSkeletonBlock(width: 80, height: 12)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 1);
  });

  testWidgets(
    'empty, error, offline and permission states expose their facts',
    (tester) async {
      var retries = 0;
      var alternative = 0;
      var settings = 0;
      await _pump(
        tester,
        Column(
          children: <Widget>[
            const LoopEmpty(
              icon: 'offline',
              message: '无法连接到服务器',
              reason: '缓存为空',
            ),
            LoopErrorState(
              title: '服务暂时不可用',
              reason: '错误 502',
              traceId: '7f3a2c9e',
              source: 'Wallet API',
              onRetry: () => retries += 1,
              alternative: () => alternative += 1,
              alternativeLabel: '联系客服',
            ),
            const LoopOfflineState(cachedAtLabel: '09:38'),
            const LoopOfflineState(),
            LoopPermissionState(
              title: '通知权限已被系统关闭',
              purpose: '你将收不到挖矿结算与 Launch 提醒。',
              denied: true,
              onOpenSettings: () => settings += 1,
            ),
          ],
        ),
        size: const Size(390, 1600),
      );
      expect(find.byKey(const ValueKey<String>('loop-empty')), findsOneWidget);
      expect(find.text('缓存为空'), findsOneWidget);
      expect(find.text('追踪号 7f3a2c9e · 来源 Wallet API'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.tap(find.text('联系客服'));
      expect(retries, 1);
      expect(alternative, 1);
      expect(find.text('缓存 09:38'), findsOneWidget);
      expect(find.text('缓存 —'), findsOneWidget);
      expect(find.textContaining('已暂停：发送、兑换、跨链、签名'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey<String>('loop-permission-state')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('前往系统设置'));
      await tester.tap(find.text('前往系统设置'));
      expect(settings, 1);
    },
  );

  testWidgets(
    'LoopDisclosure toggles with a 44px summary and expanded semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const LoopDisclosure(summary: '查看组件出现位置', child: Text('说明')),
        size: const Size(390, 844),
      );
      final summary = find.byKey(
        const ValueKey<String>('loop-disclosure-summary'),
      );
      expect(tester.getSize(summary).height, greaterThanOrEqualTo(44));
      expect(find.text('说明'), findsNothing);
      expect(find.text('+'), findsOneWidget);
      await tester.tap(summary);
      await tester.pump();
      expect(find.text('说明'), findsOneWidget);
      expect(find.text('−'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('查看组件出现位置')),
        matchesSemantics(
          label: '查看组件出现位置',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    },
  );
}

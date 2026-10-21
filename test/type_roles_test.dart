import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

/// Decision 0189 (docs/37 §1, G7): every shared widget draws each of its
/// words in exactly one ladder step. A widget that changes its type changes
/// this table with it.

Future<void> _pump(WidgetTester tester, Widget child) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

/// The style the word [text] is actually painted in, after every
/// `DefaultTextStyle` above it has been merged.
TextStyle _painted(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.text(text, findRichText: true).first,
  );
  return paragraph.text.style!;
}

void _expectStep(
  WidgetTester tester,
  String text,
  TextStyle step, {
  FontWeight? weight,
}) {
  final painted = _painted(tester, text);
  expect(painted.fontSize, step.fontSize, reason: '$text · size');
  expect(
    painted.fontWeight,
    weight ?? step.fontWeight,
    reason: '$text · weight',
  );
  expect(painted.height, step.height, reason: '$text · height');
  expect(painted.fontFamily, step.fontFamily, reason: '$text · family');
}

void main() {
  test('the new steps hold their documented values', () {
    // Decision 0229: the v3 ladder (docs/46 §2).
    expect(LoopType.kicker.fontSize, 14);
    expect(LoopType.kicker.fontWeight, FontWeight.w700);
    expect(LoopType.stepTitle.fontSize, 28);
    expect(LoopType.stepTitle.fontFamily, LoopFonts.body);
    expect(LoopType.flatTitle.fontSize, 22);
    expect(LoopType.flatTitle.fontFamily, LoopFonts.body);
    expect(LoopType.figure.fontSize, 17);
    expect(LoopType.figure.fontWeight, FontWeight.w600);
  });

  testWidgets('S1 · LoopQuoteRow and its change pill sit on the ladder', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          LoopQuoteRow(
            leading: const SizedBox(width: 36, height: 36),
            title: 'BNB',
            subtitle: '市值 1.2B',
            subtitleMark: '以 WBNB 计价',
            value: r'$612.40',
            valueCaption: const Text('0.52 BNB'),
            trailing: LoopChangePill(change: Decimal.parse('2.5')),
          ),
          const LoopChangePill(change: null),
        ],
      ),
    );
    _expectStep(tester, 'BNB', LoopType.titleLg);
    // Decision 0229: the second line is a caption.
    _expectStep(tester, '市值 1.2B', LoopType.caption);
    _expectStep(tester, '以 WBNB 计价', LoopType.captionSm);
    _expectStep(tester, r'$612.40', LoopType.figureMd);
    _expectStep(tester, '0.52 BNB', LoopType.figureSm);
    _expectStep(tester, '+2.50%', LoopType.figure, weight: FontWeight.w700);
    _expectStep(tester, '未报告', LoopType.caption);
  });

  for (final flat in <bool>[false, true]) {
    testWidgets('S2 · LoopRecordRow is one row ladder (flat: $flat)', (
      tester,
    ) async {
      final rows = Column(
        children: <Widget>[
          LoopRecordRow(
            title: '收到 USDT',
            subtitle: '来自 0x12…34',
            trailing: '+2.99',
            trailingCaption: '10:24',
            onTap: () {},
          ),
          const LoopRecordRow(
            title: '涨跌',
            trailing: '1.00',
            trailingCaption: '+1.20%',
            trailingCaptionUp: true,
          ),
        ],
      );
      await _pump(tester, flat ? LoopFlat(child: rows) : rows);
      _expectStep(tester, '收到 USDT', LoopType.title);
      _expectStep(tester, '来自 0x12…34', LoopType.caption);
      expect(_painted(tester, '来自 0x12…34').color, LoopColors.text2);
      _expectStep(tester, '+2.99', LoopType.figure);
      _expectStep(tester, '10:24', LoopType.figureXs);
      _expectStep(tester, '+1.20%', LoopType.figureXs, weight: FontWeight.w600);
    });
  }

  testWidgets('S2 · LoopPersonRow shares the row ladder', (tester) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          const LoopPersonRow(
            leading: SizedBox(width: 40, height: 40),
            title: 'Alice',
            subtitle: 'LOOP ID 1024',
            tag: LoopTag('主持'),
          ),
          LoopPillAction(label: '接受', onPressed: () {}),
          LoopSeeAll(onPressed: () {}),
        ],
      ),
    );
    _expectStep(tester, 'Alice', LoopType.title);
    _expectStep(tester, 'LOOP ID 1024', LoopType.caption);
    _expectStep(tester, '主持', LoopType.kicker, weight: FontWeight.w600);
    _expectStep(tester, '接受', LoopType.titleSm, weight: FontWeight.w600);
    _expectStep(tester, '查看全部', LoopType.bodySm);
  });

  testWidgets('R2 · every sheet title is LoopType.heading', (tester) async {
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          LoopSheetHeading('选择网络'),
          LoopSignSheet(
            state: LoopSignSheetState.pending,
            facts: <LoopSignFact>[LoopSignFact('金额', '10 USDT')],
            title: '确认转账',
            reason: '额度不足时需要先授权',
          ),
        ],
      ),
    );
    _expectStep(tester, '选择网络', LoopType.heading);
    _expectStep(tester, '确认转账', LoopType.heading);
    _expectStep(tester, '额度不足时需要先授权', LoopType.caption);
    // Decision 0229: a fact's label and value are both at the body2 size —
    // the label 400, the value the line's 600 figure.
    _expectStep(tester, '金额', LoopType.body2);
    _expectStep(tester, '10 USDT', LoopType.figureBody);
  });

  testWidgets('R25 · a field types and hints in the input step', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          const TextField(decoration: InputDecoration(hintText: '主题占位')),
          TextField(decoration: loopFormFieldDecoration(hint: '表单占位')),
        ],
      ),
    );
    _expectStep(tester, '主题占位', LoopType.bodyLg);
    _expectStep(tester, '表单占位', LoopType.bodyLg);
    for (final field in tester.widgetList<EditableText>(
      find.byType(EditableText),
    )) {
      expect(field.style.fontSize, LoopType.bodyLg.fontSize);
      expect(field.style.fontWeight, LoopType.bodyLg.fontWeight);
    }
  });

  testWidgets('R8–R11 · the folio kicker, heading, caption and stamp', (
    tester,
  ) async {
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          LoopFolioPrimary(
            kicker: '钱包',
            heading: '动作页',
            caption: '一句说明',
            stamp: '已读',
          ),
          LoopFolioPrimary(
            heading: '记录页',
            archetype: LoopFolioArchetype.record,
          ),
          LoopFolioPrimary(
            heading: '索引页',
            archetype: LoopFolioArchetype.listing,
          ),
          LoopFolioPrimary(heading: '紧凑', compact: true),
        ],
      ),
    );
    _expectStep(tester, '钱包', LoopType.kicker);
    _expectStep(tester, '动作页', LoopType.display);
    _expectStep(tester, '一句说明', LoopType.caption);
    _expectStep(tester, '已读', LoopType.kicker);
    _expectStep(tester, '记录页', LoopType.displayXl);
    _expectStep(tester, '索引页', LoopType.displaySm);
    _expectStep(tester, '紧凑', LoopType.displaySm);
  });

  testWidgets('R12–R17 · stat grid, badge, button, segment', (tester) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          const LoopStatGrid(
            stats: <LoopStat>[LoopStat(label: '持有人', value: '1,024')],
          ),
          const LoopBadge('已验证'),
          LoopButton(label: '确认', onPressed: () {}),
          LoopFlat(
            child: LoopButton(label: '保存', block: true, onPressed: () {}),
          ),
          LoopSeg(label: '全部', selected: true, onSelected: () {}),
          LoopSeg(label: '收到', selected: false, onSelected: () {}),
          LoopSeg(label: '静默', selected: false, quiet: true, onSelected: () {}),
        ],
      ),
    );
    _expectStep(tester, '1,024', LoopType.figure);
    _expectStep(tester, '持有人', LoopType.kicker);
    _expectStep(tester, '已验证', LoopType.label, weight: FontWeight.w600);
    _expectStep(tester, '确认', LoopType.action);
    _expectStep(tester, '保存', LoopType.titleLg);
    _expectStep(tester, '全部', LoopType.label, weight: FontWeight.w700);
    _expectStep(tester, '收到', LoopType.label, weight: FontWeight.w600);
    _expectStep(tester, '静默', LoopType.action, weight: FontWeight.w600);
  });

  testWidgets('R3 · R20 · R31 · label, notice, unavailable and empty states', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          const LoopLabel('资产'),
          const LoopFlat(child: LoopLabel('账户')),
          const LoopNotice(body: '卡片说明'),
          const LoopFlat(child: LoopNotice(body: '平铺说明')),
          LoopInlineUnavailable(message: '余额读不到', onRetry: () {}),
          const LoopEmptyState(
            illustration: LoopIllustration.holders,
            title: '还没有持有者',
            message: '有人买入后会出现在这里',
          ),
          const LoopEmptyState(
            illustration: LoopIllustration.holders,
            title: '紧凑空态',
            compact: true,
          ),
        ],
      ),
    );
    // Decision 0211: a section label is the section title step.
    _expectStep(tester, '资产', LoopType.sectionTitle);
    // S241c: a flat section title is Arimo 700, not Anton.
    _expectStep(tester, '账户', LoopType.sectionTitle);
    _expectStep(tester, '卡片说明', LoopType.caption);
    _expectStep(tester, '平铺说明', LoopType.caption);
    _expectStep(tester, '余额读不到', LoopType.captionSm);
    _expectStep(tester, '重试', LoopType.label, weight: FontWeight.w600);
    _expectStep(tester, '还没有持有者', LoopType.titleLg);
    _expectStep(tester, '有人买入后会出现在这里', LoopType.bodySm);
    _expectStep(tester, '紧凑空态', LoopType.title);
  });

  testWidgets('R1b · R1c · flat titles and the step heading', (tester) async {
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          LoopFlat(child: LoopTopbar(title: '设置')),
          LoopFlat(step: true, child: LoopTopbar(title: '创建钱包')),
          LoopFlatHeading(title: '欢迎来到 LOOP', subtitle: '一句副标'),
        ],
      ),
    );
    _expectStep(tester, '设置', LoopType.flatTitle);
    _expectStep(tester, '创建钱包', LoopType.stepTitle);
    _expectStep(tester, '欢迎来到 LOOP', LoopType.stepTitle);
    _expectStep(tester, '一句副标', LoopType.body);
  });
}

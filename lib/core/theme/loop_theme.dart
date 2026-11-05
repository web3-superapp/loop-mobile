import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// LOOP colour tokens — the requester's Figma system (decision 0277, docs/58
/// §9.3), which restates 0210's looplabs palette on the Figma's values: a
/// near-black ground, three neutral greys for type, a Yellow first accent and
/// a Purple second accent, white at 3–15 % for every glass ground and line.
///
/// Yellow is the primary brand accent; Purple is a second accent for counts,
/// the live mark, ambient light and the title doodle — **a selection is
/// white** (a white word over a white 10 % ground or a Yellow underline),
/// never a Purple ground. The retired Lime names ([lime], [limeSoft],
/// [limeHighlight], [mint]) are aliases of the Yellow tokens, and every older
/// name below is kept as an alias of the Figma token it now means, so
/// existing call sites move with the palette; new code names the new token.
///
/// Price movement is not a brand colour. A market rise and fall are painted
/// in [rise] / [fall] (decision 0117, v3 requirement §6.2.1), and only through
/// `LoopPriceMove` or these two tokens — never through [yellow] or [danger],
/// which keep their brand and error meanings. They do not count towards the
/// brand colours.
///
/// 黄紫是品牌强调色；行情涨跌用 rise/fall，不计入品牌色。
/// 选中态是白字（决策 0277）。
abstract final class LoopColors {
  // ---- Figma ground and type (docs/58 §1.1 / §9.3) ------------------------

  /// Page ground · `#070809` (Figma Background; MEME's `#08090b` and the
  /// power pages' `#050607` fold into it).
  static const Color bg = Color(0xFF070809);

  /// Primary text · `#f4f5f7` (the wallet's `#f5f5f7` and the power pages'
  /// `#f7f7f8` fold into it).
  static const Color textPrimary = Color(0xFFF4F5F7);

  /// Secondary text · `#a2a4ad` — an unchosen tab or chip, a preview, a
  /// description, the tab bar's idle word.
  static const Color textSecondary = Color(0xFFA2A4AD);

  /// Tertiary text · `#6f717a` — a symbol, a time, an unchosen page title, a
  /// search placeholder (the chat time's `#626368` folds into it).
  static const Color textTertiary = Color(0xFF6F717A);

  /// The word on a chosen tab or chip · white.
  static const Color textOnSelected = Color(0xFFFFFFFF);

  /// Primary accent · `#ffd21c` (Figma Accent Yellow).
  static const Color yellow = Color(0xFFFFD21C);

  /// The word or glyph on a Yellow ground · `#090a0c`.
  static const Color onYellow = Color(0xFF090A0C);

  /// Second accent · `#a62eff`: tab counts, the live mark, ambient light,
  /// the title doodle, the token card's spark line.
  static const Color purple = Color(0xFFA62EFF);

  /// The podium's Purple glow · `#8e22ff`.
  static const Color podiumGlow = Color(0xFF8E22FF);

  /// Stage capsule / tag ground behind a Yellow word · `#30280c` (the
  /// post tag's `#2e2908` folds into it).
  static const Color yellowSoft = Color(0xFF30280C);

  /// 「毕业」 tag · `#1ad68c` on `#053324`.
  static const Color tagGreen = Color(0xFF1AD68C);
  static const Color tagGreenBg = Color(0xFF053324);

  /// 「观点」 tag · `#c957ff` on `#290a3b`.
  static const Color tagPurple = Color(0xFFC957FF);
  static const Color tagPurpleBg = Color(0xFF290A3B);

  /// Third place · `#cd8032`.
  static const Color bronze = Color(0xFFCD8032);

  // ---- Figma grounds and lines (docs/58 §1.2) -----------------------------

  /// White 3 % — the tab bar's and the live ticker's glass ground and edge.
  static const Color white3 = Color(0x08FFFFFF);

  /// White 4 % — an unchosen filter chip's ground.
  static const Color white4 = Color(0x0AFFFFFF);

  /// White 5 % — a row divider, a tab count's ground, a card's inner line.
  static const Color white5 = Color(0x0DFFFFFF);

  /// White 8 % — a quiet button's ground (加入, 生成海报), a tag's edge.
  static const Color white8 = Color(0x14FFFFFF);

  /// White 10 % — a chosen filter chip's ground; the tab strip's rule.
  static const Color white10 = Color(0x1AFFFFFF);

  /// White 15 % — a banner's edge.
  static const Color white15 = Color(0x26FFFFFF);

  /// White 30 % — the power card's 「快照」 line.
  static const Color white30 = Color(0x4DFFFFFF);

  /// White 60 % — an unchosen tab's count.
  static const Color white60 = Color(0x99FFFFFF);

  static const Color surfaceGlass = white3;
  static const Color chipIdle = white4;
  static const Color divider = white5;
  static const Color buttonGhost = white8;
  static const Color chipActive = white10;
  static const Color tabRule = white10;
  static const Color bannerEdge = white15;

  /// The tab bar's 1 px edge · `#34353b`.
  static const Color navEdge = Color(0xFF34353B);

  /// A search field's, a token card's and a featured card's edge ·
  /// `#1d1f24`.
  static const Color cardEdge = Color(0xFF1D1F24);

  /// A solid divider (Figma Divider) · `#24262c` — the wallet's key rules.
  static const Color dividerSolid = Color(0xFF24262C);

  /// A raised tile (Figma Surface Elevated) · `#1a1b20` — the wallet's
  /// function-icon ground.
  static const Color surfaceElevated = Color(0xFF1A1B20);

  /// A sunken card · `#0b0c0f` — the quoted token card, the featured
  /// community card.
  static const Color cardInset = Color(0xFF0B0C0F);

  /// A card · `#121318` — the invite code card, the metric card.
  static const Color card = Color(0xFF121318);

  /// The chat search field's ground · `#0e0f12`.
  static const Color searchBg = Color(0xFF0E0F12);

  /// A small count chip's ground beside a conversation name · `#131417`.
  static const Color countBg = Color(0xFF131417);

  /// A progress track · `#22232a`; its fill is white 80 %.
  static const Color progressTrack = Color(0xFF22232A);
  static const Color progressFill = Color(0xCCFFFFFF);

  /// The power card's ground: `#14151a` → `#1b1028` at about 107°.
  static const LinearGradient powerCardGradient = LinearGradient(
    begin: Alignment(-0.95, -0.3),
    end: Alignment(0.95, 0.3),
    colors: <Color>[Color(0xFF14151A), Color(0xFF1B1028)],
  );

  // ---- Older names, now on the Figma values ------------------------------

  /// Page ground ([bg]).
  static const Color ink = bg;

  /// Pressed / highlighted primary.
  static const Color yellowHighlight = Color(0xFFFFE066);

  /// A pressed primary button: Yellow deepened (decision 0211).
  static const Color yellowPressed = Color(0xFFE0B800);

  /// Purple at 9.4 % — a chosen row's wash.
  static const Color purpleSoft = Color(0x18A62EFF);

  /// The chosen ground of a segment, a filter chip or a choice. Decision
  /// 0277: white 10 % with a white word (the Figma's chosen chip); Purple is
  /// no longer a selected ground.
  static const Color purpleSelected = chipActive;

  /// The word on [purpleSelected] · white.
  static const Color onPurple = textOnSelected;

  /// Purple at 18 % — only the ground of the 「已毕业」 stage capsule.
  static const Color purpleTint = Color(0x2EA62EFF);

  /// Purple at 44 % — a selected or focused edge.
  static const Color purpleLine = Color(0x70A62EFF);

  /// Text input ground: the raised block.
  static const Color input = plateRaised;

  /// Text input edge.
  static const Color inputLine = cardEdge;

  /// Foreground ([textPrimary]).
  static const Color chalk = textPrimary;

  /// Surface · `#111214`: the ground a sheet, a dialog or a floating layer
  /// is drawn on; the community search field and an avatar's placeholder.
  static const Color graphite = Color(0xFF111214);

  /// The block ground, level 1 ([card] · `#121318`, decision 0277): every
  /// card, panel, board and grouped list stands on it.
  static const Color plate = card;

  /// The block ground, level 2 · `#24262c`: what sits inside a block.
  static const Color plateRaised = dividerSolid;

  /// A fourth, mid grey for glyphs and monograms · `#8b8d96`.
  static const Color muted = Color(0xFF8B8D96);

  /// Console / sunken ground ([searchBg]).
  static const Color bg2 = searchBg;

  /// Panel ([card]).
  static const Color panel = card;

  /// Card 2 · the block ground, level 2 ([plateRaised]).
  static const Color card2 = plateRaised;

  /// 辅助按钮's face ([buttonGhost]).
  static const Color assistFill = buttonGhost;

  /// Line ([divider], white 5 %) — a divider hairline.
  static const Color line = divider;

  /// Line 2 ([cardEdge]) — a card edge.
  static const Color line2 = cardEdge;

  /// Line 3 · `#4a4a53` — an outline button's edge.
  static const Color line3 = Color(0xFF4A4A53);

  /// Text 2 ([textSecondary]).
  static const Color text2 = textSecondary;

  /// Text 3 ([textTertiary]).
  static const Color text3 = textTertiary;

  /// Retired Lime names, now the Yellow tokens (decision 0210).
  static const Color lime = yellow;
  static const Color limeSoft = yellowSoft;
  static const Color limeHighlight = yellowHighlight;

  /// The quiet folio's two tints, Yellow-based.
  static const Color quietFolioGlow = Color(0x26FFD21C);
  static const Color quietFolioTint = Color(0x10FFD21C);

  /// The record card's two tints. Flat: both are the card surface.
  static const Color recordCardGlow = card;
  static const Color recordCardTint = card;

  /// The primary button's glow.
  static const Color primaryGlow = Color(0x35FFD21C);

  /// Ink at 40 % — a contact shadow, only where a floating layer needs one.
  static const Color contactShadow = Color(0x66070809);

  /// Ink at 62% — an unselected glyph on a light ground.
  static const Color inkMuted = Color(0x9E070809);

  /// Ink at 72% / 62% — secondary text on Yellow or Chalk grounds.
  static const Color inkText2 = Color(0xB8070809);
  static const Color inkText3 = Color(0x9E070809);

  /// Sheet veil · ink at 76 %.
  static const Color veil = Color(0xC2070809);

  /// Top bar ground · ink at 95 %.
  static const Color topbar = Color(0xF2070809);

  /// The pressed-state wash every ink response paints (decision 0130).
  static const Color pressHighlight = Color(0x29A2A4AD);

  /// Market rise · `#22c982`. Price movement only (decision 0117).
  static const Color rise = Color(0xFF22C982);

  /// Market fall · #EF4444 (the Figma has no fall). Price movement only.
  static const Color fall = Color(0xFFEF4444);

  /// The ground behind a rising badge (「买入」) · `#123025`.
  static const Color riseSoft = Color(0xFF123025);

  /// Fall at 13% — the soft ground behind a falling badge.
  static const Color fallSoft = Color(0x21EF4444);

  /// Second place · #D9B36A. Medals and illustration strokes only (decision
  /// 0122); never a brand accent, a state or a price direction.
  static const Color brass = Color(0xFFD9B36A);

  /// Third place ([bronze]).
  static const Color copper = bronze;

  /// Chrome ramp (S264, decision 0220): the MEME home's chrome edge and
  /// default project avatar — light, mid and dark steel.
  static const Color chrome1 = Color(0xFFF0F0F3);
  static const Color chrome2 = Color(0xFF9A9AA3);
  static const Color chrome3 = Color(0xFF3A3A42);

  /// The 已毕业 capsule's word ([tagPurple]).
  static const Color purpleInk = tagPurple;

  /// The 已毕业 capsule's ground ([tagPurpleBg]).
  static const Color purpleCapsule = tagPurpleBg;

  // Semantic aliases retained for existing widgets.
  static const Color hairline = line;
  static const Color abyss = ink;
  static const Color basalt = graphite;
  static const Color elevated = card2;
  static const Color vapor = muted;
  static const Color mint = yellow;

  // Legacy categorical accents used by not-yet-migrated feature slices. New
  // surfaces must not use these and no further colour may be added to this
  // group.
  static const Color market = Color(0xFF68B9FF);
  static const Color chat = Color(0xFFF2B562);
  static const Color danger = Color(0xFFFF6B82);

  /// Danger at 13 % — a pressed danger button's ground (decision 0211).
  static const Color dangerSoft = Color(0x21FF6B82);

  /// Warning · orange `#FF9F1C`, kept apart from the Yellow accent.
  static const Color warning = Color(0xFFFF9F1C);
}

/// One initials-tile ground: a fill and the letter colour legible on it.
typedef LoopMonogramGround = ({String id, Color fill, Color ink});

/// The six grounds an initials tile (a community with no preset logo) is
/// drawn on (S241c, decision 0210).
///
/// Greys and Purple only: Yellow is reserved for calls to action, labels and
/// key figures, so an identity tile must never be Yellow or a Yellow blend.
/// Purple at full strength measures 4.28:1 against Chalk and 4.15:1 against
/// Ink — under the 4.5:1 floor — so it appears here only deepened over Ink
/// (Chalk letters) or paled toward Chalk (Ink letters). Every pair clears
/// 4.5:1; every fill stays clear of the page, card and Chalk grounds.
abstract final class LoopMonogramPalette {
  static const List<LoopMonogramGround> grounds = <LoopMonogramGround>[
    /// Chalk at 75 % over Ink.
    (id: 'chalk-dim', fill: Color(0xFFB8B8BA), ink: LoopColors.ink),
    (id: 'muted', fill: LoopColors.muted, ink: LoopColors.ink),

    /// Muted at 60 % over Ink.
    (id: 'muted-deep', fill: Color(0xFF595660), ink: LoopColors.chalk),

    /// Purple at 60 % over Ink.
    (id: 'purple-deep', fill: Color(0xFF61249D), ink: LoopColors.chalk),

    /// Purple and Chalk, half each.
    (id: 'purple-pale', fill: Color(0xFFC794FA), ink: LoopColors.ink),

    /// The strong outline grey.
    (id: 'graphite', fill: LoopColors.line3, ink: LoopColors.chalk),
  ];
}

/// The ink of the ground a widget was actually placed on.
///
/// The palette is authored for the Ink page. A shared widget that can land on
/// a light ground (Chalk or Yellow) derives its colours from the ambient
/// [DefaultTextStyle] — which the light grounds set to Ink — instead of
/// naming a fixed token. On the Ink page (a light ambient ink) every derived
/// colour is the solid token itself; on a light ground it is the ground's
/// ink at the weight the token stands for.
///
/// This only works because a light ground *declares itself*: the container
/// that paints Chalk or Yellow wraps its children in a [DefaultTextStyle] and
/// an [IconTheme] carrying that ground's ink — which is why
/// `scripts/check_harness.py` holds the declaration itself.
abstract final class LoopGround {
  /// The ground's own ink at full strength: Chalk on Ink, Ink on Chalk/Yellow.
  ///
  /// The dark page's greys ([LoopColors.text2] / [LoopColors.text3]) are
  /// solid colours since decision 0210, where they used to be Chalk at an
  /// alpha; any light ambient ink therefore reads as the page's Chalk, so a
  /// subtree set in a grey still derives from the Ink page.
  static Color inkOf(BuildContext context) {
    final ink = (DefaultTextStyle.of(context).style.color ?? LoopColors.chalk)
        .withValues(alpha: 1);
    return _onDark(ink) ? LoopColors.chalk : ink;
  }

  /// Whether the ambient ink is the dark page's light ink.
  ///
  /// Decision 0277: the Figma's tertiary grey (`#6f717a`) measures 0.17,
  /// so the line sits at 0.05 — every page grey is above it, the Ink a
  /// light ground declares (0.003) is far below.
  static bool _onDark(Color ink) => ink.computeLuminance() > 0.05;

  static Color _derive(BuildContext context, Color token, double alpha) {
    final ink = inkOf(context);
    return _onDark(ink) ? token : ink.withValues(alpha: alpha);
  }

  /// [LoopColors.card2] — a filled inset or a placeholder.
  static Color fillOf(BuildContext context) =>
      _derive(context, LoopColors.card2, 0.10);

  /// [LoopColors.card] — the panel a placeholder or an inset sits on.
  static Color tintOf(BuildContext context) =>
      _derive(context, LoopColors.card, 0.06);

  /// [LoopColors.line] — a hairline edge.
  static Color hairlineOf(BuildContext context) =>
      _derive(context, LoopColors.line, 0.13);

  /// [LoopColors.line2] — a strong edge, the one a control draws around
  /// itself.
  static Color edgeOf(BuildContext context) =>
      _derive(context, LoopColors.line2, 0.22);

  /// [LoopColors.text2] — secondary copy.
  static Color secondaryOf(BuildContext context) =>
      _derive(context, LoopColors.text2, 0.68);

  /// [LoopColors.text3] — auxiliary copy and glyphs.
  static Color auxiliaryOf(BuildContext context) =>
      _derive(context, LoopColors.text3, 0.58);
}

/// Spacing semantics — the requester's Figma (decision 0277, docs/58 §9.4,
/// which restates docs/46 v3): a 20 page margin, 24 from a card to the next
/// section heading and 12 under it, 16 from a banner to the next block, 12
/// between two posts or two stacked blocks.
abstract final class LoopSpacing {
  /// 紧凑 · 8 — between two words of one line, an icon and its label.
  static const double tight = 8;

  /// 卡内 · 16 — the padding inside a card or a board.
  static const double card = 16;

  /// 组间 · 24 — a label that follows another label.
  static const double group = 24;

  /// 区块上 · 24 — from a card to the next section heading (「排行榜」).
  static const double section = 24;

  /// 页边距 · 20 — the page's left and right content line.
  static const double page = 20;

  /// 区块下 · 12 — from a page or section heading to its first block.
  static const double headingGap = 12;

  /// 区块上 · 24 (v3 name of [section]).
  static const double sectionTop = section;

  /// 区块下 · 12 (v3 name of [headingGap]).
  static const double sectionBottom = headingGap;

  /// 行间 / 卡间 · 12 — between two cards, two boards, two stacked blocks.
  static const double rowGap = 12;

  /// A list row with one line: at least 72 high.
  static const double rowMin = 72;

  /// A list row with a second (caption) line: at least 80 high.
  static const double rowMinWithSub = 80;

  /// From a banner (or a chrome plate) to the next block · 16.
  static const double bannerGap = 16;

  /// From a tab strip to the list under it · 16 (MEME's is 8).
  static const double segmentGap = 16;

  /// From a row of filter chips to the content under it · 12.
  static const double chipGap = 12;

  /// Between two filter chips · 8.
  static const double chipSpacing = 8;

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

/// List row heights from the Figma frames (docs/58 §3.2, ruled in §9.4;
/// S353c · decision 0280). Each is the row's full height, its own divider
/// included where it draws one.
///
/// Dividers (§9.4): token, chat, community, post and management rows draw a
/// 1 px [LoopColors.divider] line under them (`LoopRecordRow.divider` where
/// the row is a [LoopRecordRow]); holdings and rank rows draw none.
abstract final class LoopRowHeight {
  /// MEME token row · 71 (avatar 44), divider.
  static const double token = 71;

  /// Chat conversation row · 67 (avatar 48), divider.
  static const double chat = 67;

  /// Community row · 86 (square avatar 56 r12), divider.
  static const double community = 86;

  /// Wallet management row · 56 (glyph 20 on a 34 r9 ground), divider.
  static const double management = 56;

  /// Holdings row on 我的 and another account's page · 51 (avatar 36, 6
  /// above and below), no divider.
  static const double holdings = 51;

  /// Leaderboard row · 51 (avatar 36, 6 above and below), no divider.
  static const double rank = 51;

  /// Avatar on a holdings or rank row · 36.
  static const double holdingsAvatar = 36;
}

/// Corner radii — the requester's Figma (decision 0277, docs/58 §4 / §9.4,
/// which revises 0211): a sheet and the shell at 20, a card, a control, a
/// search field and the tab bar at 12, a button and a filter chip at 8, a
/// post tag at 5, a stage capsule at 4, a tab count at 2. [pill] is no
/// longer round — a filter or a segment is a rounded rectangle now — and
/// [round] is for what really is round: an avatar, a dot, a progress end.
abstract final class LoopRadius {
  static const double shellValue = 20;
  static const double cardValue = 12;
  static const double controlValue = 12;
  static const double innerValue = 10;

  /// The bottom tab bar (decision 0277).
  static const double tabBarValue = 12;

  /// Chat bubble tail corner — the one tighter corner of a 16 bubble.
  static const double bubbleTailValue = 6;

  static const double tileValue = 10;
  static const double buttonValue = 8;
  static const double toolValue = 8;
  static const double badgeValue = 6;
  static const double wideButtonValue = 8;

  /// A filter chip (54 × 32) · 8.
  static const double chipValue = 8;

  /// A post tag (置顶 / 毕业 / 观点) · 5.
  static const double tagValue = 5;

  /// A stage capsule (公开内盘) and the 「买入」 tag · 4.
  static const double stageValue = 4;

  /// A tab count chip · 2.
  static const double countValue = 2;

  /// A function row's glyph ground (docs/58 §9.4 「功能图标底 9」, S371 ·
  /// decision 0297) · 9.
  static const double glyphGroundValue = 9;

  /// The small buttons: 发射 / 加入 · 6.
  static const double compactButtonValue = 6;

  /// A fully round end.
  static const double roundValue = 999;

  /// A chat bubble (decision 0211).
  static const double bubbleValue = 16;

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
  static const BorderRadius tile = BorderRadius.all(Radius.circular(tileValue));
  static const BorderRadius button = BorderRadius.all(
    Radius.circular(buttonValue),
  );
  static const BorderRadius tool = BorderRadius.all(Radius.circular(toolValue));
  static const BorderRadius badge = BorderRadius.all(
    Radius.circular(badgeValue),
  );
  static const BorderRadius wideButton = BorderRadius.all(
    Radius.circular(wideButtonValue),
  );
  static const BorderRadius bubble = BorderRadius.all(
    Radius.circular(bubbleValue),
  );

  /// The top corners of a sheet.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(shellValue),
  );

  static const BorderRadius chip = BorderRadius.all(Radius.circular(chipValue));
  static const BorderRadius tag = BorderRadius.all(Radius.circular(tagValue));
  static const BorderRadius stage = BorderRadius.all(
    Radius.circular(stageValue),
  );
  static const BorderRadius glyphGround = BorderRadius.all(
    Radius.circular(glyphGroundValue),
  );
  static const BorderRadius count = BorderRadius.all(
    Radius.circular(countValue),
  );
  static const BorderRadius compactButton = BorderRadius.all(
    Radius.circular(compactButtonValue),
  );

  /// A capsule — a filter, a segment, a tag, a badge. Decision 0277: 8, the
  /// Figma's chip corner, no longer round.
  static const BorderRadius pill = chip;

  /// Fully round — avatars, dots, rings and progress ends.
  static const BorderRadius round = BorderRadius.all(
    Radius.circular(roundValue),
  );

  /// The name the task gave [round].
  static const BorderRadius pillRound = round;

  // Existing aliases.
  static const BorderRadius container = shell;
  static const BorderRadius large = shell;
  static const BorderRadius medium = control;
  static const BorderRadius small = inner;
}

/// Depth (decision 0210, 0277). The surface is flat: a 1px edge instead of a
/// drop shadow, and a coloured glow on the one element a page wants to stand
/// out. The two floating layers of the Figma — the tab bar and the live
/// ticker — carry its one shadow, `0 8 20 rgba(0,0,0,.38)`. The lift names
/// survive, empty, so call sites keep compiling.
abstract final class LoopDepth {
  static const List<BoxShadow> liftPrimary = <BoxShadow>[];
  static const Color liftPrimaryEdge = Color(0x00000000);
  static const List<BoxShadow> liftPrimaryLight = <BoxShadow>[];
  static const Color liftPrimaryLightEdge = Color(0x00000000);
  static const List<BoxShadow> liftCard = <BoxShadow>[];
  static const Color liftCardEdge = Color(0x00000000);
  static const List<BoxShadow> liftInner = <BoxShadow>[];
  static const Color innerEdge = Color(0x00000000);

  /// `0 8 20 rgba(0,0,0,.38)` — the tab bar and the live ticker.
  static const List<BoxShadow> tabBar = <BoxShadow>[
    BoxShadow(color: Color(0x61000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> ticker = tabBar;
  static const Color tabBarEdge = LoopColors.navEdge;
  static const List<BoxShadow> tabSelected = <BoxShadow>[];
  static const Color tabSelectedEdge = Color(0x00000000);

  /// `0 0 24px #a62eff22` — the Purple glow of a focused or featured card.
  static const List<BoxShadow> glowPurple = <BoxShadow>[
    BoxShadow(color: Color(0x22A62EFF), blurRadius: 24),
  ];

  /// `0 0 17px #ffd21c35` — the Yellow glow of a primary action or a tag.
  static const List<BoxShadow> glowYellow = <BoxShadow>[
    BoxShadow(color: LoopColors.primaryGlow, blurRadius: 17),
  ];
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

  /// Primary button height (48, decision 0211).
  static const double primaryButton = 48;

  /// A compact button's visible face (S325 · decision 0255): 32, inside a
  /// [minimum] target.
  static const double compactButton = 32;

  /// The Figma's page buttons (decision 0277), each inside a [minimum]
  /// target: 发射 30, 分享 / 次按钮 36, 加入 28 (54 wide).
  static const double buttonCompact = 30;
  static const double buttonMedium = 36;
  static const double buttonJoin = 28;
  static const double buttonJoinWidth = 54;

  /// A filter chip's face: 54 × 32 (decision 0277).
  static const double chipHeight = 32;
  static const double chipMinWidth = 54;

  /// A search field (decision 0277): 44 on 聊天 and 广场 alike.
  static const double searchField = 44;

  /// Floating tab bar height (the Figma's 68); a cell fills it (decision
  /// 0285).
  static const double tabBarHeight = 68;
  static const double tabCellMinHeight = 68;
}

/// Page layout reserves (chapter 5.3 / 5.4).
abstract final class LoopLayout {
  /// Design baseline width/height.
  static const Size designBaseline = Size(390, 844);

  /// Top-level tab pages reserve `92 + safe-area-bottom` under the bar: the
  /// 68 bar on its 24 bottom inset (decision 0277).
  static const double tabPageBottomReserve = 92;

  /// Child pages keep `max(24, safe-area-bottom)`.
  static const double childPageBottomMinimum = 24;

  /// A page's floating action key — 聊天's 「发起」 (decisions 0122 / 0210)
  /// — on each side. The 意见反馈 entry keeps 12 clear of it (decision 0266).
  static const double floatingActionExtent = 56;

  /// Tab bar bottom inset on mobile (decision 0277: 24, or the safe area).
  static const double tabBarInset = 24;

  /// Tab bar side inset: on the page margin (353 wide on the 393 board).
  static const double tabBarSideInset = 20;

  /// Tab bar inner padding: the five cells fill the bar.
  static const double tabBarPadding = 0;

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

/// Font families (decision 0277, which supersedes 0210's Anton / Arimo).
/// The requester's Figma system sets every screen in **Inter**; Inter has
/// Latin, figures and punctuation only, so a Chinese run falls through
/// [systemFallback] to the bundled **Noto Sans SC**:
///
/// - [sans] — Inter, static 300 / 400 / 500 / 600 / 700, and Black Italic
///   900 for the 「第 N 名」 place figure ([LoopType.rankFigure]).
/// - [cjk] — Noto Sans SC Regular 400 / Medium 500 / Bold 700. The engine
///   resolves a Han glyph at the nearest bundled weight, so the Chinese half
///   of a line follows the Latin half like this: 300 / 400 → Regular,
///   500 → Medium, 600 / 700 / 900 → Bold.
/// - [mono] — IBM Plex Mono, kept registered for a real code block. An
///   address or a link is Inter since 0277 ([LoopType.code] 14 / 400,
///   [LoopType.codeSm] 13 / 400).
abstract final class LoopFonts {
  /// Inter — every Latin letter and figure on screen.
  static const String sans = 'Inter';

  /// Retained name: the body face is [sans].
  static const String body = sans;

  static const String mono = 'IBM Plex Mono';

  /// The bundled CJK family — the controlled Chinese face.
  static const String cjk = 'Noto Sans SC';

  /// Retained names: call sites that asked for "the system face".
  static const String system = sans;

  /// Retired with decision 0210: a band no longer switches optical cut.
  static String familyFor(double size) => sans;

  /// Fallback chain behind Inter: the bundled CJK face first, then the
  /// platform stacks for scripts it does not carry.
  static const List<String> systemFallback = <String>[
    cjk,
    'PingFang SC',
    'HarmonyOS Sans SC',
    'Source Han Sans SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  /// Retained name for the body chain (Stream's theme adapter calls it).
  static const List<String> cjkFallback = systemFallback;

  /// Fallback chain for the fixed-width band. IBM Plex Mono has no Han
  /// coverage, so a Chinese run inside a code line still lands on a real
  /// CJK face instead of the system monospace.
  static const List<String> monoFallback = <String>[
    'SF Mono',
    'Menlo',
    cjk,
    'PingFang SC',
    'monospace',
  ];
}

/// Type builders. Leading is distributed evenly
/// ([TextLeadingDistribution.even]) because a mixed 中英 line resolves two
/// files with different ascent/descent ratios.
abstract final class LoopTypography {
  /// The one builder (Inter, Noto Sans SC behind it). [italic] is only for
  /// the Black Italic place figure.
  static TextStyle sans({
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color color = LoopColors.chalk,
    bool tabularFigures = false,
    bool italic = false,
  }) {
    return TextStyle(
      fontFamily: LoopFonts.sans,
      fontStyle: italic ? FontStyle.italic : null,
      fontFamilyFallback: LoopFonts.systemFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      // Explicit, never null: a null tracking lets Material's own 2021
      // typography leak through the merge that builds a `Text`'s style.
      letterSpacing: letterSpacing ?? 0,
      color: color,
      fontFeatures: tabularFigures
          ? const <FontFeature>[FontFeature.tabularFigures()]
          : null,
    );
  }

  /// Fixed width. Addresses, transaction hashes, contract identifiers and
  /// code — never an amount, a price or a percentage: those are band 7.
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
  // The band builders. Feature code never writes `fontSize`, `fontWeight` or
  // `fontFamily` — see `scripts/check_harness.py`.
  // ---------------------------------------------------------------------

  /// Band 1 · display — a folio heading: Inter 700 with Noto Sans SC Bold
  /// behind it, no tracking.
  static TextStyle display(double size, {Color color = LoopColors.chalk}) =>
      sans(size: size, weight: FontWeight.w700, height: 1.25, color: color);

  /// Band 2 · heading — page and sheet titles, Inter 700 / Noto Sans SC
  /// Bold, sentence case and no tracking.
  static TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.chalk,
  }) => sans(size: size, weight: weight, height: 1.3, color: color);

  /// Band 3 · title — card and row titles, Inter 700.
  static TextStyle title(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.chalk,
  }) => sans(size: size, weight: weight, height: 1.35, color: color);

  /// Band 4 · body — running prose, Inter 400 at a 1.5 leading.
  static TextStyle body(double size, {Color color = LoopColors.chalk}) =>
      sans(size: size, weight: FontWeight.w400, height: 1.5, color: color);

  /// Band 5 · caption — supporting copy, 1.5 leading.
  static TextStyle caption(double size, {Color color = LoopColors.text3}) =>
      sans(size: size, weight: FontWeight.w400, height: 1.5, color: color);

  /// Band 6 · label — controls and inline labels, 700.
  static TextStyle label(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = LoopColors.text3,
  }) => sans(size: size, weight: weight, height: 1.3, color: color);

  /// Band 6b · eyebrow / kicker — a small 700 label, sentence case and no
  /// tracking (decision 0211 retired the uppercase +0.15em kicker).
  static TextStyle eyebrow(double size, {Color color = LoopColors.text3}) =>
      sans(size: size, weight: FontWeight.w700, height: 1.3, color: color);

  /// Band 7 · figure — every number the product shows, in the body face with
  /// [FontFeature.tabularFigures]. Addresses and hashes are [code].
  static TextStyle figure(
    double size, {
    FontWeight weight = FontWeight.w700,
    double height = 1.3,
    Color color = LoopColors.chalk,
  }) => sans(
    size: size,
    weight: weight,
    height: height,
    color: color,
    tabularFigures: true,
  );

  /// Band 7b · code — an address, a hash, a link. Inter 400 with tabular
  /// figures since decision 0277 (the Figma sets the wallet address in Inter
  /// 14 / 400 and the invite link in Inter 13 / 400); [mono] stays for a
  /// real code block.
  static TextStyle code(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.4,
    Color color = LoopColors.chalk,
  }) => sans(
    size: size,
    weight: weight,
    height: height,
    color: color,
    tabularFigures: true,
  );

  /// Restate [style] at [weight]. Every step is Inter since decision 0277,
  /// and Inter carries every weight the ladder names.
  static TextStyle withWeight(TextStyle style, FontWeight weight) =>
      style.copyWith(fontWeight: weight);
}

/// The named steps — the requester's Figma ladder (decision 0277, docs/58
/// §9.2), which restates docs/46 v3 (0229) one to two steps down: a row's
/// title is 14 / 500, its second line 12 / 300, the tab bar's word 12 / 500,
/// and small tags, counts and progress figures go down to 10.
/// `lib/features/**` and `lib/widgets/**` take a step from here and never a
/// raw number.
///
/// Every face is Inter with Noto Sans SC behind it. `normal` leading in the
/// Figma is Inter's own 1.21; a step the Figma fixes a line for states it.
///
/// | step | size / weight / line | default ink | where |
/// | --- | --- | --- | --- |
/// | `plateFigure` | 40 / 700 / 46 | textPrimary | 总资产 |
/// | `heroFigure` `sectionIndex` | 30 / 700 | textPrimary | 算力值 |
/// | `title1` | 28 / 700 / 1.2 | textPrimary | 页标题、选中段名 |
/// | `segmentTitleIdle` | 24 / 600 / 1.2 | textTertiary | 并列段名未选 |
/// | `inviteCode` | 23 / 600 | yellow | 邀请码 |
/// | `title2` | 22 / 700 / 1.3 | textPrimary | 二级页标题、弹层标题 |
/// | `headline` | 19 / 700 | textPrimary | 排行榜类区块标题 |
/// | `postAuthor` | 18 / 600 | textPrimary | 帖子作者 |
/// | `emptyTitle` | 17 / 700 / 24 | textPrimary | 空态标题 |
/// | `emptyMessage` | 12 / 400 / 18 | textSecondary | 空态的状态事实句（只在 showMessage 时画） |
/// | `headlineSm` | 16 / 700 | textPrimary | 小区块标题（热门社区） |
/// | `rowTitleLg` | 16 / 500 / 23 | textPrimary | 会话名 |
/// | `figure` | 16 / 600 / 23 tnum | textPrimary | 行右主数字（价格） |
/// | `button` | 16 / 600 | textPrimary | 发射、发帖、全宽 CTA |
/// | `tab` / `tabIdle` | 16 / 600 / 20 · 16 / 500 / 20 | white · textSecondary | 分段 tab |
/// | `body2` | 16 / 400 / 25 | textPrimary | 帖子正文、输入 |
/// | `body1` | 14 / 500 / 22 | textPrimary | **行主标题** |
/// | `figureSm` | 14 / 600 tnum | textSecondary | 持仓数量、引用卡名（主字在调用处给） |
/// | `label` | 14 / 500 / 20 | textTertiary | 快捷键字、功能行标题（主字在调用处给） |
/// | `body2Sm` | 14 / 400 / 22 | textPrimary | 公告帖、总资产标签行 |
/// | `searchHint` | 15 / 500 | textTertiary | 聊天搜索占位 |
/// | `captionMd` | 14 / 300 / 22 | textSecondary | 会话预览 |
/// | `code` | 14 / 400 tnum | textPrimary | 地址 |
/// | `figureXs` | 13 / 600 tnum | textSecondary | 榜单名次与数值 |
/// | `chip` / `chipIdle` | 13 / 600 · 13 / 500 | white · textSecondary | 筛选胶囊 |
/// | `buttonSm` | 13 / 600 | textPrimary | 邀请卡按钮 |
/// | `eyebrow` `kicker` | 13 / 500 | textSecondary | 小节标题（置顶 / 最近消息） |
/// | `codeSm` | 13 / 400 tnum | textPrimary | 邀请链接 |
/// | `caption` | 12 / 300 / 16 | textTertiary | **行副标**：符号、描述、时间 |
/// | `tag` | 12 / 600 / 1.2 | textSecondary | 帖子标签、算力社区 |
/// | `buttonXs` | 12 / 600 | yellow | 加入 |
/// | `navLabel` | 12 / 500 / 16 | textSecondary | 底栏（英文项 `navLabelLatin` 11 / 600 / 15） |
/// | `meta` | 12 / 500 | textTertiary | 产生算力、成员最多、当前排名、市值 |
/// | `tickerFigure` | 12 / 600 / 16 tnum | textPrimary | 跑马灯金额 |
/// | `count` | 11 / 500 / 15 | textSecondary | tab 计数小标 |
/// | `stageTag` | 11 / 400 / 1.0 | yellow | 阶段胶囊 |
/// | `buyTag` | 10 / 600 / 15 | rise | 「买入」 |
/// | `unreadCount` | 10 / 700 | onYellow | 未读数 |
/// | `metaSm` | 10 / 400 | textSecondary | 实时更新、快照、成员数 |
/// | `progress` | 10 / 300 / 16 | textSecondary | 进度 %、榜单副行 |
/// | `rankFigure` | 16 / 900 italic tnum | (by place) | 「第 N 名」的数字（字用 `figureXs`） |
///
/// A step that existed before keeps its older default ink unless the Figma
/// states one (caption, chip, tab, segmentTitleIdle, inviteCode); a page
/// that wants the Figma's ink names it at the call site.
///
/// Older names stay, each on the Figma step it now means (docs/46's
/// 「旧名仍可用」): `title` `titleLg` → `body1`; `body` `bodyLg` → `body2`;
/// `bodySm` → `body2Sm` in textSecondary; `captionSm` → `caption`;
/// `figureMd` → `figure`; `figureCompact` → `figureXs`; `action` → `button`;
/// `headingSm` `sectionTitle` → `headline`. Nothing on screen is under 10.
abstract final class LoopType {
  /// Uppercase the Latin letters of a heading or a kicker
  /// (`text-transform: uppercase`). Han characters have no case and pass
  /// through untouched, so a Chinese title is unchanged.
  ///
  /// Decision 0211 retired the uppercase kicker: this is now the identity, so
  /// a label reads exactly as it was written.
  static String caps(String text) => text;

  /// Inter's own `normal` leading, which the Figma uses wherever it fixes no
  /// line.
  static const double normalLeading = 1.21;

  static TextStyle _step(
    double size,
    FontWeight weight, {
    double height = normalLeading,
    Color color = LoopColors.textPrimary,
    bool figures = false,
    bool italic = false,
  }) => LoopTypography.sans(
    size: size,
    weight: weight,
    height: height,
    color: color,
    tabularFigures: figures,
    italic: italic,
  );

  // ---- Figma steps (decision 0277) ----------------------------------------

  /// title1 · 28 / 700 — a page title, and the chosen segment of a page
  /// whose title is split (动态 | 社区 | 语音房).
  static final TextStyle title1 = _step(28, FontWeight.w700, height: 1.2);

  /// segmentTitleIdle · 24 / 600 textTertiary — an unchosen segment beside
  /// [title1].
  static final TextStyle segmentTitleIdle = _step(
    24,
    FontWeight.w600,
    height: 1.2,
    color: LoopColors.textTertiary,
  );

  /// title2 · 22 / 700 — a second-level page's bar title (beside its back
  /// control), a banner title, a card's big title, a sheet title.
  static final TextStyle title2 = _step(22, FontWeight.w700, height: 1.3);

  /// inviteCode · 23 / 600 Yellow — 邀请码.
  static final TextStyle inviteCode = _step(
    23,
    FontWeight.w600,
    color: LoopColors.yellow,
    figures: true,
  );

  /// headline · 19 / 700 — a ranking section's heading (排行榜).
  static final TextStyle headline = _step(19, FontWeight.w700);

  /// headlineSm · 16 / 700 — a small section's heading (热门社区).
  static final TextStyle headlineSm = _step(16, FontWeight.w700);

  /// postAuthor · 18 / 600 — the author over a post.
  static final TextStyle postAuthor = _step(18, FontWeight.w600);

  /// emptyTitle · 17 / 700 on 24 — the title of an empty state.
  static final TextStyle emptyTitle = _step(
    17,
    FontWeight.w700,
    height: 24 / 17,
  );

  /// emptyMessage · 12 / 400 on 18 textSecondary — the one fact an empty
  /// state may state under its title (docs/58 §5.19).
  static final TextStyle emptyMessage = _step(
    12,
    FontWeight.w400,
    height: 18 / 12,
    color: LoopColors.textSecondary,
  );

  /// rowTitleLg · 16 / 500 on 23 — a conversation's name.
  static final TextStyle rowTitleLg = _step(
    16,
    FontWeight.w500,
    height: 23 / 16,
  );

  /// body1 · 14 / 500 on 22 — the one primary line of a list row: a token, a
  /// community, a person on a board, a holding.
  static final TextStyle body1 = _step(14, FontWeight.w500, height: 22 / 14);

  /// body2 · 16 / 400 on 25 — prose, a post, a note, an input.
  static final TextStyle body2 = _step(16, FontWeight.w400, height: 25 / 16);

  /// body2Sm · 14 / 400 on 22 — an announcement post, the community search
  /// placeholder, the line under 总资产.
  static final TextStyle body2Sm = _step(14, FontWeight.w400, height: 22 / 14);

  /// caption · 12 / 300 on 16 textTertiary — a row's second line: a symbol,
  /// a description, a time, a holding's line.
  static final TextStyle caption = _step(
    12,
    FontWeight.w300,
    height: 16 / 12,
    color: LoopColors.textTertiary,
  );

  /// captionMd · 14 / 300 on 22 textSecondary — a conversation's preview.
  static final TextStyle captionMd = _step(
    14,
    FontWeight.w300,
    height: 22 / 14,
    color: LoopColors.textSecondary,
  );

  /// searchHint · 15 / 500 textTertiary — 聊天's search placeholder.
  static final TextStyle searchHint = _step(
    15,
    FontWeight.w500,
    color: LoopColors.textTertiary,
  );

  /// label · 14 / 500 on 20 — a wallet key's word, a function row's title
  /// (Chalk at the call site). The step keeps its older textTertiary ink.
  static final TextStyle label = _step(
    14,
    FontWeight.w500,
    height: 20 / 14,
    color: LoopColors.textTertiary,
  );

  /// chip · 13 / 600 white — a chosen filter chip's word.
  static final TextStyle chip = _step(
    13,
    FontWeight.w600,
    color: LoopColors.textOnSelected,
  );

  /// chipIdle · 13 / 500 textSecondary — an unchosen filter chip's word.
  static final TextStyle chipIdle = _step(
    13,
    FontWeight.w500,
    color: LoopColors.textSecondary,
  );

  /// tab · 16 / 600 on 20 white — a chosen tab in a tab strip.
  static final TextStyle tab = _step(
    16,
    FontWeight.w600,
    height: 20 / 16,
    color: LoopColors.textOnSelected,
  );

  /// tabIdle · 16 / 500 on 20 textSecondary — an unchosen tab.
  static final TextStyle tabIdle = _step(
    16,
    FontWeight.w500,
    height: 20 / 16,
    color: LoopColors.textSecondary,
  );

  /// count · 11 / 500 on 15 — a tab's count chip (Purple when chosen, white
  /// 60 % otherwise, at the call site).
  static final TextStyle count = _step(
    11,
    FontWeight.w500,
    height: 15 / 11,
    color: LoopColors.textSecondary,
    figures: true,
  );

  /// navLabel · 12 / 500 on 16 — the tab bar's word.
  static final TextStyle navLabel = _step(
    12,
    FontWeight.w500,
    height: 16 / 12,
    color: LoopColors.textSecondary,
  );

  /// navLabelLatin · 11 / 600 on 15 — the tab bar's Latin word (MEME).
  static final TextStyle navLabelLatin = _step(
    11,
    FontWeight.w600,
    height: 15 / 11,
    color: LoopColors.textSecondary,
  );

  /// meta · 12 / 500 — 「产生算力」「成员最多」「当前排名」, a market cap.
  /// The step keeps its older textTertiary ink; the Figma's textSecondary
  /// is stated at the call site.
  static final TextStyle meta = _step(
    12,
    FontWeight.w500,
    color: LoopColors.textTertiary,
  );

  /// metaSm · 10 / 400 textSecondary — 「实时更新」, a snapshot line, a
  /// member count, a `$DOGE` tag.
  static final TextStyle metaSm = _step(
    10,
    FontWeight.w400,
    color: LoopColors.textSecondary,
  );

  /// progress · 10 / 300 on 16 textSecondary — a progress percentage, a
  /// board row's second line.
  static final TextStyle progress = _step(
    10,
    FontWeight.w300,
    height: 16 / 10,
    color: LoopColors.textSecondary,
    figures: true,
  );

  /// button · 16 / 600 — the word on a button (发射, 发帖, a full-width CTA).
  static final TextStyle button = _step(16, FontWeight.w600);

  /// buttonSm · 13 / 600 — the invite card's two buttons.
  static final TextStyle buttonSm = _step(13, FontWeight.w600);

  /// buttonXs · 12 / 600 Yellow — 「加入」.
  static final TextStyle buttonXs = _step(
    12,
    FontWeight.w600,
    color: LoopColors.yellow,
  );

  /// tag · 12 / 600 — a post tag (置顶 / 毕业 / 观点), 「算力社区」, a corner
  /// badge.
  static final TextStyle tag = _step(
    12,
    FontWeight.w600,
    height: 1.2,
    color: LoopColors.textSecondary,
  );

  /// stageTag · 11 / 400 Yellow — a stage capsule (公开内盘).
  static final TextStyle stageTag = _step(
    11,
    FontWeight.w400,
    height: 1.0,
    color: LoopColors.yellow,
  );

  /// buyTag · 10 / 600 on 15 rise — the ticker's 「买入」.
  static final TextStyle buyTag = _step(
    10,
    FontWeight.w600,
    height: 15 / 10,
    color: LoopColors.rise,
  );

  /// unreadCount · 10 / 700 onYellow — the count on a Yellow unread dot.
  static final TextStyle unreadCount = _step(
    10,
    FontWeight.w700,
    height: 1.0,
    color: LoopColors.onYellow,
    figures: true,
  );

  // ---- Figures ------------------------------------------------------------

  /// figure · 16 / 600 on 23 tabular — a row's trailing figure (a price).
  static final TextStyle figure = _step(
    16,
    FontWeight.w600,
    height: 23 / 16,
    figures: true,
  );

  /// figureSm · 14 / 600 tabular — a holding's amount, a quoted card's name
  /// (Chalk at the call site). The step keeps its older textSecondary ink:
  /// most of its callers are a row's secondary figure.
  static final TextStyle figureSm = _step(
    14,
    FontWeight.w600,
    color: LoopColors.textSecondary,
    figures: true,
  );

  /// figureXs · 13 / 600 tabular — a board's place and value; the word
  /// beside [rankFigure]. textSecondary, as [figureSm].
  static final TextStyle figureXs = _step(
    13,
    FontWeight.w600,
    color: LoopColors.textSecondary,
    figures: true,
  );

  /// rankFigure · Inter Black Italic 16 — the place in 「第 3 名」, coloured
  /// by place at the call site.
  static final TextStyle rankFigure = _step(
    16,
    FontWeight.w900,
    figures: true,
    italic: true,
  );

  /// plateFigure · 40 / 700 on 46 — 总资产 (white, decision 0277).
  static final TextStyle plateFigure = _step(
    40,
    FontWeight.w700,
    height: 46 / 40,
    figures: true,
  );

  /// heroFigure · 30 / 700 — the power card's figure, a project page's
  /// price.
  static final TextStyle heroFigure = _step(30, FontWeight.w700, figures: true);

  /// sectionIndex · 30 / 700 — the MEME home's 「01」 (Yellow at the call
  /// site).
  static final TextStyle sectionIndex = _step(
    30,
    FontWeight.w700,
    height: 1.0,
    figures: true,
  );

  /// tabIndex · 18 / 700 — the same index inside a tab 「01 内盘」.
  static final TextStyle tabIndex = _step(
    18,
    FontWeight.w700,
    height: 1.0,
    figures: true,
  );

  /// tickerFigure · 12 / 600 on 16 — the amount on the live ticker.
  static final TextStyle tickerFigure = _step(
    12,
    FontWeight.w600,
    height: 16 / 12,
    figures: true,
  );

  /// A hero line — the one statement on an intro page.
  static final TextStyle heroDisplay = LoopTypography.sans(
    size: 56,
    weight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 56 * -0.02,
  );

  /// A big stat value · 28 / 700 tabular.
  static final TextStyle statFigure = _step(
    28,
    FontWeight.w700,
    height: 1.15,
    figures: true,
  );

  /// A key figure · 32 / 700 tabular (Yellow at the call site).
  static final TextStyle keyFigure = _step(
    32,
    FontWeight.w700,
    height: 1.15,
    figures: true,
  );

  /// The hero figure on a page · 28 / 700 tabular.
  static final TextStyle figureXl = _step(
    28,
    FontWeight.w700,
    height: 1.2,
    figures: true,
  );

  /// The fraction of a hero figure; an amount input · 22 / 700 tabular.
  static final TextStyle figureLg = _step(
    22,
    FontWeight.w700,
    height: 1.25,
    figures: true,
  );

  // ---- Older names on the Figma steps -------------------------------------

  /// R9 folio heading on the intro / record / state archetypes — [title1].
  static final TextStyle displayXl = title1;

  /// R9 folio heading on the action archetype — [title1].
  static final TextStyle display = title1;

  /// R9 folio heading on the index archetype — [title1].
  static final TextStyle displaySm = title1;

  /// R1c the heading of an account-opening step page — [title1].
  static final TextStyle stepTitle = title1;

  /// R1 page title of a first-level tab or a ledger page — [title1].
  static final TextStyle headingLg = title1;

  /// R1b the one-line title of a flat second-level page — [title2].
  static final TextStyle flatTitle = title2;

  /// R2 every sheet's title — [title2].
  static final TextStyle heading = title2;

  /// R1d dense (chat) top bar — [headline].
  static final TextStyle headingSm = headline;

  /// R3b a section or group heading inside a page — [headline].
  static final TextStyle sectionTitle = headline;

  /// The quote-row title; a centred state's title — [body1].
  static final TextStyle titleLg = body1;

  /// R4 a row title — [body1].
  static final TextStyle title = body1;

  /// A small control word or a label over a form field · 14 / 600.
  static final TextStyle titleSm = _step(14, FontWeight.w600);

  /// R25 the text of a text input and its placeholder — [body2].
  static final TextStyle bodyLg = body2;

  /// R18 running prose — [body2].
  static final TextStyle body = body2;

  /// A chat message: 16 / 400 at a chat leading (1.45).
  static final TextStyle message = _step(16, FontWeight.w400, height: 1.45);

  /// R19 the support copy under a sheet title, a note on a page:
  /// [body2Sm] in textSecondary.
  static final TextStyle bodySm = body2Sm.copyWith(
    color: LoopColors.textSecondary,
  );

  /// R21 one grey line of provenance, version or legal footnote — [caption].
  static final TextStyle captionSm = caption;

  /// The button word and the Material button slot — [button].
  static final TextStyle action = button;

  /// R3 the section label over a group, R3c the first line inside a card ·
  /// 13 / 500 textSecondary (聊天's 「置顶 / 最近消息」).
  static final TextStyle eyebrow = _step(
    13,
    FontWeight.w500,
    color: LoopColors.textSecondary,
  );

  /// R8 folio kicker, R11 folio stamp, R13 stat-grid label — [eyebrow].
  static final TextStyle kicker = eyebrow;

  /// R23 a secondary hero figure; the quote-row value — [figure].
  static final TextStyle figureMd = figure;

  /// A figure at the body size: a fact table's value — [figure].
  static final TextStyle figureBody = figure;

  /// A dense cell's figure — [figureXs].
  static final TextStyle figureCompact = figureXs;

  // Retired aliases (decision 0189).
  static final TextStyle monoTitle = figureLg;
  static final TextStyle monoStamp = figureXs;

  /// R30 an address · Inter 14 / 400 tabular (decision 0277).
  static final TextStyle code = LoopTypography.code(14);

  /// R30 a link · Inter 13 / 400 tabular (decision 0277).
  static final TextStyle codeSm = LoopTypography.code(13, height: 1.35);
}

/// Retired alias layer (decision 0189). These are [LoopType] steps under the
/// names some feature slices and the Stream chat theme still call; `lib/widgets`
/// no longer does, and every `lib/features` call is counted in G1's shrinking
/// allowlist. New code takes the [LoopType] step itself.
abstract final class LoopMono {
  /// Retired: [LoopType.figureXl].
  static final TextStyle display = LoopType.figureXl;

  /// Retired: [LoopType.figureLg].
  static final TextStyle headline = LoopType.figureLg;

  /// Retired: [LoopType.figure].
  static final TextStyle value = LoopType.figure;

  /// Retired: [LoopType.figureSm].
  static final TextStyle body = LoopType.figureSm;

  /// Retired: [LoopType.eyebrow].
  static final TextStyle label = LoopType.eyebrow;

  /// Retired: [LoopType.figureXs].
  static final TextStyle stamp = LoopType.figureXs;

  /// Retired: [LoopType.code].
  static final TextStyle address = LoopType.code;
}

abstract final class LoopTheme {
  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: LoopColors.yellow,
      onPrimary: LoopColors.onYellow,
      secondary: LoopColors.purple,
      onSecondary: LoopColors.chalk,
      surface: LoopColors.graphite,
      onSurface: LoopColors.chalk,
      outline: LoopColors.divider,
      outlineVariant: LoopColors.cardEdge,
      error: LoopColors.danger,
    ).copyWith(tertiary: LoopColors.purple, onTertiary: LoopColors.chalk);

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
      // Band 4 · body. `bodyLarge` is the slot a bare `TextField` draws in,
      // so it is the input step (R25, decision 0189).
      bodyLarge: LoopType.bodyLg,
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
      // Decision 0130: an iOS-style pressed wash on both platforms, never a
      // Material ripple. Every InkWell that does not say otherwise highlights
      // while held and splashes nothing.
      splashFactory: NoSplash.splashFactory,
      highlightColor: LoopColors.pressHighlight,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
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
      dividerColor: LoopColors.divider,
      dividerTheme: const DividerThemeData(
        color: LoopColors.divider,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: LoopTouch.tabBarHeight,
        elevation: 0,
        backgroundColor: LoopColors.ink,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? LoopColors.yellow
                : LoopColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return LoopType.navLabel.copyWith(
            color: states.contains(WidgetState.selected)
                ? LoopColors.yellow
                : LoopColors.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: LoopColors.ink,
        indicatorColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(
          color: LoopColors.yellow,
          size: 21,
        ),
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
        fillColor: LoopColors.input,
        // R25: a field's placeholder and floating label are the input step,
        // the same size as what is typed into it (decision 0189).
        hintStyle: LoopType.bodyLg.copyWith(color: LoopColors.text3),
        labelStyle: LoopType.bodyLg.copyWith(color: LoopColors.text3),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        // Decision 0211: a field is a filled ground with no edge until it
        // takes focus, when it draws 1px Purple.
        border: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.purple),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.danger),
        ),
        // UX-008 (decision 0254): every state of a field keeps the 12 corner,
        // so a field never squares off while it is disabled or focused with
        // an error.
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.danger),
        ),
        disabledBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LoopColors.yellow,
          foregroundColor: LoopColors.onYellow,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.button),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LoopColors.chalk,
          backgroundColor: LoopColors.card2,
          minimumSize: const Size(LoopTouch.minimum, LoopTouch.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide.none,
          shape: const RoundedRectangleBorder(borderRadius: LoopRadius.button),
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
      // Decision 0277: a chip is the Figma's filter chip — white 4 % idle,
      // white 10 % chosen with a white word, an 8 corner.
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        backgroundColor: LoopColors.chipIdle,
        selectedColor: LoopColors.chipActive,
        labelStyle: LoopType.chipIdle,
        secondaryLabelStyle: LoopType.chip,
        shape: const RoundedRectangleBorder(borderRadius: LoopRadius.chip),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      // A list tile's title stays prose (R18) now that `bodyLarge` is the
      // input step.
      listTileTheme: ListTileThemeData(
        titleTextStyle: LoopType.body,
        subtitleTextStyle: LoopType.bodySm,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LoopColors.graphite,
        modalBackgroundColor: LoopColors.graphite,
        modalBarrierColor: LoopColors.veil,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: LoopRadius.sheetTop),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: LoopColors.graphite,
        surfaceTintColor: Colors.transparent,
        barrierColor: LoopColors.veil,
        shape: RoundedRectangleBorder(borderRadius: LoopRadius.shell),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: LoopType.body,
        behavior: SnackBarBehavior.floating,
        backgroundColor: LoopColors.card2,
        shape: const RoundedRectangleBorder(borderRadius: LoopRadius.control),
      ),
      focusColor: LoopColors.purpleSoft,
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
  /// Retired alias for [LoopType.figure] (decision 0189).
  TextStyle get dataStyle => LoopType.figure;

  TextTheme get loopText => Theme.of(this).textTheme;
}

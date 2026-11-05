import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_widgets.dart'
    show confirmCommunityAction;
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_entry.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_gateway.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_editor.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

/// Replaces the square crop in a page test. Tests only.
@visibleForTesting
Future<Uint8List?> Function(BuildContext context, Uint8List bytes)?
debugLaunch2CropOverride;

/// The three steps of `launch2-create`.
/// Decision 0202: step 2 holds only the outside links, so it is named for
/// them; binding a community is done on the community side.
List<String> get launch2CreateSteps => <String>[
  LoopL10n.current.common_profile,
  LoopL10n.current.common_link,
  LoopL10n.current.launch2Creator_launch2CreateText,
];

/// Step 2's heading, its line, and the line on where a community is bound.
String get launch2CreateLinksHeading =>
    LoopL10n.current.launch2Creator_launch2CreateLaunch2CreateLinksHeading;
String get launch2CreateLinksLine =>
    LoopL10n.current.launch2Creator_launch2CreateLaunch2CreateLinksLine;
String get launch2CreateLinksCommunityHint => LoopL10n
    .current
    .launch2Creator_launch2CreateLaunch2CreateLinksCommunityHint;

/// The fields the form checks before the server does.
///
/// Decision 0284 (S359): [nftPrice] (whole USD1) and [walletCap] (per mille
/// of the supply) are the project's own terms; blank means the default.
enum Launch2Field {
  name,
  ticker,
  description,
  x,
  telegram,
  website,
  discord,
  nftPrice,
  walletCap,
}

/// Why a project-term field is refused (decision 0284), or `null`. Blank is
/// allowed: the server then uses the default.
String? launch2TermError(String raw, {required int min, required int max}) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
    return LoopL10n.current.launch2Creator_termsWholeNumbers;
  }
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < min || parsed > max) {
    return LoopL10n.current.launch2Creator_termsRange(min, max);
  }
  return null;
}

/// The whole number a valid, non-blank term field holds; otherwise `null`.
int? launch2TermValue(String raw) {
  final value = raw.trim();
  return RegExp(r'^[0-9]+$').hasMatch(value) ? int.tryParse(value) : null;
}

/// S257 (with loop-api S256): a name or ticker made only of marks,
/// variation selectors or stray tag characters passes the hazard rule but
/// draws nothing. Three more rules, checked after the existing ones:
/// ① at least one letter, number, symbol or punctuation
/// (`\p{L}\p{N}\p{S}\p{P}`); ② tag characters U+E0020–E007F only inside a
/// flag sequence that opens with U+1F3F4 and closes with U+E007F; ③ no
/// leading combining mark (`\p{M}`).
String get launch2NameInvisibleMessage =>
    LoopL10n.current.launch2Creator_launch2CreateLaunch2NameInvisibleMessage;
String get launch2TickerInvisibleMessage =>
    LoopL10n.current.launch2Creator_launch2CreateLaunch2TickerInvisibleMessage;

final RegExp _launch2Visible = RegExp(r'[\p{L}\p{N}\p{S}\p{P}]', unicode: true);
final RegExp _launch2TagFlag = RegExp(
  r'\u{1F3F4}[\u{E0020}-\u{E007E}]+\u{E007F}',
  unicode: true,
);
final RegExp _launch2Tag = RegExp(r'[\u{E0020}-\u{E007F}]', unicode: true);
final RegExp _launch2LeadingMark = RegExp(r'^\p{M}', unicode: true);

/// [message] when the trimmed [raw] breaks one of the three visible-text
/// rules, otherwise `null`. Empty input is the required rule's to report.
String? launch2VisibleTextError(String raw, String message) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (!_launch2Visible.hasMatch(value)) return message;
  if (_launch2Tag.hasMatch(value.replaceAll(_launch2TagFlag, ''))) {
    return message;
  }
  if (_launch2LeadingMark.hasMatch(value)) return message;
  return null;
}

/// Why one field is refused, or `null` (hooks-config §3 and the catalogue
/// project's own limits; the stricter of the two).
String? launch2FieldError(Launch2Field field, String raw) {
  final value = raw.trim();
  switch (field) {
    // Decisions 0199 / 0206: any script; the name and the ticker share
    // four.meme's 1–20 rule, and the ticker is kept as typed.
    case Launch2Field.name:
      return loopTokenNameError(raw) ??
          launch2VisibleTextError(raw, launch2NameInvisibleMessage);
    case Launch2Field.ticker:
      return loopTokenTickerError(raw) ??
          launch2VisibleTextError(raw, launch2TickerInvisibleMessage);
    case Launch2Field.description:
      return loopTokenDescriptionError(raw);
    case Launch2Field.x:
    case Launch2Field.telegram:
    case Launch2Field.website:
    case Launch2Field.discord:
      if (value.isEmpty) return null;
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          value.length < 9 ||
          value.length > 512) {
        return LoopL10n.current.launch2Creator_launch2CreateIf;
      }
    case Launch2Field.nftPrice:
      return launch2TermError(
        raw,
        min: Launch2ProjectTerms.minNftPriceUsd1,
        max: Launch2ProjectTerms.maxNftPriceUsd1,
      );
    case Launch2Field.walletCap:
      return launch2TermError(
        raw,
        min: Launch2ProjectTerms.minWalletCapPerMille,
        max: Launch2ProjectTerms.maxWalletCapPerMille,
      );
  }
  return null;
}

/// `launch2-create` · 发起 v2 发射 (archetype `action`, layout `focus`).
///
/// Three steps: ① picture, name, ticker, description; ② the community links;
/// ③ the NFT sale start, then the buyback recipient and the fixed template,
/// both read only (the recipient is the platform's fixed address, decision
/// 0144). 「提交审核」 creates (or edits) the catalogue project, saves the
/// Hooks draft and submits the project for review. With [projectId] the page
/// edits a draft, returned or rejected project (or a rejected launch
/// configuration) and starts from what the server holds.
class Launch2CreateScreen extends ConsumerStatefulWidget {
  const Launch2CreateScreen({
    super.key,
    this.projectId,
    this.onBack,
    this.onSubmitted,
    this.onOpenMyProjects,
    this.clock,
  });

  final String? projectId;
  final VoidCallback? onBack;
  final void Function(String projectId)? onSubmitted;

  /// 「我的项目」 in the top bar of a new launch (S294 · decision 0244);
  /// absent, or on the edit form (reached from 我的项目), it is not drawn.
  final VoidCallback? onOpenMyProjects;
  final DateTime Function()? clock;

  @override
  ConsumerState<Launch2CreateScreen> createState() =>
      _Launch2CreateScreenState();
}

class _Launch2CreateScreenState extends ConsumerState<Launch2CreateScreen> {
  final _name = TextEditingController();
  final _ticker = TextEditingController();
  final _description = TextEditingController();
  final _x = TextEditingController();
  final _telegram = TextEditingController();
  final _website = TextEditingController();
  final _discord = TextEditingController();
  final _nftPrice = TextEditingController();
  final _walletCap = TextEditingController();

  int _step = 0;
  bool _showErrors = false;
  DateTime? _saleStart;
  bool _saleStartMissing = false;

  String? _logoUrl;
  bool _uploading = false;
  String? _uploadFailure;

  /// Decision 0233: the image the project's NFT shows in the wallet,
  /// uploaded beside the logo through the same media endpoint.
  String? _nftImageUrl;
  bool _nftUploading = false;
  String? _nftUploadFailure;

  /// A new project cannot leave the first step without an NFT image; an
  /// older draft being edited may still have none (the server keeps the
  /// key optional), so there it is offered, not demanded.
  bool get _nftImageRequired => widget.projectId == null;

  bool _prefilled = false;

  /// Decision 0200: the rejection the edit answers, shown above the form.
  /// `null` for a new project and for one that is not rejected.
  LaunchRejection? _rejection;
  bool _rejectedConfiguration = false;
  String? _returnedReason;
  LaunchProject? _existing;
  Launch2HooksDraft? _existingDraft;

  /// The server's sale lead (`hooks-config.minSaleLeadSeconds`), once read:
  /// from the project being edited, or from the save's own read.
  Duration? _minSaleLead;

  /// The platform's fixed recipient from the project being edited
  /// (`hooks-config.fixedBuybackRecipient`); `null` until a config was read.
  String? _fixedRecipient;
  bool _fixedRecipientRead = false;

  List<TextEditingController> get _controllers => <TextEditingController>[
    _name,
    _ticker,
    _description,
    _x,
    _telegram,
    _website,
    _discord,
    _nftPrice,
    _walletCap,
  ];

  DateTime get _now => (widget.clock ?? DateTime.now)();

  String get _scope => widget.projectId ?? 'new';

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_changed)
        ..dispose();
    }
    super.dispose();
  }

  /// Set while the page fills the fields from the server's copy, which is
  /// not an edit.
  bool _silenced = false;

  void _changed() {
    if (_silenced) return;
    ref.read(launch2SaveControllerProvider(_scope).notifier).contentChanged();
    setState(() {});
  }

  TextEditingController _controller(Launch2Field field) => switch (field) {
    Launch2Field.name => _name,
    Launch2Field.ticker => _ticker,
    Launch2Field.description => _description,
    Launch2Field.x => _x,
    Launch2Field.telegram => _telegram,
    Launch2Field.website => _website,
    Launch2Field.discord => _discord,
    Launch2Field.nftPrice => _nftPrice,
    Launch2Field.walletCap => _walletCap,
  };

  /// Decision 0206: the name and the ticker count UTF-16 units once
  /// trimmed (a Chinese character 1, most emoji 2), as four.meme does; a
  /// `maxLength` would count grapheme clusters instead, so neither has one.
  String _unitsCounter(TextEditingController controller) =>
      '${loopTokenTextUnits(controller.text)}/$loopTokenTextMaxUnits';

  /// The description's limit, counted as its `maxLength` counts.
  static const int _descriptionMax = 2000;

  /// The ticker field's `$`, shown only where [loopTickerLabel] adds one.
  String? get _tickerPrefix {
    final ticker = _ticker.text.trim();
    return ticker.isNotEmpty && loopTickerLabel(ticker) != ticker ? r'$' : null;
  }

  String? _error(Launch2Field field) =>
      _showErrors ? launch2FieldError(field, _controller(field).text) : null;

  static const List<List<Launch2Field>> _stepFields = <List<Launch2Field>>[
    <Launch2Field>[
      Launch2Field.name,
      Launch2Field.ticker,
      Launch2Field.description,
    ],
    <Launch2Field>[
      Launch2Field.x,
      Launch2Field.telegram,
      Launch2Field.website,
      Launch2Field.discord,
    ],
    <Launch2Field>[Launch2Field.nftPrice, Launch2Field.walletCap],
  ];

  bool _stepValid(int step) {
    for (final field in _stepFields[step]) {
      if (launch2FieldError(field, _controller(field).text) != null) {
        return false;
      }
    }
    if (step == 0 && _logoUrl == null) return false;
    if (step == 0 && _nftImageRequired && _nftImageUrl == null) return false;
    if (step == 2 && _saleStart == null) return false;
    return true;
  }

  bool get _hasInput =>
      _logoUrl != null ||
      _nftImageUrl != null ||
      _saleStart != null ||
      <TextEditingController>[
        _name,
        _ticker,
        _description,
        _x,
        _telegram,
        _website,
        _discord,
        _nftPrice,
        _walletCap,
      ].any((controller) => controller.text.trim().isNotEmpty);

  bool get _saving => ref.read(launch2SaveControllerProvider(_scope)).busy;

  Future<void> _back() async {
    if (_saving) return;
    if (_step > 0) {
      setState(() {
        _step -= 1;
        _showErrors = false;
      });
      return;
    }
    if (_hasInput && widget.projectId == null) {
      final abandon = await confirmCommunityAction(
        context,
        title: LoopL10n.current.launch2Creator_launch2CreateTitle,
        body: LoopL10n.current.launch2Creator_launch2CreateBody,
        confirmLabel: LoopL10n.current.launch2Creator_launch2CreateConfirmLabel,
        cancelLabel: LoopL10n.current.launch2Creator_launch2CreateCancelLabel,
        sheetKey: 'launch2-create-abandon-sheet',
      );
      if (!abandon || !mounted) return;
    }
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (!_stepValid(_step)) {
      setState(() {
        _showErrors = true;
        _saleStartMissing = _step == 2 && _saleStart == null;
      });
      return;
    }
    if (_step < 2) {
      setState(() {
        _step += 1;
        _showErrors = false;
      });
      return;
    }
    unawaited(_submit());
  }

  String? _link(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    final start = _saleStart;
    final logo = _logoUrl;
    if (start == null || logo == null) return;
    final links = LaunchOfficialLinks(
      website: _link(_website),
      x: _link(_x),
      telegram: _link(_telegram),
      discord: _link(_discord),
    );
    final description = _description.text.trim();
    final ticker = _ticker.text.trim();
    final name = _name.text.trim();
    final id = await ref
        .read(launch2SaveControllerProvider(_scope).notifier)
        .save(
          project: LaunchProjectDraft(
            name: name,
            ticker: ticker,
            narrative: description.isEmpty ? null : description,
            officialLinks: links,
          ),
          now: _now,
          config: Launch2ConfigInput(
            name: name,
            ticker: ticker,
            logoAssetUrl: logo,
            nftImageAssetUrl: _nftImageUrl,
            description: description,
            links: <String>[for (final (_, url) in links.entries) url],
            nftSaleStart: start,
            // Shown read only; the controller sends the address the server
            // names just before the save (decision 0144).
            buybackRecipient: _shownRecipient ?? '',
            nftPriceUsd1: launch2TermValue(_nftPrice.text),
            walletCapPerMille: launch2TermValue(_walletCap.text),
          ),
          existing: _existing,
        );
    if (id != null && mounted) widget.onSubmitted?.call(id);
  }

  Future<void> _upload() => _uploadSquare(nft: false);

  Future<void> _uploadNft() => _uploadSquare(nft: true);

  /// Picks, crops and uploads one square image: the logo, or with [nft]
  /// the NFT image (decision 0233) — the same picker, crop and endpoint.
  Future<void> _uploadSquare({required bool nft}) async {
    if (nft ? _nftUploading : _uploading) return;
    void busy(bool value) => nft ? _nftUploading = value : _uploading = value;
    void failed(String? value) =>
        nft ? _nftUploadFailure = value : _uploadFailure = value;
    setState(() {
      busy(true);
      failed(null);
    });
    try {
      final picked = await ref.read(avatarImagePickerProvider).pick();
      if (picked == null || !mounted) return;
      final crop = debugLaunch2CropOverride ?? showAvatarCropDialog;
      final square = await crop(context, picked.bytes);
      if (square == null || !mounted) return;
      // Decision 0233: the NFT image is its own media kind
      // ([launch2NftImageMediaKind]); the logo stays a community logo.
      final uploaded = nft
          ? await ref
                .read(launch2NftImageUploaderProvider)
                .upload(bytes: square, contentType: 'image/png')
          : await ref
                .read(memeGatewayProvider)
                .uploadImage(bytes: square, contentType: 'image/png');
      if (!mounted) return;
      setState(
        () => nft ? _nftImageUrl = uploaded.url : _logoUrl = uploaded.url,
      );
      ref.read(launch2SaveControllerProvider(_scope).notifier).contentChanged();
    } on LoopChainException catch (failure) {
      if (mounted) {
        setState(
          () => failed(
            LoopL10n.current.launch2Creator_launch2CreateFailed(
              memeFailureText(failure),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => failed(
            avatarUploadFailureReason(AvatarUploadFailureKind.unexpected),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy(false));
    }
  }

  Duration? get _knownLead =>
      ref.read(launch2SaveControllerProvider(_scope)).minSaleLead ??
      _minSaleLead;

  /// Now + the server's lead, rounded up to the minute (decision 0142). A
  /// project not created yet has no config to read: the contract floor.
  DateTime _earliest() => launch2EarliestSaleStart(
    _now,
    _knownLead ?? Launch2Template.contractMinimumSaleLead,
  );

  static String _leadLabel(Duration lead) {
    final minutes = (lead.inSeconds + 59) ~/ 60;
    if (minutes % 60 == 0) {
      return LoopL10n.current.launch2Creator_launch2CreateLeadLabel(
        minutes ~/ 60,
      );
    }
    return LoopL10n.current.launch2Creator_launch2CreateLeadLabel2(minutes);
  }

  Future<void> _pickSaleStart() async {
    final earliest = _earliest();
    final lead = _knownLead;
    final initial =
        _saleStart ??
        _now
            .add(Launch2Template.suggestedSaleLead)
            .copyWith(minute: 0, second: 0, millisecond: 0, microsecond: 0);
    var chosen = initial.isBefore(earliest) ? earliest : initial;
    final picked = await showLoopSheet<DateTime>(
      context,
      builder: (context) => Column(
        key: const ValueKey<String>('launch2-sale-start-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopSheetHeading(
            context.l10n.launch2Creator_launch2CreateLoopSheetHeading,
          ),
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: CupertinoDatePicker(
                key: const ValueKey<String>('launch2-sale-start-picker'),
                initialDateTime: chosen.toLocal(),
                minimumDate: earliest.toLocal(),
                use24hFormat: true,
                minuteInterval: 1,
                onDateTimeChanged: (value) => chosen = value,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              8,
              LoopSpacing.page,
              4,
            ),
            child: Text(
              lead == null
                  ? context
                        .l10n
                        .launch2Creator_launch2CreateLaunch2SaleStartHint
                  : context.l10n
                        .launch2Creator_launch2CreateLaunch2SaleStartHint2(
                          _leadLabel(lead),
                          loopLocalTimestampLabel(earliest),
                        ),
              key: const ValueKey<String>('launch2-sale-start-hint'),
              style: LoopType.captionSm.copyWith(color: LoopColors.text3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              16,
              LoopSpacing.page,
              16,
            ),
            child: LoopButton(
              key: const ValueKey<String>('launch2-sale-start-confirm'),
              label: context.l10n.common_ok,
              primary: true,
              block: true,
              onPressed: () => Navigator.of(context).pop(chosen),
            ),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _saleStart = picked.toUtc();
      _saleStartMissing = false;
    });
    ref.read(launch2SaveControllerProvider(_scope).notifier).contentChanged();
  }

  void _prefill(Launch2CreatorProject value) {
    if (_prefilled) return;
    _prefilled = true;
    final project = value.project;
    final draft = value.draft;
    _existing = project;
    _existingDraft = draft;
    if (value.status == Launch2CreatorStatus.rejected) {
      _rejection = value.rejection;
      _rejectedConfiguration =
          project.reviewStatus != LaunchReviewStatus.rejected &&
          project.reviewStatus != LaunchReviewStatus.returned;
      _returnedReason = project.reviewReasonText;
    }
    _minSaleLead = value.config.minSaleLead;
    _fixedRecipient = value.config.fixedBuybackRecipient;
    _fixedRecipientRead = true;
    _silenced = true;
    _name.text = draft?.name ?? project.name;
    _ticker.text = draft?.ticker ?? project.ticker;
    _description.text = draft?.description ?? project.narrative ?? '';
    _x.text = project.officialLinks.x ?? '';
    _telegram.text = project.officialLinks.telegram ?? '';
    _website.text = project.officialLinks.website ?? '';
    _discord.text = project.officialLinks.discord ?? '';
    if (draft != null) {
      _logoUrl = draft.logoAssetUrl;
      _nftImageUrl = draft.nftImageAssetUrl;
      _saleStart = draft.nftSaleStart;
      if (draft.nftPriceUsd1 case final int price) {
        _nftPrice.text = '$price';
      }
      if (draft.walletCapPerMille case final int cap) {
        _walletCap.text = '$cap';
      }
    }
    _silenced = false;
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId;
    final save = ref.watch(launch2SaveControllerProvider(_scope));
    if (projectId != null && !_prefilled) {
      final provider = launch2ProjectControllerProvider(projectId);
      final state = ref.watch(provider);
      if (state.phase == LoopChainViewPhase.loading && state.value == null) {
        scheduleMicrotask(() {
          if (mounted) unawaited(ref.read(provider.notifier).load());
        });
      }
      final value = state.value;
      if (value != null) {
        _prefill(value);
      } else {
        return LoopFocusPage(
          key: const ValueKey<String>('launch2-create-screen'),
          archetype: LoopPageArchetype.action,
          title:
              context.l10n.launch2Creator_launch2CreateLaunch2CreateScreenTitle,
          onBack: widget.onBack,
          body: <Widget>[
            LoopChainStateBlock(
              keyPrefix: 'launch2-create-load',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage:
                  context.l10n.launch2Creator_launch2CreateEmptyMessage,
              onRetry: () => unawaited(ref.read(provider.notifier).reload()),
            ),
          ],
        );
      }
    }

    final page = LoopFocusPage(
      key: const ValueKey<String>('launch2-create-screen'),
      archetype: LoopPageArchetype.action,
      title: projectId == null
          ? context.l10n.launch2Creator_launch2CreateLaunch2CreateScreenTitle2
          : context.l10n.launch2Creator_launch2CreateLaunch2CreateScreenTitle,
      onBack: () => unawaited(_back()),
      actions: <Widget>[
        if (projectId == null && widget.onOpenMyProjects != null)
          Launch2MyProjectsAction(onPressed: widget.onOpenMyProjects!),
      ],
      keyboardAccessory: true,
      primaryAction: LoopButton(
        key: const ValueKey<String>('launch2-create-next'),
        label: _step < 2
            ? context.l10n.common_next
            : save.busy
            ? switch (save.stage) {
                Launch2SaveStage.project =>
                  context.l10n.launch2Creator_launch2CreateProject,
                Launch2SaveStage.config =>
                  context.l10n.launch2Creator_launch2CreateConfig,
                _ => context.l10n.launch2Creator_launch2CreateLoopButton,
              }
            : (save.phase == Launch2SavePhase.failed
                  ? context.l10n.launch2Creator_launch2CreateLabel
                  : context.l10n.launch2Creator_launch2CreateLabel2),
        primary: true,
        block: true,
        onPressed: save.busy || _uploading ? null : _next,
      ),
      body: <Widget>[
        ..._rejectionBanner(),
        ...switch (_step) {
          0 => _profileStep(),
          1 => _linksStep(),
          _ => _saleStep(save),
        },
      ],
    );
    // S326 · decision 0256 (UX-006): the steps are an equal-segment bar
    // across the top of the page, over the title bar, as in the sign-in
    // flow; the dots under the title are gone.
    final padding = MediaQuery.paddingOf(context);
    final framed = ColoredBox(
      color: LoopColors.ink,
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              padding.top + 8,
              LoopSpacing.page,
              4,
            ),
            child: Launch2CreateStepBar(
              key: ValueKey<String>('launch2-create-step-${_step + 1}'),
              labels: launch2CreateSteps,
              current: _step,
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: page,
            ),
          ),
        ],
      ),
    );
    return PopScope(
      canPop: _step == 0 && !_hasInput && !save.busy,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_back());
      },
      child: framed,
    );
  }

  /// Decision 0200: what the reviewer said, on every step of the edit, so
  /// the owner fixes it without going back to the project page. A resubmitted
  /// version is awaiting review again and the banner is gone.
  List<Widget> _rejectionBanner() {
    final rejection = _rejection;
    if (rejection != null) {
      return <Widget>[
        KeyedSubtree(
          key: const ValueKey<String>('launch2-create-rejection'),
          child: Launch2RejectionNotice(
            rejection: rejection,
            configuration: _rejectedConfiguration,
          ),
        ),
      ];
    }
    final reason = _returnedReason;
    if (reason == null) return const <Widget>[];
    return <Widget>[
      LoopNotice(
        key: const ValueKey<String>('launch2-create-rejection'),
        icon: 'warn',
        tone: LoopNoticeTone.warn,
        title: LoopL10n
            .current
            .launch2Creator_launch2CreateLaunch2CreateRejectionTitle,
        body: reason,
      ),
    ];
  }

  /// One field (S326 · decision 0256): its title on the left above the
  /// box, the count at the right of the same line, then the box.
  Widget _field(
    Launch2Field field, {
    required String label,
    String? hint,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? prefix,
    String? counter,
  }) => Column(
    key: ValueKey<String>('launch2-create-${field.name}-block'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              key: ValueKey<String>('launch2-create-${field.name}-label'),
              style: _fieldTitleStyle,
            ),
          ),
          if (counter != null)
            Text(
              counter,
              key: ValueKey<String>('launch2-create-${field.name}-counter'),
              style: LoopType.captionSm.copyWith(color: LoopColors.text3),
            ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        key: ValueKey<String>('launch2-create-${field.name}'),
        controller: _controller(field),
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: 1,
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.none,
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          counterText: '',
          errorText: _error(field),
        ),
      ),
    ],
  );

  /// A field's or a picture's title: 14 / 600 Chalk.
  static final TextStyle _fieldTitleStyle = LoopTypography.withWeight(
    LoopType.label,
    FontWeight.w600,
  ).copyWith(color: LoopColors.chalk);

  /// A group's title on the profile step (「图片资料」, 「基础信息」).
  Widget _groupTitle(String text, {required double top}) => Padding(
    padding: EdgeInsets.fromLTRB(LoopSpacing.page, top, LoopSpacing.page, 12),
    child: Semantics(
      header: true,
      child: Text(
        text,
        key: ValueKey<String>('launch2-create-group-$text'),
        // S370a · decision 0293: a small block's title, 16 / 700
        // (docs/58 §9.2 headlineSm, 类推 热门社区).
        style: LoopType.headlineSm,
      ),
    ),
  );

  /// A picture's title with its one line under it.
  Widget _pictureHeading(String title, Widget line) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: _fieldTitleStyle),
        const SizedBox(height: 2),
        line,
      ],
    ),
  );

  /// Step 1 (S326 · decision 0256, UX-006): two groups with left-aligned
  /// titles — 「图片资料」 (the logo and the NFT image, each a placeholder
  /// that is its own upload control) and 「基础信息」 (name, ticker,
  /// description, each titled above its box with the count beside the
  /// title). 24 between the groups, 20 between two pictures, 12 inside.
  List<Widget> _profileStep() {
    final picker = ref.watch(avatarImagePickerProvider);
    final ticker = _ticker.text.trim();
    final logoMissing = _showErrors && _logoUrl == null;
    final nftMissing = _showErrors && _nftImageRequired && _nftImageUrl == null;
    final logoUrl = _logoUrl;
    Widget note(String text, {Key? key, bool alert = false}) => Text(
      text,
      key: key,
      style: LoopType.captionSm.copyWith(
        color: alert ? LoopColors.chalk : LoopColors.text3,
      ),
    );
    return <Widget>[
      _groupTitle(
        LoopL10n.current.launch2Creator_launch2CreateGroupTitle,
        top: 12,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _pictureHeading(
              LoopL10n
                  .current
                  .launch2Creator_launch2CreateLaunch2CreateLogoMissing,
              logoMissing
                  ? note(
                      LoopL10n
                          .current
                          .launch2Creator_launch2CreateLaunch2CreateLogoMissing2,
                      key: const ValueKey<String>(
                        'launch2-create-logo-missing',
                      ),
                      alert: true,
                    )
                  : note(LoopL10n.current.launch2Creator_launch2CreateNote),
            ),
            Launch2UploadSlot(
              key: const ValueKey<String>('launch2-create-upload'),
              previewKey: const ValueKey<String>('launch2-create-logo-preview'),
              size: 96,
              semanticLabel: LoopL10n
                  .current
                  .launch2Creator_launch2CreateLaunch2CreateLogoMissing,
              imageUrl: logoUrl,
              preview: logoUrl == null
                  ? null
                  : MemeLogo(
                      symbol: ticker,
                      imageUrl: logoUrl,
                      size: 96,
                      radius: 0,
                    ),
              missing: logoMissing,
              uploading: _uploading,
              onTap: picker.available && !_uploading
                  ? () => unawaited(_upload())
                  : null,
            ),
          ],
        ),
      ),
      if (_uploadFailure != null)
        LoopNotice(
          key: const ValueKey<String>('launch2-create-upload-failed'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: _uploadFailure!,
        ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _pictureHeading(
              _nftImageRequired
                  ? LoopL10n
                        .current
                        .launch2Creator_launch2CreateLaunch2CreateNftMissing
                  : LoopL10n
                        .current
                        .launch2Creator_launch2CreateLaunch2CreateNftMissing2,
              nftMissing
                  ? note(
                      LoopL10n
                          .current
                          .launch2Creator_launch2CreateLaunch2CreateNftMissing3,
                      key: const ValueKey<String>('launch2-create-nft-missing'),
                      alert: true,
                    )
                  : note(
                      launch2NftImageHelp,
                      key: const ValueKey<String>('launch2-create-nft-help'),
                    ),
            ),
            Launch2UploadSlot(
              key: const ValueKey<String>('launch2-create-nft-upload'),
              previewKey: const ValueKey<String>('launch2-create-nft-preview'),
              emptyKey: const ValueKey<String>('launch2-nft-image-empty'),
              size: 128,
              semanticLabel: LoopL10n
                  .current
                  .launch2Creator_launch2CreateLaunch2CreateNftMissing,
              imageUrl: _nftImageUrl,
              missing: nftMissing,
              uploading: _nftUploading,
              onTap: picker.available && !_nftUploading
                  ? () => unawaited(_uploadNft())
                  : null,
            ),
          ],
        ),
      ),
      if (_nftUploadFailure != null)
        LoopNotice(
          key: const ValueKey<String>('launch2-create-nft-upload-failed'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: _nftUploadFailure!,
        ),
      _groupTitle(
        LoopL10n.current.launch2Creator_launch2CreateGroupTitle2,
        top: 24,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _field(
              Launch2Field.name,
              label: LoopL10n.current.common_name,
              hint: LoopL10n.current.launch2Creator_launch2CreateHint,
              counter: _unitsCounter(_name),
            ),
            const SizedBox(height: 12),
            _field(
              Launch2Field.ticker,
              label: LoopL10n.current.launch2Creator_launch2CreateLabel3,
              hint: LoopL10n.current.launch2Creator_launch2CreateHint2,
              counter: _unitsCounter(_ticker),
              prefix: _tickerPrefix,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                loopTokenTextRule,
                key: const ValueKey<String>('launch2-create-text-rule'),
                style: LoopType.captionSm.copyWith(color: LoopColors.text3),
              ),
            ),
            const SizedBox(height: 12),
            _field(
              Launch2Field.description,
              label: LoopL10n.current.launch2Creator_launch2CreateLabel4,
              hint: LoopL10n.current.launch2Creator_launch2CreateHint3,
              maxLength: _descriptionMax,
              maxLines: 4,
              counter:
                  '${_description.text.characters.length}/$_descriptionMax',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ];
  }

  List<Widget> _linksStep() => <Widget>[
    LoopLabel(
      launch2CreateLinksHeading,
      key: ValueKey<String>('launch2-create-links-heading'),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            launch2CreateLinksLine,
            key: const ValueKey<String>('launch2-create-links-line'),
            style: LoopType.bodySm.copyWith(color: LoopColors.text2),
          ),
          const SizedBox(height: 4),
          Text(
            launch2CreateLinksCommunityHint,
            key: const ValueKey<String>('launch2-create-links-community-hint'),
            style: LoopType.caption.copyWith(color: LoopColors.text3),
          ),
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (field, label) in <(Launch2Field, String)>[
            (Launch2Field.x, LoopL10n.current.launch2Creator_launch2CreateFor),
            (
              Launch2Field.telegram,
              LoopL10n.current.launch2Creator_launch2CreateFor2,
            ),
            (
              Launch2Field.website,
              LoopL10n.current.launch2Creator_launch2CreateFor3,
            ),
            (
              Launch2Field.discord,
              LoopL10n.current.launch2Creator_launch2CreateFor4,
            ),
          ]) ...<Widget>[
            _field(
              field,
              label: label,
              hint: 'https://',
              keyboard: TextInputType.url,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  ];

  /// The address the form shows: the server's, once any `hooks-config` read
  /// named it; before a project exists, the requirer's fixed address.
  String? get _shownRecipient {
    final save = ref.read(launch2SaveControllerProvider(_scope));
    if (save.fixedBuybackRecipient case final String fixed) return fixed;
    if (_fixedRecipientRead) return _fixedRecipient;
    return Launch2Template.defaultBuybackRecipient;
  }

  /// A project-term field (decision 0284): whole numbers only, the default
  /// as its placeholder; blank sends nothing.
  Widget _termField(
    Launch2Field field, {
    required String label,
    required int placeholder,
  }) => _field(
    field,
    label: label,
    hint: '$placeholder',
    keyboard: TextInputType.number,
    formatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
  );

  /// The template card's figures with the terms as they stand in the form
  /// (decision 0284): a typed term over the saved draft's; a blank one is
  /// the default once the server speaks of terms, else the template's own.
  Launch2FixedEconomics _shownEconomics(Launch2HooksDraft? draft) {
    final base = draft?.projectEconomics ?? Launch2Template.v1;
    final serverTerms =
        draft != null &&
        (draft.nftPriceUsd1 != null || draft.walletCapPerMille != null);
    int? term(TextEditingController controller, Launch2Field field, int dflt) {
      if (launch2FieldError(field, controller.text) != null) return null;
      return launch2TermValue(controller.text) ?? (serverTerms ? dflt : null);
    }

    final cap = term(
      _walletCap,
      Launch2Field.walletCap,
      Launch2ProjectTerms.defaultWalletCapPerMille,
    );
    return base.withProjectTerms(
      nftPriceUsd1: term(
        _nftPrice,
        Launch2Field.nftPrice,
        Launch2ProjectTerms.defaultNftPriceUsd1,
      ),
      capRaw: cap == null ? null : Launch2ProjectTerms.walletCapRaw(cap),
    );
  }

  List<Widget> _saleStep(Launch2SaveState save) {
    final start = _saleStart;
    final failure = save.failure;
    final draft = _existingDraft;
    return <Widget>[
      LoopLabel(LoopL10n.current.launch2Creator_launch2CreateLoopSheetHeading),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          16,
        ),
        child: LoopButton(
          key: const ValueKey<String>('launch2-create-sale-start'),
          label: start == null
              ? LoopL10n
                    .current
                    .launch2Creator_launch2CreateLaunch2CreateSaleStartLabel
              : launch2SaleStartLabel(start, _now),
          icon: 'clock',
          block: true,
          onPressed: save.busy ? null : () => unawaited(_pickSaleStart()),
        ),
      ),
      if (_saleStartMissing)
        LoopNotice(
          key: ValueKey<String>('launch2-create-sale-start-missing'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: LoopL10n
              .current
              .launch2Creator_launch2CreateLaunch2CreateSaleStartMissingBody,
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _termField(
              Launch2Field.nftPrice,
              label: LoopL10n.current.launch2Creator_termsNftPriceLabel,
              placeholder: Launch2ProjectTerms.defaultNftPriceUsd1,
            ),
            const SizedBox(height: 12),
            _termField(
              Launch2Field.walletCap,
              label: LoopL10n.current.launch2Creator_termsWalletCapLabel,
              placeholder: Launch2ProjectTerms.defaultWalletCapPerMille,
            ),
          ],
        ),
      ),
      LoopLabel(LoopL10n.current.launch2Creator_launch2CreateLoopLabel),
      Launch2FixedRecipient(address: _shownRecipient),
      const SizedBox(height: 16),
      LoopLabel(LoopL10n.current.launch2Creator_launch2CreateLoopLabel2),
      Launch2TemplateCard(
        economics: _shownEconomics(draft),
        fromServer: draft != null,
      ),
      if (save.earliestSaleStart case final DateTime earliest)
        LoopNotice(
          key: const ValueKey<String>('launch2-create-sale-too-early'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: LoopL10n.current
              .launch2Creator_launch2CreateLaunch2CreateSaleTooEarlyBody(
                _leadLabel(save.minSaleLead ?? Duration.zero),
                loopLocalTimestampLabel(earliest),
              ),
        ),
      if (failure != null)
        LoopNotice(
          key: ValueKey<String>(
            'launch2-create-failed-${save.stage?.name ?? 'project'}',
          ),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: launch2FailureText(failure),
        ),
    ];
  }
}

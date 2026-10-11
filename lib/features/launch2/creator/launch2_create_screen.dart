import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_widgets.dart'
    show confirmCommunityAction;
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_controllers.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_widgets.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_editor.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

/// Replaces the square crop in a page test. Tests only.
@visibleForTesting
Future<Uint8List?> Function(BuildContext context, Uint8List bytes)?
debugLaunch2CropOverride;

/// The three steps of `launch2-create`.
const List<String> launch2CreateSteps = <String>['资料', '社区', '发售'];

/// The fields the form checks before the server does.
enum Launch2Field { name, ticker, description, x, telegram, website, discord }

final RegExp _tickerPattern = RegExp(r'^[A-Z0-9]{2,12}$');

/// Why one field is refused, or `null` (hooks-config §3 and the catalogue
/// project's own limits; the stricter of the two).
String? launch2FieldError(Launch2Field field, String raw) {
  final value = raw.trim();
  switch (field) {
    case Launch2Field.name:
      if (value.isEmpty || value.length > 64) return '名称 1–64 个字符';
    case Launch2Field.ticker:
      if (!_tickerPattern.hasMatch(value.toUpperCase())) {
        return '代码 2–12 位字母或数字';
      }
    case Launch2Field.description:
      if (value.length > 2000) return '简介最多 2000 字';
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
        return '只支持 https:// 开头的链接';
      }
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
    this.clock,
  });

  final String? projectId;
  final VoidCallback? onBack;
  final void Function(String projectId)? onSubmitted;
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

  int _step = 0;
  bool _showErrors = false;
  DateTime? _saleStart;
  bool _saleStartMissing = false;

  String? _logoUrl;
  bool _uploading = false;
  String? _uploadFailure;

  bool _prefilled = false;
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
  };

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
    <Launch2Field>[],
  ];

  bool _stepValid(int step) {
    for (final field in _stepFields[step]) {
      if (launch2FieldError(field, _controller(field).text) != null) {
        return false;
      }
    }
    if (step == 0 && _logoUrl == null) return false;
    if (step == 2 && _saleStart == null) return false;
    return true;
  }

  bool get _hasInput =>
      _logoUrl != null ||
      _saleStart != null ||
      <TextEditingController>[
        _name,
        _ticker,
        _description,
        _x,
        _telegram,
        _website,
        _discord,
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
        title: '放弃发起？',
        body: '已填写的内容不会保存。',
        confirmLabel: '放弃',
        cancelLabel: '继续编辑',
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
    final ticker = _ticker.text.trim().toUpperCase();
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
            description: description,
            links: <String>[for (final (_, url) in links.entries) url],
            nftSaleStart: start,
            // Shown read only; the controller sends the address the server
            // names just before the save (decision 0144).
            buybackRecipient: _shownRecipient ?? '',
          ),
          existing: _existing,
        );
    if (id != null && mounted) widget.onSubmitted?.call(id);
  }

  Future<void> _upload() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _uploadFailure = null;
    });
    try {
      final picked = await ref.read(avatarImagePickerProvider).pick();
      if (picked == null || !mounted) return;
      final crop = debugLaunch2CropOverride ?? showAvatarCropDialog;
      final square = await crop(context, picked.bytes);
      if (square == null || !mounted) return;
      final uploaded = await ref
          .read(memeGatewayProvider)
          .uploadImage(bytes: square, contentType: 'image/png');
      if (!mounted) return;
      setState(() => _logoUrl = uploaded.url);
      ref.read(launch2SaveControllerProvider(_scope).notifier).contentChanged();
    } on LoopChainException catch (failure) {
      if (mounted) {
        setState(() => _uploadFailure = '图片没有上传成功：${memeFailureText(failure)}');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _uploadFailure = avatarUploadFailureReason(
            AvatarUploadFailureKind.unexpected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
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
    if (minutes % 60 == 0) return '${minutes ~/ 60} 小时';
    return '$minutes 分钟';
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
          const LoopSheetHeading('NFT 开售时间'),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              lead == null
                  ? '最早可选时间由平台决定，太早会被退回。'
                  : '平台要求至少提前 ${_leadLabel(lead)}开售，最早 '
                        '${loopLocalTimestampLabel(earliest)}。',
              key: const ValueKey<String>('launch2-sale-start-hint'),
              style: LoopType.captionSm.copyWith(color: LoopColors.text3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LoopButton(
              key: const ValueKey<String>('launch2-sale-start-confirm'),
              label: '确定',
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
      _saleStart = draft.nftSaleStart;
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
          title: '修改资料',
          onBack: widget.onBack,
          body: <Widget>[
            LoopChainStateBlock(
              keyPrefix: 'launch2-create-load',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '找不到这个项目',
              onRetry: () => unawaited(ref.read(provider.notifier).reload()),
            ),
          ],
        );
      }
    }

    final page = LoopFocusPage(
      key: const ValueKey<String>('launch2-create-screen'),
      archetype: LoopPageArchetype.action,
      title: projectId == null ? '发起 v2 发射' : '修改资料',
      onBack: () => unawaited(_back()),
      keyboardAccessory: true,
      primaryAction: LoopButton(
        key: const ValueKey<String>('launch2-create-next'),
        label: _step < 2
            ? '下一步'
            : save.busy
            ? switch (save.stage) {
                Launch2SaveStage.project => '正在保存资料…',
                Launch2SaveStage.config => '正在保存配置…',
                _ => '正在提交审核…',
              }
            : (save.phase == Launch2SavePhase.failed ? '重试提交' : '提交审核'),
        primary: true,
        block: true,
        onPressed: save.busy || _uploading ? null : _next,
      ),
      body: <Widget>[
        Launch2StepDots(index: _step, labels: launch2CreateSteps),
        ...switch (_step) {
          0 => _profileStep(),
          1 => _communityStep(),
          _ => _saleStep(save),
        },
      ],
    );
    return PopScope(
      canPop: _step == 0 && !_hasInput && !save.busy,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_back());
      },
      child: page,
    );
  }

  Widget _field(
    Launch2Field field, {
    required String label,
    String? hint,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboard,
    String? prefix,
    bool upper = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: ValueKey<String>('launch2-create-${field.name}'),
      controller: _controller(field),
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: 1,
      keyboardType: keyboard,
      textCapitalization: upper
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        errorText: _error(field),
      ),
    ),
  );

  List<Widget> _profileStep() {
    final picker = ref.watch(avatarImagePickerProvider);
    final ticker = _ticker.text.trim().toUpperCase();
    final logoMissing = _showErrors && _logoUrl == null;
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          4,
          LoopSpacing.page,
          12,
        ),
        child: Row(
          children: <Widget>[
            MemeLogo(
              key: const ValueKey<String>('launch2-create-logo-preview'),
              symbol: ticker,
              imageUrl: _logoUrl,
              size: 72,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LoopButton(
                    key: const ValueKey<String>('launch2-create-upload'),
                    label: _uploading
                        ? '上传中…'
                        : (_logoUrl == null ? '上传头像' : '换一张'),
                    icon: 'camera',
                    onPressed: picker.available && !_uploading
                        ? () => unawaited(_upload())
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    logoMissing ? '发射需要一张方形头像' : '方形图片，上传前可裁剪。',
                    key: logoMissing
                        ? const ValueKey<String>('launch2-create-logo-missing')
                        : null,
                    style: LoopType.captionSm.copyWith(
                      color: logoMissing ? LoopColors.danger : LoopColors.text3,
                    ),
                  ),
                ],
              ),
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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _field(
              Launch2Field.name,
              label: '名称',
              hint: '1–64 个字符',
              maxLength: 64,
            ),
            _field(
              Launch2Field.ticker,
              label: '代码',
              hint: '2–12 位字母或数字',
              maxLength: 12,
              prefix: r'$',
              upper: true,
            ),
            _field(
              Launch2Field.description,
              label: '简介（可不填）',
              maxLength: 2000,
              maxLines: 4,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _communityStep() => <Widget>[
    Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        12,
      ),
      child: Text(
        '绑定项目的社区，审核与用户都会看到。',
        style: LoopType.bodySm.copyWith(color: LoopColors.text2),
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (field, label) in const <(Launch2Field, String)>[
            (Launch2Field.x, 'X（可不填）'),
            (Launch2Field.telegram, 'Telegram（可不填）'),
            (Launch2Field.website, '官网（可不填）'),
            (Launch2Field.discord, 'Discord（可不填）'),
          ])
            _field(
              field,
              label: label,
              hint: 'https://',
              keyboard: TextInputType.url,
            ),
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

  List<Widget> _saleStep(Launch2SaveState save) {
    final start = _saleStart;
    final failure = save.failure;
    final draft = _existingDraft;
    return <Widget>[
      const LoopLabel('NFT 开售时间'),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          16,
        ),
        child: LoopButton(
          key: const ValueKey<String>('launch2-create-sale-start'),
          label: start == null ? '选择开售时间' : launch2SaleStartLabel(start, _now),
          icon: 'clock',
          block: true,
          onPressed: save.busy ? null : () => unawaited(_pickSaleStart()),
        ),
      ),
      if (_saleStartMissing)
        const LoopNotice(
          key: ValueKey<String>('launch2-create-sale-start-missing'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: '请先选择 NFT 开售时间。',
        ),
      const LoopLabel('回购收币地址'),
      Launch2FixedRecipient(address: _shownRecipient),
      const SizedBox(height: 16),
      const LoopLabel('发射模板'),
      Launch2TemplateCard(
        economics: draft?.economics ?? Launch2Template.v1,
        fromServer: draft != null,
      ),
      if (save.earliestSaleStart case final DateTime earliest)
        LoopNotice(
          key: const ValueKey<String>('launch2-create-sale-too-early'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body:
              '开售时间太早：平台要求至少提前 '
              '${_leadLabel(save.minSaleLead ?? Duration.zero)}，'
              '最早 ${loopLocalTimestampLabel(earliest)}，请重新选择。',
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

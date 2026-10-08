import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/meme/meme_controllers.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_launchpad.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_signing.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_editor.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Replaces the square crop in a page test, which has no image codec to run
/// the real one with. Tests only.
@visibleForTesting
Future<Uint8List?> Function(BuildContext context, Uint8List bytes)?
debugMemeCropOverride;

/// The three steps of `meme-create`, in order.
enum MemeCreateStep {
  profile('资料'),
  media('图片与链接'),
  confirm('确认');

  const MemeCreateStep(this.label);

  final String label;
}

/// The fields the form checks before the server does (contract §7).
enum MemeCreateField { name, symbol, description, twitter, telegram, website }

final RegExp _symbolPattern = RegExp(r'^[A-Z0-9]{2,10}$');

/// The reason one field is refused, or `null` when it passes.
String? memeCreateFieldError(MemeCreateField field, String raw) {
  final value = raw.trim();
  switch (field) {
    case MemeCreateField.name:
      if (value.isEmpty || value.runes.length > 32) return '名称 1–32 个字';
    case MemeCreateField.symbol:
      if (!_symbolPattern.hasMatch(value.toUpperCase())) {
        return '符号 2–10 位字母或数字';
      }
    case MemeCreateField.description:
      if (value.runes.length > 500) return '简介最多 500 字';
    case MemeCreateField.twitter:
    case MemeCreateField.telegram:
    case MemeCreateField.website:
      if (value.isEmpty) return null;
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return '只支持 https:// 开头的链接';
      }
  }
  return null;
}

/// `meme-create` · 创建代币 (archetype `action`, layout `focus`).
///
/// Three steps on one page with the progress dots on top: ① name, symbol and
/// description; ② the square picture and three optional links; ③ the
/// parameters, the predicted address with its tail highlighted, and an
/// optional first buy. Leaving step ② creates the server draft (it is what
/// predicts the address); 「创建」 prepares the create intent and goes through
/// the shared signing exit, approval first when there is a first buy. A
/// broadcast is 「已广播」; the page opens the token once the intent reads
/// `confirmed`.
class MemeCreateScreen extends ConsumerStatefulWidget {
  const MemeCreateScreen({
    super.key,
    this.draftId,
    this.onBack,
    this.onOpenToken,
    this.clock,
  });

  /// A draft this account already owns, resumed at the confirm step.
  final String? draftId;
  final VoidCallback? onBack;

  /// Opens the token page once the create intent is confirmed.
  final void Function(String memeTokenId)? onOpenToken;
  final DateTime Function()? clock;

  /// The scope of the one submission this page owns.
  static const String submissionScope = 'create';

  @override
  ConsumerState<MemeCreateScreen> createState() => _MemeCreateScreenState();
}

class _MemeCreateScreenState extends ConsumerState<MemeCreateScreen> {
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  final _description = TextEditingController();
  final _twitter = TextEditingController();
  final _telegram = TextEditingController();
  final _website = TextEditingController();
  final _firstBuy = TextEditingController();

  MemeCreateStep _step = MemeCreateStep.profile;
  bool _showErrors = false;

  String? _imageMediaId;
  String? _imageUrl;
  bool _uploading = false;
  AvatarUploadFailureKind? _uploadFailure;
  LoopChainException? _uploadChainFailure;

  MemeTokenDetail? _draft;
  String? _draftSignature;
  bool _creatingDraft = false;
  LoopChainException? _draftFailure;
  bool _resumed = false;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    for (final controller in <TextEditingController>[
      _name,
      _symbol,
      _description,
      _twitter,
      _telegram,
      _website,
      _firstBuy,
    ]) {
      controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _symbol,
      _description,
      _twitter,
      _telegram,
      _website,
      _firstBuy,
    ]) {
      controller
        ..removeListener(_changed)
        ..dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  String? _error(MemeCreateField field) {
    if (!_showErrors) return null;
    final controller = switch (field) {
      MemeCreateField.name => _name,
      MemeCreateField.symbol => _symbol,
      MemeCreateField.description => _description,
      MemeCreateField.twitter => _twitter,
      MemeCreateField.telegram => _telegram,
      MemeCreateField.website => _website,
    };
    return memeCreateFieldError(field, controller.text);
  }

  bool _stepValid(MemeCreateStep step) {
    final fields = switch (step) {
      MemeCreateStep.profile => const <MemeCreateField>[
        MemeCreateField.name,
        MemeCreateField.symbol,
        MemeCreateField.description,
      ],
      MemeCreateStep.media => const <MemeCreateField>[
        MemeCreateField.twitter,
        MemeCreateField.telegram,
        MemeCreateField.website,
      ],
      MemeCreateStep.confirm => const <MemeCreateField>[],
    };
    for (final field in fields) {
      final controller = switch (field) {
        MemeCreateField.name => _name,
        MemeCreateField.symbol => _symbol,
        MemeCreateField.description => _description,
        MemeCreateField.twitter => _twitter,
        MemeCreateField.telegram => _telegram,
        MemeCreateField.website => _website,
      };
      if (memeCreateFieldError(field, controller.text) != null) return false;
    }
    return true;
  }

  String? _link(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  MemeCreateDraft get _currentDraft => MemeCreateDraft(
    name: _name.text.trim(),
    symbol: _symbol.text.trim().toUpperCase(),
    description: _description.text.trim(),
    imageMediaId: _imageMediaId,
    links: MemeLinks(
      twitter: _link(_twitter),
      telegram: _link(_telegram),
      website: _link(_website),
    ),
  );

  void _back() {
    final submission = ref.read(
      memeSubmissionControllerProvider(MemeCreateScreen.submissionScope),
    );
    if (submission.busy || submission.locked) return;
    if (_step == MemeCreateStep.profile ||
        (widget.draftId != null && _step == MemeCreateStep.confirm)) {
      widget.onBack?.call();
      return;
    }
    setState(() {
      _step = MemeCreateStep.values[_step.index - 1];
      _showErrors = false;
    });
  }

  Future<void> _next() async {
    if (!_stepValid(_step)) {
      setState(() => _showErrors = true);
      return;
    }
    if (_step == MemeCreateStep.profile) {
      setState(() {
        _step = MemeCreateStep.media;
        _showErrors = false;
      });
      return;
    }
    if (_step == MemeCreateStep.media) await _createDraft();
  }

  /// `POST /v2/meme/tokens`: the draft and its predicted address. The same
  /// content reuses the draft already made; changed content makes a new one.
  Future<void> _createDraft() async {
    final draft = _currentDraft;
    if (_draft != null && _draftSignature == draft.signature) {
      setState(() => _step = MemeCreateStep.confirm);
      return;
    }
    if (_creatingDraft) return;
    setState(() {
      _creatingDraft = true;
      _draftFailure = null;
    });
    try {
      final created = await ref.read(memeGatewayProvider).createToken(draft);
      if (!mounted) return;
      setState(() {
        _draft = created;
        _draftSignature = draft.signature;
        _step = MemeCreateStep.confirm;
      });
    } on LoopChainException catch (failure) {
      if (mounted) setState(() => _draftFailure = failure);
    } catch (_) {
      if (mounted) {
        setState(
          () => _draftFailure = const LoopChainException(
            LoopChainFailureKind.unexpected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingDraft = false);
    }
  }

  Future<void> _upload() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _uploadFailure = null;
      _uploadChainFailure = null;
    });
    try {
      final picked = await ref.read(avatarImagePickerProvider).pick();
      if (picked == null || !mounted) return;
      final crop = debugMemeCropOverride ?? showAvatarCropDialog;
      final square = await crop(context, picked.bytes);
      if (square == null || !mounted) return;
      final uploaded = await ref
          .read(memeGatewayProvider)
          .uploadImage(bytes: square, contentType: 'image/png');
      if (!mounted) return;
      setState(() {
        _imageMediaId = uploaded.mediaId;
        _imageUrl = uploaded.url;
      });
    } on LoopChainException catch (failure) {
      if (mounted) setState(() => _uploadChainFailure = failure);
    } catch (_) {
      if (mounted) {
        setState(() => _uploadFailure = AvatarUploadFailureKind.unexpected);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _create(MemeTokenDetail draft) async {
    final wallet = memeReadActiveWallet(ref);
    final walletId = wallet.walletId;
    if (walletId == null) return;
    final firstBuy = memeRawFromInput(_firstBuy.text);
    final submission = ref.read(
      memeSubmissionControllerProvider(MemeCreateScreen.submissionScope)
          .notifier,
    );
    final intent = await submission.prepare(
      memeTokenId: draft.memeTokenId,
      kind: MemeIntentKind.create,
      walletId: walletId,
      usd1Amount: firstBuy == null ? null : memeDecimalString(firstBuy),
      slippageBps: firstBuy == null ? null : 100,
    );
    if (intent == null || !mounted) return;
    final outcome = await showMemeSignSheet(
      context,
      intent: intent,
      signer: ref.read(memeIntentSignerProvider),
      fromAddress: wallet.address,
      symbol: draft.row.symbol,
      clock: widget.clock,
    );
    if (!mounted) return;
    submission.recordOutcome(outcome);
  }

  void _resume(MemeTokenDetail detail) {
    if (_resumed) return;
    _resumed = true;
    if (detail.status != MemeTokenStatus.draft) {
      scheduleMicrotask(() => widget.onOpenToken?.call(detail.memeTokenId));
      return;
    }
    _name.text = detail.row.name;
    _symbol.text = detail.row.symbol;
    _description.text = detail.description;
    _twitter.text = detail.links.twitter ?? '';
    _telegram.text = detail.links.telegram ?? '';
    _website.text = detail.links.website ?? '';
    _draft = detail;
    _draftSignature = _currentDraft.signature;
    _step = MemeCreateStep.confirm;
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.meme),
    );
    final blocked = memeReadsBlocked(ref);
    final wallet = blocked ? null : memeActiveWallet(ref);
    final submission = ref.watch(
      memeSubmissionControllerProvider(MemeCreateScreen.submissionScope),
    );
    ref.listen<MemeSubmissionState>(
      memeSubmissionControllerProvider(MemeCreateScreen.submissionScope),
      (previous, next) {
        final draft = _draft;
        if (next.phase == MemeSubmissionPhase.confirmed &&
            previous?.phase != MemeSubmissionPhase.confirmed &&
            draft != null &&
            !_opened) {
          _opened = true;
          widget.onOpenToken?.call(draft.memeTokenId);
        }
      },
    );

    final draftId = widget.draftId;
    if (!blocked && draftId != null && !_resumed) {
      final provider = memeTokenControllerProvider(draftId);
      final state = ref.watch(provider);
      if (state.phase == LoopChainViewPhase.loading) {
        scheduleMicrotask(() {
          if (mounted) unawaited(ref.read(provider.notifier).load());
        });
      }
      final value = state.value;
      if (value != null) {
        _resume(value);
      } else {
        return LoopFocusPage(
          key: const ValueKey<String>('meme-create-screen'),
          archetype: LoopPageArchetype.action,
          title: '创建代币',
          onBack: widget.onBack,
          body: <Widget>[
            LoopChainStateBlock(
              keyPrefix: 'meme-create-draft',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '这个草稿已经不在了',
              onRetry: () => unawaited(ref.read(provider.notifier).reload()),
            ),
          ],
        );
      }
    }

    final draft = _draft;
    return LoopFocusPage(
      key: const ValueKey<String>('meme-create-screen'),
      archetype: LoopPageArchetype.action,
      title: '创建代币',
      onBack: _back,
      keyboardAccessory: true,
      block: blocked
          ? LoopPageBlock(
              key: const ValueKey<String>('meme-create-blocked'),
              title: '现在不能创建代币',
              message: memeCapabilityText(capability),
            )
          : null,
      primaryAction: blocked ? null : _primaryAction(draft, wallet, submission),
      body: <Widget>[
        _StepDots(step: _step),
        ...switch (_step) {
          MemeCreateStep.profile => _profileStep(),
          MemeCreateStep.media => _mediaStep(),
          MemeCreateStep.confirm =>
            draft == null
                ? const <Widget>[]
                : _confirmStep(draft, wallet, submission, capability),
        },
      ],
    );
  }

  Widget? _primaryAction(
    MemeTokenDetail? draft,
    MemeActiveWallet? wallet,
    MemeSubmissionState submission,
  ) {
    switch (_step) {
      case MemeCreateStep.profile:
        return LoopButton(
          key: const ValueKey<String>('meme-create-next'),
          label: '下一步',
          primary: true,
          block: true,
          onPressed: () => unawaited(_next()),
        );
      case MemeCreateStep.media:
        return LoopButton(
          key: const ValueKey<String>('meme-create-next'),
          label: _creatingDraft ? '正在生成地址…' : '下一步',
          primary: true,
          block: true,
          onPressed: _creatingDraft || _uploading
              ? null
              : () => unawaited(_next()),
        );
      case MemeCreateStep.confirm:
        if (draft == null) return null;
        final firstBuyText = _firstBuy.text.trim();
        final firstBuy = memeRawFromInput(firstBuyText);
        final firstBuyBad =
            firstBuyText.isNotEmpty &&
            (firstBuy == null || _firstBuyRefusal(draft, firstBuy) != null);
        final enabled =
            wallet?.walletId != null &&
            !firstBuyBad &&
            !submission.busy &&
            !submission.locked &&
            submission.phase != MemeSubmissionPhase.confirmed;
        return LoopButton(
          key: const ValueKey<String>('meme-create-submit'),
          label: switch (submission.phase) {
            MemeSubmissionPhase.preparing => '正在准备…',
            MemeSubmissionPhase.waiting => '已广播，等待确认…',
            MemeSubmissionPhase.confirmed => '已创建',
            _ => '创建',
          },
          primary: true,
          block: true,
          onPressed: enabled ? () => unawaited(_create(draft)) : null,
        );
    }
  }

  List<Widget> _profileStep() => <Widget>[
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('meme-create-name'),
            controller: _name,
            maxLength: 32,
            decoration: InputDecoration(
              labelText: '名称',
              hintText: '1–32 个字',
              errorText: _error(MemeCreateField.name),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('meme-create-symbol'),
            controller: _symbol,
            maxLength: 10,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: '符号',
              hintText: '2–10 位字母或数字',
              prefixText: r'$',
              errorText: _error(MemeCreateField.symbol),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey<String>('meme-create-description'),
            controller: _description,
            maxLength: 500,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              labelText: '简介（可不填）',
              errorText: _error(MemeCreateField.description),
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _mediaStep() {
    final picker = ref.watch(avatarImagePickerProvider);
    final symbol = _symbol.text.trim().toUpperCase();
    final failure = _draftFailure;
    final uploadFailure = _uploadChainFailure;
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
              key: const ValueKey<String>('meme-create-image-preview'),
              symbol: symbol,
              imageUrl: _imageUrl,
              size: 72,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LoopButton(
                    key: const ValueKey<String>('meme-create-upload'),
                    label: _uploading
                        ? '上传中…'
                        : (_imageMediaId == null ? '上传图片' : '换一张'),
                    icon: 'camera',
                    onPressed: picker.available && !_uploading
                        ? () => unawaited(_upload())
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    picker.available
                        ? '方形图片，上传前可裁剪；不传就用符号首字母。'
                        : '这台设备暂时不能选图，不传就用符号首字母。',
                    style: LoopType.captionSm.copyWith(color: LoopColors.text3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (uploadFailure != null || _uploadFailure != null)
        LoopNotice(
          key: const ValueKey<String>('meme-create-upload-failed'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: uploadFailure != null
              ? '图片没有上传成功：${memeFailureText(uploadFailure)}'
              : avatarUploadFailureReason(_uploadFailure!),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('meme-create-twitter'),
              controller: _twitter,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'X（可不填）',
                hintText: 'https://',
                errorText: _error(MemeCreateField.twitter),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('meme-create-telegram'),
              controller: _telegram,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Telegram（可不填）',
                hintText: 'https://',
                errorText: _error(MemeCreateField.telegram),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('meme-create-website'),
              controller: _website,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: '官网（可不填）',
                hintText: 'https://',
                errorText: _error(MemeCreateField.website),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (failure != null)
        LoopNotice(
          key: const ValueKey<String>('meme-create-draft-failed'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: _draftFailureText(failure),
        ),
    ];
  }

  static String _draftFailureText(LoopChainException failure) {
    if (failure.reasonCode == 'MEME_CREATE_RATE_LIMITED' ||
        failure.kind == LoopChainFailureKind.rateLimited) {
      return '今天的创建次数用完了，明天再来';
    }
    return memeFailureText(failure);
  }

  /// Why a first buy cannot go out as typed, or `null`.
  String? _firstBuyRefusal(MemeTokenDetail draft, BigInt usd1In) {
    final curve = draft.curve;
    if (usd1In < curve.minBuyUsd1) {
      return '最少买入 ${memeUsd1Label(curve.minBuyUsd1)}';
    }
    final estimate = curve.estimateBuy(usd1In);
    if (estimate.out > curve.walletCapTokens) {
      return '超过单钱包上限 ${memeTokenFigure(curve.walletCapTokens)} 枚';
    }
    return null;
  }

  List<Widget> _confirmStep(
    MemeTokenDetail draft,
    MemeActiveWallet? wallet,
    MemeSubmissionState submission,
    LoopCapabilityProjection capability,
  ) {
    final curve = draft.curve;
    final symbol = draft.row.symbol;
    final saleShare = curve.totalSupply == BigInt.zero
        ? null
        : (curve.saleSupply * BigInt.from(10000) ~/ curve.totalSupply).toInt();
    final fillTarget = curve.fillTargetUsd1;
    final firstBuyText = _firstBuy.text.trim();
    final firstBuy = memeRawFromInput(firstBuyText);
    final estimate = firstBuy == null ? null : curve.estimateBuy(firstBuy);
    final refusal = firstBuy == null ? null : _firstBuyRefusal(draft, firstBuy);
    final statusText = memeSubmissionText(submission, MemeIntentKind.create);
    final predicted = draft.predictedAddress;
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          4,
          LoopSpacing.page,
          8,
        ),
        child: Row(
          children: <Widget>[
            MemeLogo(symbol: symbol, imageUrl: draft.row.imageUrl, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${draft.row.name} \$$symbol',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.titleLg,
                  ),
                  if (draft.description.isNotEmpty)
                    Text(
                      draft.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LoopType.caption.copyWith(color: LoopColors.text2),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const LoopLabel('代币地址'),
      Padding(
        key: const ValueKey<String>('meme-create-predicted'),
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          8,
        ),
        child: predicted == null
            ? Text(
                '地址会在创建时确定',
                style: LoopType.body.copyWith(color: LoopColors.text2),
              )
            : MemeAddressTail(address: predicted),
      ),
      if (!draft.vanity)
        const LoopNotice(
          key: ValueKey<String>('meme-create-no-vanity'),
          icon: 'info',
          body: '本次无法分配 6666 尾号，代币仍可正常创建和交易。',
        ),
      const LoopLabel('参数'),
      LoopKeyValue(
        label: '总量',
        value: '${memeTokenFigure(curve.totalSupply)} 枚',
      ),
      LoopKeyValue(
        label: '可售',
        value: saleShare == null
            ? '${memeTokenFigure(curve.saleSupply)} 枚'
            : '${memeTokenFigure(curve.saleSupply)} 枚（${memeBpsLabel(saleShare)}）',
      ),
      LoopKeyValue(label: '交易费率', value: memeBpsLabel(curve.tradeFeeBps)),
      LoopKeyValue(
        label: '单钱包上限',
        value: '${memeTokenFigure(curve.walletCapTokens)} 枚',
      ),
      LoopKeyValue(
        label: '毕业条件',
        value: fillTarget == null
            ? '可售部分卖完后自动上 PancakeSwap'
            : '募满约 ${memeUsd1Label(fillTarget, maxFractionDigits: 0)} 后自动上 PancakeSwap',
      ),
      const LoopLabel('首买（可不填）'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: TextField(
          key: const ValueKey<String>('meme-create-first-buy'),
          controller: _firstBuy,
          enabled: !submission.busy && !submission.locked,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: '用 USD1 首买',
            suffixText: 'USD1',
            errorText: firstBuyText.isEmpty
                ? null
                : firstBuy == null
                ? '请输入大于 0 的金额，最多 18 位小数'
                : refusal,
          ),
        ),
      ),
      if (estimate != null && refusal == null)
        Padding(
          key: const ValueKey<String>('meme-create-first-buy-estimate'),
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            8,
            LoopSpacing.page,
            0,
          ),
          child: Text(
            '约得 ${memeTokenLabel(estimate.out, '\$$symbol')}，'
            '手续费 ${memeUsd1Label(estimate.fee, maxFractionDigits: 4)}；'
            '上限 ${memeTokenFigure(curve.walletCapTokens)} 枚。签名前以服务端报价为准。',
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      const SizedBox(height: 12),
      if (wallet != null && wallet.walletId == null)
        LoopNotice(
          key: const ValueKey<String>('meme-create-no-wallet'),
          icon: 'wallet',
          tone: LoopNoticeTone.warn,
          body: wallet.loading ? '正在读取钱包…' : '还没有可用的钱包，先在钱包里创建或激活一个。',
        ),
      if (capability.evidencePending)
        const LoopNotice(
          key: ValueKey<String>('meme-create-evidence-pending'),
          icon: 'info',
          body: '发射台合约还在核对，创建可能暂时不可用。',
        ),
      if (statusText != null)
        LoopNotice(
          key: ValueKey<String>('meme-create-status-${submission.phase.name}'),
          icon: switch (submission.phase) {
            MemeSubmissionPhase.confirmed => 'check',
            MemeSubmissionPhase.waiting ||
            MemeSubmissionPhase.preparing => 'clock',
            _ => 'warn',
          },
          tone:
              submission.phase == MemeSubmissionPhase.confirmed ||
                  submission.phase == MemeSubmissionPhase.waiting ||
                  submission.phase == MemeSubmissionPhase.preparing
              ? LoopNoticeTone.normal
              : LoopNoticeTone.warn,
          body:
              submission.phase == MemeSubmissionPhase.prepareFailed &&
                  submission.failure != null
              ? _draftFailureText(submission.failure!)
              : statusText,
          trailing: _statusAction(submission),
        ),
    ];
  }

  Widget? _statusAction(MemeSubmissionState submission) {
    final controller = ref.read(
      memeSubmissionControllerProvider(MemeCreateScreen.submissionScope)
          .notifier,
    );
    return switch (submission.phase) {
      MemeSubmissionPhase.pollTimedOut => LoopButton(
        key: const ValueKey<String>('meme-create-resume'),
        label: '再查一次',
        onPressed: controller.resumePolling,
      ),
      MemeSubmissionPhase.locked
          when submission.outcome?.status == MoneySignStatus.reportRefused &&
              memeReportRetryable(submission.outcome!.reasonCode) =>
        LoopButton(
          key: const ValueKey<String>('meme-create-retry-report'),
          label: '重新上报',
          onPressed: () => unawaited(controller.retryReport()),
        ),
      MemeSubmissionPhase.failed ||
      MemeSubmissionPhase.expired ||
      MemeSubmissionPhase.signRefused ||
      MemeSubmissionPhase.prepareFailed => LoopButton(
        key: const ValueKey<String>('meme-create-reset'),
        label: '重新发起',
        onPressed: controller.reset,
      ),
      _ => null,
    };
  }
}

/// A token address with its last four characters in Lime — where a vanity
/// tail (6666) shows.
class MemeAddressTail extends StatelessWidget {
  const MemeAddressTail({required this.address, super.key});

  final String address;

  @override
  Widget build(BuildContext context) {
    final head = address.substring(0, address.length - 4);
    final tail = address.substring(address.length - 4);
    return Semantics(
      label: '代币地址 $address',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: head,
              style: LoopType.code.copyWith(color: LoopColors.text2),
            ),
            TextSpan(
              text: tail,
              style: LoopType.code.copyWith(color: LoopColors.lime),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});

  final MemeCreateStep step;

  @override
  Widget build(BuildContext context) {
    const total = MemeCreateStep.values;
    return Padding(
      key: ValueKey<String>('meme-create-step-${step.index + 1}'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        14,
      ),
      child: Semantics(
        label: '第 ${step.index + 1} 步，共 ${total.length} 步，${step.label}',
        excludeSemantics: true,
        child: Row(
          children: <Widget>[
            for (final item in total) ...<Widget>[
              Container(
                width: item == step ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.index <= step.index
                      ? LoopColors.lime
                      : LoopColors.line2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 6),
            Text(
              '${step.index + 1} / ${total.length} · ${step.label}',
              style: LoopType.caption.copyWith(color: LoopColors.text2),
            ),
          ],
        ),
      ),
    );
  }
}

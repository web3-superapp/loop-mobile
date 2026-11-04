import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_widgets.dart'
    show confirmCommunityAction;
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
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_step_track.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Replaces the square crop in a page test, which has no image codec to run
/// the real one with. Tests only.
@visibleForTesting
Future<Uint8List?> Function(BuildContext context, Uint8List bytes)?
debugMemeCropOverride;

/// The three steps of `meme-create`, in order.
enum MemeCreateStep {
  profile(),
  media(),
  confirm();

  const MemeCreateStep();

  String get label => switch (this) {
    MemeCreateStep.profile => LoopL10n.current.common_profile,

    MemeCreateStep.media => LoopL10n.current.meme_createMedia,

    MemeCreateStep.confirm => LoopL10n.current.common_confirm,
  };
}

/// The fields the form checks before the server does (contract §7).
enum MemeCreateField { name, symbol, description, twitter, telegram, website }

final RegExp _symbolPattern = RegExp(r'^[A-Z0-9]{2,10}$');

/// The reason one field is refused, or `null` when it passes.
String? memeCreateFieldError(MemeCreateField field, String raw) {
  final value = raw.trim();
  switch (field) {
    case MemeCreateField.name:
      if (value.isEmpty || value.runes.length > 32) {
        return LoopL10n.current.meme_createSwitch;
      }
    case MemeCreateField.symbol:
      if (!_symbolPattern.hasMatch(value.toUpperCase())) {
        return LoopL10n.current.meme_createSwitch2;
      }
    case MemeCreateField.description:
      if (value.runes.length > 500) return LoopL10n.current.meme_createSwitch3;
    case MemeCreateField.twitter:
    case MemeCreateField.telegram:
    case MemeCreateField.website:
      if (value.isEmpty) return null;
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return LoopL10n.current.meme_createIf;
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
///
/// Decision 0195: while [LoopFeatureSwitchValues.classicMemeLaunchVisible]
/// is off the route stays mounted but draws only the 「经典发射已停用」 notice
/// — no form, no draft read, no request — with the way to v2 发射.
class MemeCreateScreen extends ConsumerStatefulWidget {
  const MemeCreateScreen({
    super.key,
    this.draftId,
    this.onBack,
    this.onOpenToken,
    this.onOpenLaunch2Create,
    this.clock,
  });

  /// Opens the v2 (Loop Hook) create page from the retired notice.
  final VoidCallback? onOpenLaunch2Create;

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

  /// Whether 返回 on this step leaves the flow rather than going one step
  /// back: the first step, or the confirm step of a resumed draft.
  bool get _backLeaves =>
      _step == MemeCreateStep.profile ||
      (widget.draftId != null && _step == MemeCreateStep.confirm);

  /// What leaving the first step would throw away.
  bool get _hasUnsavedInput =>
      _step == MemeCreateStep.profile &&
      (_imageMediaId != null ||
          <TextEditingController>[
            _name,
            _symbol,
            _description,
            _twitter,
            _telegram,
            _website,
            _firstBuy,
          ].any((controller) => controller.text.trim().isNotEmpty));

  bool get _submissionHolds {
    final submission = ref.read(
      memeSubmissionControllerProvider(MemeCreateScreen.submissionScope),
    );
    return submission.busy || submission.locked;
  }

  /// One 返回 for the top bar and the system (decision 0128, S123 M1): one
  /// step back on 2 and 3; on 1, leave — after 「放弃创建？」 when something
  /// was typed. A submission in flight holds the page.
  Future<void> _back() async {
    if (_submissionHolds) return;
    if (!_backLeaves) {
      setState(() {
        _step = MemeCreateStep.values[_step.index - 1];
        _showErrors = false;
      });
      return;
    }
    if (_hasUnsavedInput) {
      final abandon = await confirmCommunityAction(
        context,
        title: LoopL10n.current.meme_createTitle,
        body: LoopL10n.current.meme_createBody,
        confirmLabel: LoopL10n.current.meme_createConfirmLabel,
        cancelLabel: LoopL10n.current.meme_createCancelLabel,
        sheetKey: 'meme-create-abandon-sheet',
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

  /// Decision 0195: the page a deep link or a direct route lands on while
  /// classic launches are retired.
  Widget _retired() {
    final openV2 = widget.onOpenLaunch2Create;
    return LoopFocusPage(
      key: const ValueKey<String>('meme-create-retired'),
      archetype: LoopPageArchetype.action,
      title: LoopL10n.current.meme_createMemeCreateRetiredTitle,
      onBack: widget.onBack,
      body: <Widget>[
        LoopEmptyState(
          showMessage: true,
          illustration: LoopIllustration.launchpad,
          title: LoopL10n.current.meme_createMemeCreateRetiredOpenV2Title,
          message: LoopL10n.current.meme_createMemeCreateRetiredOpenV2Message,
          action: openV2 == null
              ? null
              : LoopButton(
                  key: const ValueKey<String>('meme-create-retired-open-v2'),
                  label:
                      LoopL10n.current.meme_createMemeCreateRetiredOpenV2Label,
                  primary: true,
                  onPressed: openV2,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(loopFeatureSwitchesProvider).classicMemeLaunchVisible) {
      return _retired();
    }
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
          title: context.l10n.meme_createMemeCreateRetiredTitle,
          onBack: widget.onBack,
          body: <Widget>[
            LoopChainStateBlock(
              keyPrefix: 'meme-create-draft',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: context.l10n.meme_createEmptyMessage,
              onRetry: () => unawaited(ref.read(provider.notifier).reload()),
            ),
          ],
        );
      }
    }

    final draft = _draft;
    // The system back (Android key, predictive back, iOS edge swipe) is the
    // same 返回 as the top bar's: it may leave at once only from an empty
    // first step.
    final page = LoopFocusPage(
      key: const ValueKey<String>('meme-create-screen'),
      archetype: LoopPageArchetype.action,
      title: context.l10n.meme_createMemeCreateRetiredTitle,
      onBack: () => unawaited(_back()),
      keyboardAccessory: true,
      block: blocked
          ? LoopPageBlock(
              key: const ValueKey<String>('meme-create-blocked'),
              title: context.l10n.meme_createMemeCreateBlockedTitle,
              message: memeCapabilityText(capability),
            )
          : null,
      primaryAction: blocked ? null : _primaryAction(draft, wallet, submission),
      body: <Widget>[
        LoopStepTrack.dots(
          key: ValueKey<String>('meme-create-step-${_step.index + 1}'),
          labels: <String>[
            for (final step in MemeCreateStep.values) step.label,
          ],
          current: _step.index,
        ),
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
    return PopScope(
      canPop:
          _backLeaves &&
          !_hasUnsavedInput &&
          !submission.busy &&
          !submission.locked,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_back());
      },
      child: page,
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
          label: LoopL10n.current.common_next,
          primary: true,
          block: true,
          onPressed: () => unawaited(_next()),
        );
      case MemeCreateStep.media:
        return LoopButton(
          key: const ValueKey<String>('meme-create-next'),
          label: _creatingDraft
              ? LoopL10n.current.meme_createMemeCreateNextLabel
              : LoopL10n.current.common_next,
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
            MemeSubmissionPhase.preparing =>
              LoopL10n.current.meme_createPreparing,
            MemeSubmissionPhase.waiting => LoopL10n.current.meme_createWaiting,
            MemeSubmissionPhase.confirmed =>
              LoopL10n.current.meme_createConfirmed,
            _ => LoopL10n.current.meme_createLoopButton,
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
              labelText: LoopL10n.current.common_name,
              hintText: LoopL10n.current.meme_createHintText,
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
              labelText: LoopL10n.current.meme_createLabelText,
              hintText: LoopL10n.current.meme_createHintText2,
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
              labelText: LoopL10n.current.meme_createLabelText2,
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
                        ? LoopL10n.current.common_uploading
                        : (_imageMediaId == null
                              ? LoopL10n.current.meme_createLabel
                              : LoopL10n.current.meme_createLabel2),
                    icon: 'camera',
                    onPressed: picker.available && !_uploading
                        ? () => unawaited(_upload())
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    picker.available
                        ? LoopL10n.current.meme_createMediaStep
                        : LoopL10n.current.meme_createS,
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
              ? LoopL10n.current.meme_createMemeCreateUploadFailedBody(
                  memeFailureText(uploadFailure),
                )
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
                labelText: LoopL10n.current.meme_createLabelText3,
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
                labelText: LoopL10n.current.meme_createLabelText4,
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
                labelText: LoopL10n.current.meme_createLabelText5,
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
      return LoopL10n.current.meme_createIf2;
    }
    return memeFailureText(failure);
  }

  /// Why a first buy cannot go out as typed, or `null`.
  String? _firstBuyRefusal(MemeTokenDetail draft, BigInt usd1In) {
    final curve = draft.curve;
    if (usd1In < curve.minBuyUsd1) {
      return LoopL10n.current.meme_createIf3(memeUsd1Label(curve.minBuyUsd1));
    }
    final estimate = curve.estimateBuy(usd1In);
    if (estimate.out > curve.walletCapTokens) {
      return LoopL10n.current.meme_createIf4(
        memeTokenFigure(curve.walletCapTokens),
      );
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
                    '${draft.row.name} ${loopTickerLabel(symbol)}',
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
      LoopLabel(LoopL10n.current.meme_createLoopLabel),
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
                LoopL10n.current.meme_createConfirmStep,
                style: LoopType.body.copyWith(color: LoopColors.text2),
              )
            : MemeAddressTail(address: predicted),
      ),
      if (!draft.vanity)
        LoopNotice(
          key: ValueKey<String>('meme-create-no-vanity'),
          icon: 'info',
          body: LoopL10n.current.meme_createMemeCreateNoVanityBody,
        ),
      LoopLabel(LoopL10n.current.meme_createLoopLabel2),
      LoopKeyValue(
        label: LoopL10n.current.common_totalSupply,
        value: LoopL10n.current.meme_createValue(
          memeTokenFigure(curve.totalSupply),
        ),
      ),
      LoopKeyValue(
        label: LoopL10n.current.meme_createLabel3,
        value: saleShare == null
            ? LoopL10n.current.meme_createValue(
                memeTokenFigure(curve.saleSupply),
              )
            : LoopL10n.current.meme_createValue2(
                memeBpsLabel(saleShare),
                memeTokenFigure(curve.saleSupply),
              ),
      ),
      LoopKeyValue(
        label: LoopL10n.current.meme_createLabel4,
        value: memeBpsLabel(curve.tradeFeeBps),
      ),
      LoopKeyValue(
        label: LoopL10n.current.meme_createLabel5,
        value: LoopL10n.current.meme_createValue(
          memeTokenFigure(curve.walletCapTokens),
        ),
      ),
      LoopKeyValue(
        label: LoopL10n.current.meme_createLabel6,
        value: fillTarget == null
            ? LoopL10n.current.meme_createValue3
            : LoopL10n.current.meme_createValue4(
                memeUsd1Label(fillTarget, maxFractionDigits: 0),
              ),
      ),
      LoopLabel(LoopL10n.current.meme_createLoopLabel3),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: TextField(
          key: const ValueKey<String>('meme-create-first-buy'),
          controller: _firstBuy,
          enabled: !submission.busy && !submission.locked,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: LoopL10n.current.meme_createLabelText6,
            suffixText: 'USD1',
            errorText: firstBuyText.isEmpty
                ? null
                : firstBuy == null
                ? LoopL10n.current.meme_createErrorText
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
            LoopL10n.current.meme_createText(
              memeTokenFigure(curve.walletCapTokens),
              memeTokenLabel(estimate.out, loopTickerLabel(symbol)),
              memeUsd1Label(estimate.fee, maxFractionDigits: 4),
            ),
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      const SizedBox(height: 12),
      if (wallet != null && wallet.walletId == null)
        LoopNotice(
          key: const ValueKey<String>('meme-create-no-wallet'),
          icon: 'wallet',
          tone: LoopNoticeTone.warn,
          body: wallet.loading
              ? LoopL10n.current.meme_createMemeCreateNoWalletBody
              : LoopL10n.current.meme_createMemeCreateNoWalletBody2,
        ),
      if (capability.evidencePending)
        LoopNotice(
          key: ValueKey<String>('meme-create-evidence-pending'),
          icon: 'info',
          body: LoopL10n.current.meme_createMemeCreateEvidencePendingBody,
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
        label: LoopL10n.current.meme_createMemeCreateResumeLabel,
        onPressed: controller.resumePolling,
      ),
      MemeSubmissionPhase.locked
          when submission.outcome?.status == MoneySignStatus.reportRefused &&
              memeReportRetryable(submission.outcome!.reasonCode) =>
        LoopButton(
          key: const ValueKey<String>('meme-create-retry-report'),
          label: LoopL10n.current.meme_createMemeCreateRetryReportLabel,
          onPressed: () => unawaited(controller.retryReport()),
        ),
      MemeSubmissionPhase.failed ||
      MemeSubmissionPhase.expired ||
      MemeSubmissionPhase.signRefused ||
      MemeSubmissionPhase.prepareFailed => LoopButton(
        key: const ValueKey<String>('meme-create-reset'),
        label: LoopL10n.current.meme_createMemeCreateResetLabel,
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
      label: context.l10n.meme_createLabel7(address),
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
              style: LoopType.code.copyWith(color: LoopColors.yellow),
            ),
          ],
        ),
      ),
    );
  }
}

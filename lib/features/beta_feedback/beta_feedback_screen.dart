import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_controllers.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_copy.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_gateway.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `beta-feedback` · 内测反馈 (S332 · decision 0262): archetype `action`,
/// layout `focus`.
///
/// A category, the text, up to four pictures and the read-only environment
/// the entry captured. 提交 uploads the pictures one by one, then sends the
/// feedback; a success says 已提交 and goes back. States: unavailable (no
/// adapter — the whole page), the environment loading, and a failed send
/// (offline, refused, rate-limited, unresolved) under the form with the
/// form kept. A refused library or camera is a toast.
class BetaFeedbackScreen extends ConsumerStatefulWidget {
  const BetaFeedbackScreen({
    required this.origin,
    required this.onOpenMine,
    required this.onDone,
    super.key,
    this.onBack,
  });

  /// Where the person was when they tapped the entry.
  final BetaFeedbackOrigin origin;
  final VoidCallback onOpenMine;

  /// After 已提交.
  final VoidCallback onDone;
  final VoidCallback? onBack;

  @override
  ConsumerState<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends ConsumerState<BetaFeedbackScreen> {
  final TextEditingController _body = TextEditingController();
  BetaFeedbackCategory _category = BetaFeedbackCategory.bug;
  bool _picking = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool camera}) async {
    final form = ref.read(betaFeedbackFormControllerProvider);
    if (_picking || !form.canAddImage) return;
    final room = BetaFeedbackPolicy.maximumImages - form.images.length;
    final picker = ref.read(betaFeedbackImagePickerProvider);
    setState(() => _picking = true);
    try {
      final picked = camera
          ? <BetaFeedbackPickedImage>[?await picker.takePhoto()]
          : await picker.pickFromLibrary(limit: room);
      if (!mounted || picked.isEmpty) return;
      final result = ref
          .read(betaFeedbackFormControllerProvider.notifier)
          .addImages(picked);
      switch (result) {
        case BetaFeedbackAddResult.added:
          break;
        case BetaFeedbackAddResult.tooMany:
          _toast(
            '最多 ${BetaFeedbackPolicy.maximumImages} 张图片',
            LoopToastKind.warn,
          );
        case BetaFeedbackAddResult.rejected:
          _toast('有图片无法使用', LoopToastKind.warn);
      }
    } on BetaFeedbackPickException catch (error) {
      if (!mounted) return;
      _toast(switch (error.failure) {
        BetaFeedbackPickFailure.permissionDenied =>
          camera ? '没有相机权限' : '没有相册权限',
        BetaFeedbackPickFailure.unavailable => camera ? '无法打开相机' : '无法打开相册',
      }, LoopToastKind.err);
    } catch (_) {
      if (mounted) {
        _toast(camera ? '无法打开相机' : '无法打开相册', LoopToastKind.err);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _toast(String message, LoopToastKind kind) =>
      LoopToast.show(context, message: message, kind: kind);

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final receipt = await ref
        .read(betaFeedbackFormControllerProvider.notifier)
        .submit(category: _category, body: _body.text, origin: widget.origin);
    if (!mounted) return;
    if (receipt == null) {
      final kind = ref.read(betaFeedbackFormControllerProvider).failureKind;
      if (kind != null) _toast('没有提交', LoopToastKind.err);
      return;
    }
    _toast('已提交', LoopToastKind.ok);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(betaFeedbackGatewayProvider).mode;
    final form = ref.watch(betaFeedbackFormControllerProvider);
    final blocked = mode == LoopChainGatewayMode.unavailable;
    final length = betaFeedbackBodyLength(_body.text);
    final problem = betaFeedbackBodyProblem(_body.text);
    final submittable = !blocked && !form.busy && problem == null;
    final busyLabel = switch (form.step) {
      BetaFeedbackSubmitStep.uploading =>
        '上传图片 ${form.uploaded} / ${form.images.length}',
      BetaFeedbackSubmitStep.sending => '提交中',
      BetaFeedbackSubmitStep.idle => '提交',
    };
    return LoopFlat(
      child: LoopFocusPage(
        key: const ValueKey<String>('beta-feedback-screen'),
        archetype: LoopPageArchetype.action,
        title: '内测反馈',
        onBack: widget.onBack,
        keyboardAccessory: true,
        actions: <Widget>[
          LoopIconButton(
            key: const ValueKey<String>('beta-feedback-open-mine'),
            icon: 'clock',
            label: '我的反馈',
            onPressed: widget.onOpenMine,
          ),
        ],
        block: blocked
            ? const LoopPageBlock(
                key: ValueKey<String>('beta-feedback-unavailable'),
                title: '内测反馈暂不可用',
                message: '现在无法提交反馈。',
              )
            : null,
        body: <Widget>[
          LoopSegBar(
            key: const ValueKey<String>('beta-feedback-category'),
            labels: <String>[
              for (final category in BetaFeedbackCategory.values)
                category.label,
            ],
            selectedIndex: BetaFeedbackCategory.values.indexOf(_category),
            onSelected: form.busy
                ? (_) {}
                : (index) => setState(
                    () => _category = BetaFeedbackCategory.values[index],
                  ),
          ),
          const SizedBox(height: 8),
          LoopFlatField(
            key: const ValueKey<String>('beta-feedback-body'),
            label: '描述',
            footnote: '$length / ${BetaFeedbackPolicy.maximumBodyLength}',
            error: problem == BetaFeedbackBodyProblem.tooLong,
            child: TextField(
              key: const ValueKey<String>('beta-feedback-body-field'),
              controller: _body,
              enabled: !form.busy,
              minLines: 5,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              style: LoopType.bodyLg,
              decoration: loopFormFieldDecoration(hint: ''),
            ),
          ),
          const LoopLabel('图片'),
          _ImageGrid(
            images: form.images,
            canAdd: form.canAddImage && !_picking,
            enabled: !form.busy,
            onAddFromLibrary: () => unawaited(_pick(camera: false)),
            onTakePhoto: () => unawaited(_pick(camera: true)),
            onRemove: (localId) => ref
                .read(betaFeedbackFormControllerProvider.notifier)
                .removeImage(localId),
          ),
          const LoopLabel('环境'),
          _EnvironmentBlock(origin: widget.origin),
          if (form.failureKind case final LoopChainFailureKind kind)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: LoopErrorState(
                key: const ValueKey<String>('beta-feedback-error'),
                title: '没有提交',
                reason: betaFeedbackFailureReason(kind, write: true),
              ),
            ),
          const SizedBox(height: 20),
        ],
        primaryAction: LoopButton(
          key: const ValueKey<String>('beta-feedback-submit'),
          label: busyLabel,
          block: true,
          primary: true,
          onPressed: submittable ? () => unawaited(_submit()) : null,
        ),
      ),
    );
  }
}

/// Three across: the chosen pictures, then 相册 and 拍照 while there is room.
class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.images,
    required this.canAdd,
    required this.enabled,
    required this.onAddFromLibrary,
    required this.onTakePhoto,
    required this.onRemove,
  });

  final List<BetaFeedbackImage> images;
  final bool canAdd;
  final bool enabled;
  final VoidCallback onAddFromLibrary;
  final VoidCallback onTakePhoto;
  final ValueChanged<int> onRemove;

  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final full = images.length >= BetaFeedbackPolicy.maximumImages;
    final tiles = <Widget>[
      for (final image in images)
        _ImageTile(
          key: ValueKey<String>('beta-feedback-image-${image.localId}'),
          image: image,
          onRemove: enabled ? () => onRemove(image.localId) : null,
        ),
      if (!full) ...<Widget>[
        _AddTile(
          key: const ValueKey<String>('beta-feedback-add-library'),
          icon: 'plus',
          label: '相册',
          onTap: canAdd ? onAddFromLibrary : null,
        ),
        _AddTile(
          key: const ValueKey<String>('beta-feedback-add-camera'),
          icon: 'camera',
          label: '拍照',
          onTap: canAdd ? onTakePhoto : null,
        ),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final tile in tiles)
                SizedBox.square(dimension: side, child: tile),
            ],
          );
        },
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.image, required this.onRemove, super.key});

  final BetaFeedbackImage image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ClipRRect(
          borderRadius: LoopRadius.tile,
          child: Image.memory(
            image.bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 360,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: LoopColors.card),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            button: true,
            label: '删除图片',
            excludeSemantics: true,
            onTap: onRemove,
            child: LoopPressable(
              key: ValueKey<String>('beta-feedback-remove-${image.localId}'),
              onTap: onRemove,
              child: SizedBox.square(
                dimension: LoopTouch.minimum,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: LoopColors.chalk,
                      shape: BoxShape.circle,
                    ),
                    child: const LoopIcon(
                      'close',
                      size: 14,
                      color: LoopColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: LoopPressable(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: LoopColors.card,
              borderRadius: LoopRadius.tile,
              border: Border.all(color: LoopColors.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                LoopIcon(icon, size: 22, color: LoopColors.text2),
                const SizedBox(height: 6),
                Text(label, style: LoopType.captionSm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The read-only facts the feedback carries: build, device, system, the
/// page the entry was tapped on, the language.
class _EnvironmentBlock extends ConsumerWidget {
  const _EnvironmentBlock({required this.origin});

  final BetaFeedbackOrigin origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(betaFeedbackEnvironmentProvider);
    String show(String value) => value.isEmpty ? '未知' : value;
    final rows = switch (environment) {
      AsyncData(:final value) => <(String, String)>[
        (
          '版本',
          value.build.isEmpty
              ? show(value.appVersion)
              : '${show(value.appVersion)} (${value.build})',
        ),
        ('设备', show(value.deviceModel)),
        ('系统', show(value.osVersion)),
        ('页面', show(origin.route)),
        ('语言', show(origin.locale)),
      ],
      _ => null,
    };
    return Padding(
      key: const ValueKey<String>('beta-feedback-environment'),
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: LoopColors.card,
          borderRadius: LoopRadius.card,
        ),
        child: rows == null
            ? const Padding(
                padding: EdgeInsets.all(LoopSpacing.card),
                child: LoopSkeleton.row(
                  key: ValueKey<String>('beta-feedback-environment-loading'),
                  rows: 3,
                ),
              )
            : Column(
                children: <Widget>[
                  for (final (label, value) in rows)
                    LoopKeyValue(
                      label: label,
                      value: value,
                      labelFlex: 2,
                      valueFlex: 5,
                      valueKey: ValueKey<String>(
                        'beta-feedback-environment-$label',
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

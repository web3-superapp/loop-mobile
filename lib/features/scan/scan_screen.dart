import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/scan/loop_qr_scanner.dart';
import 'package:loop_mobile/features/scan/scan_result.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';

/// The camera-permission sentence LOOP already uses on `permission-notice`.
const String scanCameraDeniedBody = '扫码功能不可用；可在 系统设置 → LOOP → 相机 中重新开启。';

/// `scan` · action / focus (decision 0113, S109b §3.2).
///
/// A viewfinder, the photo library and the torch. A decoded payload is read
/// by [loopScanResultFor]: a LOOP card, community or room link opens that
/// page, a wallet address opens the send flow with the recipient filled in,
/// and anything else is shown back as text with 复制. The page itself makes
/// no network request; whatever it opens reads its own data.
///
/// Five states: loading is the camera opening; error is a camera that did
/// not start (重试); permission is the system refusing the camera; empty is
/// an unrecognised code (shown, copyable, 继续扫描); offline does not apply —
/// decoding is on device, and the page it opens owns its own offline state.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({
    super.key,
    this.onBack,
    this.onOpen,
    this.returnsRecipient,
  });

  final VoidCallback? onBack;

  /// Whether a wallet address is handed back to the page that opened the
  /// scanner (decision 0131: 发送's own 扫码 control) instead of opening a
  /// new send flow. Null reads the route's state: `/scan` pushed with
  /// [SendScanForRecipient] returns the address as the push's result. In this
  /// mode a code that is not an address is shown as text, never opened.
  final bool? returnsRecipient;

  /// Opens what a code named. The route replaces this page with it, so 返回
  /// from there leads back to where scanning started.
  final void Function(String location, {Object? extra})? onOpen;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  LoopQrCameraSession? _session;
  StreamSubscription<String>? _codes;

  /// The text of an unrecognised code, while it is on screen.
  String? _unknown;

  /// Set once a code has been handed on: a second frame of the same code
  /// must not open the page twice.
  bool _handled = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    final scanner = ref.read(loopQrScannerProvider);
    if (scanner.available) {
      final session = scanner.openCamera();
      _session = session;
      _codes = session.codes.listen(_onCode);
      WidgetsBinding.instance.addObserver(this);
      // The preview is mounted in this first frame; the camera starts once,
      // after it, and never by itself.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_session?.start());
      });
    }
  }

  /// The page owns the camera's lifecycle: it is released whenever the app
  /// stops being in front, and asked for again when it returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = _session;
    if (session == null) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(session.pause());
      case AppLifecycleState.resumed:
        unawaited(session.resume());
      case AppLifecycleState.detached:
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_codes?.cancel());
    final session = _session;
    _session = null;
    if (session != null) unawaited(session.dispose());
    super.dispose();
  }

  void _onCode(String raw) {
    if (_handled || _unknown != null || !mounted) return;
    _dispatch(raw);
  }

  bool get _returnsRecipient {
    final explicit = widget.returnsRecipient;
    if (explicit != null) return explicit;
    try {
      return GoRouterState.of(context).extra is SendScanForRecipient;
    } on GoError {
      return false;
    }
  }

  void _dispatch(String raw) {
    final result = loopScanResultFor(raw);
    if (_returnsRecipient) {
      switch (result) {
        case LoopScanAddress(:final address):
          _handled = true;
          LoopHaptics.selection();
          Navigator.of(context).pop(address);
        case LoopScanDestination():
          setState(() => _unknown = raw.trim());
        case LoopScanUnknown(:final text):
          setState(() => _unknown = text);
      }
      return;
    }
    switch (result) {
      case LoopScanDestination():
        _handled = true;
        LoopHaptics.selection();
        widget.onOpen?.call(result.location, extra: result.extra);
      case LoopScanUnknown(:final text):
        setState(() => _unknown = text);
    }
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    final scan = await ref.read(loopQrScannerProvider).scanImage();
    if (!mounted) return;
    setState(() => _pickingImage = false);
    switch (scan) {
      case LoopQrImageFound(:final text):
        _dispatch(text);
      case LoopQrImageCancelled():
        return;
      case LoopQrImageNoCode():
        LoopToast.show(
          context,
          message: '这张图片里没有识别到二维码',
          kind: LoopToastKind.warn,
        );
      case LoopQrImagePermissionDenied():
        LoopToast.show(
          context,
          message: '没有相册权限，去系统设置里允许 LOOP 访问照片后再试',
          kind: LoopToastKind.warn,
        );
      case LoopQrImageFailed():
        LoopToast.show(
          context,
          message: '图片没有读出来，请换一张再试',
          kind: LoopToastKind.warn,
        );
    }
  }

  Future<void> _copyUnknown(String text) async {
    await LoopCopy.text(context, text, message: '已复制二维码内容');
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(loopQrScannerProvider);
    final session = _session;
    if (!scanner.available || session == null) {
      return LoopFocusPage(
        key: const ValueKey<String>('scan-screen'),
        archetype: LoopPageArchetype.action,
        title: '扫一扫',
        onBack: widget.onBack,
        block: const LoopEmpty(
          key: ValueKey<String>('scan-unavailable'),
          icon: 'camera',
          message: '扫码当前不可用',
          reason: '这个版本没有装配相机扫码，本页不会打开相机。',
        ),
        body: const <Widget>[],
      );
    }
    // Decision 0133 (audit m11): the camera fills the screen, as every
    // system and wallet scanner does. The bar floats over the picture, the
    // window in the middle is where to hold the code, and the two tools sit
    // at the foot within thumb reach.
    return ValueListenableBuilder<LoopQrCameraState>(
      valueListenable: session.state,
      builder: (context, camera, _) {
        final unknown = _unknown;
        final torchOn = camera.torch == LoopQrTorch.on;
        final running = camera.status == LoopQrCameraStatus.running;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Material(
            key: const ValueKey<String>('scan-screen'),
            color: LoopColors.ink,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Mounted for the session's whole life: a start must never
                // wait on a preview that is not there.
                KeyedSubtree(
                  key: const ValueKey<String>('scan-viewfinder'),
                  child: session.buildPreview(context),
                ),
                if (running)
                  const IgnorePointer(
                    child: _ViewfinderMask(key: ValueKey<String>('scan-mask')),
                  ),
                _ViewfinderState(
                  status: camera.status,
                  onRetry: () => unawaited(session.retry()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: _ScanBar(onBack: widget.onBack),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  // An unrecognised code is read on a solid panel, not over
                  // the moving picture.
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: unknown == null ? null : LoopColors.ink,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (unknown != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _UnknownCode(
                                text: unknown,
                                onCopy: () => unawaited(_copyUnknown(unknown)),
                                onContinue: () =>
                                    setState(() => _unknown = null),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Text(
                                '对准 LOOP 名片、社区二维码或钱包地址二维码。',
                                key: const ValueKey<String>('scan-hint'),
                                textAlign: TextAlign.center,
                                style: LoopTypography.caption(
                                  13,
                                  color: LoopColors.chalk,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                _ScanTool(
                                  key: const ValueKey<String>(
                                    'scan-pick-image',
                                  ),
                                  icon: Icons.photo_library_outlined,
                                  label: _pickingImage ? '正在读取…' : '相册',
                                  semanticLabel: '从相册选图',
                                  onPressed: _pickingImage
                                      ? null
                                      : () => unawaited(_pickImage()),
                                ),
                                _ScanTool(
                                  key: const ValueKey<String>('scan-torch'),
                                  icon: torchOn
                                      ? Icons.flashlight_off_outlined
                                      : Icons.flashlight_on_outlined,
                                  label: torchOn ? '关闭手电筒' : '手电筒',
                                  toggled: torchOn,
                                  onPressed:
                                      running &&
                                          camera.torch !=
                                              LoopQrTorch.unavailable
                                      ? () => unawaited(session.toggleTorch())
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The bar over the picture: back and the page name, Chalk on the camera.
class _ScanBar extends StatelessWidget {
  const _ScanBar({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      6,
      LoopSpacing.page,
      0,
    ),
    child: SizedBox(
      height: LoopTouch.minimum,
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            LoopIconButton(
              key: const ValueKey<String>('loop-topbar-back'),
              icon: 'back',
              label: '返回',
              color: LoopColors.chalk,
              onPressed: onBack,
            ),
            const SizedBox(width: 10),
          ],
          Semantics(
            header: true,
            child: Text(
              '扫一扫',
              style: LoopTypography.heading(20, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

/// One tool at the foot of the scanner: a 56 round glyph and its name.
class _ScanTool extends StatelessWidget {
  const _ScanTool({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.semanticLabel,
    this.toggled,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final bool? toggled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = enabled ? LoopColors.chalk : LoopColors.text3;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: toggled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onPressed,
      child: LoopPressable(
        onTap: onPressed,
        child: SizedBox(
          width: 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: toggled == true
                      ? LoopColors.lime
                      : LoopColors.chalk.withValues(alpha: 0.16),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: toggled == true ? LoopColors.ink : ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopTypography.caption(12, color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The window to hold a code in: the picture outside it is dimmed, and four
/// Lime corners mark its edge. It is centred a little above the middle so the
/// tools at the foot never sit over it.
class _ViewfinderMask extends StatelessWidget {
  const _ViewfinderMask({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = (constraints.maxWidth * 0.68).clamp(180.0, 320.0);
      final window = Rect.fromCenter(
        center: Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.42),
        width: side,
        height: side,
      );
      return CustomPaint(
        size: constraints.biggest,
        painter: _MaskPainter(window),
      );
    },
  );
}

class _MaskPainter extends CustomPainter {
  const _MaskPainter(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final veil = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(16)));
    canvas.drawPath(
      veil,
      Paint()..color = LoopColors.ink.withValues(alpha: 0.55),
    );
    canvas.save();
    canvas.translate(window.left, window.top);
    const _CornerPainter().paint(canvas, window.size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) =>
      oldDelegate.window != window;
}

/// What stands over the viewfinder while there is no picture to scan.
class _ViewfinderState extends StatelessWidget {
  const _ViewfinderState({required this.status, required this.onRetry});

  final LoopQrCameraStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => switch (status) {
    LoopQrCameraStatus.running => const SizedBox.shrink(),
    _ => ColoredBox(color: LoopColors.ink, child: _body()),
  };

  Widget _body() => switch (status) {
    LoopQrCameraStatus.running => const SizedBox.shrink(),
    LoopQrCameraStatus.starting => Center(
      child: Text(
        '正在打开相机…',
        key: const ValueKey<String>('scan-state-loading'),
        style: LoopTypography.caption(12, color: LoopColors.text2),
      ),
    ),
    LoopQrCameraStatus.permissionDenied => const Center(
      child: LoopEmpty(
        key: ValueKey<String>('scan-state-permission'),
        icon: 'camera',
        message: '没有相机权限',
        reason: scanCameraDeniedBody,
      ),
    ),
    LoopQrCameraStatus.unsupported => const Center(
      child: LoopEmpty(
        key: ValueKey<String>('scan-state-unsupported'),
        icon: 'camera',
        message: '这台设备没有可用的相机',
        reason: '可以改用下方的「相册」识别二维码图片。',
      ),
    ),
    LoopQrCameraStatus.failed => Center(
      child: SingleChildScrollView(
        child: LoopErrorState(
          key: const ValueKey<String>('scan-state-error'),
          reason: '相机没有打开。可以重试，或改用下方的「相册」。',
          onRetry: onRetry,
        ),
      ),
    ),
  };
}

/// Four Lime corners: where to hold the code.
class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 28.0;
    final paint = Paint()
      ..color = LoopColors.lime
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, arm)
      ..lineTo(0, 0)
      ..lineTo(arm, 0)
      ..moveTo(w - arm, 0)
      ..lineTo(w, 0)
      ..lineTo(w, arm)
      ..moveTo(w, h - arm)
      ..lineTo(w, h)
      ..lineTo(w - arm, h)
      ..moveTo(arm, h)
      ..lineTo(0, h)
      ..lineTo(0, h - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => false;
}

/// An unrecognised code: said plainly, shown in full, copyable.
class _UnknownCode extends StatelessWidget {
  const _UnknownCode({
    required this.text,
    required this.onCopy,
    required this.onContinue,
  });

  final String text;
  final VoidCallback onCopy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('scan-unknown'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LoopNotice(
        icon: 'info',
        title: '不是 LOOP 二维码',
        body: 'LOOP 不会打开这段内容，只把它显示在下面。',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LoopSurfaceCard(
          child: SelectableText(
            text,
            key: const ValueKey<String>('scan-unknown-text'),
            maxLines: 6,
            style: LoopTypography.code(12, color: LoopColors.text2),
          ),
        ),
      ),
      LoopButtonPair(
        children: <Widget>[
          LoopButton(
            key: const ValueKey<String>('scan-unknown-copy'),
            label: '复制',
            onPressed: onCopy,
          ),
          LoopButton(
            key: const ValueKey<String>('scan-unknown-continue'),
            label: '继续扫描',
            primary: true,
            onPressed: onContinue,
          ),
        ],
      ),
    ],
  );
}

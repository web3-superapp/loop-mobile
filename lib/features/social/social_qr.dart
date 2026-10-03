// 开发交接 S-05：默认无相机解码器；粘贴识别不是原生扫码验收。
// 码是公开资源定位，不是加入/好友授权；系统相机唤起尚未验收。
// 详见 docs/handoff/2026-10-03-social-development-handoff.md。

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/qr/loop_qr_code.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Offline social QR payloads are discovery locators, never admission tokens.
/// No Stream CID, wallet address or private account key enters the symbol.
String communityQrPayload(String id) => Uri(
  scheme: 'loop',
  host: 'community',
  pathSegments: <String>[id],
).toString();
String userQrPayload(String loopId) => loopId;

/// Strict allowlist: recognise only an exact ID, our social scheme, or an
/// HTTPS link on this build's configured origin. Never navigate arbitrary QR URLs.
String? socialQrLocation(String value, {String? trustedBaseUrl}) {
  try {
    return _socialQrLocation(value, trustedBaseUrl: trustedBaseUrl);
  } on FormatException {
    return null;
  }
}

String? _socialQrLocation(String value, {String? trustedBaseUrl}) {
  final text = value.trim();
  if (text.length > 512 ||
      text.contains('..') ||
      RegExp(r'%2e', caseSensitive: false).hasMatch(text)) {
    return null;
  }
  final id = loopIdFromText(text);
  if (id != null && id.length == text.length) return loopIdSearchLocation(id);
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  String? community;
  if (uri.scheme == 'loop' &&
      uri.host == 'community' &&
      !uri.hasPort &&
      uri.pathSegments.length == 1) {
    community = uri.pathSegments.single;
  } else {
    final trusted = Uri.tryParse(trustedBaseUrl ?? '');
    if (uri.scheme != 'https' ||
        trusted == null ||
        trusted.scheme != 'https' ||
        trusted.host.isEmpty ||
        uri.origin != trusted.origin) {
      return null;
    }
    final user = loopIdFromLinkPath(uri.path);
    if (user != null) return loopIdSearchLocation(user);
    final match = RegExp(r'^/c/([A-Za-z0-9_-]{1,64})/?$').firstMatch(uri.path);
    community = match?.group(1);
  }
  if (community == null ||
      !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(community)) {
    return null;
  }
  return Uri(
    path: '/community/profile',
    queryParameters: {'id': community},
  ).toString();
}

/// A platform adapter may provide camera decoding; absence never fakes a scan.
typedef SocialQrScanner = Future<String?> Function();
final socialQrScannerProvider = Provider<SocialQrScanner?>((ref) => null);

class SocialQrSymbol extends StatelessWidget {
  const SocialQrSymbol({required this.payload, this.size = 200, super.key});
  final String payload;
  final double size;
  @override
  Widget build(BuildContext context) {
    final code = LoopQrCode.encode(payload);
    if (code == null) return const Text('二维码无法生成');
    return Semantics(
      label: 'LOOP 二维码',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _QrPainter(code)),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.code);
  final LoopQrCode code;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final cell = size.shortestSide / (code.size + 8);
    final paint = Paint()..color = Colors.black;
    for (var y = 0; y < code.size; y++) {
      for (var x = 0; x < code.size; x++) {
        if (code.isDark(x, y)) {
          canvas.drawRect(
            Rect.fromLTWH((x + 4) * cell, (y + 4) * cell, cell, cell),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.code != code;
}

Future<void> showSocialQr(
  BuildContext context, {
  required String title,
  required String payload,
  required String caption,
}) {
  final posterKey = GlobalKey();
  var sharing = false;
  return showLoopSheet<void>(
    Navigator.of(context, rootNavigator: true).context,
    barrierLabel: '关闭二维码',
    builder: (context) => Consumer(
      builder: (context, ref, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: posterKey,
              child: Container(
                color: LoopColors.ink,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: LoopTypography.title(22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      caption,
                      style: LoopTypography.caption(
                        13,
                        color: LoopColors.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SocialQrSymbol(payload: payload),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: LoopButton(
                    label: '复制',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: payload));
                      if (context.mounted) {
                        LoopToast.show(context, message: '已复制');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LoopButton(
                    label: '分享',
                    primary: true,
                    onPressed: () async {
                      if (sharing) return;
                      sharing = true;
                      try {
                        final boundary =
                            posterKey.currentContext!.findRenderObject()!
                                as RenderRepaintBoundary;
                        final image = await boundary.toImage(pixelRatio: 3);
                        try {
                          final bytes = await image.toByteData(
                            format: ui.ImageByteFormat.png,
                          );
                          if (bytes == null) {
                            throw StateError('QR encoding failed');
                          }
                          final outcome = await ref
                              .read(chatMergeExportSinkProvider)
                              .shareImage(
                                pngBytes: bytes.buffer.asUint8List(),
                                fileName: 'loop-social-qr.png',
                              );
                          if (context.mounted &&
                              (outcome == ChatMergeExportOutcome.failed ||
                                  outcome ==
                                      ChatMergeExportOutcome.unavailable)) {
                            LoopToast.show(context, message: '无法打开图片分享，可以先复制');
                          }
                        } finally {
                          image.dispose();
                        }
                      } catch (_) {
                        if (context.mounted) {
                          LoopToast.show(context, message: '二维码图片未生成，请重试');
                        }
                      } finally {
                        sharing = false;
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> openSocialScan(BuildContext context, WidgetRef ref) async {
  final router = GoRouter.of(context);
  final base = ref.read(loopIdLinkBaseUrlProvider);
  final scanner = ref.read(socialQrScannerProvider);
  String? result;
  if (scanner != null) {
    try {
      result = await scanner();
    } catch (_) {
      if (context.mounted) LoopToast.show(context, message: '无法使用相机，请粘贴二维码内容');
    }
    if (!context.mounted) return;
  }
  if (result == null && context.mounted) {
    result = await showLoopSheet<String>(
      Navigator.of(context, rootNavigator: true).context,
      builder: (_) => const _QrInput(),
    );
  }
  if (result == null || !context.mounted) return;
  final location = socialQrLocation(result, trustedBaseUrl: base);
  if (location == null) {
    LoopToast.show(context, message: '请使用 LOOP 用户或社区二维码');
    return;
  }
  unawaited(router.push(location));
}

class _QrInput extends StatefulWidget {
  const _QrInput();
  @override
  State<_QrInput> createState() => _QrInputState();
}

class _QrInputState extends State<_QrInput> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('识别 LOOP 二维码', style: LoopTypography.title(20)),
        const SizedBox(height: 8),
        Text(
          '当前无法使用相机，可粘贴 LOOP ID 或二维码内容。',
          style: LoopTypography.caption(13, color: LoopColors.muted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          autofocus: true,
          maxLength: 512,
          decoration: const InputDecoration(hintText: 'LOOP ID / 社区二维码内容'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        const SizedBox(height: 12),
        LoopButton(
          label: '识别',
          primary: true,
          onPressed: () => Navigator.of(context).pop(_text.text),
        ),
      ],
    ),
  );
}

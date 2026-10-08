import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/qr/loop_qr_code.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:loop_mobile/features/community/community_link.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Who a QR card introduces (decision 0113, S109b §3.1).
///
/// Only what the card prints and what the code carries: a person by LOOP ID,
/// a community by its id. Nothing here is read again by the card; the opener
/// passes what its own page already shows.
sealed class LoopQrCardSubject {
  const LoopQrCardSubject();
}

/// A person: their avatar, their name and the LOOP ID the code links to.
final class LoopUserQrCard extends LoopQrCardSubject {
  const LoopUserQrCard({
    required this.loopId,
    required this.displayName,
    this.avatarRef,
  });

  final String loopId;
  final String displayName;
  final String? avatarRef;
}

/// A community: its logo, its name, its member count and its one-line
/// description.
final class LoopCommunityQrCard extends LoopQrCardSubject {
  const LoopCommunityQrCard({
    required this.communityId,
    required this.name,
    required this.memberCount,
    this.logoRef,
    this.description,
  });

  final String communityId;
  final String name;
  final int memberCount;
  final String? logoRef;
  final String? description;
}

/// The readable link the card offers, or null when this build has no
/// backend host to build one on.
String? loopQrCardLink(LoopQrCardSubject subject, String backendBaseUrl) =>
    switch (subject) {
      LoopUserQrCard(:final loopId) => loopIdProfileLink(
        backendBaseUrl,
        loopId,
      ),
      LoopCommunityQrCard(:final communityId) => communityCardLink(
        backendBaseUrl,
        communityId,
      ),
    };

/// What the QR symbol carries: the link, or — for a person in a build with
/// no host — the bare LOOP ID, which the scanner recognises just the same.
/// A community has no address without a host, so it gets no symbol at all.
String? loopQrCardPayload(LoopQrCardSubject subject, String backendBaseUrl) =>
    loopQrCardLink(subject, backendBaseUrl) ??
    switch (subject) {
      LoopUserQrCard(:final loopId) => loopId,
      LoopCommunityQrCard() => null,
    };

/// The invitation text 「复制邀请文字」 puts on the clipboard.
String loopQrCardInviteText(LoopQrCardSubject subject, String backendBaseUrl) {
  final link = loopQrCardLink(subject, backendBaseUrl);
  return switch (subject) {
    LoopUserQrCard(:final loopId) => loopIdShareTextFor(
      loopId,
      backendBaseUrl: backendBaseUrl,
    ),
    LoopCommunityQrCard(:final name) =>
      link == null ? '来 LOOP 加入『$name』' : '来 LOOP 加入『$name』\n$link',
  };
}

/// zh-CN copy for one poster export. It states only what happened.
String loopPosterExportMessage(ChatMergeExportOutcome outcome) =>
    switch (outcome) {
      ChatMergeExportOutcome.shared => '海报已生成，请在分享面板中选择去处',
      ChatMergeExportOutcome.dismissed => '海报已生成，但没有选择分享去处',
      ChatMergeExportOutcome.failed => '海报没有生成成功，没有任何内容离开这台设备',
      ChatMergeExportOutcome.unavailable => '本次运行没有装配系统分享，海报未生成',
    };

/// Opens the QR card sheet for [subject].
///
/// The sheet *is* the poster: what the reader sees is exactly what
/// 「分享海报」 encodes, so there is no second, unseen layout that could drift
/// from it. Below it are the link with its copy control and the invitation
/// text, for a reader who would rather paste than send a picture.
Future<void> showLoopQrCardSheet(
  BuildContext context,
  LoopQrCardSubject subject,
) => showLoopSheet<void>(
  context,
  barrierLabel: '关闭二维码名片',
  useRootNavigator: true,
  builder: (sheetContext) => LoopQrCardSheet(subject: subject),
);

/// The card sheet's body. Public so a test can mount it without a route.
class LoopQrCardSheet extends ConsumerStatefulWidget {
  const LoopQrCardSheet({required this.subject, super.key});

  final LoopQrCardSubject subject;

  @override
  ConsumerState<LoopQrCardSheet> createState() => _LoopQrCardSheetState();
}

class _LoopQrCardSheetState extends ConsumerState<LoopQrCardSheet> {
  final GlobalKey _posterKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(loopIdLinkBaseUrlProvider);
    final subject = widget.subject;
    final link = loopQrCardLink(subject, base);
    final payload = loopQrCardPayload(subject, base);
    final code = payload == null ? null : LoopQrCode.encode(payload);
    final screenHeight = MediaQuery.sizeOf(context).height;
    // The poster keeps its 2:3 shape at any size; on a short phone it gives
    // way so the link and the two actions stay inside the sheet.
    final posterHeight = (screenHeight * 0.5).clamp(300.0, 480.0);
    return Padding(
      key: const ValueKey<String>('qr-card-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(switch (subject) {
            LoopUserQrCard() => '我的二维码名片',
            LoopCommunityQrCard() => '社区二维码名片',
          }, style: LoopTypography.heading(18, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (code == null)
            const LoopUnavailableCard(
              key: ValueKey<String>('qr-card-unavailable'),
              label: '二维码不可用',
              reasonCode: 'QR_CARD_LINK_UNAVAILABLE',
              margin: EdgeInsets.zero,
            )
          else
            Center(
              child: SizedBox(
                height: posterHeight,
                width: posterHeight * LoopSharePoster.aspectRatio,
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _posterKey,
                    child: LoopSharePoster(subject: subject, code: code),
                  ),
                ),
              ),
            ),
          if (link != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    link,
                    key: const ValueKey<String>('qr-card-link'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.code(11, color: LoopColors.text2),
                  ),
                ),
                LoopIconButton(
                  key: const ValueKey<String>('qr-card-copy-link'),
                  icon: 'copy',
                  label: '复制链接',
                  onPressed: () => unawaited(_copy(link, '已复制链接')),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('qr-card-share-poster'),
                label: _exporting ? '正在生成…' : '分享海报',
                primary: true,
                onPressed: code == null || _exporting
                    ? null
                    : () => unawaited(_export()),
              ),
              LoopButton(
                key: const ValueKey<String>('qr-card-copy-invite'),
                label: '复制邀请文字',
                onPressed: () => unawaited(
                  _copy(loopQrCardInviteText(subject, base), '已复制邀请文字'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    LoopToast.show(context, message: done);
  }

  /// Captures the poster, encodes it as PNG on device and hands the bytes to
  /// the system share sheet. Nothing is uploaded and nothing is kept.
  Future<void> _export() async {
    setState(() => _exporting = true);
    final sink = ref.read(chatMergeExportSinkProvider);
    ChatMergeExportOutcome outcome;
    try {
      final boundary =
          _posterKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      final bytes = boundary == null ? null : await _encode(boundary);
      outcome = bytes == null
          ? ChatMergeExportOutcome.failed
          : await sink.shareImage(
              pngBytes: bytes,
              fileName: switch (widget.subject) {
                LoopUserQrCard() => 'loop-card.png',
                LoopCommunityQrCard() => 'loop-community-card.png',
              },
            );
    } catch (_) {
      outcome = ChatMergeExportOutcome.failed;
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    LoopToast.show(
      context,
      message: loopPosterExportMessage(outcome),
      kind: outcome == ChatMergeExportOutcome.shared
          ? LoopToastKind.ok
          : LoopToastKind.warn,
    );
  }

  /// The poster is laid out at 360 × 540 and encoded at three times that:
  /// a 1080 × 1620 picture, whatever size it was drawn at in the sheet.
  static Future<Uint8List?> _encode(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(
      pixelRatio: LoopSharePoster.exportPixelRatio,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// `LoopSharePoster` — the shareable picture (decision 0113).
///
/// Ink ground, Lime accents, the face and name at the top, the code on a
/// Chalk plate in the middle and the call to action at the foot. The code
/// itself is always dark modules on a light plate: a scanner reads contrast,
/// and an inverted symbol is the one many camera apps refuse.
class LoopSharePoster extends StatelessWidget {
  const LoopSharePoster({required this.subject, required this.code, super.key});

  final LoopQrCardSubject subject;
  final LoopQrCode code;

  static const double width = 360;
  static const double height = 540;
  static const double aspectRatio = width / height;
  static const double exportPixelRatio = 3;

  @override
  Widget build(BuildContext context) {
    final (String name, String line, String action) = switch (subject) {
      LoopUserQrCard(:final displayName, :final loopId) => (
        displayName,
        loopId,
        '扫码加我',
      ),
      LoopCommunityQrCard(
        :final name,
        :final memberCount,
        :final description,
      ) =>
        (
          name,
          description == null || description.trim().isEmpty
              ? '$memberCount 位成员'
              : description.trim(),
          '扫码加入',
        ),
    };
    final face = switch (subject) {
      LoopUserQrCard(:final avatarRef, :final displayName) => LoopProfileAvatar(
        avatarRef: avatarRef,
        alias: displayName,
        size: 56,
      ),
      LoopCommunityQrCard(:final communityId, :final name, :final logoRef) =>
        CommunityLogo(
          identity: communityId,
          name: name,
          logoRef: logoRef,
          size: 56,
          radius: 16,
        ),
    };
    return Semantics(
      key: const ValueKey<String>('qr-card-poster'),
      container: true,
      label: '$name 的二维码名片',
      child: DefaultTextStyle(
        style: LoopTypography.body(14),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            color: LoopColors.ink,
            borderRadius: BorderRadius.circular(LoopRadius.shellValue),
            border: Border.all(color: LoopColors.line2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  face,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopTypography.heading(
                            20,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          line,
                          key: const ValueKey<String>('qr-card-poster-line'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subject is LoopUserQrCard
                              ? LoopTypography.code(12, color: LoopColors.lime)
                              : LoopTypography.caption(
                                  12,
                                  color: LoopColors.text2,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 236,
                  height: 236,
                  decoration: BoxDecoration(
                    color: LoopColors.chalk,
                    borderRadius: BorderRadius.circular(LoopRadius.cardValue),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: LoopQrView(
                    key: const ValueKey<String>('qr-card-code'),
                    code: code,
                    semanticLabel: '$name 的二维码',
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: LoopColors.lime,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'LOOP',
                      style: LoopTypography.label(
                        12,
                        weight: FontWeight.w700,
                        color: LoopColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'LOOP · $action',
                      key: const ValueKey<String>('qr-card-poster-action'),
                      style: LoopTypography.title(15),
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
}

/// One QR symbol, drawn Ink on Chalk with the mandatory four-module quiet
/// zone. The symbol fills the shortest side of whatever box it is given.
class LoopQrView extends StatelessWidget {
  const LoopQrView({
    required this.code,
    required this.semanticLabel,
    super.key,
  });

  final LoopQrCode code;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(painter: _LoopQrPainter(code)),
    ),
  );
}

class _LoopQrPainter extends CustomPainter {
  const _LoopQrPainter(this.code);

  final LoopQrCode code;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const quietZone = 4;
    final modules = code.size + quietZone * 2;
    final scale = size.shortestSide / modules;
    canvas.drawRect(Offset.zero & size, Paint()..color = LoopColors.chalk);
    final paint = Paint()..color = LoopColors.ink;
    for (var y = 0; y < code.size; y += 1) {
      for (var x = 0; x < code.size; x += 1) {
        if (!code.isDark(x, y)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (x + quietZone) * scale,
            (y + quietZone) * scale,
            scale,
            scale,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LoopQrPainter oldDelegate) =>
      oldDelegate.code != code;
}

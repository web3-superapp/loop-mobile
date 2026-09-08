import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// One extra command a caller offers on the public-profile sheet.
///
/// The sheet only renders it; the caller owns its confirmation and its result.
@immutable
final class PublicProfileSheetAction<T> {
  const PublicProfileSheetAction({
    required this.id,
    required this.label,
    required this.value,
  });

  /// Widget-key suffix, so a caller's test can find its own command.
  final String id;
  final String label;
  final T value;
}

/// The shared "public profile" panel.
///
/// LOOP has no dedicated page for another account before D7, so a user search
/// result and a member-directory row open this sheet instead of routing
/// somewhere that would have to invent a page. It shows only the fixed
/// four-field identity projection: no wallet address, no profile code, and no
/// figure the server did not send.
///
/// Returns the value of the extra command the viewer chose, or null when the
/// sheet was dismissed or only the follow control was used.
Future<T?> showPublicProfileSheet<T extends Object>(
  BuildContext context, {
  required LoopPublicProfile profile,
  bool? viewerFollows,
  List<PublicProfileSheetAction<T>> actions =
      const <PublicProfileSheetAction<Never>>[],
}) {
  return showLoopSheet<T>(
    context,
    barrierLabel: '关闭公开资料',
    builder: (sheetContext) => _PublicProfileSheet<T>(
      profile: profile,
      viewerFollows: viewerFollows,
      actions: actions,
    ),
  );
}

class _PublicProfileSheet<T extends Object> extends ConsumerStatefulWidget {
  const _PublicProfileSheet({
    required this.profile,
    required this.viewerFollows,
    required this.actions,
  });

  final LoopPublicProfile profile;
  final bool? viewerFollows;
  final List<PublicProfileSheetAction<T>> actions;

  @override
  ConsumerState<_PublicProfileSheet<T>> createState() =>
      _PublicProfileSheetState<T>();
}

class _PublicProfileSheetState<T extends Object>
    extends ConsumerState<_PublicProfileSheet<T>> {
  late bool? _following = widget.viewerFollows;
  var _busy = false;
  CommunityFailureKind? _failureKind;

  Future<void> _toggleFollow() async {
    final target = widget.profile.publicProfileId;
    if (target == null || _busy) return;
    final next = !(_following ?? false);
    setState(() {
      _busy = true;
      _failureKind = null;
    });
    try {
      final outcome = await ref
          .read(socialGatewayProvider)
          .setFollowing(publicProfileId: target, following: next);
      if (!mounted) return;
      // The badge repeats the server's own `viewerFollows`, never the request.
      setState(() {
        _following = outcome.viewerFollows;
        _busy = false;
      });
    } on CommunityGatewayException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failureKind = error.kind;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failureKind = CommunityFailureKind.unexpected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final following = _following;
    final canFollow = profile.isCommandTarget;
    return Padding(
      key: const ValueKey<String>('public-profile-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              LoopProfileAvatar(
                avatarRef: profile.avatarRef,
                alias: profile.alias,
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.displayName,
                      key: const ValueKey<String>('public-profile-name'),
                      style: LoopTypography.sora(
                        size: 17,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.loopId,
                      key: const ValueKey<String>('public-profile-loop-id'),
                      style: LoopTypography.mono(
                        size: 12,
                        color: LoopColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (following != null)
                LoopBadge(
                  following ? '已关注' : '未关注',
                  key: const ValueKey<String>('public-profile-follow-state'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!canFollow)
            const LoopEmpty(
              key: ValueKey<String>('public-profile-not-targetable'),
              icon: 'warn',
              message: '这个成员没有可用的公开资料',
              reason: '服务端没有为该账号返回公开资料标识，因此不能关注，也不能作为任何操作的目标。',
              margin: EdgeInsets.zero,
            )
          else ...<Widget>[
            if (following == null)
              const LoopNotice(
                key: ValueKey<String>('public-profile-follow-unknown'),
                icon: 'info',
                body: '当前关注状态没有随本页下发，按钮结果以服务端返回为准。',
                margin: EdgeInsets.only(bottom: 12),
              ),
            LoopButton(
              key: const ValueKey<String>('public-profile-follow'),
              label: (following ?? false) ? '取消关注' : '关注',
              primary: !(following ?? false),
              block: true,
              onPressed: _busy ? null : () => unawaited(_toggleFollow()),
            ),
            const SizedBox(height: 8),
          ],
          // `dm` has no V2 send path before D7; the control states that
          // instead of opening a conversation that cannot exist.
          LoopButton(
            key: const ValueKey<String>('public-profile-open-dm'),
            label: '打开私聊',
            block: true,
            onPressed: null,
          ),
          const SizedBox(height: 6),
          Text(
            '私聊要等 Stream 会话接通（D7）后才能从这里发起。',
            key: const ValueKey<String>('public-profile-dm-reason'),
            style: LoopTypography.sora(
              size: 11.5,
              weight: FontWeight.w500,
              color: LoopColors.muted,
            ),
          ),
          if (_failureKind != null) ...<Widget>[
            const SizedBox(height: 12),
            LoopNotice(
              key: const ValueKey<String>('public-profile-failure'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '上一次操作没有完成',
              body: communityFailureReason(_failureKind),
              margin: EdgeInsets.zero,
            ),
          ],
          for (final action in widget.actions) ...<Widget>[
            const SizedBox(height: 8),
            LoopButton(
              key: ValueKey<String>('public-profile-action-${action.id}'),
              label: action.label,
              block: true,
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).pop(action.value),
            ),
          ],
          const SizedBox(height: 10),
          LoopButton(
            key: const ValueKey<String>('public-profile-close'),
            label: '关闭',
            block: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

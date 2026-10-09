import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_time_format.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/loop_id_copy.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_controller.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_round_key.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The location of another account's profile page (manifest `user-profile`).
String userProfileLocation(String publicProfileId) => Uri(
  path: '/profile/user',
  queryParameters: <String, String>{'id': publicProfileId},
).toString();

/// The same page addressed by a LOOP ID — the `/u/{loopId}` link.
String userProfileLoopIdLocation(String loopId) => Uri(
  path: '/profile/user',
  queryParameters: <String, String>{'loopId': loopId},
).toString();

final RegExp _profileIdQuery = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _loopIdQuery = RegExp(r'^LOOP-[0-9A-HJKMNP-TV-Z]{8}$');

/// Reads the page's subject from its query, or `null` for a location that
/// names nobody the page may ask for. Nothing is guessed from display copy.
PublicProfileTarget? userProfileTargetFromQuery(Map<String, String> query) {
  final id = query['id'];
  if (id != null) {
    return _profileIdQuery.hasMatch(id) ? PublicProfileById(id) : null;
  }
  final loopId = query['loopId']?.toUpperCase();
  if (loopId != null && _loopIdQuery.hasMatch(loopId)) {
    return PublicProfileByLoopId(loopId);
  }
  return null;
}

/// `user-profile` · record / stream (S107 §3, decision 0112).
///
/// Another account: who they are, what the viewer can do with them, and —
/// when they let it be seen — what they hold and what they traded. Opened
/// from a chat avatar, a search result, a community member row and a `/u/`
/// link. The viewer's own account never opens here; it goes to 我.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({
    required this.target,
    super.key,
    this.onBack,
    this.onOpenSelf,
    this.onOpenDirectMessage,
    this.onOpenFriendRequests,
    this.onOpenToken,
  });

  final PublicProfileTarget? target;
  final VoidCallback? onBack;

  /// The page turned out to be the viewer's own: 我 replaces it.
  final VoidCallback? onOpenSelf;
  final ValueChanged<LoopPublicProfile>? onOpenDirectMessage;
  final VoidCallback? onOpenFriendRequests;
  final ValueChanged<String>? onOpenToken;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  var _section = PublicProfileSection.holdings;
  var _handedToSelf = false;

  void _handToSelf() {
    if (_handedToSelf) return;
    _handedToSelf = true;
    scheduleMicrotask(() {
      if (mounted) widget.onOpenSelf?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    if (target == null) {
      return LoopStreamPage(
        key: const ValueKey<String>('user-profile-screen'),
        archetype: LoopPageArchetype.record,
        title: '用户资料',
        onBack: widget.onBack,
        collection: const SizedBox.shrink(),
        block: const LoopEmpty(
          key: ValueKey<String>('user-profile-invalid-target'),
          icon: 'warn',
          message: '链接里没有可打开的用户',
          reason: '请从聊天、搜索或成员列表进入。',
        ),
      );
    }
    final ownLoopId = ref.watch(
      profileControllerProvider.select((state) => state.resource?.loopId),
    );
    if (target is PublicProfileByLoopId && target.loopId == ownLoopId) {
      _handToSelf();
    }
    final provider = publicProfileControllerProvider(target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (state.phase == CommunityViewPhase.loading && state.record == null) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final record = state.record;
    if (record != null && ownLoopId != null && record.loopId == ownLoopId) {
      _handToSelf();
    }
    return LoopStreamPage(
      key: const ValueKey<String>('user-profile-screen'),
      archetype: LoopPageArchetype.record,
      title: record?.displayName ?? '用户资料',
      kicker: communityPreviewKicker(state.mode),
      onBack: widget.onBack,
      onRefresh: record == null ? null : controller.reload,
      collection: ListView(
        key: const ValueKey<String>('user-profile-list'),
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          CommunityPreviewNotice(mode: state.mode, resource: '用户资料'),
          if (record == null)
            _RecordStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            _ProfileHeader(
              record: record,
              busy: state.busy,
              onFollow: record.relationship.blocked
                  ? null
                  : () => unawaited(
                      _run(
                        controller.setFollowing(!record.relationship.following),
                      ),
                    ),
            ),
            if (record.relationship.blocked)
              _BlockedNotice(
                busy: state.busy,
                onUnblock: () => unawaited(_run(controller.setBlocked(false))),
              )
            else ...<Widget>[
              _ActionRow(
                record: record,
                busy: state.busy,
                onFriend: () => unawaited(_friend(record, controller)),
                onShare: () => unawaited(_shareCard(record)),
                onMore: () => unawaited(_openMore(record, controller)),
                onMessage: widget.onOpenDirectMessage == null
                    ? null
                    : () => widget.onOpenDirectMessage!(
                        LoopPublicProfile(
                          publicProfileId: record.publicProfileId,
                          loopId: record.loopId,
                          alias: record.alias,
                          avatarRef: record.avatarRef,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: LoopSegBar(
                  key: const ValueKey<String>('user-profile-sections'),
                  labels: const <String>['持仓', '交易', '社区'],
                  selectedIndex: _section.index,
                  onSelected: (index) => setState(
                    () => _section = PublicProfileSection.values[index],
                  ),
                ),
              ),
              switch (_section) {
                PublicProfileSection.holdings => _HoldingsSection(
                  record: record,
                  state: state.holdings,
                  onLoad: controller.loadHoldings,
                  onOpenToken: widget.onOpenToken,
                ),
                PublicProfileSection.trades => _TradesSection(
                  record: record,
                  state: state.trades,
                  onLoad: controller.loadTrades,
                  onLoadMore: controller.loadMoreTrades,
                ),
                PublicProfileSection.communities => _CommunitiesSection(
                  record: record,
                ),
              },
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _run(Future<PublicProfileActionOutcome?> pending) async {
    final outcome = await pending;
    if (outcome == null || !mounted) return;
    LoopToast.show(
      context,
      message: outcome.message,
      kind: outcome.failed ? LoopToastKind.warn : LoopToastKind.ok,
    );
  }

  Future<void> _friend(
    PublicProfileRecord record,
    PublicProfileController controller,
  ) async {
    switch (record.relationship.friendship) {
      case ProfileFriendship.none:
        await _run(controller.requestFriend());
      case ProfileFriendship.pendingIn:
        widget.onOpenFriendRequests?.call();
      case ProfileFriendship.pendingOut:
      case ProfileFriendship.friends:
        return;
    }
  }

  /// Decision 0113: this account's QR card, the same one 我 shows.
  Future<void> _shareCard(PublicProfileRecord record) => showLoopQrCardSheet(
    context,
    LoopUserQrCard(
      loopId: record.loopId,
      displayName: record.displayName,
      avatarRef: record.avatarRef,
    ),
  );

  Future<void> _openMore(
    PublicProfileRecord record,
    PublicProfileController controller,
  ) async {
    final choice = await showLoopSheet<String>(
      context,
      barrierLabel: '关闭更多操作',
      builder: (sheetContext) => Padding(
        key: const ValueKey<String>('user-profile-more-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (record.relationship.friendship ==
                ProfileFriendship.friends) ...<Widget>[
              LoopButton(
                key: const ValueKey<String>('user-profile-remove-friend'),
                label: '删除好友',
                block: true,
                onPressed: () => Navigator.of(sheetContext).pop('unfriend'),
              ),
              const SizedBox(height: 8),
            ],
            LoopButton(
              key: const ValueKey<String>('user-profile-block'),
              label: record.relationship.blocked ? '解除拉黑' : '拉黑',
              block: true,
              onPressed: () =>
                  Navigator.of(sheetContext)
                      .pop(record.relationship.blocked ? 'unblock' : 'block'),
            ),
            const SizedBox(height: 8),
            // There is no report endpoint for an account outside a message
            // request yet, so the entry is shown and says so rather than
            // pretending a report was filed.
            const LoopButton(
              key: ValueKey<String>('user-profile-report'),
              label: '举报并屏蔽',
              block: true,
            ),
            const SizedBox(height: 6),
            Text(
              '举报通道暂未开放；需要时可以先拉黑。',
              key: const ValueKey<String>('user-profile-report-unavailable'),
              textAlign: TextAlign.center,
              style: LoopTypography.caption(12, color: LoopColors.text3),
            ),
            const SizedBox(height: 10),
            LoopButton(
              label: '取消',
              block: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'unfriend':
        final confirmed = await confirmCommunityAction(
          context,
          title: '删除好友？',
          body: '删除后你们不再是好友，私聊记录保留。之后可以重新申请。',
          confirmLabel: '删除',
          sheetKey: 'user-profile-unfriend-confirm',
        );
        if (confirmed) await _run(controller.removeFriend());
      case 'block':
        final confirmed = await confirmCommunityAction(
          context,
          title: '拉黑 ${record.displayName}？',
          body: '拉黑后对方看不到你的资料，也不能给你发消息或好友申请。可以在「屏蔽名单」里解除。',
          confirmLabel: '拉黑',
          sheetKey: 'user-profile-block-confirm',
        );
        if (confirmed) await _run(controller.setBlocked(true));
      case 'unblock':
        await _run(controller.setBlocked(false));
    }
  }
}

class _RecordStateBlock extends StatelessWidget {
  const _RecordStateBlock({
    required this.phase,
    required this.failureKind,
    required this.onRetry,
  });

  final CommunityViewPhase phase;
  final CommunityFailureKind? failureKind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (phase == CommunityViewPhase.empty) {
      // `404 PROFILE_NOT_FOUND`: no such account, or one that blocked the
      // viewer. The server does not say which and neither does the page.
      return const LoopEmpty(
        key: ValueKey<String>('user-profile-not-found'),
        icon: 'user',
        message: '找不到这个用户',
        reason: '账号不存在，或对方的资料对你不可见。',
      );
    }
    if (phase == CommunityViewPhase.unavailable) {
      return const LoopEmpty(
        key: ValueKey<String>('user-profile-unavailable'),
        icon: 'warn',
        message: '用户资料暂不可用',
        reason: '资料服务还没有开放，这一页没有读取任何内容。',
      );
    }
    return CommunityStateBlock(
      key: const ValueKey<String>('user-profile-state'),
      phase: phase,
      failureKind: failureKind,
      skeleton: LoopSkeletonType.detail,
      rows: 3,
      onRetry: onRetry,
    );
  }
}

/// The header (decision 0127, Fomo / OKX): the face at 72, the name at 22
/// over the LOOP ID, 关注 as a small capsule on the right, the bio and the
/// three counts.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.record,
    required this.busy,
    required this.onFollow,
  });

  final PublicProfileRecord record;
  final bool busy;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final bio = record.bio;
    final following = record.relationship.following;
    final follow = onFollow;
    return Padding(
      key: const ValueKey<String>('user-profile-header'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              LoopProfileAvatar(
                avatarRef: record.avatarRef,
                alias: record.displayName,
                size: 72,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      record.displayName,
                      key: const ValueKey<String>('user-profile-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.heading(
                        22,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    LoopIdCopyLine(
                      loopId: record.loopId,
                      textKey: const ValueKey<String>('user-profile-loop-id'),
                      copyKey: const ValueKey<String>(
                        'user-profile-copy-loop-id',
                      ),
                      style: LoopTypography.figure(
                        13,
                        weight: FontWeight.w400,
                        height: 1.5,
                        color: LoopColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (follow != null)
                LoopPillAction(
                  key: ValueKey<String>(
                    following ? 'user-profile-unfollow' : 'user-profile-follow',
                  ),
                  label: following ? '已关注' : '关注',
                  primary: false,
                  onPressed: busy ? null : follow,
                ),
            ],
          ),
          if (bio != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              bio,
              key: const ValueKey<String>('user-profile-bio'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.body(14, color: LoopColors.text2),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            key: const ValueKey<String>('user-profile-counts'),
            children: <Widget>[
              _Count(label: '关注', value: record.counts.following),
              const SizedBox(width: 22),
              _Count(label: '粉丝', value: record.counts.followers),
              const SizedBox(width: 22),
              _Count(label: '社区', value: record.counts.communities),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: <Widget>[
      Text(
        loopFormatDecimal(Decimal.fromInt(value), maxFractionDigits: 0),
        style: LoopTypography.figure(16, color: LoopColors.chalk),
      ),
      const SizedBox(width: 4),
      Text(label, style: LoopTypography.caption(13, color: LoopColors.text2)),
    ],
  );
}

/// The round keys (decision 0127): 加好友 while there is no friendship, then
/// 私聊, 分享 and 更多. A friend has three keys; a stranger four.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.record,
    required this.busy,
    required this.onFriend,
    required this.onMessage,
    required this.onShare,
    required this.onMore,
  });

  final PublicProfileRecord record;
  final bool busy;
  final VoidCallback onFriend;
  final VoidCallback? onMessage;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final friendship = record.relationship.friendship;
    final friendEnabled =
        !busy &&
        (friendship == ProfileFriendship.none ||
            friendship == ProfileFriendship.pendingIn);
    final message = onMessage;
    return LoopRoundKeyRow(
      key: const ValueKey<String>('user-profile-keys'),
      keys: <Widget>[
        if (friendship != ProfileFriendship.friends)
          LoopRoundKey(
            key: ValueKey<String>('user-profile-friend-${friendship.wireName}'),
            icon: switch (friendship) {
              ProfileFriendship.none => 'plus',
              ProfileFriendship.pendingIn => 'mail',
              _ => 'check',
            },
            label: switch (friendship) {
              ProfileFriendship.none => '加好友',
              ProfileFriendship.pendingOut => '已申请',
              ProfileFriendship.pendingIn => '处理申请',
              ProfileFriendship.friends => '已是好友',
            },
            onPressed: friendEnabled ? onFriend : null,
          ),
        LoopRoundKey(
          key: const ValueKey<String>('user-profile-message'),
          icon: 'chat',
          label: friendship == ProfileFriendship.friends ? '聊天' : '私聊',
          onPressed: busy || message == null ? null : message,
        ),
        LoopRoundKey(
          key: const ValueKey<String>('user-profile-share-card'),
          icon: 'share',
          label: '分享',
          semanticLabel: '分享名片',
          onPressed: onShare,
        ),
        LoopRoundKey(
          key: const ValueKey<String>('user-profile-more'),
          icon: 'keypad',
          label: '更多',
          semanticLabel: '更多操作',
          onPressed: busy ? null : onMore,
        ),
      ],
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice({required this.busy, required this.onUnblock});

  final bool busy;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) => LoopNotice(
    key: const ValueKey<String>('user-profile-blocked'),
    icon: 'blocked',
    tone: LoopNoticeTone.warn,
    title: '你已拉黑对方',
    body: '对方不能给你发消息或好友申请，你也看不到对方的持仓与交易。',
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    trailing: LoopButton(
      key: const ValueKey<String>('user-profile-unblock'),
      label: '解除',
      onPressed: busy ? null : onUnblock,
    ),
  );
}

/// The hidden branch, shared by both sections: the account keeps it private.
class _HiddenSection extends StatelessWidget {
  const _HiddenSection({required this.sectionKey, required this.what});

  final String sectionKey;
  final String what;

  @override
  Widget build(BuildContext context) => LoopEmptyState(
    key: ValueKey<String>('user-profile-$sectionKey-hidden'),
    illustration: LoopIllustration.watchlist,
    title: '对方未公开$what',
    message: '对方在隐私设置里关闭了「公开持仓与交易」。',
    compact: true,
  );
}

class _UnavailableSection extends StatelessWidget {
  const _UnavailableSection({
    required this.sectionKey,
    required this.what,
    this.reasonCode,
  });

  final String sectionKey;
  final String what;

  /// The server's reason (backend decision 0095). `WALLET_NOT_BOUND` is a
  /// fact about the account, not an outage, and reads as one.
  final String? reasonCode;

  @override
  Widget build(BuildContext context) => reasonCode == 'WALLET_NOT_BOUND'
      ? LoopEmptyState(
          key: ValueKey<String>('user-profile-$sectionKey-no-wallet'),
          illustration: LoopIllustration.watchlist,
          title: '对方暂无钱包',
          message: '对方还没有绑定钱包，没有可显示的$what。',
          compact: true,
        )
      : LoopEmpty(
          key: ValueKey<String>('user-profile-$sectionKey-unavailable'),
          icon: 'warn',
          message: '$what暂时读不到',
          reason: '链上数据暂不可用，这里不会显示 0 代替。',
        );
}

class _HoldingsSection extends StatelessWidget {
  const _HoldingsSection({
    required this.record,
    required this.state,
    required this.onLoad,
    required this.onOpenToken,
  });

  final PublicProfileRecord record;
  final PublicProfileSectionState<ProfileHoldings> state;
  final Future<void> Function({bool force}) onLoad;
  final ValueChanged<String>? onOpenToken;

  @override
  Widget build(BuildContext context) {
    // The record already says the account keeps it private; no request is
    // made for a section the server would only answer `hidden` for.
    if (!record.visibility.holdings) {
      return const _HiddenSection(sectionKey: 'holdings', what: '持仓');
    }
    final phase = state.phase;
    if (phase == null) {
      scheduleMicrotask(() => unawaited(onLoad()));
    }
    if (phase == null || phase != CommunityViewPhase.ready) {
      if (phase == CommunityViewPhase.unavailable) {
        return const _UnavailableSection(sectionKey: 'holdings', what: '持仓');
      }
      return CommunityStateBlock(
        key: const ValueKey<String>('user-profile-holdings-state'),
        phase: phase ?? CommunityViewPhase.loading,
        failureKind: state.failureKind,
        skeleton: LoopSkeletonType.record,
        rows: 4,
        onRetry: () => unawaited(onLoad(force: true)),
      );
    }
    final value = state.value!;
    switch (value.status) {
      case ProfileSectionStatus.hidden:
        return const _HiddenSection(sectionKey: 'holdings', what: '持仓');
      case ProfileSectionStatus.unavailable:
        return _UnavailableSection(
          sectionKey: 'holdings',
          what: '持仓',
          reasonCode: value.reasonCode,
        );
      case ProfileSectionStatus.available:
        break;
    }
    final total = value.totalUsd;
    return Column(
      key: const ValueKey<String>('user-profile-holdings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '持仓总额',
                style: LoopTypography.caption(12, color: LoopColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                total == null ? '暂无报价' : loopFormatUsd(total),
                key: const ValueKey<String>('user-profile-holdings-total'),
                style: LoopTypography.figure(26, color: LoopColors.chalk),
              ),
              if (value.observedAt case final DateTime observedAt)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '读取于 ${loopLocalTimestampLabel(observedAt)}',
                    style: LoopTypography.caption(11, color: LoopColors.text3),
                  ),
                ),
            ],
          ),
        ),
        if (value.items.isEmpty)
          const LoopEmptyState(
            key: ValueKey<String>('user-profile-holdings-empty'),
            illustration: LoopIllustration.watchlist,
            title: '还没有持仓',
            message: '对方的钱包里暂时没有可显示的资产。',
            compact: true,
          )
        else
          for (final item in value.items) _holdingRow(item),
      ],
    );
  }

  /// One OKX quote row (decision 0127): the token, the value over the
  /// balance. A holding without a quote shows the balance as the figure.
  Widget _holdingRow(ProfileHolding item) {
    final usd = item.usdValue;
    final balance =
        '${loopFormatDecimal(item.balance, maxFractionDigits: 4)} ${item.symbol}';
    final open = onOpenToken;
    return LoopQuoteRow(
      key: ValueKey<String>('user-profile-holding-${item.assetId}'),
      leading: LoopTokenLogo(
        assetSymbol: item.symbol,
        logoUrl: item.logoUrl,
        size: 36,
      ),
      title: item.symbol,
      subtitle: item.name,
      value: usd == null ? balance : loopFormatUsd(usd),
      valueCaption: Text(usd == null ? '暂无报价' : balance),
      onTap: open == null ? null : () => open(item.assetId),
      semanticLabel:
          '${item.symbol}，${usd == null ? balance : loopFormatUsd(usd)}',
    );
  }
}

class _TradesSection extends StatelessWidget {
  const _TradesSection({
    required this.record,
    required this.state,
    required this.onLoad,
    required this.onLoadMore,
  });

  final PublicProfileRecord record;
  final PublicProfileTradesState state;
  final Future<void> Function({bool force}) onLoad;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (!record.visibility.trades) {
      return const _HiddenSection(sectionKey: 'trades', what: '交易');
    }
    final phase = state.phase;
    if (phase == null) {
      scheduleMicrotask(() => unawaited(onLoad()));
    }
    if (phase == null || phase != CommunityViewPhase.ready) {
      if (phase == CommunityViewPhase.unavailable) {
        return const _UnavailableSection(sectionKey: 'trades', what: '交易');
      }
      return CommunityStateBlock(
        key: const ValueKey<String>('user-profile-trades-state'),
        phase: phase ?? CommunityViewPhase.loading,
        failureKind: state.failureKind,
        skeleton: LoopSkeletonType.record,
        rows: 4,
        onRetry: () => unawaited(onLoad(force: true)),
      );
    }
    switch (state.status) {
      case ProfileSectionStatus.hidden:
        return const _HiddenSection(sectionKey: 'trades', what: '交易');
      case ProfileSectionStatus.unavailable:
        return _UnavailableSection(
          sectionKey: 'trades',
          what: '交易',
          reasonCode: state.reasonCode,
        );
      case ProfileSectionStatus.available:
      case null:
        break;
    }
    if (state.items.isEmpty) {
      return const LoopEmptyState(
        key: ValueKey<String>('user-profile-trades-empty'),
        illustration: LoopIllustration.chartEmpty,
        title: '还没有交易',
        message: '对方的钱包还没有可显示的买卖或转账。',
        compact: true,
      );
    }
    return Column(
      key: const ValueKey<String>('user-profile-trades'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final trade in state.items) _tradeRow(trade),
        if (state.appendFailed && !state.loadingMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('user-profile-trades-retry-more'),
              label: '重试',
              block: true,
              onPressed: () => unawaited(onLoadMore()),
            ),
          )
        else if (state.nextCursor case final String cursor) ...<Widget>[
          LoopLoadMoreSentinel(
            key: const ValueKey<String>('user-profile-trades-load-more'),
            cursor: cursor,
            onLoadMore: () => unawaited(onLoadMore()),
          ),
          if (state.loadingMore)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LoopSkeleton(type: LoopSkeletonType.record, rows: 1),
            ),
        ],
        // The end of the list draws nothing (decision 0127).
      ],
    );
  }

  /// One OKX quote row (decision 0127): 买入 / 卖出 and the token, when,
  /// the signed amount over its dollar value.
  Widget _tradeRow(ProfileTrade trade) {
    final usd = trade.usdValue;
    final inbound =
        trade.kind == ProfileTradeKind.buy ||
        trade.kind == ProfileTradeKind.transferIn;
    final amount =
        '${inbound ? '+' : '-'}${loopFormatDecimal(trade.amount, maxFractionDigits: 4)}';
    return LoopQuoteRow(
      key: ValueKey<String>('user-profile-trade-${trade.eventId}'),
      leading: LoopTokenLogo(assetSymbol: trade.symbol, size: 36),
      title: '${trade.kind.label} ${trade.symbol}',
      subtitle: switch ((trade.blockTimestamp, trade.blockNumber)) {
        (final DateTime at, _) => loopLocalTimestampLabel(at),
        (null, final String block) => '区块 #$block',
        (null, null) => null,
      },
      value: amount,
      valueCaption: usd == null
          ? null
          : Text(
              loopFormatUsd(usd),
              style: LoopTypography.body(
                14,
                color: inbound ? LoopColors.rise : LoopColors.text2,
              ),
            ),
    );
  }
}

class _CommunitiesSection extends StatelessWidget {
  const _CommunitiesSection({required this.record});

  final PublicProfileRecord record;

  @override
  Widget build(BuildContext context) => LoopEmpty(
    key: const ValueKey<String>('user-profile-communities-unavailable'),
    icon: 'community',
    message: '已加入 ${record.counts.communities} 个社区',
    reason: '社区列表暂未开放查看。',
  );
}

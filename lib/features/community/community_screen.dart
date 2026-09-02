import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

typedef CommunityNavigation = void Function(String location);

/// UI-first Community home for the v2 product shape.
///
/// The screen intentionally owns no provider, controller, or request. Existing
/// social and Stream destinations remain responsible for proving their own
/// current availability after navigation.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key, this.onNavigate});

  final CommunityNavigation? onNavigate;

  void _open(BuildContext context, String location) {
    final navigate = onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('community-screen'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const _LoopWordmark(),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('community-search-action'),
            onPressed: () => _open(context, '/search'),
            tooltip: '搜索（数据源待接入）',
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            key: const ValueKey<String>('community-chat-action'),
            onPressed: () => _open(context, '/chat'),
            tooltip: '聊天',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          IconButton(
            key: const ValueKey<String>('community-profile-action'),
            onPressed: () => _open(context, '/profile'),
            tooltip: '个人资料',
            icon: const Icon(Icons.person_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _LedgerBackdrop()),
          SafeArea(
            top: false,
            bottom: false,
            child: CustomScrollView(
              key: const ValueKey<String>('community-scroll'),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                  sliver: SliverList.list(
                    children: <Widget>[
                      Text(
                        'COMMUNITY / V2',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: LoopColors.lime,
                              letterSpacing: 1.7,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        header: true,
                        child: Text(
                          '社区',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '社区将成为登录后的默认首页。现阶段先提供已实现的聊天与社交入口，社区数据仍保持明确不可用。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      const _CommunitySourceCard(),
                      const SizedBox(height: 28),
                      const _SectionHeading(
                        index: '01',
                        title: '沟通与关系',
                        caption: '入口已就绪，服务状态由目标页面独立校验',
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final tileWidth = (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              _CommunityRouteTile(
                                key: const ValueKey<String>(
                                  'community-open-chat',
                                ),
                                width: tileWidth,
                                icon: Icons.forum_outlined,
                                title: '聊天',
                                detail: '打开 Stream 会话入口',
                                onTap: () => _open(context, '/chat'),
                              ),
                              _CommunityRouteTile(
                                key: const ValueKey<String>(
                                  'community-open-friends',
                                ),
                                width: tileWidth,
                                icon: Icons.people_outline_rounded,
                                title: '我的好友',
                                detail: '查看服务端确认的好友关系',
                                onTap: () => _open(context, '/profile/friends'),
                              ),
                              _CommunityRouteTile(
                                key: const ValueKey<String>(
                                  'community-add-friend',
                                ),
                                width: tileWidth,
                                icon: Icons.person_add_alt_1_outlined,
                                title: '添加好友',
                                detail: '按昵称搜索并发送申请',
                                onTap: () =>
                                    _open(context, '/chat/friends/add'),
                              ),
                              _CommunityRouteTile(
                                key: const ValueKey<String>(
                                  'community-create-group',
                                ),
                                width: tileWidth,
                                icon: Icons.group_add_outlined,
                                title: '创建群组',
                                detail: '从已确认好友中选择成员',
                                onTap: () =>
                                    _open(context, '/chat/groups/create'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      const _SectionHeading(
                        index: '02',
                        title: '社区内容',
                        caption: '后端 D3–D5 分阶段交付',
                      ),
                      const SizedBox(height: 12),
                      const _UnavailableCommunityIndex(),
                      const SizedBox(height: 16),
                      const _TruthNotice(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopWordmark extends StatelessWidget {
  const _LoopWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            color: LoopColors.lime,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(dimension: 9),
        ),
        const SizedBox(width: 8),
        Text(
          'LOOP',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: LoopColors.chalk, letterSpacing: 1.1),
        ),
      ],
    );
  }
}

class _LedgerBackdrop extends StatelessWidget {
  const _LedgerBackdrop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LoopColors.ink,
      child: CustomPaint(painter: _LedgerGridPainter()),
    );
  }
}

class _LedgerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LoopColors.chalk.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const gap = 18.0;
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(
        Offset.zero.translate(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LedgerGridPainter oldDelegate) => false;
}

class _CommunitySourceCard extends StatelessWidget {
  const _CommunitySourceCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '社区首页数据源未连接',
      child: DecoratedBox(
        key: const ValueKey<String>('community-home-unavailable'),
        decoration: const BoxDecoration(
          color: LoopColors.lime,
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    'COMMUNITY INDEX',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: LoopColors.ink.withValues(alpha: 0.68),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const _InkPill(label: 'D3 · NOT CONNECTED'),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '社区内容源待连接',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: LoopColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '已加入、推荐和最近访问的社区，将在后端 D3 提供真实来源、能力状态与新鲜度后显示。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: LoopColors.ink.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0x33050604)),
              const SizedBox(height: 14),
              Text(
                '当前不展示社区数量、在线人数、未读数或推荐结果。',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: LoopColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InkPill extends StatelessWidget {
  const _InkPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LoopColors.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: LoopColors.lime,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.index,
    required this.title,
    required this.caption,
  });

  final String index;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          index,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: LoopColors.lime, letterSpacing: 1.1),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(caption, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityRouteTile extends StatelessWidget {
  const _CommunityRouteTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    super.key,
  });

  final double width;
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: '$title，$detail',
        child: Material(
          color: LoopColors.graphite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: LoopColors.chalk.withValues(alpha: 0.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 132),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(icon, color: LoopColors.lime, size: 25),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: LoopColors.chalk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LoopColors.chalk.withValues(alpha: 0.56),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableCommunityIndex extends StatelessWidget {
  const _UnavailableCommunityIndex();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey<String>('community-index-unavailable'),
      decoration: BoxDecoration(
        color: LoopColors.graphite.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LoopColors.chalk.withValues(alpha: 0.12)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          children: <Widget>[
            _UnavailableRow(label: '已加入的社区', dependency: 'D3'),
            _UnavailableRow(label: '推荐与社区发现', dependency: 'D3–D4'),
            _UnavailableRow(
              label: '社区成员与治理',
              dependency: 'D5',
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableRow extends StatelessWidget {
  const _UnavailableRow({
    required this.label,
    required this.dependency,
    this.showDivider = true,
  });

  final String label;
  final String dependency;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$dependency · 待接入',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: LoopColors.lime,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(color: LoopColors.chalk.withValues(alpha: 0.1), height: 1),
      ],
    );
  }
}

class _TruthNotice extends StatelessWidget {
  const _TruthNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LoopColors.lime.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LoopColors.lime.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.verified_user_outlined, color: LoopColors.lime),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '本页没有请求或生成社区事实。点击沟通入口后，目标页面会按当前账号重新校验 LOOP backend 与 Stream 状态。',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: LoopColors.chalk.withValues(alpha: 0.72)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

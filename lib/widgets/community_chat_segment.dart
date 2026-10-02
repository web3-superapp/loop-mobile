import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Community and the existing inbox share one primary destination.
class CommunityChatSegment extends StatelessWidget {
  const CommunityChatSegment({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
    key: const ValueKey<String>('community-chat-segment'),
    segments: const <ButtonSegment<String>>[
      ButtonSegment(value: '/community', label: Text('社区')),
      ButtonSegment(value: '/chat', label: Text('聊天')),
    ],
    selected: <String>{location},
    showSelectedIcon: false,
    onSelectionChanged: (values) => context.go(values.first),
  );
}

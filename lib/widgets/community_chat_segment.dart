import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// Community and the existing inbox share one primary destination.
class CommunityChatSegment extends StatelessWidget {
  const CommunityChatSegment({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey<String>('community-chat-segment'),
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final item in const <String, String>{
        '/community': '社区',
        '/chat': '聊天',
      }.entries)
        Flexible(
          child: Semantics(
            button: true,
            selected: location == item.key,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: LoopRadius.inner,
                onTap: () {
                  if (location != item.key) context.go(item.key);
                },
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 58,
                    minHeight: 44,
                  ),
                  margin: const EdgeInsets.only(right: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: location == item.key
                            ? LoopColors.lime
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    item.value,
                    style: LoopTypography.heading(
                      17,
                      color: location == item.key
                          ? LoopColors.chalk
                          : LoopColors.text3,
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

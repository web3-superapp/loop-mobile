import 'package:flutter/material.dart';
import 'package:loop_mobile/widgets/loop_inputs.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// UX-008 (decision 0254): the chat composer's field shows focus.
///
/// Stream's own input container draws one fixed hairline whether or not the
/// field is being typed into, so the composer was the one field in LOOP with
/// no focused state. This keeps the official container exactly as it is and
/// lays LOOP's Purple focus edge over it, on the container's own capsule
/// corners.
Widget loopStreamComposerInputBuilder(
  BuildContext context,
  MessageComposerInputProps props,
) => LoopFocusRing(
  key: const ValueKey<String>('loop-composer-focus-ring'),
  borderRadius: BorderRadius.all(context.streamRadius.xxxl),
  enabled: !props.isSlowModeActive,
  child: DefaultStreamMessageComposerInput(props: props),
);

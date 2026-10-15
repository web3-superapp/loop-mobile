import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_gate.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

/// The one sentence the first-launch prompt says (decision 0186).
const loopAppLockPromptBody = '切到后台 60 秒后回来需要 Face ID / 指纹，钱包和聊天更安全';

/// Timeout for the one read and the write, the same second every other
/// device-local preference uses (AGENTS rule 23).
const loopAppLockPromptIoTimeout = Duration(seconds: 1);

/// Whether this installation has already been offered the lock.
///
/// One Boolean per installation, device-local and never an account fact. It
/// says only that the question was asked: it is not the lock's own state,
/// which stays in the secure store, and it never proves the lock is on.
abstract interface class LoopAppLockPromptStore {
  Future<bool?> readPrompted();

  Future<void> writePrompted();
}

/// The default for any composition that installed no adapter. Reads fail,
/// which the prompt treats as "not asked yet" (fail-open), and the run-local
/// guard still keeps it to one sheet per run.
final class UnavailableLoopAppLockPromptStore
    implements LoopAppLockPromptStore {
  const UnavailableLoopAppLockPromptStore();

  @override
  Future<bool?> readPrompted() => Future<bool?>.error(
    UnsupportedError('local_app_lock_prompt_unavailable'),
  );

  @override
  Future<void> writePrompted() =>
      Future<void>.error(UnsupportedError('local_app_lock_prompt_unavailable'));
}

final class InMemoryLoopAppLockPromptStore implements LoopAppLockPromptStore {
  InMemoryLoopAppLockPromptStore([this.prompted]);

  bool? prompted;

  @override
  Future<bool?> readPrompted() async => prompted;

  @override
  Future<void> writePrompted() async => prompted = true;
}

final loopAppLockPromptStoreProvider = Provider<LoopAppLockPromptStore>(
  (ref) => const UnavailableLoopAppLockPromptStore(),
);

final loopAppLockPromptIoTimeoutProvider = Provider<Duration>(
  (ref) => loopAppLockPromptIoTimeout,
);

/// Decides, once per run, whether the first-launch prompt is due.
///
/// The state is `true` once this run has settled the question — the sheet
/// was claimed, or the installation had already been asked. A lock that is
/// unavailable or already on settles nothing and records nothing: the
/// question is about a lock the owner could turn on and has not.
final class LoopAppLockPromptController extends Notifier<bool> {
  Future<bool>? _deciding;
  Future<void> _writeTail = Future<void>.value();
  bool _recorded = false;

  @override
  bool build() => false;

  /// Answers `true` exactly once per run, when the sheet should be shown.
  Future<bool> claim() {
    if (state) return Future<bool>.value(false);
    final deciding = _deciding;
    if (deciding != null) return deciding.then((_) => false);
    final next = _decide().whenComplete(() => _deciding = null);
    _deciding = next;
    return next;
  }

  Future<bool> _decide() async {
    await ref.read(loopAppLockProvider.notifier).whenLoaded();
    if (!ref.mounted || state || !_offerable()) return false;
    bool? prompted;
    try {
      prompted = await Future<bool?>.sync(
        ref.read(loopAppLockPromptStoreProvider).readPrompted,
      ).timeout(ref.read(loopAppLockPromptIoTimeoutProvider));
    } on Object {
      // Fail-open: a device that cannot say is treated as not asked, and the
      // run-local state below keeps it to one sheet.
      prompted = null;
    }
    if (!ref.mounted || state) return false;
    if (prompted ?? false) {
      state = true;
      return false;
    }
    // The lock may have changed while the read was out.
    if (!_offerable()) return false;
    state = true;
    return true;
  }

  bool _offerable() {
    final lock = ref.read(loopAppLockProvider);
    return lock.isAvailable && !lock.enabled;
  }

  /// Records that this installation was asked, once per run. Ordered,
  /// bounded, and never thrown: a refused write leaves the record run-local.
  Future<void> markPrompted() async {
    state = true;
    if (_recorded) return;
    _recorded = true;
    final previous = _writeTail;
    final store = ref.read(loopAppLockPromptStoreProvider);
    final operation = () async {
      try {
        await previous;
      } on Object {
        // A later write still gets its own attempt.
      }
      await Future<void>.sync(store.writePrompted);
    }();
    _writeTail = operation;
    try {
      await operation.timeout(ref.read(loopAppLockPromptIoTimeoutProvider));
    } on Object {
      // Run-local: the state above already keeps this run from asking again.
    }
  }
}

final loopAppLockPromptProvider =
    NotifierProvider<LoopAppLockPromptController, bool>(
      LoopAppLockPromptController.new,
    );

/// Offers the lock on the first arrival of this installation (decision 0186).
///
/// Only a signed-in session is offered it; Preview never is. Answers, as
/// soon as it is decided, whether the sheet was opened; the sheet itself
/// stays up until the owner answers it.
Future<bool> loopOfferAppLock(BuildContext context, WidgetRef ref) async {
  final mode = ref.read(loopSessionProvider).mode;
  if (mode != LoopSessionMode.authenticated &&
      mode != LoopSessionMode.authenticatedUnverified) {
    return false;
  }
  final controller = ref.read(loopAppLockPromptProvider.notifier);
  if (!await controller.claim()) return false;
  if (!context.mounted) return false;
  unawaited(
    showLoopSheet<void>(
      context,
      builder: (context) => const LoopAppLockPromptSheet(),
    ).then((_) {
      // Closing the sheet any way — 以后再说, the veil, a drag — is an
      // answer. A run that ends with the sheet still up has not been one.
      if (ref.context.mounted) unawaited(controller.markPrompted());
    }),
  );
  return true;
}

/// 「开启应用锁」: one Lime 开启 that runs the lock's own switch, and
/// 以后再说.
class LoopAppLockPromptSheet extends ConsumerStatefulWidget {
  const LoopAppLockPromptSheet({super.key});

  @override
  ConsumerState<LoopAppLockPromptSheet> createState() =>
      _LoopAppLockPromptSheetState();
}

class _LoopAppLockPromptSheetState
    extends ConsumerState<LoopAppLockPromptSheet> {
  Future<void> _enable() async {
    unawaited(ref.read(loopAppLockPromptProvider.notifier).markPrompted());
    final on = await ref.read(loopAppLockProvider.notifier).enable();
    if (on && mounted) Navigator.of(context).pop();
  }

  void _later() {
    unawaited(ref.read(loopAppLockPromptProvider.notifier).markPrompted());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(loopAppLockProvider);
    final outcome = lock.lastOutcome;
    return Column(
      key: const ValueKey<String>('app-lock-prompt-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSheetHeading('开启应用锁'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(loopAppLockPromptBody, style: LoopType.bodySm),
        ),
        if (outcome != null &&
            outcome != LoopDeviceAuthOutcome.succeeded &&
            !lock.busy)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                loopAppLockAttemptText(outcome, lock.systemMessage),
                key: const ValueKey<String>('app-lock-prompt-attempt'),
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: LoopButton(
            key: const ValueKey<String>('app-lock-prompt-enable'),
            label: lock.busy ? '正在验证…' : '开启',
            primary: true,
            block: true,
            onPressed: lock.busy || !lock.isAvailable ? null : _enable,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: LoopButton(
            key: const ValueKey<String>('app-lock-prompt-later'),
            label: '以后再说',
            block: true,
            onPressed: lock.busy ? null : _later,
          ),
        ),
      ],
    );
  }
}

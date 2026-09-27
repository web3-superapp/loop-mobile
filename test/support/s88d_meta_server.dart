import 'dart:async';

import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';

/// A D0 port whose document a test can change between reads, and whose
/// answers it can hold, so a page's forced capability refresh (S88d) can be
/// observed on the wire and while it is running.
final class S88dMetaServer implements LoopV2MetaRepository {
  S88dMetaServer(this.document);

  /// What the next read answers.
  LoopV2MetaSnapshot document;

  /// Every request, in order: `policy` / `capabilities`.
  final List<String> log = <String>[];

  /// While true, both reads wait for [release].
  bool hold = false;

  /// While true, both reads fail as a dropped connection would.
  bool failing = false;
  Completer<void> _gate = Completer<void>();

  void release() {
    hold = false;
    if (!_gate.isCompleted) _gate.complete();
  }

  Future<void> _wait() async {
    if (!hold) return;
    if (_gate.isCompleted) _gate = Completer<void>();
    await _gate.future;
  }

  @override
  Future<LoopV2ClientPolicy> getClientPolicy() async {
    log.add('policy');
    await _wait();
    if (failing) throw StateError('offline');
    return document.clientPolicy;
  }

  @override
  Future<LoopV2Capabilities> getCapabilities() async {
    log.add('capabilities');
    await _wait();
    if (failing) throw StateError('offline');
    return document.capabilities;
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef LoopCommunicationRetirement = Future<void> Function();

final loopCommunicationRetirementRegistryProvider =
    Provider<LoopCommunicationRetirementRegistry>((ref) {
      return LoopCommunicationRetirementRegistry();
    });

final class LoopCommunicationRetirementRegistry {
  final Map<Object, LoopCommunicationRetirement> _retirements =
      Map<Object, LoopCommunicationRetirement>.identity();

  LoopCommunicationRetirementRegistration register(
    Object owner,
    LoopCommunicationRetirement retirement,
  ) {
    _retirements[owner] = retirement;
    return LoopCommunicationRetirementRegistration._(this, owner);
  }

  LoopCommunicationRetirementPlan capture() {
    return LoopCommunicationRetirementPlan._(
      List<LoopCommunicationRetirement>.unmodifiable(_retirements.values),
    );
  }

  void _unregister(Object owner) {
    _retirements.remove(owner);
  }
}

final class LoopCommunicationRetirementRegistration {
  LoopCommunicationRetirementRegistration._(this._registry, this._owner);

  LoopCommunicationRetirementRegistry? _registry;
  final Object _owner;

  void unregister() {
    _registry?._unregister(_owner);
    _registry = null;
  }
}

final class LoopCommunicationRetirementPlan {
  const LoopCommunicationRetirementPlan._(this._retirements);

  final List<LoopCommunicationRetirement> _retirements;

  Future<void> retire() async {
    await Future.wait<void>(
      _retirements.map((retirement) async {
        try {
          await retirement();
        } catch (_) {
          // Each captured owner becomes unreachable after the local principal
          // barrier. Transport cleanup failure cannot restore authorization.
        }
      }),
    );
  }
}

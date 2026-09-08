import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/profile/support/support_gateway.dart';
import 'package:loop_mobile/features/profile/support/support_models.dart';

@immutable
final class SupportState {
  const SupportState({
    required this.resource,
    this.commandFailureKind,
    this.submittedTicketId,
  });

  final LoopChainResourceState<LoopSupportTicketPage> resource;

  /// The failure of the last submit, kept apart from the list's own failure.
  final LoopChainFailureKind? commandFailureKind;

  /// The ticket the last successful submit created (or replayed).
  final String? submittedTicketId;

  bool get busy => resource.busy;

  SupportState copyWith({
    LoopChainResourceState<LoopSupportTicketPage>? resource,
    LoopChainFailureKind? commandFailureKind,
    String? submittedTicketId,
    bool clearCommand = false,
  }) => SupportState(
    resource: resource ?? this.resource,
    commandFailureKind: clearCommand
        ? null
        : (commandFailureKind ?? this.commandFailureKind),
    submittedTicketId: clearCommand
        ? null
        : (submittedTicketId ?? this.submittedTicketId),
  );
}

/// `support` · the ticket list plus the create command.
final class SupportController extends Notifier<SupportState>
    with LoopChainSingleFlight {
  @override
  SupportState build() {
    nextGeneration();
    final mode = ref.watch(
      supportGatewayProvider.select((gateway) => gateway.mode),
    );
    ref.onDispose(nextGeneration);
    return SupportState(
      resource: LoopChainResourceState<LoopSupportTicketPage>.initial(mode),
    );
  }

  Future<void> load() {
    if (state.resource.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final generation = nextGeneration();
    state = state.copyWith(resource: state.resource.loading());
    try {
      final page = await ref.read(supportGatewayProvider).listTickets();
      if (!isCurrent(generation)) return;
      state = state.copyWith(resource: state.resource.ready(page));
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(resource: state.resource.failed(error.kind));
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(
        resource: state.resource.failed(LoopChainFailureKind.unexpected),
      );
    }
  });

  /// Submits one ticket. A rejected draft never reaches the network.
  Future<bool> submit({
    required LoopSupportCategory category,
    required String body,
  }) async {
    if (state.busy) return false;
    late final LoopSupportDraft draft;
    try {
      draft = LoopSupportDraft(category: category, body: body);
    } on InvalidLoopChainContractException {
      state = state.copyWith(
        commandFailureKind: LoopChainFailureKind.validationFailed,
      );
      return false;
    }
    state = state.copyWith(
      resource: state.resource.working(true),
      clearCommand: true,
    );
    try {
      final result = await ref.read(supportGatewayProvider).createTicket(draft);
      state = state.copyWith(
        resource: state.resource.working(false),
        submittedTicketId: result.ticket.ticketId,
      );
      await reload();
      return true;
    } on LoopChainException catch (error) {
      state = state.copyWith(
        resource: state.resource.working(false),
        commandFailureKind: error.kind,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        resource: state.resource.working(false),
        commandFailureKind: LoopChainFailureKind.unexpected,
      );
      return false;
    }
  }
}

final supportControllerProvider =
    NotifierProvider<SupportController, SupportState>(SupportController.new);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/support/support_models.dart';

/// `support` port: create one ticket, list the account's tickets.
abstract interface class SupportGateway {
  LoopChainGatewayMode get mode;

  Future<LoopSupportTicketPage> listTickets({String? cursor});

  Future<LoopSupportTicketResult> createTicket(LoopSupportDraft draft);
}

final class UnavailableSupportGateway implements SupportGateway {
  const UnavailableSupportGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<LoopSupportTicketPage> listTickets({String? cursor}) =>
      Future<LoopSupportTicketPage>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );

  @override
  Future<LoopSupportTicketResult> createTicket(LoopSupportDraft draft) =>
      Future<LoopSupportTicketResult>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
}

final supportGatewayProvider = Provider<SupportGateway>(
  (ref) => const UnavailableSupportGateway(),
);

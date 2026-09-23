import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_ai_gateway.dart';
import 'package:loop_mobile/features/community/community_ai_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';

/// One exchange in the conversation: what was asked, and what came back.
///
/// A failed turn keeps the question on screen with the server's reason under
/// it. It is never quietly dropped and never answered by anything but the
/// model.
@immutable
final class CommunityAiTurn {
  const CommunityAiTurn({
    required this.question,
    this.answer,
    this.failureKind,
    this.reasonCode,
    this.scope,
    this.reported = false,
  });

  final String question;
  final CommunityAiAnswer? answer;
  final CommunityFailureKind? failureKind;

  /// The rule the server named, when it named one. It becomes a sentence
  /// through [communityAiReason]; it never reaches the screen as itself.
  final String? reasonCode;

  /// Which quota a `rateLimited` refusal was measured against.
  final String? scope;

  /// This account has already reported this answer. The server stores one
  /// report per (answer, account), so the control says so instead of offering
  /// a second one.
  final bool reported;

  bool get isPending => answer == null && failureKind == null;

  CommunityAiTurn answered(CommunityAiAnswer next) =>
      CommunityAiTurn(question: question, answer: next);

  CommunityAiTurn failed(CommunityGatewayException failure) => CommunityAiTurn(
    question: question,
    failureKind: failure.kind,
    reasonCode: failure.reasonCode,
    scope: failure.scope,
  );

  CommunityAiTurn markReported() => CommunityAiTurn(
    question: question,
    answer: answer,
    failureKind: failureKind,
    reasonCode: reasonCode,
    scope: scope,
    reported: true,
  );
}

/// The whole page: the overview it read, the conversation it holds, and
/// whichever question is in flight.
@immutable
final class CommunityAiState {
  const CommunityAiState({
    required this.mode,
    required this.phase,
    this.overview,
    this.failureKind,
    this.reasonCode,
    this.turns = const <CommunityAiTurn>[],
    this.asking = false,
    this.refreshing = false,
  });

  factory CommunityAiState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return CommunityAiState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final CommunityAiOverview? overview;
  final CommunityFailureKind? failureKind;

  /// Why the overview read was refused, in the server's own words.
  final String? reasonCode;
  final List<CommunityAiTurn> turns;

  /// A question is in flight: the composer is disabled and the pending turn
  /// is on screen.
  final bool asking;
  final bool refreshing;

  bool get isReady => phase == CommunityViewPhase.ready && overview != null;

  /// What the conversation's foot says. It is the server's fixed sentence,
  /// taken from the newest thing the model produced.
  String? get disclaimer {
    for (final turn in turns.reversed) {
      final answer = turn.answer;
      if (answer != null) return answer.disclaimer;
    }
    return overview?.disclaimer;
  }

  CommunityAiState copyWith({
    CommunityViewPhase? phase,
    CommunityAiOverview? overview,
    CommunityFailureKind? failureKind,
    String? reasonCode,
    List<CommunityAiTurn>? turns,
    bool? asking,
    bool? refreshing,
    bool clearFailure = false,
  }) => CommunityAiState(
    mode: mode,
    phase: phase ?? this.phase,
    overview: overview ?? this.overview,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    reasonCode: clearFailure ? null : (reasonCode ?? this.reasonCode),
    turns: turns ?? this.turns,
    asking: asking ?? this.asking,
    refreshing: refreshing ?? this.refreshing,
  );
}

/// `community-ai`: one community's assistant.
///
/// The controller holds the conversation for as long as the page is mounted
/// and no longer. Nothing is cached across mounts: an answer is a reading of
/// sources at a moment, and replaying it later would be presenting an old
/// reading as a current one.
final class CommunityAiController extends Notifier<CommunityAiState> {
  CommunityAiController(this.communityId);

  /// How long the page waits before reading the overview again while today's
  /// summary is being written.
  ///
  /// It is one wait, not the poll the contract forbids. The length is the
  /// server's own: it writes the summary behind the read that missed it and
  /// says that takes 10–15 s, so a shorter wait would spend the one re-read
  /// on an answer that is not written yet. If this read still misses it the
  /// line stays neutral, the page stops reading, and the pull is the
  /// reader's.
  static const briefRecheckDelay = Duration(seconds: 15);

  final String communityId;

  Future<void>? _operation;
  var _generation = 0;

  /// The one re-read a pending summary earns, and the timer holding it.
  ///
  /// Both are per mount: leaving the page disposes the controller, which
  /// cancels the timer, so nothing reads for a page that is gone.
  Timer? _briefRecheck;
  var _briefRecheckSpent = false;

  @override
  CommunityAiState build() {
    _generation += 1;
    _operation = null;
    _briefRecheck?.cancel();
    _briefRecheck = null;
    _briefRecheckSpent = false;
    final mode = ref.watch(communityAiGatewayProvider).mode;
    ref.onDispose(() {
      _generation += 1;
      _briefRecheck?.cancel();
      _briefRecheck = null;
    });
    return CommunityAiState.initial(mode);
  }

  /// Arms the single re-read, when the summary is the only thing missing.
  ///
  /// Every other reason — no membership, no official group, a model that
  /// refused, a budget spent for today — is a fact that will not change while
  /// the page is open, and reading again would print the same sentence.
  void _scheduleBriefRecheck(CommunityAiBrief brief, int generation) {
    _briefRecheck?.cancel();
    _briefRecheck = null;
    if (_briefRecheckSpent) return;
    if (brief is! CommunityAiBriefUnavailable || !brief.isGenerating) return;
    _briefRecheckSpent = true;
    _briefRecheck = Timer(briefRecheckDelay, () {
      _briefRecheck = null;
      if (!_isCurrent(generation)) return;
      unawaited(reload());
    });
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() {
    final active = _operation;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _read().whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _read() async {
    final gateway = ref.read(communityAiGatewayProvider);
    final generation = _generation;
    final held = state.overview;
    state = state.copyWith(
      phase: held == null
          ? CommunityViewPhase.loading
          : CommunityViewPhase.ready,
      refreshing: held != null,
      clearFailure: true,
    );
    try {
      final overview = await gateway.loadOverview(communityId);
      if (!_isCurrent(generation)) return;
      _scheduleBriefRecheck(overview.brief, generation);
      state = CommunityAiState(
        mode: state.mode,
        phase: CommunityViewPhase.ready,
        overview: overview,
        turns: state.turns,
      );
    } on CommunityGatewayException catch (failure) {
      if (!_isCurrent(generation)) return;
      state = CommunityAiState(
        mode: state.mode,
        phase: held == null
            ? communityPhaseForFailure(failure.kind)
            : CommunityViewPhase.ready,
        overview: held,
        failureKind: failure.kind,
        reasonCode: failure.reasonCode,
        turns: state.turns,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      state = CommunityAiState(
        mode: state.mode,
        phase: held == null
            ? CommunityViewPhase.error
            : CommunityViewPhase.ready,
        overview: held,
        failureKind: CommunityFailureKind.unexpected,
        turns: state.turns,
      );
    }
  }

  /// Asks one question.
  ///
  /// The turn is put on screen before the request leaves, so the reader can
  /// see what was asked while it is in flight. A refusal replaces the pending
  /// turn with the reason it was refused — never with an answer this client
  /// wrote.
  Future<void> ask(String question) async {
    final asked = question.trim();
    if (asked.isEmpty || state.asking) return;
    final gateway = ref.read(communityAiGatewayProvider);
    final generation = _generation;
    final index = state.turns.length;
    state = state.copyWith(
      turns: <CommunityAiTurn>[
        ...state.turns,
        CommunityAiTurn(question: asked),
      ],
      asking: true,
    );
    try {
      final answer = await gateway.ask(
        communityId: communityId,
        question: asked,
      );
      if (!_isCurrent(generation)) return;
      _replace(index, (turn) => turn.answered(answer));
    } on CommunityGatewayException catch (failure) {
      if (!_isCurrent(generation)) return;
      _replace(index, (turn) => turn.failed(failure));
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _replace(
        index,
        (turn) => turn.failed(
          const CommunityGatewayException(CommunityFailureKind.unexpected),
        ),
      );
    }
  }

  void _replace(int index, CommunityAiTurn Function(CommunityAiTurn) update) {
    final turns = <CommunityAiTurn>[...state.turns];
    if (index < 0 || index >= turns.length) {
      state = state.copyWith(asking: false);
      return;
    }
    turns[index] = update(turns[index]);
    state = state.copyWith(turns: turns, asking: false);
  }

  /// Reports one answer. Returns the server's failure when it refused, so the
  /// sheet's caller can say what did not happen.
  Future<CommunityGatewayException?> report({
    required String answerId,
    required CommunityAiReportReason reason,
  }) async {
    final gateway = ref.read(communityAiGatewayProvider);
    final generation = _generation;
    try {
      await gateway.report(
        communityId: communityId,
        answerId: answerId,
        reason: reason,
      );
      if (!_isCurrent(generation)) return null;
      final turns = <CommunityAiTurn>[
        for (final turn in state.turns)
          turn.answer?.answerId == answerId ? turn.markReported() : turn,
      ];
      state = state.copyWith(turns: turns);
      return null;
    } on CommunityGatewayException catch (failure) {
      return failure;
    } catch (_) {
      return const CommunityGatewayException(CommunityFailureKind.unexpected);
    }
  }
}

final communityAiControllerProvider = NotifierProvider.autoDispose
    .family<CommunityAiController, CommunityAiState, String>(
      CommunityAiController.new,
    );

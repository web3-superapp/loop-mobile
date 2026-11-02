import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_gateway.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';

// ---------------------------------------------------------------------------
// The form
// ---------------------------------------------------------------------------

/// Where a submit is.
enum BetaFeedbackSubmitStep { idle, uploading, sending }

/// What adding pictures did.
enum BetaFeedbackAddResult {
  added,

  /// Some or all were left out: the form already holds four.
  tooMany,

  /// A picture was not a JPEG / PNG / WebP / HEIC, or was over the size
  /// limit, and was left out.
  rejected,
}

@immutable
final class BetaFeedbackFormState {
  BetaFeedbackFormState({
    List<BetaFeedbackImage> images = const <BetaFeedbackImage>[],
    this.step = BetaFeedbackSubmitStep.idle,
    this.uploaded = 0,
    this.failureKind,
  }) : images = List<BetaFeedbackImage>.unmodifiable(images);

  final List<BetaFeedbackImage> images;
  final BetaFeedbackSubmitStep step;

  /// Pictures already uploaded during the running submit.
  final int uploaded;

  /// The last submit's failure, until the next attempt.
  final LoopChainFailureKind? failureKind;

  bool get busy => step != BetaFeedbackSubmitStep.idle;

  bool get canAddImage =>
      !busy && images.length < BetaFeedbackPolicy.maximumImages;

  BetaFeedbackFormState copyWith({
    List<BetaFeedbackImage>? images,
    BetaFeedbackSubmitStep? step,
    int? uploaded,
    LoopChainFailureKind? failureKind,
    bool clearFailure = false,
  }) => BetaFeedbackFormState(
    images: images ?? this.images,
    step: step ?? this.step,
    uploaded: uploaded ?? this.uploaded,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
  );
}

/// The `beta-feedback` form: its pictures and the submit.
///
/// The submit uploads every picture first, one at a time and in order, and
/// only then sends the feedback with their media ids. A picture that was
/// uploaded is remembered for the life of the form, so a retry after a
/// failed send does not upload it again; the send itself replays the same
/// idempotency key while its outcome is unresolved (the gateway's keyring).
final class BetaFeedbackFormController extends Notifier<BetaFeedbackFormState> {
  static const _acceptedTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
  };

  int _nextLocalId = 0;
  final Map<int, String> _uploadedMediaIds = <int, String>{};

  @override
  BetaFeedbackFormState build() => BetaFeedbackFormState();

  /// Adds [picked] in order until the form holds four.
  BetaFeedbackAddResult addImages(List<BetaFeedbackPickedImage> picked) {
    if (state.busy) return BetaFeedbackAddResult.rejected;
    final next = state.images.toList();
    var result = BetaFeedbackAddResult.added;
    for (final image in picked) {
      if (next.length >= BetaFeedbackPolicy.maximumImages) {
        result = BetaFeedbackAddResult.tooMany;
        break;
      }
      if (!_acceptedTypes.contains(image.contentType) ||
          image.bytes.isEmpty ||
          image.bytes.length > BetaFeedbackPolicy.maximumImageBytes) {
        result = BetaFeedbackAddResult.rejected;
        continue;
      }
      next.add(
        BetaFeedbackImage(
          localId: _nextLocalId++,
          bytes: image.bytes,
          contentType: image.contentType,
        ),
      );
    }
    state = state.copyWith(images: next, clearFailure: true);
    return result;
  }

  void removeImage(int localId) {
    if (state.busy) return;
    _uploadedMediaIds.remove(localId);
    state = state.copyWith(
      images: <BetaFeedbackImage>[
        for (final image in state.images)
          if (image.localId != localId) image,
      ],
    );
  }

  /// Sends the form. Returns the receipt, or `null` when nothing was sent or
  /// the send failed ([BetaFeedbackFormState.failureKind] says why).
  Future<BetaFeedbackReceipt?> submit({
    required BetaFeedbackCategory category,
    required String body,
    required BetaFeedbackOrigin origin,
  }) async {
    if (state.busy) return null;
    if (betaFeedbackBodyProblem(body) != null) {
      state = state.copyWith(
        failureKind: LoopChainFailureKind.validationFailed,
      );
      return null;
    }
    final gateway = ref.read(betaFeedbackGatewayProvider);
    final images = state.images;
    state = state.copyWith(
      step: BetaFeedbackSubmitStep.uploading,
      uploaded: images
          .where((i) => _uploadedMediaIds.containsKey(i.localId))
          .length,
      clearFailure: true,
    );
    try {
      final mediaIds = <String>[];
      for (final image in images) {
        var mediaId = _uploadedMediaIds[image.localId];
        if (mediaId == null) {
          final uploaded = await gateway.uploadImage(image);
          mediaId = uploaded.mediaId;
          _uploadedMediaIds[image.localId] = mediaId;
          if (!ref.mounted) return null;
          state = state.copyWith(uploaded: state.uploaded + 1);
        }
        mediaIds.add(mediaId);
      }
      final environment = await ref.read(
        betaFeedbackEnvironmentProvider.future,
      );
      if (!ref.mounted) return null;
      state = state.copyWith(step: BetaFeedbackSubmitStep.sending);
      final receipt = await gateway.submit(
        BetaFeedbackSubmission(
          category: category,
          body: body.trim(),
          mediaIds: mediaIds,
          context: BetaFeedbackContext.of(environment, origin),
        ),
      );
      if (!ref.mounted) return receipt;
      state = state.copyWith(step: BetaFeedbackSubmitStep.idle, uploaded: 0);
      return receipt;
    } on LoopChainException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          step: BetaFeedbackSubmitStep.idle,
          uploaded: 0,
          failureKind: error.kind,
        );
      }
      return null;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          step: BetaFeedbackSubmitStep.idle,
          uploaded: 0,
          failureKind: LoopChainFailureKind.unexpected,
        );
      }
      return null;
    }
  }
}

final betaFeedbackFormControllerProvider =
    NotifierProvider.autoDispose<
      BetaFeedbackFormController,
      BetaFeedbackFormState
    >(BetaFeedbackFormController.new);

// ---------------------------------------------------------------------------
// 我的反馈
// ---------------------------------------------------------------------------

@immutable
final class BetaFeedbackMineState {
  const BetaFeedbackMineState({
    required this.resource,
    this.loadingMore = false,
    this.moreFailureKind,
  });

  final LoopChainResourceState<BetaFeedbackPage> resource;
  final bool loadingMore;
  final LoopChainFailureKind? moreFailureKind;

  BetaFeedbackMineState copyWith({
    LoopChainResourceState<BetaFeedbackPage>? resource,
    bool? loadingMore,
    LoopChainFailureKind? moreFailureKind,
    bool clearMoreFailure = false,
  }) => BetaFeedbackMineState(
    resource: resource ?? this.resource,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailureKind: clearMoreFailure
        ? null
        : (moreFailureKind ?? this.moreFailureKind),
  );
}

/// `beta-feedback-mine`: the account's own feedback, newest first, a keyset
/// page at a time.
final class BetaFeedbackMineController extends Notifier<BetaFeedbackMineState>
    with LoopChainSingleFlight {
  @override
  BetaFeedbackMineState build() {
    nextGeneration();
    final mode = ref.watch(
      betaFeedbackGatewayProvider.select((gateway) => gateway.mode),
    );
    ref.onDispose(nextGeneration);
    return BetaFeedbackMineState(
      resource: LoopChainResourceState<BetaFeedbackPage>.initial(mode),
    );
  }

  Future<void> load() {
    if (state.resource.isReady ||
        state.resource.mode == LoopChainGatewayMode.unavailable) {
      return Future<void>.value();
    }
    return reload();
  }

  Future<void> reload() => single(() async {
    if (state.resource.mode == LoopChainGatewayMode.unavailable) return;
    final generation = nextGeneration();
    state = state.copyWith(
      resource: state.resource.loading(),
      clearMoreFailure: true,
    );
    try {
      final page = await ref.read(betaFeedbackGatewayProvider).listMine();
      if (!isCurrent(generation)) return;
      state = state.copyWith(resource: state.resource.ready(page));
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(resource: state.resource.failed(error.kind));
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(
        resource: state.resource.failed(LoopChainFailureKind.readFailed),
      );
    }
  });

  Future<void> loadMore() async {
    final page = state.resource.value;
    final cursor = page?.nextCursor;
    if (page == null || cursor == null || state.loadingMore || inFlight) {
      return;
    }
    final generation = nextGeneration();
    state = state.copyWith(loadingMore: true, clearMoreFailure: true);
    try {
      final next = await ref
          .read(betaFeedbackGatewayProvider)
          .listMine(cursor: cursor);
      if (!isCurrent(generation)) return;
      final seen = <String>{for (final item in page.items) item.id};
      state = state.copyWith(
        loadingMore: false,
        resource: state.resource.ready(
          BetaFeedbackPage(
            items: <BetaFeedbackItem>[
              ...page.items,
              for (final item in next.items)
                if (seen.add(item.id)) item,
            ],
            nextCursor: next.nextCursor,
          ),
        ),
      );
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(loadingMore: false, moreFailureKind: error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(
        loadingMore: false,
        moreFailureKind: LoopChainFailureKind.readFailed,
      );
    }
  }
}

final betaFeedbackMineControllerProvider =
    NotifierProvider.autoDispose<
      BetaFeedbackMineController,
      BetaFeedbackMineState
    >(BetaFeedbackMineController.new);

// ---------------------------------------------------------------------------
// The floating entry's place
// ---------------------------------------------------------------------------

/// How far the 内测反馈 entry's bottom edge sits above its lowest place, in
/// logical pixels. Kept for the run, never stored: `0` is the default place
/// on top of the tab bar.
final class BetaFeedbackEntryLift extends Notifier<double> {
  @override
  double build() => 0;

  void set(double lift) => state = lift < 0 ? 0 : lift;
}

final betaFeedbackEntryLiftProvider =
    NotifierProvider<BetaFeedbackEntryLift, double>(BetaFeedbackEntryLift.new);

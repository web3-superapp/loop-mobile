import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';

/// A continuous directory loaded in batches of six. Room discovery is scoped
/// to loaded records; an unread room is never treated as an empty one.
class PlazaController extends ChangeNotifier {
  PlazaController(this.gateway);
  final CommunityGateway gateway;
  static const pageSize = 6;
  final List<CommunitySummary> _items = [];
  final Set<String> _seenCursors = {};
  final Map<String, CommunityVoiceSection?> voices = {};
  String? _cursor;
  bool _started = false;
  bool _end = false;
  bool _disposed = false;
  bool loading = false;
  bool failed = false;
  List<CommunitySummary>? _refreshRows;
  bool _refreshFailed = false;
  int page = 0;
  List<CommunitySummary> get _batch =>
      _items.skip(page * pageSize).take(pageSize).toList();
  List<CommunitySummary> get items =>
      _refreshRows ?? _items.take((page + 1) * pageSize).toList();
  bool get hasUnreadDirectory => !_end;
  bool get canNext =>
      !loading && (!_end || _items.length > (page + 1) * pageSize);

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> reload() async {
    if (loading) return;
    _refreshRows = items;
    _refreshFailed = false;
    _items.clear();
    _seenCursors.clear();
    voices.clear();
    _cursor = null;
    _started = false;
    _end = false;
    page = 0;
    await _read();
    _refreshFailed = failed;
    if (!failed) _refreshRows = null;
    _publish();
  }

  Future<void> next() async {
    if (!canNext) return;
    final previous = page;
    if (_batch.length == pageSize || !hasUnreadDirectory) page++;
    await _read();
    if (_batch.isEmpty) {
      page = previous;
      _publish();
    }
  }

  Future<void> retry() => _refreshFailed
      ? reload()
      : items.isEmpty
      ? _read()
      : next();
  Future<void> _read() async {
    if (loading || _disposed) return;
    loading = true;
    failed = false;
    _publish();
    try {
      // Bounded continuation even when a server page is empty or overlaps.
      for (
        var reads = 0;
        reads < 4 &&
            !_end &&
            (!_started || _items.length < (page + 1) * pageSize);
        reads++
      ) {
        final result = await gateway.listCommunities(
          verification: CommunityVerificationFilter.all,
          membership: CommunityMembershipFilter.all,
          sort: CommunityDirectorySort.members,
          cursor: _cursor,
        );
        if (_disposed) return;
        if (result.orderingFailed) {
          throw StateError('Directory ordering unavailable');
        }
        final known = _items.map((item) => item.communityId).toSet();
        for (final item in result.items) {
          if (known.add(item.communityId)) _items.add(item);
        }
        _started = true;
        _cursor = result.nextCursor;
        _end = _cursor == null;
        if (!_end && !_seenCursors.add(_cursor!)) {
          throw StateError('Directory cursor did not advance');
        }
      }
      final batch = _batch;
      // At most three independent detail reads are in flight.
      for (var offset = 0; offset < batch.length; offset += 3) {
        await Future.wait(
          batch.skip(offset).take(3).map((item) async {
            try {
              final detail = await gateway.loadCommunity(item.communityId);
              if (!_disposed) {
                voices[item.communityId] =
                    detail.community.communityId == item.communityId
                    ? detail.voice
                    : null;
              }
            } catch (_) {
              if (!_disposed) voices[item.communityId] = null;
            }
          }),
        );
      }
    } catch (_) {
      failed = true;
    } finally {
      loading = false;
      _publish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final plazaControllerProvider = Provider.autoDispose<PlazaController>((ref) {
  ref.watch(loopAccountScopeProvider);
  final controller = PlazaController(ref.watch(communityGatewayProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

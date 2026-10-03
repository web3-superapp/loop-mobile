import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

enum ScopedAssetsScope { platform, community }

@immutable
final class ScopedAssetEntry {
  const ScopedAssetEntry({
    required this.sourceId,
    required this.label,
    this.assetId,
    this.detail,
    this.reason,
  });
  final String sourceId;
  final String label;
  final String? assetId;
  final MarketAssetDetail? detail;
  final String? reason;
}

@immutable
final class ScopedAssetsState {
  const ScopedAssetsState({
    this.items = const [],
    this.loading = false,
    this.initialized = false,
    this.page = 0,
    this.hasNext = false,
    this.continuationPending = false,
    this.failure,
    this.notice,
  });
  final List<ScopedAssetEntry> items;
  final bool loading, initialized, hasNext, continuationPending;
  final int page;
  final String? failure, notice;
}

class ScopedAssetsController extends Notifier<ScopedAssetsState> {
  ScopedAssetsController(this.scope);
  final ScopedAssetsScope scope;
  static const pageSize = 6;
  int _generation = 0;
  int? _failedPage;
  final List<_SourceRecord> _records = [];
  final Set<String> _seenIds = {}, _seenCursors = {};
  String? _cursor, _notice;
  bool _catalogRead = false, _end = false;

  @override
  ScopedAssetsState build() {
    ref.watch(loopAccountScopeProvider);
    ref.watch(marketReadGatewayProvider);
    if (scope == ScopedAssetsScope.platform) {
      ref.watch(launchGatewayProvider);
    } else {
      ref.watch(communityGatewayProvider);
    }
    _generation++;
    ref.onDispose(() => _generation++);
    _clear();
    return const ScopedAssetsState();
  }

  void _clear() {
    _failedPage = null;
    _records.clear();
    _seenIds.clear();
    _seenCursors.clear();
    _cursor = _notice = null;
    _catalogRead = _end = false;
  }

  bool _current(int generation) => ref.mounted && generation == _generation;
  Future<void> load() async {
    if (state.initialized || state.loading) return;
    await _readPage(0);
  }

  Future<void> reload() async {
    if (state.loading) return;
    _clear();
    await _readPage(0);
  }

  Future<void> next() async {
    if (state.loading || !state.hasNext) return;
    // Continue a partial viewport before moving past its unread source records.
    final fillCurrent =
        state.continuationPending &&
        state.items.length < (state.page + 1) * pageSize;
    await _readPage(fillCurrent ? state.page : state.page + 1);
  }

  /// Retry the failed read, including a first-batch refresh that retained
  /// earlier records. Visible rows alone do not describe the failed request.
  Future<void> retry() async {
    if (state.loading || _failedPage == null) return;
    await _readPage(_failedPage!);
  }

  Future<void> _readPage(int page) async {
    if (state.loading) return;
    _failedPage = null;
    final generation = _generation;
    final market = ref.read(marketReadGatewayProvider);
    final launch = scope == ScopedAssetsScope.platform
        ? ref.read(launchGatewayProvider)
        : null;
    final community = scope == ScopedAssetsScope.community
        ? ref.read(communityGatewayProvider)
        : null;
    final previous = state;
    state = ScopedAssetsState(
      items: previous.items,
      loading: true,
      initialized: previous.initialized,
      page: previous.page,
      hasNext: previous.hasNext,
      notice: _notice,
    );
    try {
      if (launch != null && !_catalogRead) {
        final overview = await launch.loadOverview();
        if (!_current(generation)) return;
        final graduated = overview.graduated;
        if (graduated is LaunchGraduatedUnavailable) {
          _notice = '已毕业目录：${launchReasonCodeText(graduated.fact.reasonCode)}';
        }
        for (final record in <LaunchSummary>[
          ...overview.segments.live,
          ...overview.segments.upcoming,
          ...overview.segments.awaitingSchedule,
          ...overview.segments.ended,
          if (graduated is LaunchGraduatedAvailable) ...graduated.launches,
        ]) {
          if (_seenIds.add(record.launchId)) {
            _records.add(
              _SourceRecord(record.launchId, record.name, launch: record),
            );
          }
        }
        _catalogRead = _end = true;
      }
      if (community != null) {
        for (
          var reads = 0;
          reads < 4 &&
              !_end &&
              (!_catalogRead || _records.length < (page + 1) * pageSize);
          reads++
        ) {
          final result = await community.listCommunities(
            verification: CommunityVerificationFilter.all,
            membership: CommunityMembershipFilter.all,
            sort: CommunityDirectorySort.members,
            cursor: _cursor,
          );
          if (!_current(generation)) return;
          if (result.ordering is CommunityOrderingUnavailable) {
            throw const CommunityGatewayException(
              CommunityFailureKind.unavailable,
            );
          }
          if (result.nextCursor != null &&
              !_seenCursors.add(result.nextCursor!)) {
            throw const CommunityGatewayException(
              CommunityFailureKind.invalidData,
            );
          }
          for (final record in result.items) {
            if (_seenIds.add(record.communityId)) {
              _records.add(
                _SourceRecord(
                  record.communityId,
                  record.name,
                  communityAssetId: record.boundAssetKey,
                ),
              );
            }
          }
          _catalogRead = true;
          _cursor = result.nextCursor;
          _end = _cursor == null;
        }
      }
      if (!_current(generation)) return;
      final records = _records.skip(page * pageSize).take(pageSize).toList();
      final entries = <ScopedAssetEntry>[];
      final assetReads = <String, Future<MarketAssetDetail>>{};
      for (var offset = 0; offset < records.length; offset += 3) {
        if (!_current(generation)) return;
        final batch = await Future.wait(
          records
              .skip(offset)
              .take(3)
              .map(
                (record) =>
                    _resolve(record, launch, market, assetReads, generation),
              ),
        );
        if (!_current(generation)) return;
        entries.addAll(batch);
      }
      if (!_current(generation)) return;
      if (entries.isEmpty && page > 0) {
        state = ScopedAssetsState(
          items: previous.items,
          initialized: true,
          page: previous.page,
          hasNext: !_end,
          continuationPending: !_end,
          notice: _notice,
        );
      } else {
        state = ScopedAssetsState(
          items: List.unmodifiable([
            ...previous.items.take(page * pageSize),
            ...entries,
          ]),
          initialized: true,
          page: page,
          hasNext: !_end || _records.length > (page + 1) * pageSize,
          continuationPending: !_end && records.length < pageSize,
          notice: _notice,
        );
      }
    } catch (error) {
      if (!_current(generation)) return;
      _failedPage = page;
      state = ScopedAssetsState(
        items: previous.items,
        initialized: true,
        page: previous.page,
        hasNext: previous.hasNext || !_end,
        continuationPending:
            previous.continuationPending ||
            (!_end && previous.items.length < (previous.page + 1) * pageSize),
        failure: _failure(error),
        notice: _notice,
      );
    }
  }

  Future<ScopedAssetEntry> _resolve(
    _SourceRecord record,
    LaunchGateway? launch,
    MarketReadGateway market,
    Map<String, Future<MarketAssetDetail>> reads,
    int generation,
  ) async {
    String? id = record.communityAssetId;
    try {
      if (launch != null) {
        final detail = await launch.loadLaunch(record.id);
        if (!_current(generation)) return record.entry();
        final expected = record.launch!;
        if (detail.launch.launchId != expected.launchId ||
            detail.launch.projectId != expected.projectId ||
            detail.launch.chainId != expected.chainId) {
          return record.entry(reason: '项目资料与目录不一致，未采用资产');
        }
        final config = detail.saleConfig;
        final onChain = detail.onChain;
        if (config == null ||
            onChain == null ||
            config.configVersion != onChain.configVersion ||
            !loopKnownChainIds.contains(detail.launch.chainId)) {
          return record.entry(reason: '项目代币配置尚未确认');
        }
        final address = config.projectToken.toLowerCase();
        if (!loopAddressPattern.hasMatch(address) ||
            address == '0x0000000000000000000000000000000000000000') {
          return record.entry(reason: '项目代币地址不可用');
        }
        id = '${detail.launch.chainId}:$address';
      }
      if (id == null) return record.entry(reason: '该社区尚未绑定资产');
      if (!loopAssetIdPattern.hasMatch(id) || id.endsWith(':native')) {
        return record.entry(reason: '绑定资产身份不可用');
      }
      if (!id.startsWith('$loopPrimaryChainId:')) {
        return record.entry(assetId: id, reason: '此网络的行情尚未开放');
      }
      if (!_current(generation)) return record.entry();
      final detail = await reads.putIfAbsent(id, () => market.loadAsset(id!));
      if (!_current(generation)) return record.entry();
      if (detail.assetId != id ||
          (detail.asset.settled != null &&
              detail.asset.settled!.chainId != loopPrimaryChainId)) {
        return record.entry(assetId: id, reason: '行情返回的资产不匹配，未采用价格');
      }
      return record.entry(assetId: id, detail: detail);
    } catch (error) {
      return record.entry(assetId: id, reason: _failure(error));
    }
  }

  String _failure(Object error) => switch (error) {
    LaunchException(:final kind, :final reasonCode) =>
      reasonCode == null
          ? launchFailureReason(kind)
          : launchReasonCodeText(reasonCode),
    CommunityGatewayException(:final kind) => communityFailureReason(kind),
    LoopChainException(:final kind, :final reasonCode) =>
      reasonCode == null
          ? loopChainFailureReason(kind)
          : loopReasonCodeText(reasonCode),
    _ => '暂时读不到资料，请重试',
  };
}

final class _SourceRecord {
  const _SourceRecord(
    this.id,
    this.label, {
    this.launch,
    this.communityAssetId,
  });
  final String id, label;
  final LaunchSummary? launch;
  final String? communityAssetId;
  ScopedAssetEntry entry({
    String? assetId,
    MarketAssetDetail? detail,
    String? reason,
  }) => ScopedAssetEntry(
    sourceId: id,
    label: label,
    assetId: assetId,
    detail: detail,
    reason: reason,
  );
}

final platformScopedAssetsControllerProvider =
    NotifierProvider.autoDispose<ScopedAssetsController, ScopedAssetsState>(
      () => ScopedAssetsController(ScopedAssetsScope.platform),
    );
final communityScopedAssetsControllerProvider =
    NotifierProvider.autoDispose<ScopedAssetsController, ScopedAssetsState>(
      () => ScopedAssetsController(ScopedAssetsScope.community),
    );

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_profile_link_inbox.dart';
import 'package:loop_mobile/core/crypto/loop_keccak.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:loop_mobile/features/chat/v2/group_rename.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_link.dart';
import 'package:loop_mobile/features/community/community_manage_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/scan/loop_qr_scanner.dart';
import 'package:loop_mobile/features/scan/scan_result.dart';
import 'package:loop_mobile/features/scan/scan_screen.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_group_profile.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

const _stagingBase = 'https://api-staging.quant-dinger.cc';
const _loopId = 'LOOP-FE3EMCPE';
const _address = '0x71bd2e4c5b6c4d7e8f901a2b3c4d5e60aa0b0b91';

/// The Preview's first community (演示社区 · Frogs).
const _previewCommunityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';

/// Decision 0113 (S109b): QR cards and posters, the scanner, the
/// `/c/{communityId}` link, the community manage center and group renaming.
void main() {
  loopWatchGround();

  group('QR card', () {
    testWidgets('a person: avatar, name, LOOP ID, the /u/ link and its code', (
      tester,
    ) async {
      final clipboard = _mockClipboard(tester);
      await _pumpCardOpener(
        tester,
        const LoopUserQrCard(loopId: _loopId, displayName: 'QuietComet'),
      );

      expect(
        find.byKey(const ValueKey<String>('qr-card-sheet')),
        findsOneWidget,
      );
      expect(find.text('我的二维码名片'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('qr-card-code')),
        findsOneWidget,
      );
      expect(find.text('QuietComet'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('qr-card-poster-line')),
            )
            .data,
        _loopId,
      );
      expect(find.text('LOOP · 扫码加我'), findsOneWidget);
      const link = '$_stagingBase/u/$_loopId';
      expect(find.text(link), findsOneWidget);

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('qr-card-copy-link')),
      );
      expect(clipboard.text, link);
      expect(find.text('已复制链接'), findsOneWidget);
    });

    testWidgets('a community: logo, name, member count and the /c/ link', (
      tester,
    ) async {
      await _pumpCardOpener(
        tester,
        const LoopCommunityQrCard(
          communityId: testCommunityId,
          name: 'Frog Holders',
          memberCount: 128,
        ),
      );

      expect(find.text('社区二维码名片'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('qr-card-code')),
        findsOneWidget,
      );
      expect(find.text('128 位成员'), findsOneWidget);
      expect(find.text('LOOP · 扫码加入'), findsOneWidget);
      expect(find.text('$_stagingBase/c/$testCommunityId'), findsOneWidget);
    });

    testWidgets('a community with no backend host has no code to draw', (
      tester,
    ) async {
      await _pumpCardOpener(
        tester,
        const LoopCommunityQrCard(
          communityId: testCommunityId,
          name: 'Frog Holders',
          memberCount: 128,
        ),
        base: '',
      );
      expect(
        find.byKey(const ValueKey<String>('qr-card-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('qr-card-code')), findsNothing);
      final share = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('qr-card-share-poster')),
      );
      expect(share.onPressed, isNull);
    });

    test('a person in a build with no host still gets a scannable ID', () {
      const subject = LoopUserQrCard(loopId: _loopId, displayName: 'x');
      expect(loopQrCardLink(subject, ''), isNull);
      expect(loopQrCardPayload(subject, ''), _loopId);
      expect(
        loopScanResultFor(loopQrCardPayload(subject, '')!),
        isA<LoopScanUser>(),
      );
    });

    testWidgets('分享海报 encodes the poster once and hands it to the sheet', (
      tester,
    ) async {
      final sink = RecordingChatMergeExportSink();
      await _pumpCardOpener(
        tester,
        const LoopUserQrCard(loopId: _loopId, displayName: 'QuietComet'),
        sink: sink,
      );

      final share = find.byKey(const ValueKey<String>('qr-card-share-poster'));
      await tester.ensureVisible(share);
      await tester.pumpAndSettle();
      // `toImage` awaits real engine work, so the capture runs outside the
      // fake async zone.
      await tester.runAsync(() async {
        await tester.tap(share);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(sink.shared, hasLength(1));
      expect(sink.fileNames, <String>['loop-card.png']);
      expect(sink.shared.single.take(4), <int>[0x89, 0x50, 0x4e, 0x47]);
      expect(find.text('海报已生成，请在分享面板中选择去处'), findsOneWidget);
    });
  });

  group('scan · what a payload means', () {
    test('a /u/ link or a bare LOOP ID is that account', () {
      final link = loopScanResultFor('$_stagingBase/u/$_loopId');
      expect(link, isA<LoopScanUser>());
      expect((link as LoopScanUser).location, '/profile/user?loopId=$_loopId');
      expect(loopScanResultFor('  loop-fe3emcpe '), isA<LoopScanUser>());
      expect(loopScanResultFor('加我 LOOP-FE3EMCPE'), isA<LoopScanUnknown>());
    });

    test('a /c/ link is the community; /c/…/room asks for the room', () {
      final community = loopScanResultFor('$_stagingBase/c/$testCommunityId');
      expect(community, isA<LoopScanCommunity>());
      expect(
        (community as LoopScanDestination).location,
        '/community/profile?id=$testCommunityId',
      );
      final room = loopScanResultFor('$_stagingBase/c/$testCommunityId/room');
      expect(room, isA<LoopScanRoom>());
      expect(
        (room as LoopScanDestination).location,
        '/community/profile?id=$testCommunityId&room=live',
      );
    });

    test('an address opens 发送 with the recipient as typed state', () {
      final plain = loopScanResultFor(_address);
      expect(plain, isA<LoopScanAddress>());
      final destination = plain as LoopScanDestination;
      expect(destination.location, '/wallet/send');
      expect(SendRecipientPrefill.addressFrom(destination.extra), _address);
      // The receive page's own EIP-681 form, on this build's send chain.
      expect(
        (loopScanResultFor('ethereum:$_address@56') as LoopScanAddress).address,
        _address,
      );
      // No chain, another chain, or a token transfer whose first address is
      // the token contract is never read as the person being paid.
      expect(loopScanResultFor('ethereum:$_address'), isA<LoopScanUnknown>());
      expect(loopScanResultFor('ethereum:$_address@1'), isA<LoopScanUnknown>());
      expect(
        loopScanResultFor('ethereum:$_address@97'),
        isA<LoopScanUnknown>(),
      );
      expect(
        loopScanResultFor('ethereum:$_address@56/transfer?address=0x1'),
        isA<LoopScanUnknown>(),
      );
      // The chain comes from configuration, not from the payload.
      expect(
        loopScanResultFor('ethereum:$_address@97', sendChainReference: 97),
        isA<LoopScanAddress>(),
      );
    });

    test('a mixed-case address must carry a correct EIP-55 checksum', () {
      const checksummed = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
      expect(loopScanResultFor(checksummed), isA<LoopScanAddress>());
      expect(
        loopScanResultFor(checksummed.toLowerCase()),
        isA<LoopScanAddress>(),
      );
      expect(
        loopScanResultFor('0x${checksummed.substring(2).toUpperCase()}'),
        isA<LoopScanAddress>(),
      );
      // One letter in the wrong case.
      const broken = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeD';
      expect(loopScanResultFor(broken), isA<LoopScanUnknown>());
      expect(loopScanResultFor('ethereum:$broken@56'), isA<LoopScanUnknown>());
    });

    test('Keccak-256 and EIP-55 match the published vectors', () {
      String hex(List<int> bytes) =>
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex(loopKeccak256(const <int>[])),
        'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470',
      );
      expect(
        hex(loopKeccak256('abc'.codeUnits)),
        '4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45',
      );
      // 200 bytes: more than one 136-byte block.
      expect(hex(loopKeccak256(List<int>.filled(200, 0x61))).length, 64);
      for (final address in const <String>[
        '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
        '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
        '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
        '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb',
      ]) {
        expect(loopEip55Checksum(address.toLowerCase()), address);
      }
    });

    test('anything else is shown back as text', () {
      expect(
        loopScanResultFor('https://example.com/x'),
        isA<LoopScanUnknown>(),
      );
      expect(loopScanResultFor('WIFI:S:home;;'), isA<LoopScanUnknown>());
      expect(
        loopScanResultFor('$_stagingBase/c/not-a-uuid'),
        isA<LoopScanUnknown>(),
      );
    });
  });

  group('scan · page', () {
    testWidgets('a /u/ code opens that profile', (tester) async {
      final opened = await _pumpScan(tester);
      opened.scanner.session.emit('$_stagingBase/u/$_loopId');
      await tester.pumpAndSettle();
      expect(opened.locations, <String>['/profile/user?loopId=$_loopId']);
      // A second frame of the same code does not open it twice.
      opened.scanner.session.emit('$_stagingBase/u/$_loopId');
      await tester.pumpAndSettle();
      expect(opened.locations, hasLength(1));
    });

    testWidgets('a /c/ code opens the community record', (tester) async {
      final opened = await _pumpScan(tester);
      opened.scanner.session.emit('$_stagingBase/c/$testCommunityId');
      await tester.pumpAndSettle();
      expect(opened.locations, <String>[
        '/community/profile?id=$testCommunityId',
      ]);
    });

    testWidgets('an address code opens 发送 with the address prefilled', (
      tester,
    ) async {
      final opened = await _pumpScan(tester);
      opened.scanner.session.emit(_address);
      await tester.pumpAndSettle();
      expect(opened.locations, <String>['/wallet/send']);
      expect(SendRecipientPrefill.addressFrom(opened.extras.single), _address);
    });

    testWidgets('an unknown code is shown, copyable, and scanning resumes', (
      tester,
    ) async {
      final clipboard = _mockClipboard(tester);
      final opened = await _pumpScan(tester);
      opened.scanner.session.emit('WIFI:S:home;;');
      await tester.pumpAndSettle();

      expect(opened.locations, isEmpty);
      expect(find.text('不是 LOOP 二维码'), findsOneWidget);
      expect(find.text('WIFI:S:home;;'), findsOneWidget);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('scan-unknown-copy')),
      );
      expect(clipboard.text, 'WIFI:S:home;;');

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('scan-unknown-continue')),
      );
      expect(find.byKey(const ValueKey<String>('scan-unknown')), findsNothing);
      opened.scanner.session.emit('$_stagingBase/u/$_loopId');
      await tester.pumpAndSettle();
      expect(opened.locations, hasLength(1));
    });

    testWidgets('a picture from the library is read the same way', (
      tester,
    ) async {
      final opened = await _pumpScan(
        tester,
        image: LoopQrImageFound('$_stagingBase/c/$testCommunityId'),
      );
      await _tap(tester, find.byKey(const ValueKey<String>('scan-pick-image')));
      expect(opened.locations, <String>[
        '/community/profile?id=$testCommunityId',
      ]);
    });

    testWidgets('a picture with no code says so and opens nothing', (
      tester,
    ) async {
      final opened = await _pumpScan(tester, image: const LoopQrImageNoCode());
      await _tap(tester, find.byKey(const ValueKey<String>('scan-pick-image')));
      expect(opened.locations, isEmpty);
      expect(find.text('这张图片里没有识别到二维码'), findsOneWidget);
    });

    testWidgets('the camera fills the screen, not a card (decision 0133)', (
      tester,
    ) async {
      final opened = await _pumpScan(tester);
      opened.scanner.session.set(LoopQrCameraStatus.running);
      await tester.pumpAndSettle();

      final screen = tester.getRect(
        find.byKey(const ValueKey<String>('scan-screen')),
      );
      final viewfinder = tester.getRect(
        find.byKey(const ValueKey<String>('scan-viewfinder')),
      );
      // Audit m11: the picture is the whole page, edge to edge.
      expect(viewfinder, screen);
      expect(viewfinder.size, const Size(390, 900));
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey<String>('scan-viewfinder')),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
      // The window to aim at is drawn over the picture; the bar and the two
      // tools float on it.
      expect(find.byKey(const ValueKey<String>('scan-mask')), findsOneWidget);
      expect(find.text('扫一扫'), findsOneWidget);
      final hint = tester.getRect(
        find.byKey(const ValueKey<String>('scan-hint')),
      );
      final tools = tester.getRect(
        find.byKey(const ValueKey<String>('scan-pick-image')),
      );
      expect(hint.bottom, lessThanOrEqualTo(tools.top));
      expect(tools.bottom, lessThanOrEqualTo(screen.bottom));
      expect(tools.height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey<String>('scan-pick-image')),
        ),
        matchesSemantics(
          label: '从相册选图',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('the torch follows the camera', (tester) async {
      final opened = await _pumpScan(tester);
      await _tap(tester, find.byKey(const ValueKey<String>('scan-torch')));
      expect(opened.scanner.session.torchToggles, 1);
      expect(find.text('关闭手电筒'), findsOneWidget);
    });

    testWidgets('loading, permission and error are the camera\'s own states', (
      tester,
    ) async {
      final opened = await _pumpScan(tester);
      final session = opened.scanner.session;
      session.set(LoopQrCameraStatus.starting);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('scan-state-loading')),
        findsOneWidget,
      );
      session.set(LoopQrCameraStatus.permissionDenied);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('scan-state-permission')),
        findsOneWidget,
      );
      expect(find.text(scanCameraDeniedBody), findsOneWidget);
      // The preview stays mounted under the state, so a later start never
      // waits on a widget that is not there.
      expect(
        find.byKey(const ValueKey<String>('scan-viewfinder')),
        findsOneWidget,
      );
      session.set(LoopQrCameraStatus.failed);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('scan-state-error')),
        findsOneWidget,
      );
    });

    testWidgets('the camera starts once, after the preview is on screen', (
      tester,
    ) async {
      final opened = await _pumpScan(tester);
      expect(opened.scanner.session.starts, 1);
      await tester.pumpAndSettle();
      expect(opened.scanner.session.starts, 1);
    });

    testWidgets('the page releases the camera in the background', (
      tester,
    ) async {
      final opened = await _pumpScan(tester);
      final session = opened.scanner.session;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(session.pauses, greaterThanOrEqualTo(1));
      expect(session.resumes, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(session.resumes, 1);
    });

    testWidgets('重试 asks the session once', (tester) async {
      final opened = await _pumpScan(tester);
      opened.scanner.session.set(LoopQrCameraStatus.failed);
      await tester.pump();
      await _tap(tester, find.text('重试'));
      expect(opened.scanner.session.retries, 1);
      expect(opened.scanner.session.starts, 1);
    });

    test('a second start while one runs joins it', () async {
      final gate = LoopQrStartGate();
      var calls = 0;
      final release = Completer<void>();
      Future<void> start() async {
        calls += 1;
        await release.future;
      }

      final first = gate.run(start);
      final second = gate.run(start);
      expect(gate.busy, isTrue);
      expect(calls, 1);
      release.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(gate.busy, isFalse);
      await gate.run(() async => calls += 1);
      expect(calls, 2);
    });

    testWidgets('a build with no camera adapter opens nothing', (tester) async {
      await pumpCommunityPage(tester, const ScanScreen());
      expect(
        find.byKey(const ValueKey<String>('scan-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('scan-pick-image')),
        findsNothing,
      );
    });

    testWidgets('the send flow carries the scanned address into its field', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(
          draft: SendDraft(
            walletId: s5WalletId,
            assetId: s5NativeAssetId,
            symbol: 'BNB',
            recipientPrefill: _address,
          ),
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(preflightPending: true),
      );
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('send-recipient-field')),
      );
      expect(field.controller?.text, _address);
      // A prefill is text in a field: the server's preflight still checks
      // it — by itself since decision 0131 — and nothing is decided before.
      expect(find.text('正在校验地址…'), findsOneWidget);
      final next = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('send-address-next')),
      );
      expect(next.onPressed, isNull);
    });
  });

  group('/c/{communityId} link', () {
    test('only a bare UUID path is a community link', () {
      expect(communityIdFromLinkPath('/c/$testCommunityId'), testCommunityId);
      expect(communityIdFromLinkPath('/c/$testCommunityId/'), testCommunityId);
      expect(
        communityIdFromLinkPath('/c/${testCommunityId.toUpperCase()}'),
        testCommunityId,
      );
      expect(communityIdFromLinkPath('/c/$testCommunityId/room'), isNull);
      expect(communityIdFromLinkPath('/c/community-alpha'), isNull);
      expect(communityIdFromLinkPath('/u/$_loopId'), isNull);
      expect(
        communityCardLink('$_stagingBase/v2/', testCommunityId),
        '$_stagingBase/c/$testCommunityId',
      );
      expect(communityCardLink('', testCommunityId), isNull);
    });

    testWidgets('a link opened in the product lands on the record', (
      tester,
    ) async {
      await _pumpPreviewApp(tester);
      await _enterPreview(tester);
      await _pushPlatformRoute(tester, '/c/$_previewCommunityId');
      final screen = tester.widget<CommunityProfileScreen>(
        find.byType(CommunityProfileScreen),
      );
      expect(screen.communityId, _previewCommunityId);
      expect(screen.openLiveRoomOnArrival, isFalse);
    });

    testWidgets(
      'a link opened before sign-in is held until the account lands',
      (tester) async {
        await _pumpPreviewApp(tester);
        await _pushPlatformRoute(tester, '/c/$_previewCommunityId');
        expect(find.byType(CommunityProfileScreen), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(LoopApp)),
        );
        expect(
          container.read(loopProfileLinkInboxProvider).pendingCommunity,
          _previewCommunityId,
        );

        await _enterPreview(tester);
        expect(
          tester
              .widget<CommunityProfileScreen>(
                find.byType(CommunityProfileScreen),
              )
              .communityId,
          _previewCommunityId,
        );
        expect(
          container.read(loopProfileLinkInboxProvider).pendingCommunity,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('chat-tab-screen')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a malformed link is an unknown route', (tester) async {
      await _pumpPreviewApp(tester);
      await _enterPreview(tester);
      await _pushPlatformRoute(tester, '/c/not-a-community');
      expect(find.byType(CommunityProfileScreen), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chat-tab-screen')),
        findsOneWidget,
      );
    });
  });

  group('community-manage', () {
    testWidgets('the owner sees every group, the bound token included', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(
          community: _boundCommunity(hasPool: false),
          viewer: testViewer(role: CommunityRole.owner),
        ),
        members: testDirectory(),
      );
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        community: gateway,
      );

      for (final key in <String>[
        'community-manage-profile-group',
        'community-manage-edit-profile',
        'community-manage-bound-asset',
        'community-manage-no-pool',
        'community-manage-members-group',
        'community-manage-voice-group',
        'community-manage-announcements',
        'community-manage-share',
        'community-manage-transfer',
      ]) {
        final finder = find.byKey(ValueKey<String>(key));
        await scrollToCommunitySection(tester, finder);
        expect(finder, findsOneWidget, reason: key);
      }
      expect(find.textContaining('FROG · 尚无注册池子'), findsOneWidget);
      expect(find.text('尚无已注册池子，群友买入动态不会出现。'), findsOneWidget);
      expect(find.text('Owner 1 · Admin 3 · 共 128 人'), findsOneWidget);
    });

    testWidgets('an admin sees no bound token and no ownership', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: _boundCommunity(hasPool: false),
            viewer: testViewer(role: CommunityRole.admin),
          ),
          members: testDirectory(),
        ),
      );

      for (final key in <String>[
        'community-manage-edit-profile',
        'community-manage-members',
        'community-manage-voice-group',
        'community-manage-announcements',
        'community-manage-share',
      ]) {
        final finder = find.byKey(ValueKey<String>(key));
        await scrollToCommunitySection(tester, finder);
        expect(finder, findsOneWidget, reason: key);
      }
      for (final key in <String>[
        'community-manage-bound-asset',
        'community-manage-no-pool',
        'community-manage-transfer',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing, reason: key);
      }

      // The shared edit sheet, opened by an admin, has no bound-token field.
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('community-manage-edit-profile')),
      );
      expect(
        find.byKey(const ValueKey<String>('community-edit-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-edit-bound-asset')),
        findsNothing,
      );
    });

    testWidgets('the owner\'s bound-token row opens the field', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: _boundCommunity(hasPool: true),
            viewer: testViewer(role: CommunityRole.owner),
          ),
          members: testDirectory(),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('community-manage-no-pool')),
        findsNothing,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('community-manage-bound-asset')),
      );
      expect(
        find.byKey(const ValueKey<String>('community-edit-bound-asset')),
        findsOneWidget,
      );
    });

    testWidgets('a member is told the page is not theirs', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(viewer: testViewer(role: CommunityRole.member)),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('community-manage-permission')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-manage-edit-profile')),
        findsNothing,
      );
    });

    testWidgets('a record still being read offers nothing to manage', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(detail: testDetail())..pending = true,
        settle: false,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-manage-edit-profile')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-manage-permission')),
        findsNothing,
      );
    });

    testWidgets('an offline read is its own state, not a refusal', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(failure: CommunityFailureKind.offline),
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-manage-edit-profile')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-manage-permission')),
        findsNothing,
      );
    });

    testWidgets('a missing id asks for nothing', (tester) async {
      final gateway = FakeCommunityGateway(detail: testDetail());
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: null),
        community: gateway,
      );
      expect(
        find.byKey(const ValueKey<String>('community-manage-missing-id')),
        findsOneWidget,
      );
      expect(gateway.reads, 0);
    });

    test('a bound-token refusal is worded by its reasonCode', () {
      expect(
        communityProfileEditFailureText(
          const CommunityGatewayException(
            CommunityFailureKind.validationFailed,
            reasonCode: 'ASSET_NOT_REGISTERED',
          ),
        ),
        '这个代币还没有在 LOOP 登记，不能绑定；资料没有修改。',
      );
      expect(
        communityProfileEditFailureText(
          const CommunityGatewayException(
            CommunityFailureKind.permissionDenied,
            reasonCode: 'OWNER_ONLY_FIELD',
          ),
        ),
        '只有所有者能改绑定代币；资料没有修改。',
      );
      expect(
        communityProfileEditFailureText(
          const CommunityGatewayException(
            CommunityFailureKind.validationFailed,
          ),
        ),
        communityFailureReason(CommunityFailureKind.validationFailed),
      );
    });

    testWidgets('the server\'s reasonCode reaches the manage center', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(
          community: _boundCommunity(hasPool: true),
          viewer: testViewer(role: CommunityRole.owner),
        ),
        members: testDirectory(),
        writeFailure: CommunityFailureKind.validationFailed,
      )..writeReasonCode = 'ASSET_NOT_REGISTERED';
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        community: gateway,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('community-manage-bound-asset')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('community-edit-bound-asset')),
        'eip155:56:0x00000000000000000000000000000000000000bb',
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('community-edit-submit')),
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      expect(gateway.commands.last, startsWith('edit:$testCommunityId'));
      expect(find.text('这个代币还没有在 LOOP 登记，不能绑定；资料没有修改。'), findsOneWidget);
    });

    test('the community resource reads the optional boundAsset block', () {
      Map<String, Object?> json({Object? boundAsset, bool include = true}) =>
          <String, Object?>{
            'communityId': testCommunityId,
            'name': 'Frog Holders',
            'slug': 'frog-holders',
            'description': null,
            'logoRef': null,
            'verificationStatus': 'verified',
            'boundAssetKey': _frogAssetId,
            'memberCount': 128,
            'createdAt': '2026-06-01T00:00:00.000Z',
            'configVersion': 'communityV1',
            if (include) 'boundAsset': boundAsset,
          };
      expect(
        LoopV2ProjectionCodec.community(json(include: false)).boundAsset,
        isNull,
      );
      final asset = LoopV2ProjectionCodec.community(
        json(
          boundAsset: <String, Object?>{
            'assetId': _frogAssetId,
            'symbol': 'FROG',
            'name': 'Frog',
            'logoUrl': null,
            'hasRegisteredPool': false,
          },
        ),
      ).boundAsset!;
      expect(asset.symbol, 'FROG');
      expect(asset.hasRegisteredPool, isFalse);
      expect(
        () => LoopV2ProjectionCodec.community(
          json(boundAsset: <String, Object?>{'symbol': 'FROG'}),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('group rename', () {
    testWidgets('the creator renames the group and sees it at once', (
      tester,
    ) async {
      final gateway = _FakeGroupProfileGateway();
      await _pumpGroupInfo(tester, gateway: gateway, creator: true);

      final row = find.byKey(const ValueKey<String>('group-info-name'));
      await scrollToCommunitySection(tester, row);
      expect(find.text('老友记'), findsOneWidget);
      expect(find.text('修改'), findsOneWidget);
      await _tap(tester, row);
      await tester.enterText(
        find.byKey(const ValueKey<String>('group-rename-field')),
        '  周末徒步  ',
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('group-rename-submit')),
      );

      expect(gateway.calls, <String>['$testResolvedGroupId:周末徒步']);
      expect(find.text('群名称已改为「周末徒步」'), findsOneWidget);
      expect(find.text('周末徒步'), findsOneWidget);
    });

    testWidgets('a refused rename (403) changes nothing and says why', (
      tester,
    ) async {
      final gateway = _FakeGroupProfileGateway(
        failure: CommunityFailureKind.permissionDenied,
      );
      await _pumpGroupInfo(tester, gateway: gateway, creator: true);
      await _rename(tester, '新名字');
      expect(gateway.calls, hasLength(1));
      expect(find.text('只有群主可以修改群名称；这次没有改动。'), findsOneWidget);
      expect(find.text('老友记'), findsOneWidget);
    });

    testWidgets('an unavailable rename is never a success', (tester) async {
      final gateway = _FakeGroupProfileGateway(
        failure: CommunityFailureKind.unavailable,
      );
      await _pumpGroupInfo(tester, gateway: gateway, creator: true);
      await _rename(tester, '新名字');
      expect(find.text('改名暂时不可用，群名称没有改动。'), findsOneWidget);
      expect(find.text('老友记'), findsOneWidget);
    });

    testWidgets('a group that is gone says so', (tester) async {
      final gateway = _FakeGroupProfileGateway(
        failure: CommunityFailureKind.notFound,
      );
      await _pumpGroupInfo(tester, gateway: gateway, creator: true);
      await _rename(tester, '新名字');
      expect(find.text('群不存在或你已不在群里。'), findsOneWidget);
      expect(find.text('老友记'), findsOneWidget);
    });

    testWidgets('the name shown is the one the server confirmed', (
      tester,
    ) async {
      final gateway = _FakeGroupProfileGateway(confirmed: '周末徒步群');
      await _pumpGroupInfo(tester, gateway: gateway, creator: true);
      await _rename(tester, '周末徒步');
      expect(find.text('群名称已改为「周末徒步群」'), findsOneWidget);
      expect(find.text('周末徒步群'), findsOneWidget);
    });

    testWidgets('a member who did not create the group reads it only', (
      tester,
    ) async {
      final gateway = _FakeGroupProfileGateway();
      await _pumpGroupInfo(tester, gateway: gateway, creator: false);
      final row = find.byKey(const ValueKey<String>('group-info-name'));
      await scrollToCommunitySection(tester, row);
      expect(find.text('仅群主可改'), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('group-rename-sheet')),
        findsNothing,
      );
      expect(gateway.calls, isEmpty);
    });

    test('the name follows the creation form\'s rule', () {
      expect(normalizedGroupName('  周末徒步 '), '周末徒步');
      expect(normalizedGroupName('   '), isNull);
      expect(normalizedGroupName('a' * 41), isNull);
      expect(normalizedGroupName('a' * 40), 'a' * 40);
      expect(normalizedGroupName('a\u0000b'), isNull);
    });

    test('an unenveloped 404 is unavailable; NOT_FOUND is notFound', () {
      expect(
        groupRenameFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.invalidPayload,
            statusCode: 404,
          ),
        ),
        CommunityFailureKind.unavailable,
      );
      expect(
        groupRenameFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.invalidPayload,
            statusCode: 405,
          ),
        ),
        CommunityFailureKind.unavailable,
      );
      // LOOP's own envelope: the group is gone or the reader left it.
      expect(
        groupRenameFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.unexpected,
            statusCode: 404,
            code: 'NOT_FOUND',
          ),
        ),
        CommunityFailureKind.notFound,
      );
      expect(
        groupRenameFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.unexpected,
            statusCode: 403,
            code: 'PERMISSION_DENIED',
          ),
        ),
        CommunityFailureKind.permissionDenied,
      );
    });
  });
}

const _frogAssetId = 'eip155:56:0x00000000000000000000000000000000000000aa';

CommunitySummary _boundCommunity({required bool hasPool}) => CommunitySummary(
  communityId: testCommunityId,
  name: 'Frog Holders',
  slug: 'frog-holders',
  description: null,
  logoRef: null,
  verificationStatus: CommunityVerification.verified,
  boundAssetKey: _frogAssetId,
  memberCount: 128,
  createdAt: DateTime.utc(2026, 6),
  configVersion: 'communityV1',
  boundAsset: CommunityBoundAsset(
    assetId: _frogAssetId,
    symbol: 'FROG',
    name: null,
    logoUrl: null,
    hasRegisteredPool: hasPool,
  ),
);

final class _Clipboard {
  String? text;
}

_Clipboard _mockClipboard(WidgetTester tester) {
  final clipboard = _Clipboard();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboard.text =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          final text = clipboard.text;
          return text == null ? null : <String, Object?>{'text': text};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return clipboard;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpCardOpener(
  WidgetTester tester,
  LoopQrCardSubject subject, {
  String base = _stagingBase,
  ChatMergeExportSink? sink,
}) async {
  await pumpCommunityPage(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => unawaited(showLoopQrCardSheet(context, subject)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    size: const Size(390, 900),
    mergeExportSink: sink,
    overrides: <Override>[loopIdLinkBaseUrlProvider.overrideWithValue(base)],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final class _FakeSession implements LoopQrCameraSession {
  final ValueNotifier<LoopQrCameraState> _state =
      ValueNotifier<LoopQrCameraState>(
        const LoopQrCameraState(
          status: LoopQrCameraStatus.running,
          torch: LoopQrTorch.off,
        ),
      );
  final StreamController<String> _codes = StreamController<String>.broadcast(
    sync: true,
  );
  int torchToggles = 0;
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int retries = 0;
  bool disposed = false;

  @override
  Future<void> start() async => starts += 1;

  @override
  Future<void> pause() async => pauses += 1;

  @override
  Future<void> resume() async => resumes += 1;

  void emit(String code) => _codes.add(code);

  void set(LoopQrCameraStatus status) => _state.value = LoopQrCameraState(
    status: status,
    torch: _state.value.torch,
  );

  @override
  ValueListenable<LoopQrCameraState> get state => _state;

  @override
  Stream<String> get codes => _codes.stream;

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: LoopColors.ink);

  @override
  Future<void> toggleTorch() async {
    torchToggles += 1;
    _state.value = LoopQrCameraState(
      status: _state.value.status,
      torch: _state.value.torch == LoopQrTorch.on
          ? LoopQrTorch.off
          : LoopQrTorch.on,
    );
  }

  @override
  Future<void> retry() async {
    retries += 1;
    set(LoopQrCameraStatus.running);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

final class _FakeScanner implements LoopQrScanner {
  _FakeScanner(this.image);

  final _FakeSession session = _FakeSession();
  final LoopQrImageScan image;

  @override
  bool get available => true;

  @override
  LoopQrCameraSession openCamera() => session;

  @override
  Future<LoopQrImageScan> scanImage() async => image;
}

final class _Opened {
  _Opened(this.scanner);

  final _FakeScanner scanner;
  final List<String> locations = <String>[];
  final List<Object?> extras = <Object?>[];
}

Future<_Opened> _pumpScan(
  WidgetTester tester, {
  LoopQrImageScan image = const LoopQrImageCancelled(),
}) async {
  final opened = _Opened(_FakeScanner(image));
  await pumpCommunityPage(
    tester,
    ScanScreen(
      onOpen: (location, {extra}) {
        opened.locations.add(location);
        opened.extras.add(extra);
      },
    ),
    size: const Size(390, 900),
    overrides: <Override>[
      loopQrScannerProvider.overrideWithValue(opened.scanner),
    ],
  );
  return opened;
}

final class _FakeGroupProfileGateway implements GroupProfileGateway {
  _FakeGroupProfileGateway({this.failure, this.confirmed});

  final CommunityFailureKind? failure;

  /// The name the server answers with; defaults to the one it was sent.
  final String? confirmed;
  final List<String> calls = <String>[];

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<GroupRenamed> rename(String groupId, String name) async {
    calls.add('$groupId:$name');
    final kind = failure;
    if (kind != null) throw CommunityGatewayException(kind);
    return GroupRenamed(
      groupId: groupId,
      name: confirmed ?? name,
      nameVersion: 2,
      updatedAt: DateTime.utc(2026, 10, 8),
    );
  }
}

Future<void> _pumpGroupInfo(
  WidgetTester tester, {
  required _FakeGroupProfileGateway gateway,
  required bool creator,
}) => pumpCommunityPage(
  tester,
  GroupInfoScreen(channelCid: testGroupCid),
  chat: FakeChatV2Gateway(),
  groupAliasResolver: FakeGroupAliasResolverGateway(),
  overrides: <Override>[
    groupProfileGatewayProvider.overrideWithValue(gateway),
    groupStreamFactsReaderProvider.overrideWithValue(
      (cid) async => GroupStreamFacts(name: '老友记', viewerIsCreator: creator),
    ),
  ],
);

Future<void> _rename(WidgetTester tester, String name) async {
  final row = find.byKey(const ValueKey<String>('group-info-name'));
  await scrollToCommunitySection(tester, row);
  await _tap(tester, row);
  await tester.enterText(
    find.byKey(const ValueKey<String>('group-rename-field')),
    name,
  );
  await _tap(tester, find.byKey(const ValueKey<String>('group-rename-submit')));
}

Future<void> _pumpPreviewApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const UnconfiguredPrivyAuthGateway(),
        ),
        developmentPreviewEnabledProvider.overrideWithValue(true),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterPreview(WidgetTester tester) async {
  final previewButton = find.byKey(
    const ValueKey<String>('enter-development-preview-button'),
  );
  await tester.ensureVisible(previewButton);
  await tester.pump();
  await tester.tap(previewButton);
  await tester.pumpAndSettle();
}

Future<void> _pushPlatformRoute(WidgetTester tester, String location) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', <String, Object?>{
      'location': location,
      'state': null,
    }),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

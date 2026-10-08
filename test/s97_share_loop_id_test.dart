import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_profile_link_inbox.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/features/social/public_profile_sheet.dart';
import 'package:loop_mobile/integrations/personalization/memory_profile_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

const _ownId = 'LOOP-FE3EMCPE';
const _peerId = 'LOOP-7K2M9QXA';
const _stagingBase = 'https://api-staging.quant-dinger.cc';

/// Decision 0104: copying, sharing and pasting a LOOP ID, and the
/// `/u/{loopId}` profile link.
void main() {
  loopWatchGround();

  group('LOOP ID text rules', () {
    test('a pasted note yields the ID inside it, upper-cased', () {
      expect(loopIdFromText(_ownId), _ownId);
      expect(
        loopIdFromText('在 LOOP 上加我为好友：LOOP-FE3EMCPE\nhttps://x/u/…'),
        _ownId,
      );
      expect(loopIdFromText('我的是 loop-fe3emcpe 记得加'), _ownId);
      expect(loopIdFromText('id:Loop-Fe3eMcPe.'), _ownId);
    });

    test('no ID, a short invite code or a longer run is not taken', () {
      expect(loopIdFromText(null), isNull);
      expect(loopIdFromText(''), isNull);
      expect(loopIdFromText('onchain.mia'), isNull);
      expect(loopIdFromText('邀请码 LOOP-4K7QZ'), isNull);
      expect(loopIdFromText('LOOP-FE3EMCPE9'), isNull);
      expect(loopIdFromText('XLOOP-FE3EMCPE'), isNull);
      expect(loopIdFromText('LOOP-FE3E MCPE'), isNull);
    });

    test('share text is the ID line and one readable link', () {
      expect(
        loopIdShareTextFor(_ownId, backendBaseUrl: _stagingBase),
        '在 LOOP 上加我为好友：LOOP-FE3EMCPE\n'
        'https://api-staging.quant-dinger.cc/u/LOOP-FE3EMCPE',
      );
      expect(
        loopIdShareTextFor(_ownId, backendBaseUrl: '$_stagingBase/v2/'),
        endsWith('https://api-staging.quant-dinger.cc/u/LOOP-FE3EMCPE'),
      );
      // A build with no backend shares the ID alone, never a link to nowhere.
      expect(
        loopIdShareTextFor(_ownId, backendBaseUrl: ''),
        '在 LOOP 上加我为好友：LOOP-FE3EMCPE',
      );
    });

    test('a /u/ link path names one ID; anything else names none', () {
      expect(loopIdFromLinkPath('/u/LOOP-FE3EMCPE'), _ownId);
      expect(loopIdFromLinkPath('/u/loop-fe3emcpe/'), _ownId);
      expect(loopIdFromLinkPath('/u/LOOP-FE3EMCPE/extra'), isNull);
      expect(loopIdFromLinkPath('/u/onchain.mia'), isNull);
      expect(loopIdFromLinkPath('/profile'), isNull);
      expect(loopIdSearchLocation(_ownId), '/search?q=LOOP-FE3EMCPE');
    });
  });

  group('我的 · the LOOP ID block', () {
    testWidgets('the copy glyph behind the ID copies only the ID', (
      tester,
    ) async {
      final clipboard = _mockClipboard(tester);
      await _pumpProfile(tester, loopId: _ownId);

      expect(find.text(_ownId), findsOneWidget);
      final id = find.byKey(const ValueKey<String>('profile-loop-id'));
      final copy = find.byKey(const ValueKey<String>('profile-copy-loop-id'));
      expect(
        tester.getSemantics(copy),
        matchesSemantics(
          label: '复制 LOOP ID',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      // S97b: a 32×32 target right behind the ID, on its line, no button row.
      expect(tester.getSize(copy), const Size(32, 32));
      expect(
        tester.getCenter(copy).dy,
        moreOrLessEquals(tester.getCenter(id).dy, epsilon: 1),
      );
      expect(
        tester.getTopLeft(copy).dx,
        moreOrLessEquals(tester.getTopRight(id).dx, epsilon: 1),
      );
      final glyph = tester.widget<LoopIcon>(
        find.descendant(of: copy, matching: find.byType(LoopIcon)),
      );
      expect(glyph.name, 'copy');
      expect(glyph.size, inInclusiveRange(16, 18));

      await _tap(tester, copy);

      expect(clipboard.text, _ownId);
      expect(find.text('已复制 LOOP ID'), findsOneWidget);
    });

    testWidgets('a long press on the ID copies it too', (tester) async {
      final clipboard = _mockClipboard(tester);
      await _pumpProfile(tester, loopId: _ownId);

      await tester.longPress(
        find.byKey(const ValueKey<String>('profile-loop-id')),
      );
      await tester.pumpAndSettle();

      expect(clipboard.text, _ownId);
      expect(find.text('已复制 LOOP ID'), findsOneWidget);
    });

    testWidgets('分享 is a 44×44 glyph in the card\'s top-right corner', (
      tester,
    ) async {
      await _pumpProfile(tester, loopId: _ownId);

      final card = find.byKey(const ValueKey<String>('profile-identity-card'));
      final share = find.byKey(const ValueKey<String>('profile-share-loop-id'));
      expect(tester.getSize(share), const Size(44, 44));
      expect(
        tester.getSemantics(share),
        matchesSemantics(
          label: '分享 LOOP ID',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      final glyph = tester.widget<LoopIconButton>(share);
      expect(glyph.icon, 'share');
      final cardBox = tester.getRect(card);
      final shareBox = tester.getRect(share);
      expect(cardBox.right - shareBox.right, lessThan(24));
      expect(shareBox.top - cardBox.top, lessThan(24));
      // The outlined 复制 / 分享 buttons under the ID are gone.
      expect(find.text('复制'), findsNothing);
      expect(find.text('分享'), findsNothing);
    });

    testWidgets('分享 hands the invitation text to the system sheet', (
      tester,
    ) async {
      final shared = <String>[];
      await _pumpProfile(
        tester,
        loopId: _ownId,
        share: (text, {subject}) async {
          shared.add(text);
          return true;
        },
      );

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('profile-share-loop-id')),
      );

      expect(shared, <String>[
        '在 LOOP 上加我为好友：LOOP-FE3EMCPE\n'
            'https://api-staging.quant-dinger.cc/u/LOOP-FE3EMCPE',
      ]);
    });

    testWidgets('a sheet that cannot open points to 复制 instead', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        loopId: _ownId,
        share: (text, {subject}) async => false,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('profile-share-loop-id')),
      );
      expect(find.text('无法打开分享，可以改用复制'), findsOneWidget);
    });

    testWidgets('an unread ID offers neither action', (tester) async {
      await _pumpProfile(tester, loopId: null);
      expect(find.text('LOOP ID 不可读'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('profile-copy-loop-id')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('profile-share-loop-id')),
        findsNothing,
      );
    });
  });

  group('公开资料 · another account', () {
    testWidgets('the card copies their ID and shares nothing', (tester) async {
      final clipboard = _mockClipboard(tester);
      await _pumpSheetOpener(
        tester,
        const PublicProfileIdentity(
          publicProfileId: 'pp_01',
          displayName: 'onchain.mia',
          loopId: _peerId,
        ),
      );

      final copy = find.byKey(
        const ValueKey<String>('public-profile-copy-loop-id'),
      );
      expect(copy, findsOneWidget);
      // S97b: the same glyph behind the ID as on 我的, not a block button.
      expect(tester.getSize(copy), const Size(32, 32));
      expect(find.text('复制 LOOP ID'), findsNothing);
      expect(
        tester.getTopLeft(copy).dx,
        moreOrLessEquals(
          tester
              .getTopRight(
                find.byKey(const ValueKey<String>('public-profile-loop-id')),
              )
              .dx,
          epsilon: 1,
        ),
      );
      expect(find.textContaining('分享'), findsNothing);
      await _tap(tester, copy);

      expect(clipboard.text, _peerId);
      expect(find.text('已复制 LOOP ID'), findsOneWidget);
      // Copying is not a command on the account: the card stays open.
      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
    });

    testWidgets('a card without an ID has nothing to copy', (tester) async {
      await _pumpSheetOpener(
        tester,
        const PublicProfileIdentity(
          publicProfileId: 'pp_02',
          displayName: 'no-id',
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('public-profile-copy-loop-id')),
        findsNothing,
      );
    });
  });

  group('添加好友 · 粘贴', () {
    testWidgets('an ID inside other text is lifted out and asked of 用户', (
      tester,
    ) async {
      final clipboard = _mockClipboard(tester)
        ..text = '在 LOOP 上加我为好友：loop-fe3emcpe\nhttps://x/u/loop-fe3emcpe';
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{SearchDomain.users: _userPage()},
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
      );

      final paste = find.byKey(const ValueKey<String>('search-paste-loop-id'));
      expect(tester.getSize(paste).height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('粘贴 LOOP ID 并搜索'), findsOneWidget);
      await _tap(tester, paste);

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('search-field')),
      );
      expect(field.controller?.text, _ownId);
      expect(gateway.queries, <String>['users:$_ownId']);
      expect(
        tester
            .widget<LoopSeg>(
              find.byKey(const ValueKey<String>('search-seg-users')),
            )
            .selected,
        isTrue,
      );
      expect(find.text('Mia'), findsOneWidget);
      expect(clipboard.text, contains('loop-fe3emcpe'));
    });

    testWidgets('a bare lower-case ID is upper-cased', (tester) async {
      _mockClipboard(tester).text = '  loop-fe3emcpe ';
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{SearchDomain.users: _userPage()},
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('search-paste-loop-id')),
      );
      expect(gateway.queries, <String>['users:$_ownId']);
    });

    testWidgets('no ID on the clipboard leaves the field and sends nothing', (
      tester,
    ) async {
      _mockClipboard(tester).text = 'onchain.mia 你好';
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{SearchDomain.users: _userPage()},
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('search-paste-loop-id')),
      );

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('search-field')),
      );
      expect(field.controller?.text, isEmpty);
      expect(gateway.queries, isEmpty);
      expect(find.text('剪贴板里没有 LOOP ID'), findsOneWidget);
    });

    testWidgets('an empty clipboard says the same', (tester) async {
      _mockClipboard(tester);
      final gateway = FakeSearchGateway();
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
      );
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('search-paste-loop-id')),
      );
      expect(gateway.queries, isEmpty);
      expect(find.text('剪贴板里没有 LOOP ID'), findsOneWidget);
    });

    testWidgets('an ID given to the page asks 用户 first', (tester) async {
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{SearchDomain.users: _userPage()},
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(initialQuery: _ownId),
        search: gateway,
      );
      expect(gateway.queries, <String>['users:$_ownId']);
      expect(find.text('Mia'), findsOneWidget);
    });
  });

  group('/u/{loopId} profile link', () {
    testWidgets('a link opened in the product lands on search with the ID', (
      tester,
    ) async {
      await _pumpPreviewApp(tester);
      await _enterPreview(tester);
      expect(
        find.byKey(const ValueKey<String>('chat-tab-screen')),
        findsOneWidget,
      );

      await _pushPlatformRoute(tester, '/u/loop-fe3emcpe');

      _expectSearchWith(tester, _ownId);
    });

    testWidgets(
      'a link opened before sign-in is kept until the account lands',
      (tester) async {
        await _pumpPreviewApp(tester);
        await _pushPlatformRoute(tester, '/u/LOOP-FE3EMCPE');

        // Still signed out: the credential page, with the link held.
        expect(find.text('欢迎来到 LOOP'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(LoopApp)),
        );
        expect(container.read(loopProfileLinkInboxProvider).pending, _ownId);

        await _enterPreview(tester);

        _expectSearchWith(tester, _ownId);
        expect(container.read(loopProfileLinkInboxProvider).pending, isNull);
        // The account still landed on Community; search sits over it, so
        // going back returns there.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('chat-tab-screen')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a malformed link is an unknown route, not a search', (
      tester,
    ) async {
      await _pumpPreviewApp(tester);
      await _enterPreview(tester);
      await _pushPlatformRoute(tester, '/u/not-an-id');
      expect(
        find.byKey(const ValueKey<String>('chat-tab-screen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('global-search-screen')),
        findsNothing,
      );
    });
  });
}

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

Future<void> _pumpProfile(
  WidgetTester tester, {
  required String? loopId,
  LoopTextShare? share,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final gateway = MemoryProfileGateway(
    initialResource: ProfileResource(
      version: 3,
      values: ProfileValues(alias: 'QuietComet', avatarRef: null),
      updatedAt: DateTime.utc(2026, 9, 28),
      loopId: loopId,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileGatewayProvider.overrideWithValue(gateway),
        loopIdLinkBaseUrlProvider.overrideWithValue(_stagingBase),
        if (share != null) loopTextShareProvider.overrideWithValue(share),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: ProfileSurfaceScreen.fromId(
          'profile',
          identity: const ProfileIdentity(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSheetOpener(
  WidgetTester tester,
  PublicProfileIdentity identity,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => unawaited(
                  showPublicProfileSheet<Object>(context, identity: identity),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

SearchPage _userPage() => const SearchPage(
  domain: SearchDomain.users,
  available: true,
  reasonCode: null,
  results: <SearchResult>[
    SearchResult(
      resultType: SearchResultType.user,
      stableId: 'pp_mia',
      title: 'Mia',
      subtitle: _ownId,
      avatarRef: null,
      memberCount: null,
      verificationStatus: null,
      destination: SearchPublicProfileDestination(),
    ),
  ],
  nextCursor: null,
);

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

/// What the platform does with an App Link / Universal Link: MainActivity and
/// the Flutter scene delegate push the link's path as route information.
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

/// The page the link opened, and the ID it was opened with. The preview
/// composition has no search capability, so the page draws its capability
/// block; the ID reaching the page is what the route owes it.
void _expectSearchWith(WidgetTester tester, String loopId) {
  final screen = find.byKey(const ValueKey<String>('global-search-screen'));
  expect(screen, findsOneWidget);
  expect(
    tester
        .widget<GlobalSearchScreen>(find.byType(GlobalSearchScreen))
        .initialQuery,
    loopId,
  );
}

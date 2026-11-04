// S349 · decision 0271 Amendment (docs/56 §四): 我的 has the structure of
// another account's page — the person, the stranger requests, 总资产 with
// 钱包管理 and five keys, then 持仓 / 交易 / 社区. The account rows are gone.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_profile_sections.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/me_page_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _shotDir =
    '/private/tmp/claude-501/-Users-chenyang-Documents-LOOP/'
    '6293ad8a-21d0-4c44-84aa-93724a65bef3/scratchpad';

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<void> _section(WidgetTester tester, String label) async {
  final chip = find.descendant(
    of: _key('me-sections'),
    matching: find.text(label),
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(loopLoadShotFonts);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  loopWatchGround();

  testWidgets('person, 总资产, five keys, then 持仓 / 交易 / 社区', (tester) async {
    await pumpMePage(tester);
    double top(String key) => tester.getTopLeft(_key(key)).dy;
    expect(top('profile-identity-card'), lessThan(top('wallet-total-plate')));
    expect(top('wallet-total-plate'), lessThan(top('wallet-quick-actions')));
    expect(top('wallet-quick-actions'), lessThan(top('me-sections')));
    // The bar is the one another account's page draws; since S350c it is
    // a row of tabs, not the capsules the filters under it wear.
    expect(tester.widget(_key('me-sections')), isA<LoopProfileSectionsBar>());
    expect(
      find.descendant(
        of: _key('me-sections'),
        matching: find.byType(LoopSegBar),
      ),
      findsNothing,
    );
    final labels = <String>['持仓', '交易', '社区'];
    final xs = <double>[
      for (final label in labels)
        tester
            .getCenter(
              find.descendant(
                of: _key('me-sections'),
                matching: find.text(label),
              ),
            )
            .dx,
    ];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));
    expect(LoopProfileSection.values.map((section) => section.label), labels);
    // 持仓 is first and open: the tokens, 代币 / NFT and 产生算力.
    expect(top('me-sections'), lessThan(top('wallet-asset-list')));
    expect(_key('wallet-power-tag'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the account rows and 邀请好友 are gone', (tester) async {
    await pumpMePage(tester);
    for (final section in <String>['持仓', '交易', '社区']) {
      await _section(tester, section);
      for (final gone in <String>[
        'me-account-entries',
        'profile-open-wallets',
        'profile-open-communities',
        'profile-open-referral',
        'profile-copy-invite-code',
        'wallet-history-action',
      ]) {
        expect(_key(gone), findsNothing, reason: '$section · $gone');
      }
      expect(find.text('邀请好友'), findsNothing);
      expect(find.text('My wallets'), findsNothing);
    }
  });

  testWidgets('钱包管理 beside the address opens wallets', (tester) async {
    final opened = <String>[];
    await pumpMePage(tester, onNavigate: opened.add);
    final button = _key('wallet-manage-action');
    expect(
      find.descendant(of: _key('wallet-total-plate'), matching: button),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Wallet management'), findsOneWidget);
    // On the address line, right after the address and its copy glyph.
    final address = tester.getRect(_key('wallet-address-copy'));
    final pill = tester.getRect(button);
    expect(pill.center.dy, moreOrLessEquals(address.center.dy, epsilon: 4));
    expect(pill.left, greaterThan(address.right));
    expect(pill.left - address.right, lessThan(16));
    expect(
      find.descendant(of: button, matching: find.text('Manage')),
      findsOneWidget,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened, <String>['/wallet/manage']);
  });

  testWidgets('five keys, each to its page', (tester) async {
    final opened = <String>[];
    await pumpMePage(
      tester,
      onNavigate: opened.add,
      meta: s5MetaSnapshot(
        community: LoopV2CapabilityAvailability.available,
        privySwap: LoopV2CapabilityAvailability.available,
        sendApprovals: LoopV2CapabilityAvailability.available,
        swapEvidencePending: false,
      ),
    );
    final keys = <(String, String, String)>[
      ('wallet-receive-entry', 'Receive', WalletRoute.receive(s5WalletId)),
      ('wallet-send-entry', 'Send', '/wallet/send'),
      ('wallet-swap-entry', 'Swap', '/wallet/swap'),
      ('wallet-pay-entry', 'Scan', '/scan'),
      ('wallet-dapp-entry', 'DApp', '/wallet/dapp'),
    ];
    double? last;
    for (final (key, label, location) in keys) {
      final finder = _key(key);
      expect(
        find.descendant(of: _key('wallet-quick-actions'), matching: finder),
        findsOneWidget,
        reason: key,
      );
      expect(
        find.descendant(of: finder, matching: find.text(label)),
        findsOneWidget,
        reason: key,
      );
      final x = tester.getCenter(finder).dx;
      if (last != null) expect(x, greaterThan(last), reason: key);
      last = x;
      opened.clear();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(opened, <String>[location], reason: key);
    }
  });

  testWidgets('DApp stays when the browser is closed: the URL review', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpMePage(tester, onNavigate: opened.add);
    await tester.tap(_key('wallet-dapp-entry'));
    await tester.pumpAndSettle();
    expect(opened, <String>['/wallet/dapp']);
  });

  testWidgets('交易: the tape, paged as the reader scrolls', (tester) async {
    final wallet = await pumpMePage(
      tester,
      activity: meLongTape(),
      size: const Size(390, 900),
    );
    expect(wallet.activityCursors, isEmpty);
    await _section(tester, '交易');
    expect(_key('me-trades-days'), findsOneWidget);
    expect(_key('me-trades-seg-0'), findsOneWidget);
    expect(_key('wallet-asset-list'), findsNothing);
    // The first page only: the sentinel is not built until it is near.
    expect(wallet.activityCursors, <String?>[null]);
    expect(_key('me-trades-load-more'), findsNothing);
    // One scroll container: the page's own.
    await tester.scrollUntilVisible(
      _key('me-trades-load-more'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(wallet.activityCursors, <String?>[null, 'cursor-2']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('交易: nothing yet is one line', (tester) async {
    await pumpMePage(
      tester,
      activity: s5Activity(items: const <LoopWalletActivityEntry>[]),
    );
    await _section(tester, '交易');
    expect(_key('me-trades-empty'), findsOneWidget);
    expect(find.text('No records in this range'), findsOneWidget);
  });

  testWidgets('社区: joined and created, with the review state', (tester) async {
    final opened = <String>[];
    await pumpMePage(tester, onNavigate: opened.add);
    await _section(tester, '社区');
    expect(_key('me-joined-$meJoinedA'), findsOneWidget);
    expect(_key('me-joined-$meJoinedB'), findsOneWidget);
    expect(_key('profile-owned-$meOwnedId'), findsOneWidget);
    expect(find.text('Joined'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('2,048 members'), findsOneWidget);
    expect(_key('wallet-asset-list'), findsNothing);
    double top(String key) => tester.getTopLeft(_key(key)).dy;
    expect(
      top('me-joined-$meJoinedB'),
      lessThan(top('profile-owned-$meOwnedId')),
    );
    await tester.tap(_key('me-joined-$meJoinedA'));
    await tester.pumpAndSettle();
    expect(opened, <String>['/community/profile?id=$meJoinedA']);
  });

  testWidgets('社区: only joined, no group labels', (tester) async {
    await pumpMePage(tester, home: meHome(owned: const <OwnedCommunity>[]));
    await _section(tester, '社区');
    expect(_key('me-joined-$meJoinedA'), findsOneWidget);
    expect(_key('profile-owned-communities'), findsNothing);
    expect(find.text('Joined'), findsNothing);
  });

  testWidgets('社区: none is one line', (tester) async {
    await pumpMePage(
      tester,
      home: meHome(
        joined: const <JoinedCommunity>[],
        owned: const <OwnedCommunity>[],
      ),
    );
    await _section(tester, '社区');
    expect(_key('me-communities-empty'), findsOneWidget);
    expect(find.text('No communities joined yet'), findsOneWidget);
  });

  testWidgets('wallet module closed: 社区 still reads', (tester) async {
    await pumpMePage(
      tester,
      meta: s5MetaSnapshot(
        community: LoopV2CapabilityAvailability.available,
        walletRead: LoopV2CapabilityAvailability.unavailable,
      ),
    );
    expect(_key('wallet-capability-block'), findsOneWidget);
    await _section(tester, '交易');
    expect(_key('me-trades-capability-block'), findsOneWidget);
    await _section(tester, '社区');
    expect(_key('me-joined-$meJoinedA'), findsOneWidget);
  });

  for (final width in <double>[390, 360]) {
    testWidgets('no overflow at $width in any section', (tester) async {
      await pumpMePage(tester, size: Size(width, 2400));
      // Address, copy and 管理 share one line.
      expect(
        tester.getCenter(_key('wallet-manage-action')).dy,
        moreOrLessEquals(
          tester.getCenter(_key('wallet-address')).dy,
          epsilon: 4,
        ),
      );
      expect(tester.getSize(_key('wallet-address')).height, lessThan(24));
      for (final section in <String>['持仓', '交易', '社区']) {
        await _section(tester, section);
        expect(tester.takeException(), isNull, reason: '$width · $section');
      }
    });
  }

  group('shots', () {
    testWidgets('我的 · 持仓', skip: !_shots, (tester) async {
      await pumpMePage(tester, size: const Size(390, 1500));
      await _shot(tester, 'S349-me-holdings');
    });

    testWidgets('我的 · 交易', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        activity: meLongTape(nextCursor: null),
        size: const Size(390, 1500),
      );
      await _section(tester, '交易');
      await _shot(tester, 'S349-me-trades');
    });

    testWidgets('我的 · 社区', skip: !_shots, (tester) async {
      await pumpMePage(tester, size: const Size(390, 1500));
      await _section(tester, '社区');
      await _shot(tester, 'S349-me-communities');
    });

    testWidgets('我的 · 持仓 360', skip: !_shots, (tester) async {
      await pumpMePage(tester, size: const Size(360, 1500));
      await _shot(tester, 'S349-me-holdings-360');
    });
  });
}

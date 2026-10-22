// S273 · decision 0232: the self-review shots of the NFT picture card.
//
// Not a check: it writes 390-wide renders to docs/integration/S273/shots/ so
// the card's two faces, the wallet grid, the medal and the sheet thumbnail
// can be read by eye. It runs only with `--dart-define=LOOP_SHOTS=true`; a
// plain `flutter test` skips every case and writes nothing. The stand-in
// logo is the app icon.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_card.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_wallet_rows.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _standIn = 'assets/brand/loop-app-icon-official.webp';

Launch2Position _position(
  String id,
  String ticker, {
  String? logo,
  int held = 1,
  int? tokenId,
  Launch2Stage stage = Launch2Stage.public,
}) {
  final base = l2Positions().items.single;
  return Launch2Position(
    instanceId: id,
    name: base.name,
    ticker: ticker,
    logoUrl: logo,
    memeAddress: base.memeAddress,
    stage: stage,
    walletId: base.walletId,
    nftHeld: held,
    snapshotMember: true,
    curve: base.curve,
    mintedTokenId: tokenId == null ? null : BigInt.from(tokenId),
  );
}

void main() {
  loopWatchGround();

  testWidgets('NFT cards', skip: !_shots, (tester) async {
    debugLoopRemoteAvatarImageProvider = (_) => const AssetImage(_standIn);
    addTearDown(() => debugLoopRemoteAvatarImageProvider = null);
    tester.view.physicalSize = const Size(390, 1240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tiles = <Widget>[
      for (final p in <Launch2Position>[
        _position('a', 'LOOP', logo: 'https://x/a.png', tokenId: 128),
        _position('b', 'FROG', tokenId: 7, held: 2),
        _position('c', '天才少年', tokenId: 3, stage: Launch2Stage.priority),
        _position('d', 'S234WLONG', stage: Launch2Stage.nftSale),
      ])
        Launch2WalletNftTile(position: p, hidden: false, onTap: () {}),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: LoopColors.ink,
          body: ListView(
            padding: const EdgeInsets.all(LoopSpacing.page),
            children: <Widget>[
              Launch2NftGrid(children: tiles),
              const SizedBox(height: LoopSpacing.section),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Launch2NftMedal(
                    ticker: 'LOOP',
                    logoUrl: 'https://x/a.png',
                    bottomLabel: '#128',
                    lit: true,
                    size: 170,
                  ),
                  Launch2NftMedal(
                    ticker: 'FROG',
                    bottomLabel: '共识勋章',
                    lit: false,
                    size: 170,
                  ),
                ],
              ),
              const SizedBox(height: LoopSpacing.section),
              const Row(
                children: <Widget>[
                  Launch2NftCard(
                    ticker: 'LOOP',
                    logoUrl: 'https://x/a.png',
                    size: 64,
                  ),
                  SizedBox(width: LoopSpacing.rowGap),
                  Launch2NftCard(ticker: 'FROG', size: 64),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(ListView));
    await tester.runAsync(() async {
      for (final path in <String>[...launch2NftCardAssets, _standIn]) {
        await precacheImage(AssetImage(path), context);
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await loopShot(
      tester,
      'nft-cards',
      slice: 1240,
      dir: 'docs/integration/S273/shots',
    );
  });
}

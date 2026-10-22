import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

/// The pieces [Launch2NftCard]'s default face draws, for [LoopAtmoPrecache]
/// on every page that shows a card (S273 · decision 0232).
const List<String> launch2NftCardAssets = <String>[
  LoopAtmoAssets.wall,
  LoopAtmoAssets.sprayPurple,
  LoopAtmoAssets.sprayYellow,
  LoopAtmoAssets.crownYellow,
  LoopAtmoAssets.handChrome,
];

/// Where a [Launch2NftCard] is drawn.
enum Launch2NftCardShape {
  /// A square card, 16 radius, with its own Purple double ring.
  card,

  /// The face only, clipped to a circle: the centre of [Launch2NftMedal],
  /// whose painter draws the ring and the arc words.
  medal,
}

/// The picture of one project NFT (S273 · decision 0232, 需求方 「NFT 应该展示
/// 图片吧」). There is no tokenURI on chain; the face is the owner's NFT
/// picture (`nftImageUrl`, loop-api S274) when there is one, else the
/// project's logo, else the MEME banner's default art.
///
/// * With a logo: the logo fills the card (cover), a black gradient over the
///   bottom 45 %, the ticker (headline, Chalk) at the bottom left and
///   `#tokenId` (figure, Yellow) at the bottom right.
/// * Without one — or while the logo loads, or when it fails: the wall, the
///   Purple and Yellow fog, the Ink wash, the chrome hand with its Yellow
///   crown; the ticker is the big word (title1) at the top left and
///   `#tokenId` under it. Never a two-letter monogram.
///
/// A thin Purple double ring keeps the 共识勋章 identity (decisions 0163 /
/// 0212). Nothing in the card moves — no sheen, reduced motion or not.
/// Under [compactBelow] wide the words shrink to the ticker alone.
class Launch2NftCard extends StatelessWidget {
  const Launch2NftCard({
    required this.ticker,
    super.key,
    this.nftImageUrl,
    this.logoUrl,
    this.tokenId,
    this.size,
    this.shape = Launch2NftCardShape.card,
  });

  final String ticker;

  /// The owner's NFT picture (S274 `nftImageUrl`): first choice.
  final String? nftImageUrl;

  /// The project logo: the picture when there is no NFT picture.
  final String? logoUrl;

  /// The pictures this card tries, in order (decision 0232): the NFT
  /// picture, then the logo; with neither, the default art.
  List<String> get pictureUrls => <String>[?nftImageUrl, ?logoUrl];

  /// The minted token, when this wallet holds one.
  final BigInt? tokenId;

  /// The side; `null` fills the width it is given, square.
  final double? size;
  final Launch2NftCardShape shape;

  /// Under this side the card is a thumbnail: no `#id`, a small ticker.
  static const double compactBelow = 120;

  /// The decode side of the logo: the card is up to ~200 dp at 3×.
  static const int logoDecodeSide = 640;

  String? get _idLabel => tokenId == null ? null : '#$tokenId';

  @override
  Widget build(BuildContext context) {
    final side = size;
    final face = LayoutBuilder(
      builder: (context, constraints) {
        final width = side ?? constraints.maxWidth;
        return SizedBox.square(dimension: width, child: _face(width));
      },
    );
    return Semantics(
      image: true,
      label: <String>[
        '$ticker NFT',
        ?_idLabel,
        if (pictureUrls.isEmpty) '默认图',
      ].join('，'),
      excludeSemantics: true,
      child: side == null
          ? AspectRatio(aspectRatio: 1, child: face)
          : SizedBox.square(dimension: side, child: face),
    );
  }

  /// The picture at [urls]`[index]`; the default art (without words) until
  /// its first frame; the next picture when it does not load, and the art
  /// for good after the last. Never a monogram.
  Widget _picture(List<String> urls, int index, Widget bareArt) {
    if (index >= urls.length) return bareArt;
    return Image(
      key: ValueKey<String>(
        index == 0 ? 'launch2-nft-card-logo' : 'launch2-nft-card-logo-$index',
      ),
      image: ResizeImage(
        loopRemoteImageSource(urls[index]),
        width: logoDecodeSide,
        height: logoDecodeSide,
        policy: ResizeImagePolicy.fit,
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, synchronous) =>
          synchronous || frame != null ? child : bareArt,
      errorBuilder: (context, error, stackTrace) =>
          _picture(urls, index + 1, bareArt),
    );
  }

  Widget _face(double width) {
    final medal = shape == Launch2NftCardShape.medal;
    // The medal's centre always carries its one word, scaled to fit.
    final compact = !medal && width < compactBelow;
    final art = Launch2NftArtBackdrop(
      width: width,
      words: _ArtWords(
        ticker: launch2HeroTicker(ticker),
        idLabel: medal ? null : _idLabel,
        width: width,
        compact: compact,
        centred: medal,
      ),
    );
    // Under a logo that is loading or failed: the same art without its own
    // words — the logo face lays its words over the bottom already.
    final bareArt = Launch2NftArtBackdrop(
      width: width,
      words: const SizedBox.shrink(),
    );
    final urls = pictureUrls;
    final Widget body = urls.isEmpty
        ? art
        : Stack(
            key: const ValueKey<String>('launch2-nft-card-logo-face'),
            fit: StackFit.expand,
            children: <Widget>[
              _picture(urls, 0, bareArt),
              if (!medal && !compact) ...<Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: width * 0.45,
                  child: const DecoratedBox(
                    key: ValueKey<String>('launch2-nft-card-shade'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0x00000000), Color(0xD9000000)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          launch2HeroTicker(ticker),
                          key: const ValueKey<String>(
                            'launch2-nft-card-ticker',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.headline.copyWith(
                            color: LoopColors.chalk,
                          ),
                        ),
                      ),
                      if (_idLabel case final String id) ...<Widget>[
                        const SizedBox(width: LoopSpacing.tight),
                        Text(
                          id,
                          key: const ValueKey<String>('launch2-nft-card-id'),
                          maxLines: 1,
                          style: LoopType.figure.copyWith(
                            color: LoopColors.yellow,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
    if (medal) {
      return ClipOval(
        key: const ValueKey<String>('launch2-nft-card'),
        child: body,
      );
    }
    final radius = compact ? LoopRadius.inner : LoopRadius.card;
    final inset = compact ? 3.0 : 5.0;
    return Stack(
      key: const ValueKey<String>('launch2-nft-card'),
      fit: StackFit.expand,
      children: <Widget>[
        ClipRRect(borderRadius: radius, child: body),
        // The medal's double ring (decisions 0163 / 0212): Purple outside, a
        // fainter Purple hairline inside.
        IgnorePointer(
          child: DecoratedBox(
            key: const ValueKey<String>('launch2-nft-card-ring'),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: LoopColors.purple, width: 1.5),
            ),
          ),
        ),
        Positioned.fill(
          left: inset,
          top: inset,
          right: inset,
          bottom: inset,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  math.max(0, radius.topLeft.x - inset),
                ),
                border: Border.all(color: LoopColors.purpleLine, width: 0.75),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The card's default face (S273 · decision 0232): the MEME banner's
/// default art (decisions 0220 §4 / 0222 / 0223) scaled to a square — the
/// wall at 90 %, Purple fog from the top left, Yellow from the bottom right,
/// an Ink wash under the words, and the chrome hand with its Yellow crown at
/// the bottom right. Still: the hand carries no sheen here.
class Launch2NftArtBackdrop extends StatelessWidget {
  const Launch2NftArtBackdrop({
    required this.width,
    required this.words,
    super.key,
  });

  final double width;
  final Widget words;

  @override
  Widget build(BuildContext context) {
    final w = width;
    return Stack(
      key: const ValueKey<String>('launch2-nft-card-default-art'),
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: Color(0xFF0E0D12)),
        const DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(LoopAtmoAssets.wall),
              fit: BoxFit.cover,
              alignment: Alignment(-0.4, -0.2),
              opacity: 0.9,
            ),
          ),
          child: SizedBox.expand(),
        ),
        Positioned(
          left: -w * 0.45,
          top: -w * 0.55,
          width: w * 1.6,
          height: w * 1.6,
          child: Opacity(
            opacity: 0.55,
            child: loopAtmoArt(LoopAtmoAssets.sprayPurple),
          ),
        ),
        Positioned(
          right: -w * 0.6,
          bottom: -w * 0.7,
          width: w * 1.4,
          height: w * 1.4,
          child: Opacity(
            opacity: 0.14,
            child: loopAtmoArt(LoopAtmoAssets.sprayYellow),
          ),
        ),
        const DecoratedBox(
          key: ValueKey<String>('launch2-nft-card-scrim'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xB309090B),
                Color(0x6609090B),
                Color(0x0009090B),
              ],
              stops: <double>[0, 0.45, 0.8],
            ),
          ),
        ),
        Positioned(
          right: -w * 0.08,
          bottom: -w * 0.1,
          width: w * 0.66,
          height: w * 0.66,
          child: loopAtmoArt(LoopAtmoAssets.handChrome),
        ),
        Positioned(
          right: w * 0.3,
          bottom: w * 0.42,
          width: w * 0.26,
          child: Transform.rotate(
            angle: -14 * math.pi / 180,
            child: loopAtmoArt(LoopAtmoAssets.crownYellow),
          ),
        ),
        words,
      ],
    );
  }
}

/// The words of the default face: the ticker big, `#id` under it.
class _ArtWords extends StatelessWidget {
  const _ArtWords({
    required this.ticker,
    required this.idLabel,
    required this.width,
    required this.compact,
    required this.centred,
  });

  final String ticker;
  final String? idLabel;
  final double width;
  final bool compact;

  /// The medal's centre: the ticker alone, in the middle (the medal's arcs
  /// carry the ticker and `#id` already).
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final style = compact
        ? LoopType.tag.copyWith(color: LoopColors.chalk)
        : (centred ? LoopType.title2 : LoopType.title1).copyWith(
            color: LoopColors.chalk,
          );
    final word = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: centred ? Alignment.center : Alignment.centerLeft,
      child: Text(
        ticker,
        key: const ValueKey<String>('launch2-nft-card-ticker'),
        maxLines: 1,
        style: style,
      ),
    );
    if (centred) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: width * 0.16),
        child: Center(child: word),
      );
    }
    final pad = compact ? 6.0 : 14.0;
    return Positioned(
      left: pad,
      top: compact ? 5 : 12,
      right: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          word,
          if (idLabel case final String id when !compact)
            Text(
              id,
              key: const ValueKey<String>('launch2-nft-card-id'),
              maxLines: 1,
              style: LoopType.figure.copyWith(color: LoopColors.yellow),
            ),
        ],
      ),
    );
  }
}

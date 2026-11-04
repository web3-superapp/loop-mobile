import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The wallet frames' own line glyphs (docs/58 §8, `assets/figma/wallet-*`;
/// S353c · decision 0280), tinted at the call site. Decorative: the key or
/// row around a glyph carries its label.
class WalletFigmaGlyph extends StatelessWidget {
  const WalletFigmaGlyph(
    this.asset, {
    required this.size,
    required this.color,
    super.key,
  });

  static const String _root = 'assets/figma';

  static const String eye = '$_root/wallet-eye.svg';
  static const String copy = '$_root/wallet-copy.svg';
  static const String info = '$_root/wallet-info.svg';
  static const String receive = '$_root/wallet-receive.svg';
  static const String send = '$_root/wallet-send.svg';
  static const String swap = '$_root/wallet-swap.svg';
  static const String scan = '$_root/wallet-scan.svg';
  static const String link = '$_root/wallet-link.svg';
  static const String wallet = '$_root/wallet-wallet.svg';
  static const String chevron = '$_root/wallet-chevron.svg';

  final String asset;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  );
}

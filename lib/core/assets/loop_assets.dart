/// Frozen prototype asset registry.
///
/// Every file under `assets/` is copied from `LOOP/docs/prototype/assets` and
/// `LOOP/docs/prototype/sprite` (cliview.org loop-v2 build). The identity atlas
/// slot table mirrors `FX.media` in `docs/prototype/app-v2.js`; the atlas is
/// never cut into loose images, so the mapping stays here.
library;

import 'package:flutter/foundation.dart';

abstract final class LoopAssetPaths {
  static const String icons = 'assets/icons';
  static const String tokens = 'assets/tokens';
  static const String networks = 'assets/networks';
  static const String brand = 'assets/brand';
  static const String people = 'assets/people/loop-people-atlas.webp';
  static const String communities =
      'assets/communities/loop-community-atlas.webp';

  static String icon(String name) => '$icons/i-$name.svg';
  static String token(String file) => '$tokens/$file.svg';
  static String network(String file) => '$networks/$file.svg';
}

/// Linear SVG sprite names (61) from `shell-open.html`, without the `i-` prefix.
abstract final class LoopIconNames {
  static const Set<String> all = <String>{
    'ai',
    'arrow-down',
    'arrow-up',
    'back',
    'bell',
    'blocked',
    'book',
    'camera',
    'chart',
    'chat',
    'check',
    'chevron',
    'clock',
    'close',
    'cloud',
    'community',
    'compass',
    'crown',
    'drag',
    'droplet',
    'expand',
    'globe',
    'graduate',
    'hand',
    'id',
    'info',
    'key',
    'keypad',
    'laptop',
    'launch',
    'link',
    'lock',
    'mail',
    'maintenance',
    'mic',
    'mine-tab',
    'mine',
    'news',
    'no-capture',
    'offline',
    'parachute',
    'phishing',
    'phone',
    'pin',
    'question',
    'search',
    'settings',
    'shield',
    'shuffle',
    'smart',
    'star',
    'swap-vert',
    'target',
    'ticket',
    'upgrade',
    'user',
    'users',
    'voice-off',
    'voice',
    'wallet',
    'warn',
  };

  static bool contains(String name) => all.contains(name);
}

/// Token logos shipped with the prototype, keyed by upper-case symbol.
abstract final class LoopTokenAssets {
  static const Map<String, String> bySymbol = <String, String>{
    'BONK': 'bonk',
    'LOOP': 'loop',
    'MCAT': 'mcat',
    'PEPE': 'pepe',
    'SOL': 'sol',
    'USDC': 'usdc',
    'USDT': 'usdt',
  };

  static const String fallback = 'fallback';

  static String? pathForSymbol(String symbol) {
    final file = bySymbol[symbol.trim().toUpperCase()];
    return file == null ? null : LoopAssetPaths.token(file);
  }
}

/// Network logos shipped with the prototype, keyed by lower-case id.
abstract final class LoopNetworkAssets {
  static const Map<String, String> byId = <String, String>{
    'base': 'base',
    'bsc': 'bsc',
    'bnb': 'bsc',
    'ethereum': 'ethereum',
    'eth': 'ethereum',
    'solana': 'solana',
    'sol': 'solana',
  };

  static String? pathForId(String id) {
    final file = byId[id.trim().toLowerCase()];
    return file == null ? null : LoopAssetPaths.network(file);
  }
}

/// Brand marks. WebP first, SVG fallback (chapter 4.5).
abstract final class LoopBrandAssets {
  static const String appIconWebp =
      '${LoopAssetPaths.brand}/loop-app-icon-u3d.webp';
  static const String appIconSvg = '${LoopAssetPaths.brand}/loop-app-icon.svg';
  static const String wordmarkWebp =
      '${LoopAssetPaths.brand}/loop-wordmark-u3d.webp';
  static const String wordmarkSvg = '${LoopAssetPaths.brand}/loop-wordmark.svg';
}

/// One WebP identity atlas and its grid.
enum LoopIdentityAtlas {
  /// People · 4 columns × 3 rows.
  people(LoopAssetPaths.people, columns: 4, rows: 3),

  /// Communities · 2 columns × 2 rows.
  communities(LoopAssetPaths.communities, columns: 2, rows: 2);

  const LoopIdentityAtlas(
    this.path, {
    required this.columns,
    required this.rows,
  });

  final String path;
  final int columns;
  final int rows;

  Map<String, LoopIdentitySlot> get slots => switch (this) {
    LoopIdentityAtlas.people => LoopIdentitySlots.people,
    LoopIdentityAtlas.communities => LoopIdentitySlots.communities,
  };

  LoopIdentitySlot? slot(String key) => slots[key];
}

/// A cell inside an identity atlas.
@immutable
final class LoopIdentitySlot {
  const LoopIdentitySlot({
    required this.column,
    required this.row,
    required this.fallback,
    required this.label,
  });

  final int column;
  final int row;

  /// Monogram shown when the atlas cannot load.
  final String fallback;

  /// Semantic label (the prototype `alt`).
  final String label;
}

/// Slot table copied from `FX.media` in `docs/prototype/app-v2.js`.
abstract final class LoopIdentitySlots {
  static const Map<String, LoopIdentitySlot> people =
      <String, LoopIdentitySlot>{
        'v7': LoopIdentitySlot(
          column: 0,
          row: 0,
          fallback: 'V7',
          label: 'Voyager_7 头像',
        ),
        'nightowl': LoopIdentitySlot(
          column: 1,
          row: 0,
          fallback: 'NO',
          label: 'NightOwl 头像',
        ),
        'pepe-maxi': LoopIdentitySlot(
          column: 2,
          row: 0,
          fallback: 'PM',
          label: 'pepe_maxi 头像',
        ),
        'alpha-drop': LoopIdentitySlot(
          column: 3,
          row: 0,
          fallback: 'AD',
          label: 'AlphaDrop 头像',
        ),
        'fomo-trader': LoopIdentitySlot(
          column: 0,
          row: 1,
          fallback: 'FT',
          label: 'fox_trader 头像',
        ),
        'pepe-founder': LoopIdentitySlot(
          column: 1,
          row: 1,
          fallback: 'PF',
          label: 'PEPE founder 头像',
        ),
        'smart-buyer': LoopIdentitySlot(
          column: 2,
          row: 1,
          fallback: 'SB',
          label: 'SmartBuyer 头像',
        ),
        'whale': LoopIdentitySlot(
          column: 3,
          row: 1,
          fallback: 'WH',
          label: 'whale_0x9f 头像',
        ),
        'diamondpaw': LoopIdentitySlot(
          column: 0,
          row: 2,
          fallback: 'DP',
          label: 'DiamondPaw 头像',
        ),
        'member-echo': LoopIdentitySlot(
          column: 1,
          row: 2,
          fallback: 'EC',
          label: '社区成员 Echo 头像',
        ),
        'moderator': LoopIdentitySlot(
          column: 2,
          row: 2,
          fallback: 'MOD',
          label: '社区管理员头像',
        ),
        'observer': LoopIdentitySlot(
          column: 3,
          row: 2,
          fallback: 'OBS',
          label: '社区观察员头像',
        ),
      };

  static const Map<String, LoopIdentitySlot> communities =
      <String, LoopIdentitySlot>{
        'loop': LoopIdentitySlot(
          column: 0,
          row: 0,
          fallback: 'LOOP',
          label: 'LOOP Official 社区图标',
        ),
        'pepe': LoopIdentitySlot(
          column: 1,
          row: 0,
          fallback: 'PEPE',
          label: 'PEPE Community 社区图标',
        ),
        'bonk': LoopIdentitySlot(
          column: 0,
          row: 1,
          fallback: 'BONK',
          label: 'BONK Community 社区图标',
        ),
        'mcat': LoopIdentitySlot(
          column: 1,
          row: 1,
          fallback: 'MCAT',
          label: 'MOONCAT 社区图标',
        ),
      };

  /// Alias table from `FX.media.aliases` so fixture keys resolve to slots.
  static const Map<String, String> communityAliases = <String, String>{
    'loop': 'loop',
    'loopofficial': 'loop',
    'pepe': 'pepe',
    'pepecommunity': 'pepe',
    'bonk': 'bonk',
    'bonkcommunity': 'bonk',
    'mcat': 'mcat',
    'mooncat': 'mcat',
  };
}

/// Monogram fallback: up to two upper-case characters from [source].
String loopMonogram(String source) {
  final cleaned = source.trim().replaceAll(RegExp(r'[^A-Za-z0-9一-鿿]'), '');
  if (cleaned.isEmpty) return '·';
  final runes = cleaned.runes.toList(growable: false);
  final take = runes.length >= 2 ? 2 : 1;
  return String.fromCharCodes(runes.take(take)).toUpperCase();
}

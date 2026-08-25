import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

void main() {
  group('Watchlist models', () {
    test('normalizes names and makes defensive ordered copies', () {
      final sourceItems = <WatchlistItem>[
        WatchlistItem(assetKey: 'ETH'),
        WatchlistItem(assetKey: 'BTC'),
      ];
      final sourceGroups = <WatchlistGroup>[
        WatchlistGroup(key: 'favorites', name: '  重点关注  ', items: sourceItems),
      ];
      final snapshot = WatchlistSnapshot(
        version: 1,
        groups: sourceGroups,
        updatedAt: DateTime.parse('2026-08-25T09:02:03+08:00'),
      );

      sourceItems.clear();
      sourceGroups.clear();

      expect(snapshot.groups.single.name, '重点关注');
      expect(
        snapshot.groups.single.items.map((item) => item.assetKey),
        <String>['ETH', 'BTC'],
      );
      expect(snapshot.updatedAt, DateTime.utc(2026, 8, 25, 1, 2, 3));
      expect(
        () => snapshot.groups.add(
          WatchlistGroup(key: 'other', name: 'Other', items: const []),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.groups.single.items.add(WatchlistItem(assetKey: 'SOL')),
        throwsUnsupportedError,
      );
    });

    test('counts Unicode code points rather than UTF-16 code units', () {
      final accepted = WatchlistGroup(
        key: 'emoji',
        name: _repeat('😀', 40),
        items: const [],
      );

      expect(accepted.name.runes.length, 40);
      expect(
        () => WatchlistGroup(
          key: 'emoji',
          name: _repeat('😀', 41),
          items: const [],
        ),
        throwsA(isA<InvalidWatchlistContractException>()),
      );
    });

    test('bounds the raw display name before trimming', () {
      final accepted = WatchlistGroup(
        key: 'raw_boundary',
        name: '${_repeat(' ', 176)}${_repeat('😀', 40)}',
        items: const [],
      );
      expect(accepted.name.runes.length, 40);

      expect(
        () => WatchlistGroup(
          key: 'raw_overflow',
          name: '${_repeat(' ', 177)}${_repeat('😀', 40)}',
          items: const [],
        ),
        throwsA(isA<InvalidWatchlistContractException>()),
      );
    });

    for (final invalidName in <String>[
      '   ',
      'bad\nname',
      '\tname',
      'safe\u061cevil',
      'safe\u200eevil',
      'safe\u202eevil',
      'safe\u2066evil',
      String.fromCharCode(0xD800),
    ]) {
      test('rejects unsafe display name without echoing it', () {
        Object? failure;
        try {
          WatchlistGroup(key: 'safe', name: invalidName, items: const []);
        } catch (error) {
          failure = error;
        }

        expect(failure, isA<InvalidWatchlistContractException>());
        expect(failure.toString(), isNot(contains(invalidName)));
      });
    }

    test('enforces canonical group and asset keys', () {
      expect(
        WatchlistGroup(
          key: 'a${_repeat('b', 31)}',
          name: 'Boundary',
          items: <WatchlistItem>[
            WatchlistItem(assetKey: 'A${_repeat('B', 63)}'),
          ],
        ).key.length,
        32,
      );

      for (final key in <String>['Bad', '_bad', 'a${_repeat('b', 32)}']) {
        expect(
          () => WatchlistGroup(key: key, name: 'Name', items: const []),
          throwsA(isA<InvalidWatchlistContractException>()),
        );
      }
      for (final asset in <String>[
        'eth',
        '_BTC',
        'ETH/USD',
        'A${_repeat('B', 64)}',
      ]) {
        expect(
          () => WatchlistItem(assetKey: asset),
          throwsA(isA<InvalidWatchlistContractException>()),
        );
      }
    });

    test('enforces group uniqueness and aggregate boundaries', () {
      final boundary = List<WatchlistGroup>.generate(
        watchlistMaxGroups,
        (groupIndex) => WatchlistGroup(
          key: 'g$groupIndex',
          name: 'Group $groupIndex',
          items: List<WatchlistItem>.generate(
            5,
            (itemIndex) =>
                WatchlistItem(assetKey: 'ASSET_${groupIndex}_$itemIndex'),
          ),
        ),
      );
      expect(validateWatchlistGroups(boundary), hasLength(20));

      expect(
        () => validateWatchlistGroups(<WatchlistGroup>[
          ...boundary,
          WatchlistGroup(key: 'overflow', name: 'Overflow', items: const []),
        ]),
        throwsA(isA<InvalidWatchlistContractException>()),
      );
      expect(
        () => validateWatchlistGroups(<WatchlistGroup>[
          WatchlistGroup(
            key: 'one',
            name: 'One',
            items: List<WatchlistItem>.generate(
              100,
              (index) => WatchlistItem(assetKey: 'A_$index'),
            ),
          ),
          WatchlistGroup(
            key: 'two',
            name: 'Two',
            items: <WatchlistItem>[WatchlistItem(assetKey: 'EXTRA')],
          ),
        ]),
        throwsA(isA<InvalidWatchlistContractException>()),
      );
      expect(
        () => validateWatchlistGroups(<WatchlistGroup>[
          WatchlistGroup(key: 'same', name: 'A', items: const []),
          WatchlistGroup(key: 'same', name: 'B', items: const []),
        ]),
        throwsA(isA<InvalidWatchlistContractException>()),
      );
      expect(
        () => WatchlistGroup(
          key: 'same',
          name: 'Same',
          items: <WatchlistItem>[
            WatchlistItem(assetKey: 'BTC'),
            WatchlistItem(assetKey: 'BTC'),
          ],
        ),
        throwsA(isA<InvalidWatchlistContractException>()),
      );

      expect(
        validateWatchlistGroups(<WatchlistGroup>[
          WatchlistGroup(
            key: 'one',
            name: 'One',
            items: <WatchlistItem>[WatchlistItem(assetKey: 'BTC')],
          ),
          WatchlistGroup(
            key: 'two',
            name: 'Two',
            items: <WatchlistItem>[WatchlistItem(assetKey: 'BTC')],
          ),
        ]),
        hasLength(2),
      );
    });

    test('enforces version-zero and updated-at invariants', () {
      final empty = WatchlistSnapshot.empty();
      expect(empty.version, 0);
      expect(empty.groups, isEmpty);
      expect(empty.updatedAt, isNull);

      final group = WatchlistGroup(
        key: 'favorites',
        name: 'Favorites',
        items: const [],
      );
      for (final action in <void Function()>[
        () => WatchlistSnapshot(
          version: 0,
          groups: <WatchlistGroup>[group],
          updatedAt: null,
        ),
        () => WatchlistSnapshot(
          version: 0,
          groups: const [],
          updatedAt: DateTime.utc(2026),
        ),
        () => WatchlistSnapshot(version: 1, groups: const [], updatedAt: null),
        () => WatchlistSnapshot(version: -1, groups: const [], updatedAt: null),
        () => WatchlistSnapshot(
          version: watchlistMaximumVersion + 1,
          groups: const [],
          updatedAt: null,
        ),
      ]) {
        expect(action, throwsA(isA<InvalidWatchlistContractException>()));
      }
    });

    test('value equality includes canonical order', () {
      final first = WatchlistGroup(
        key: 'favorites',
        name: 'Favorites',
        items: <WatchlistItem>[
          WatchlistItem(assetKey: 'ETH'),
          WatchlistItem(assetKey: 'BTC'),
        ],
      );
      final same = WatchlistGroup(
        key: 'favorites',
        name: 'Favorites',
        items: <WatchlistItem>[
          WatchlistItem(assetKey: 'ETH'),
          WatchlistItem(assetKey: 'BTC'),
        ],
      );
      final reordered = WatchlistGroup(
        key: 'favorites',
        name: 'Favorites',
        items: <WatchlistItem>[
          WatchlistItem(assetKey: 'BTC'),
          WatchlistItem(assetKey: 'ETH'),
        ],
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(watchlistGroupsEqual(<WatchlistGroup>[first], [same]), isTrue);
      expect(
        watchlistGroupsEqual(<WatchlistGroup>[first], [reordered]),
        isFalse,
      );
    });
  });
}

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();

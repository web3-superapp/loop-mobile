import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';

void main() {
  group('Profile models', () {
    test('normalizes Alias and copies values into an immutable resource', () {
      final source = ProfileValues(
        alias: '  LOOP 昵称 😀  ',
        avatarRef: 'avatar:users/example/profile-1.png',
      );
      final resource = ProfileResource(
        version: 3,
        values: source,
        updatedAt: DateTime.parse('2026-08-25T09:02:03+08:00'),
      );

      expect(resource.values.alias, 'LOOP 昵称 😀');
      expect(resource.values.avatarRef, 'avatar:users/example/profile-1.png');
      expect(resource.values, source);
      expect(identical(resource.values, source), isFalse);
      expect(resource.updatedAt, DateTime.utc(2026, 8, 25, 1, 2, 3));

      final cleared = resource.values.withAlias(null);
      expect(cleared.alias, isNull);
      expect(cleared.avatarRef, source.avatarRef);
      expect(resource.values.alias, 'LOOP 昵称 😀');
    });

    test('counts Alias Unicode code points rather than UTF-16 units', () {
      final accepted = ProfileValues(alias: _repeat('😀', 40), avatarRef: null);

      expect(accepted.alias!.runes.length, 40);
      expect(
        () => ProfileValues(alias: _repeat('😀', 41), avatarRef: null),
        throwsA(isA<InvalidProfileContractException>()),
      );
    });

    test('bounds raw Alias at 256 UTF-16 code units before trimming', () {
      final accepted = ProfileValues(
        alias: '${_repeat(' ', 176)}${_repeat('😀', 40)}',
        avatarRef: null,
      );
      expect(accepted.alias!.runes.length, 40);

      expect(
        () => ProfileValues(
          alias: '${_repeat(' ', 177)}${_repeat('😀', 40)}',
          avatarRef: null,
        ),
        throwsA(isA<InvalidProfileContractException>()),
      );
    });

    test('accepts null Alias but rejects empty and unsafe Alias input', () {
      expect(ProfileValues(alias: null, avatarRef: null).alias, isNull);

      for (final invalidAlias in <String>[
        '',
        '   ',
        'bad\nname',
        'bad\u0085name',
        'safe\u061cevil',
        'safe\u200eevil',
        'safe\u200fevil',
        'safe\u202aevi',
        'safe\u202bevi',
        'safe\u202cevi',
        'safe\u202devi',
        'safe\u202eevi',
        'safe\u2066evi',
        'safe\u2067evi',
        'safe\u2068evi',
        'safe\u2069evi',
        String.fromCharCode(0xD800),
        String.fromCharCode(0xDC00),
      ]) {
        Object? failure;
        try {
          ProfileValues(alias: invalidAlias, avatarRef: null);
        } catch (error) {
          failure = error;
        }
        expect(failure, isA<InvalidProfileContractException>());
        expect(failure.toString(), 'The Profile contract value is invalid');
      }
    });

    test('keeps allowed Unicode without additional normalization', () {
      const decomposed = 'e\u0301';
      final value = ProfileValues(
        alias: '  $decomposed 👩‍💻  ',
        avatarRef: null,
      );

      expect(value.alias, '$decomposed 👩‍💻');
    });

    test('enforces opaque Avatar reference syntax and boundaries', () {
      expect(
        ProfileValues(alias: null, avatarRef: 'avatar:a').avatarRef,
        'avatar:a',
      );
      final maximum = 'avatar:a${_repeat('b', 126)}';
      expect(
        ProfileValues(alias: null, avatarRef: maximum).avatarRef!.length,
        134,
      );
      expect(
        ProfileValues(alias: null, avatarRef: 'avatar:a/../b').avatarRef,
        'avatar:a/../b',
      );

      for (final invalidReference in <String>[
        'https://cdn.example/avatar.png',
        'data:image/png;base64,secret',
        'avatar:',
        'avatar:/leading-slash',
        'avatar:.leading-dot',
        'avatar:_leading-underscore',
        'avatar:-leading-hyphen',
        'avatar:user?signature=secret',
        'avatar:user#fragment',
        r'avatar:user\file',
        'avatar:用户',
        'Avatar:user',
        'avatar:${_repeat('a', 128)}',
      ]) {
        expect(
          () => ProfileValues(alias: null, avatarRef: invalidReference),
          throwsA(isA<InvalidProfileContractException>()),
        );
      }
    });

    test('enforces the resource version and timestamp biconditional', () {
      final empty = ProfileResource.empty();
      expect(empty.version, 0);
      expect(empty.values, ProfileValues.empty());
      expect(empty.updatedAt, isNull);

      // The wire contract ties version zero to its timestamp, not to values.
      expect(
        ProfileResource(
          version: 0,
          values: ProfileValues(alias: 'Alias', avatarRef: null),
          updatedAt: null,
        ).values.alias,
        'Alias',
      );

      for (final action in <void Function()>[
        () => ProfileResource(
          version: 0,
          values: ProfileValues.empty(),
          updatedAt: DateTime.utc(2026),
        ),
        () => ProfileResource(
          version: 1,
          values: ProfileValues.empty(),
          updatedAt: null,
        ),
        () => ProfileResource(
          version: -1,
          values: ProfileValues.empty(),
          updatedAt: null,
        ),
        () => ProfileResource(
          version: profileMaximumVersion + 1,
          values: ProfileValues.empty(),
          updatedAt: DateTime.utc(2026),
        ),
      ]) {
        expect(action, throwsA(isA<InvalidProfileContractException>()));
      }
    });

    test('has value equality across values and resources', () {
      final first = ProfileValues(
        alias: 'Alice',
        avatarRef: 'avatar:alice/main',
      );
      final same = ProfileValues(
        alias: 'Alice',
        avatarRef: 'avatar:alice/main',
      );
      final different = ProfileValues(
        alias: 'Alice',
        avatarRef: 'avatar:alice/other',
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(different));

      final resource = ProfileResource(
        version: 1,
        values: first,
        updatedAt: DateTime.utc(2026, 8, 25),
      );
      final copied = ProfileResource.copyOf(resource);
      expect(copied, resource);
      expect(copied.hashCode, resource.hashCode);
      expect(identical(copied, resource), isFalse);
    });
  });
}

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();

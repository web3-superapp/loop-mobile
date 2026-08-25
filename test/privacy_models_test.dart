import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';

void main() {
  group('Privacy models', () {
    test('uses the exact fail-closed backend defaults', () {
      const values = PrivacyValues.defaults();
      final resource = PrivacyResource.empty();

      expect(values.discoverable, isFalse);
      expect(values.copyTradeVisibility, CopyTradeVisibility.private);
      expect(resource.version, 0);
      expect(resource.values, values);
      expect(resource.updatedAt, isNull);
    });

    test('round-trips only the reviewed copy-trade visibility values', () {
      const exactWireValues = <CopyTradeVisibility, String>{
        CopyTradeVisibility.private: 'private',
        CopyTradeVisibility.followers: 'followers',
        CopyTradeVisibility.public: 'public',
      };
      for (final entry in exactWireValues.entries) {
        expect(entry.key.wireValue, entry.value);
        expect(CopyTradeVisibility.fromWire(entry.value), entry.key);
      }

      for (final invalid in <String>[
        '',
        'Private',
        'friends',
        'approved',
        'followers ',
      ]) {
        expect(
          () => CopyTradeVisibility.fromWire(invalid),
          throwsA(isA<InvalidPrivacyContractException>()),
        );
      }
    });

    test('edits only discoverability and copy-trade visibility', () {
      const defaults = PrivacyValues.defaults();
      final discoverable = defaults.withDiscoverable(true);
      final public = discoverable.withCopyTradeVisibility(
        CopyTradeVisibility.public,
      );

      expect(discoverable.discoverable, isTrue);
      expect(discoverable.copyTradeVisibility, CopyTradeVisibility.private);
      expect(public.discoverable, isTrue);
      expect(public.copyTradeVisibility, CopyTradeVisibility.public);
      expect(defaults, const PrivacyValues.defaults());
    });

    test('normalizes resource timestamps to UTC and copies values', () {
      const source = PrivacyValues(
        discoverable: true,
        copyTradeVisibility: CopyTradeVisibility.followers,
      );
      final resource = PrivacyResource(
        version: 3,
        values: source,
        updatedAt: DateTime.parse('2026-08-25T09:02:03+08:00'),
      );

      expect(resource.values, source);
      expect(identical(resource.values, source), isFalse);
      expect(resource.updatedAt, DateTime.utc(2026, 8, 25, 1, 2, 3));
    });

    test('enforces the version and timestamp biconditional', () {
      // Version zero is tied to the timestamp, not to default values.
      expect(
        PrivacyResource(
          version: 0,
          values: const PrivacyValues(
            discoverable: true,
            copyTradeVisibility: CopyTradeVisibility.public,
          ),
          updatedAt: null,
        ).values.discoverable,
        isTrue,
      );

      for (final action in <void Function()>[
        () => PrivacyResource(
          version: 0,
          values: const PrivacyValues.defaults(),
          updatedAt: DateTime.utc(2026),
        ),
        () => PrivacyResource(
          version: 1,
          values: const PrivacyValues.defaults(),
          updatedAt: null,
        ),
        () => PrivacyResource(
          version: -1,
          values: const PrivacyValues.defaults(),
          updatedAt: null,
        ),
        () => PrivacyResource(
          version: privacyMaximumVersion + 1,
          values: const PrivacyValues.defaults(),
          updatedAt: DateTime.utc(2026),
        ),
      ]) {
        expect(action, throwsA(isA<InvalidPrivacyContractException>()));
      }

      expect(
        PrivacyResource(
          version: privacyMaximumVersion,
          values: const PrivacyValues.defaults(),
          updatedAt: DateTime.utc(2026),
        ).version,
        privacyMaximumVersion,
      );
    });

    test('has defensive value equality across values and resources', () {
      const first = PrivacyValues(
        discoverable: true,
        copyTradeVisibility: CopyTradeVisibility.followers,
      );
      const same = PrivacyValues(
        discoverable: true,
        copyTradeVisibility: CopyTradeVisibility.followers,
      );
      const different = PrivacyValues(
        discoverable: true,
        copyTradeVisibility: CopyTradeVisibility.public,
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(different));

      final resource = PrivacyResource(
        version: 1,
        values: first,
        updatedAt: DateTime.utc(2026, 8, 25),
      );
      final copied = PrivacyResource.copyOf(resource);
      expect(copied, resource);
      expect(copied.hashCode, resource.hashCode);
      expect(identical(copied, resource), isFalse);
      expect(identical(copied.values, resource.values), isFalse);
    });

    test('keeps contract failures sanitized', () {
      const failure = InvalidPrivacyContractException();

      expect(failure.code, 'invalid_privacy_contract');
      expect(failure.toString(), 'The Privacy contract value is invalid');
      expect(failure.toString(), isNot(contains('followers')));
    });
  });
}

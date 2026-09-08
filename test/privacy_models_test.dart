import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';

void main() {
  group('Privacy models', () {
    test('uses the exact fail-closed backend defaults', () {
      const values = PrivacyValues.defaults();
      final resource = PrivacyResource.empty();

      expect(values.discoverable, isFalse);
      expect(values.anonymousMode, isFalse);
      for (final facet in PrivacyVisibilityFacet.values) {
        expect(values.visibility[facet], PrivacyAudience.self);
      }
      expect(values.visibility, const PrivacyVisibility.defaults());
      expect(PrivacyVisibility(), const PrivacyVisibility.defaults());
      expect(resource.version, 0);
      expect(resource.values, values);
      expect(resource.updatedAt, isNull);
    });

    test('round-trips only the reviewed audience values', () {
      const exactWireValues = <PrivacyAudience, String>{
        PrivacyAudience.self: 'self',
        PrivacyAudience.everyone: 'everyone',
      };
      expect(exactWireValues.length, PrivacyAudience.values.length);
      for (final entry in exactWireValues.entries) {
        expect(entry.key.wireValue, entry.value);
        expect(PrivacyAudience.fromWire(entry.value), entry.key);
      }

      for (final invalid in <String>[
        '',
        'Self',
        'friends',
        'followers',
        'public',
        'everyone ',
      ]) {
        expect(
          () => PrivacyAudience.fromWire(invalid),
          throwsA(isA<InvalidPrivacyContractException>()),
        );
      }
    });

    test('exposes exactly the four reviewed visibility facets', () {
      const exactWireValues = <PrivacyVisibilityFacet, String>{
        PrivacyVisibilityFacet.totalAssets: 'totalAssets',
        PrivacyVisibilityFacet.miningPower: 'miningPower',
        PrivacyVisibilityFacet.communities: 'communities',
        PrivacyVisibilityFacet.tradeHistory: 'tradeHistory',
      };
      expect(exactWireValues.length, PrivacyVisibilityFacet.values.length);
      for (final entry in exactWireValues.entries) {
        expect(entry.key.wireValue, entry.value);
        expect(entry.key.label, isNotEmpty);
      }

      // Copy-trade visibility is retired; no facet may reintroduce it.
      for (final facet in PrivacyVisibilityFacet.values) {
        expect(facet.wireValue.toLowerCase(), isNot(contains('copy')));
        expect(facet.name.toLowerCase(), isNot(contains('copy')));
      }
    });

    test('edits discoverability, anonymous mode, and one facet at a time', () {
      const defaults = PrivacyValues.defaults();
      final discoverable = defaults.withDiscoverable(true);
      final anonymous = discoverable.withAnonymousMode(true);
      final shared = anonymous.withFacet(
        PrivacyVisibilityFacet.totalAssets,
        PrivacyAudience.everyone,
      );

      expect(discoverable.discoverable, isTrue);
      expect(discoverable.anonymousMode, isFalse);
      expect(anonymous.discoverable, isTrue);
      expect(anonymous.anonymousMode, isTrue);
      expect(
        anonymous.visibility[PrivacyVisibilityFacet.totalAssets],
        PrivacyAudience.self,
      );
      expect(
        shared.visibility[PrivacyVisibilityFacet.totalAssets],
        PrivacyAudience.everyone,
      );
      for (final facet in PrivacyVisibilityFacet.values) {
        if (facet == PrivacyVisibilityFacet.totalAssets) continue;
        expect(shared.visibility[facet], PrivacyAudience.self);
      }

      // Every edit returns a new value; no source is mutated in place.
      expect(defaults, const PrivacyValues.defaults());
      expect(anonymous.visibility, const PrivacyVisibility.defaults());
      expect(
        shared.withVisibility(const PrivacyVisibility.defaults()).visibility,
        const PrivacyVisibility.defaults(),
      );
    });

    test('normalizes resource timestamps to UTC and copies values', () {
      final source = PrivacyValues(
        discoverable: true,
        anonymousMode: true,
        visibility: PrivacyVisibility(tradeHistory: PrivacyAudience.everyone),
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
          values: PrivacyValues(
            discoverable: true,
            anonymousMode: true,
            visibility: PrivacyVisibility(
              communities: PrivacyAudience.everyone,
            ),
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
      final first = PrivacyValues(
        discoverable: true,
        anonymousMode: true,
        visibility: PrivacyVisibility(miningPower: PrivacyAudience.everyone),
      );
      final same = PrivacyValues(
        discoverable: true,
        anonymousMode: true,
        visibility: PrivacyVisibility(miningPower: PrivacyAudience.everyone),
      );
      final differentFacet = PrivacyValues(
        discoverable: true,
        anonymousMode: true,
        visibility: PrivacyVisibility(communities: PrivacyAudience.everyone),
      );
      final differentFlag = PrivacyValues(
        discoverable: true,
        anonymousMode: false,
        visibility: PrivacyVisibility(miningPower: PrivacyAudience.everyone),
      );

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(differentFacet));
      expect(first, isNot(differentFlag));

      final copiedValues = PrivacyValues.copyOf(first);
      expect(copiedValues, first);
      expect(identical(copiedValues, first), isFalse);

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
      expect(failure.toString(), isNot(contains('everyone')));
    });
  });
}

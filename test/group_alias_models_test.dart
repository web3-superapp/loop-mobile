import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';

const _groupId = 'e464386d-cd85-472d-9b22-2d94412ad413';
const _aliasId = 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e';
const _secondAliasId = 'a36c5221-ea25-4577-89e8-825b376fd12d';

void main() {
  group('Group Alias identifiers', () {
    test('accept canonical backend UUIDs with defensive equality', () {
      final groupId = GroupId.fromWire(_groupId);
      final aliasId = GroupAliasId.fromWire(_aliasId);

      expect(groupId.wireValue, _groupId);
      expect(GroupId.copyOf(groupId), groupId);
      expect(GroupId.copyOf(groupId).hashCode, groupId.hashCode);
      expect(aliasId.wireValue, _aliasId);
      expect(GroupAliasId.copyOf(aliasId), aliasId);
      expect(GroupAliasId.copyOf(aliasId).hashCode, aliasId.hashCode);
    });

    test('rejects non-canonical IDs and every Stream/direct identifier', () {
      for (final value in <String>[
        '',
        _groupId.toUpperCase(),
        'messaging:loop_group_e464386dcd85472d9b222d94412ad413',
        'loop_direct_e464386dcd85472d9b222d94412ad413',
        '00000000-0000-0000-0000-000000000000',
        'e464386d-cd85-072d-9b22-2d94412ad413',
        'e464386d-cd85-472d-7b22-2d94412ad413',
        ' $_groupId',
      ]) {
        expect(
          () => GroupId.fromWire(value),
          throwsA(isA<InvalidGroupAliasContractException>()),
          reason: value,
        );
      }
    });
  });

  group('Group Alias text validation', () {
    test('trims Alias and counts Unicode code points', () {
      expect(normalizeGroupAlias('  Night Owl  '), 'Night Owl');
      expect(normalizeGroupAlias('${_repeat('😀', 40)}  '), _repeat('😀', 40));
      expect(
        () => normalizeGroupAlias(_repeat('😀', 41)),
        throwsA(isA<InvalidGroupAliasContractException>()),
      );
      expect(
        () => normalizeGroupAlias(_repeat(' ', 257)),
        throwsA(isA<InvalidGroupAliasContractException>()),
      );
    });

    test('rejects control, format, separator, and surrogate values', () {
      final invalidValues = <String>[
        'Night\u0000Owl',
        'Night\u00ADOwl',
        'Night\u061COwl',
        'Night\u200BOwl',
        'Night\u2028Owl',
        'Night\u2066Owl',
        'Night\uFEFFOwl',
        'Night${String.fromCharCode(0xD800)}Owl',
        'Night${String.fromCharCode(0xDC00)}Owl',
      ];
      for (final value in invalidValues) {
        expect(
          () => normalizeGroupAlias(value),
          throwsA(isA<InvalidGroupAliasContractException>()),
        );
      }
    });

    test('requires a 2-40 code-point search prefix and a 1-20 limit', () {
      expect(normalizeGroupAliasSearchPrefix('  Ni  '), 'Ni');
      final foldedSpacePrefix = 'N${_repeat(' ', 40)}i';
      expect(
        normalizeGroupAliasSearchPrefix(foldedSpacePrefix),
        foldedSpacePrefix,
      );
      expect(validateGroupAliasSearchLimit(1), 1);
      expect(validateGroupAliasSearchLimit(20), 20);

      for (final value in <String>['', 'N', _repeat('N', 41), 'N\u200BO']) {
        expect(
          () => normalizeGroupAliasSearchPrefix(value),
          throwsA(isA<InvalidGroupAliasContractException>()),
        );
      }
      for (final limit in <int>[0, 21]) {
        expect(
          () => validateGroupAliasSearchLimit(limit),
          throwsA(isA<InvalidGroupAliasContractException>()),
        );
      }
    });
  });

  group('Group Alias resources', () {
    test('copies immutable current-Alias projection values', () {
      final resource = GroupAliasResource(
        groupAliasId: GroupAliasId.fromWire(_aliasId),
        alias: '  Night Owl ',
        projectionState: GroupAliasProjectionState.pending,
      );
      final copied = GroupAliasResource.copyOf(resource);

      expect(resource.alias, 'Night Owl');
      expect(resource.requiresProjectionRetry, isTrue);
      expect(copied, resource);
      expect(copied.hashCode, resource.hashCode);
      expect(identical(copied, resource), isFalse);
      expect(identical(copied.groupAliasId, resource.groupAliasId), isFalse);
    });

    test('defensively copies a bounded, cursor-free search page', () {
      final mutable = <GroupAliasSearchItem>[
        GroupAliasSearchItem(
          groupAliasId: GroupAliasId.fromWire(_aliasId),
          alias: 'Night Owl',
        ),
      ];
      final page = GroupAliasSearchPage(items: mutable, truncated: true);
      mutable.add(
        GroupAliasSearchItem(
          groupAliasId: GroupAliasId.fromWire(_secondAliasId),
          alias: 'Nina',
        ),
      );
      final copied = GroupAliasSearchPage.copyOf(page);

      expect(page.items, hasLength(1));
      expect(() => page.items.clear(), throwsUnsupportedError);
      expect(copied, page);
      expect(copied.hashCode, page.hashCode);
      expect(identical(copied, page), isFalse);
      expect(identical(copied.items.single, page.items.single), isFalse);
      expect(page.truncated, isTrue);
    });

    test('rejects duplicate IDs, duplicate Aliases, and oversized pages', () {
      GroupAliasSearchItem item(String id, String alias) =>
          GroupAliasSearchItem(
            groupAliasId: GroupAliasId.fromWire(id),
            alias: alias,
          );

      expect(
        () => GroupAliasSearchPage(
          items: <GroupAliasSearchItem>[
            item(_aliasId, 'Night Owl'),
            item(_aliasId, 'Nina'),
          ],
          truncated: false,
        ),
        throwsA(isA<InvalidGroupAliasContractException>()),
      );
      expect(
        () => GroupAliasSearchPage(
          items: <GroupAliasSearchItem>[
            item(_aliasId, 'Night Owl'),
            item(_secondAliasId, 'Night Owl'),
          ],
          truncated: false,
        ),
        throwsA(isA<InvalidGroupAliasContractException>()),
      );

      final tooMany = List<GroupAliasSearchItem>.generate(21, (index) {
        final suffix = index.toRadixString(16).padLeft(12, '0');
        return item('00000000-0000-4000-8000-$suffix', 'Alias $index');
      });
      expect(
        () => GroupAliasSearchPage(items: tooMany, truncated: true),
        throwsA(isA<InvalidGroupAliasContractException>()),
      );
    });

    test('keeps contract failures sanitized', () {
      const failure = InvalidGroupAliasContractException();

      expect(failure.code, 'invalid_group_alias_contract');
      expect(failure.toString(), 'The group Alias contract value is invalid');
      expect(failure.toString(), isNot(contains('Night Owl')));
    });
  });
}

String _repeat(String value, int count) =>
    List<String>.filled(count, value).join();

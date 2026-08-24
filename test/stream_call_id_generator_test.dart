import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/stream_call_id_generator.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('every outgoing call receives a fresh RFC 4122 UUID v4', () {
    const generator = UuidStreamCallIdGenerator();

    final first = generator.next();
    final second = generator.next();

    expect(first, isNot(second));
    expect(Uuid.isValidUUID(fromString: first), isTrue);
    expect(Uuid.isValidUUID(fromString: second), isTrue);
    expect(first.split('-').first.length, 8);
    expect(first[14], '4');
  });
}

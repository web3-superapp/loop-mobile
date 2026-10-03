import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/social/social_qr.dart';

void main() {
  test('exact LOOP IDs and community locators route to reviewed discovery', () {
    expect(socialQrLocation('LOOP-12345678'), '/search?q=LOOP-12345678');
    expect(
      socialQrLocation(communityQrPayload('community-1')),
      '/community/profile?id=community-1',
    );
    expect(
      socialQrLocation(
        'https://api.loop.test/u/LOOP-12345678',
        trustedBaseUrl: 'https://api.loop.test',
      ),
      '/search?q=LOOP-12345678',
    );
    expect(
      socialQrLocation(
        'https://api.loop.test/c/community-1',
        trustedBaseUrl: 'https://api.loop.test',
      ),
      '/community/profile?id=community-1',
    );
  });
  test(
    'untrusted, malformed, payment and private channel payloads never navigate',
    () {
      for (final input in [
        'https://evil.test/u/LOOP-12345678',
        'https://api.loop.test:444/u/LOOP-12345678',
        'https://user@api.loop.test/u/LOOP-12345678',
        'https://api.loop.test/u/%ZZ',
        'loop://community/../../auth',
        'loop://community/a?join=true',
        'loop://community/a#evil',
        'messaging:loop_direct_secret',
        'ethereum:0x1234',
        'javascript:alert(1)',
        'Please add LOOP-12345678 now',
      ]) {
        expect(
          socialQrLocation(input, trustedBaseUrl: 'https://api.loop.test'),
          isNull,
          reason: input,
        );
      }
      expect(socialQrLocation('https://api.loop.test/u/LOOP-12345678'), isNull);
      expect(socialQrLocation('x' * 513), isNull);
    },
  );
}

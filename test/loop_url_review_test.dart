import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/security/loop_url_review.dart';

/// `dapp` · the offline URL review (D21).
void main() {
  test('a bare host is normalised to an exact HTTPS origin', () {
    final review = LoopUrlReview.review('  app.example.org  ');

    expect(review.verdict, LoopUrlVerdict.normalized);
    expect(review.host, 'app.example.org');
    expect(review.canonical.toString(), 'https://app.example.org/');
    expect(review.findings, <LoopUrlFinding>[LoopUrlFinding.schemeAssumed]);
  });

  test('the path and query survive, the fragment does not', () {
    final review = LoopUrlReview.review(
      'https://app.example.org/swap?chain=56#anchor',
    );

    expect(review.verdict, LoopUrlVerdict.normalized);
    expect(
      review.canonical.toString(),
      'https://app.example.org/swap?chain=56',
    );
  });

  test('a non-HTTPS scheme is blocked and produces no destination', () {
    for (final input in <String>[
      'http://app.example.org',
      'ftp://app.example.org',
      'javascript:alert(1)',
      'wc://connect',
    ]) {
      final review = LoopUrlReview.review(input);
      expect(review.verdict, LoopUrlVerdict.blocked, reason: input);
      expect(review.canonical, isNull, reason: input);
      expect(review.findings, contains(LoopUrlFinding.notHttps), reason: input);
    }
  });

  test('a Cyrillic homograph is blocked and its Latin reading is named', () {
    // The first character is Cyrillic а (U+0430), not Latin a.
    final review = LoopUrlReview.review('https://аpple.com');

    expect(review.verdict, LoopUrlVerdict.blocked);
    expect(review.findings, contains(LoopUrlFinding.confusableCharacters));
    expect(review.confusableReading, 'apple.com');
    expect(review.canonical, isNull);
  });

  test('a Latin label mixed with another script is blocked', () {
    // `p` is Latin, `а` and `у` are Cyrillic.
    final review = LoopUrlReview.review('https://pауpal.com');

    expect(review.verdict, LoopUrlVerdict.blocked);
    expect(review.findings, contains(LoopUrlFinding.mixedScriptLabel));
  });

  test('a single-script non-Latin host is flagged, not silently accepted', () {
    final review = LoopUrlReview.review('https://中文.com');

    expect(review.verdict, LoopUrlVerdict.flagged);
    expect(review.findings, contains(LoopUrlFinding.nonAsciiHost));
    expect(review.confusableReading, isNull);
  });

  test('an already-encoded IDN label is flagged as unreadable', () {
    final review = LoopUrlReview.review('https://xn--80ak6aa92e.com');

    expect(review.verdict, LoopUrlVerdict.flagged);
    expect(review.findings, contains(LoopUrlFinding.punycodeLabel));
  });

  test('credentials, whitespace and a missing host are blocked', () {
    expect(
      LoopUrlReview.review('https://user:secret@app.example.org').findings,
      contains(LoopUrlFinding.credentialsInUrl),
    );
    expect(
      LoopUrlReview.review('https://app.exam ple.org').findings,
      contains(LoopUrlFinding.unsafeCharacters),
    );
    expect(
      LoopUrlReview.review('https://localhost').findings,
      contains(LoopUrlFinding.missingHost),
    );
    expect(LoopUrlReview.review('').verdict, LoopUrlVerdict.blocked);
  });

  test('an IP literal and a non-standard port are flagged', () {
    final ip = LoopUrlReview.review('https://192.168.0.1/');
    expect(ip.findings, contains(LoopUrlFinding.ipLiteralHost));
    expect(ip.verdict, LoopUrlVerdict.flagged);

    final port = LoopUrlReview.review('https://app.example.org:8443/');
    expect(port.findings, contains(LoopUrlFinding.nonStandardPort));
    expect(port.canonical.toString(), 'https://app.example.org:8443/');
  });

  test('the review never resolves a redirect: the host is the typed host', () {
    // A shortener is reviewed as itself. Nothing is fetched, so the address can
    // never be replaced by a redirect target.
    final review = LoopUrlReview.review('https://t.co/abcd1234');

    expect(LoopUrlReview.followsRedirects, isFalse);
    expect(review.host, 't.co');
    expect(review.canonical.toString(), 'https://t.co/abcd1234');
  });

  test('an uppercase scheme and host are normalised, not rejected', () {
    final review = LoopUrlReview.review('HTTPS://APP.Example.ORG/Swap');

    expect(review.verdict, LoopUrlVerdict.normalized);
    expect(review.host, 'app.example.org');
    // The path keeps its case: only the scheme and host are case-insensitive.
    expect(review.canonical.toString(), 'https://app.example.org/Swap');
  });

  test('an IPv6 literal is flagged as an address, not a domain', () {
    final review = LoopUrlReview.review('https://[2001:db8::1]/');

    expect(review.findings, contains(LoopUrlFinding.ipLiteralHost));
    expect(review.verdict, LoopUrlVerdict.flagged);
    expect(review.confusableReading, isNull);
  });

  test('fullwidth Latin characters are blocked as confusables', () {
    // `ｅ` is U+FF45, not the ASCII `e`.
    final review = LoopUrlReview.review('https://ｅxample.com');

    expect(review.verdict, LoopUrlVerdict.blocked);
    expect(review.findings, contains(LoopUrlFinding.confusableCharacters));
    expect(review.confusableReading, 'example.com');
    expect(review.canonical, isNull);
  });

  test('every blocking finding refuses a canonical address', () {
    for (final finding in LoopUrlFinding.values.where((f) => f.isBlocking)) {
      expect(finding.explanation, isNotEmpty, reason: finding.name);
    }
    expect(
      LoopUrlFinding.schemeAssumed.isBlocking,
      isFalse,
      reason: 'assuming https must not by itself block an address',
    );
  });
}

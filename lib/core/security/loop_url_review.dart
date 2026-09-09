import 'package:flutter/foundation.dart';

/// Local, offline review of a URL typed into the DApp surface (D21).
///
/// It is a **pure function**: nothing here opens a socket, resolves DNS or
/// fetches the address, so a redirect can never be followed and the reviewed
/// host is always exactly the host that was typed. The verdict never grants
/// permission — connecting and signing stay unavailable regardless.
enum LoopUrlFinding {
  /// Nothing was typed.
  empty('输入为空'),

  /// Control, bidirectional or separator code points inside the input.
  unsafeCharacters('输入里含有控制字符或不可见字符'),

  /// No scheme was typed, so `https` was assumed. Not blocking on its own.
  schemeAssumed('没有写协议，已按 HTTPS 解析'),

  /// A scheme other than `https`.
  notHttps('只允许 HTTPS，明文或自定义协议一律阻止'),

  /// The address has no host at all.
  missingHost('地址里没有域名'),

  /// `user:password@host` — a classic phishing disguise.
  credentialsInUrl('地址里带有用户名或密码，这是常见的伪装手法'),

  /// A raw IPv4/IPv6 literal instead of a domain name.
  ipLiteralHost('地址是 IP，不是域名，无法核对归属'),

  /// A port other than 443.
  nonStandardPort('使用了非 443 端口'),

  /// An already-encoded IDN label. The Unicode form cannot be recovered here.
  punycodeLabel('域名含有 IDN 编码（xn--）标签，无法在本地还原成可读形式'),

  /// A label mixing Latin with another script — the classic homograph shape.
  mixedScriptLabel('域名的同一段里混用了拉丁字母与其他文字'),

  /// A code point that looks like an ASCII letter but is not one.
  confusableCharacters('域名里含有与拉丁字母同形的字符'),

  /// A non-ASCII host with no confusables. The ASCII (punycode) form cannot be
  /// computed on device, so the two forms cannot be compared.
  nonAsciiHost('域名含有非 ASCII 字符，本地无法计算它的 ASCII 形式');

  const LoopUrlFinding(this.explanation);

  final String explanation;

  /// Whether this finding alone makes the address unusable.
  bool get isBlocking => switch (this) {
    LoopUrlFinding.empty ||
    LoopUrlFinding.unsafeCharacters ||
    LoopUrlFinding.notHttps ||
    LoopUrlFinding.missingHost ||
    LoopUrlFinding.credentialsInUrl ||
    LoopUrlFinding.mixedScriptLabel ||
    LoopUrlFinding.confusableCharacters => true,
    LoopUrlFinding.schemeAssumed ||
    LoopUrlFinding.ipLiteralHost ||
    LoopUrlFinding.nonStandardPort ||
    LoopUrlFinding.punycodeLabel ||
    LoopUrlFinding.nonAsciiHost => false,
  };
}

enum LoopUrlVerdict {
  /// A canonical HTTPS address with no findings that need attention.
  normalized,

  /// Readable, but something about it must be pointed out before trusting it.
  flagged,

  /// Unusable. The address is not shown as a destination.
  blocked,
}

@immutable
final class LoopUrlReview {
  LoopUrlReview._({
    required this.input,
    required this.canonical,
    required this.host,
    required List<LoopUrlFinding> findings,
  }) : findings = List<LoopUrlFinding>.unmodifiable(findings);

  /// This review never performs a network request, so a redirect is never
  /// followed and the reviewed host is always the typed host.
  static const followsRedirects = false;

  static const maximumInputLength = 2048;

  /// Exactly what the user typed, trimmed.
  final String input;

  /// The canonical `https` URI, or `null` when the input is blocked.
  final Uri? canonical;

  /// The lower-cased host, or `null` when the input is blocked.
  final String? host;

  final List<LoopUrlFinding> findings;

  LoopUrlVerdict get verdict {
    if (canonical == null || findings.any((f) => f.isBlocking)) {
      return LoopUrlVerdict.blocked;
    }
    return findings.where((f) => f != LoopUrlFinding.schemeAssumed).isEmpty
        ? LoopUrlVerdict.normalized
        : LoopUrlVerdict.flagged;
  }

  bool get isBlocked => verdict == LoopUrlVerdict.blocked;

  /// The registrable-looking tail, purely for display next to the full host.
  String? get displayOrigin => canonical?.origin;

  static final RegExp _unsafe = RegExp(
    r'[\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}\s]',
    unicode: true,
  );
  static final RegExp _scheme = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:');
  static final RegExp _ipv4 = RegExp(r'^[0-9]{1,3}(\.[0-9]{1,3}){3}$');
  static final RegExp _latin = RegExp(r'[a-z]');

  /// Lower-case code points that render like an ASCII letter but are not one.
  /// The map is deliberately small and explicit; an unknown non-ASCII letter
  /// is reported as [LoopUrlFinding.nonAsciiHost] rather than guessed at.
  static const confusables = <String, String>{
    // Cyrillic
    'а': 'a', 'в': 'b', 'е': 'e', 'к': 'k', 'м': 'm', 'н': 'h', 'о': 'o',
    'р': 'p', 'с': 'c', 'т': 't', 'у': 'y', 'х': 'x', 'ѕ': 's', 'і': 'i',
    'ј': 'j', 'ԁ': 'd', 'һ': 'h', 'ӏ': 'l', 'ԛ': 'q', 'ԝ': 'w',
    // Greek
    'α': 'a', 'β': 'b', 'ε': 'e', 'ι': 'i', 'κ': 'k', 'ν': 'v', 'ο': 'o',
    'ρ': 'p', 'τ': 't', 'υ': 'u', 'χ': 'x', 'ѵ': 'v',
    // Armenian / Cherokee lookalikes
    'ո': 'n', 'օ': 'o', 'ա': 'w', 'Ꭰ': 'd', 'Ꭱ': 'r', 'Ꮪ': 's',
    // Fullwidth Latin
    'ａ': 'a', 'ｅ': 'e', 'ｉ': 'i', 'ｏ': 'o', 'ｐ': 'p', 'ｕ': 'u',
  };

  /// Reviews [raw] without touching the network.
  static LoopUrlReview review(String raw) {
    final input = raw.trim();
    final findings = <LoopUrlFinding>[];
    if (input.isEmpty || input.length > maximumInputLength) {
      return LoopUrlReview._(
        input: input,
        canonical: null,
        host: null,
        findings: <LoopUrlFinding>[LoopUrlFinding.empty],
      );
    }
    if (_unsafe.hasMatch(input)) {
      return LoopUrlReview._(
        input: input,
        canonical: null,
        host: null,
        findings: <LoopUrlFinding>[LoopUrlFinding.unsafeCharacters],
      );
    }

    var candidate = input;
    if (!_scheme.hasMatch(candidate)) {
      candidate = 'https://$candidate';
      findings.add(LoopUrlFinding.schemeAssumed);
    }

    final Uri parsed;
    try {
      parsed = Uri.parse(candidate);
    } on FormatException {
      return LoopUrlReview._(
        input: input,
        canonical: null,
        host: null,
        findings: <LoopUrlFinding>[LoopUrlFinding.missingHost],
      );
    }

    if (parsed.scheme.toLowerCase() != 'https') {
      findings.add(LoopUrlFinding.notHttps);
      return LoopUrlReview._(
        input: input,
        canonical: null,
        host: null,
        findings: findings,
      );
    }
    if (parsed.userInfo.isNotEmpty) {
      findings.add(LoopUrlFinding.credentialsInUrl);
    }
    // Dart percent-encodes a non-ASCII host, so the readable form is recovered
    // before it is inspected: the homograph must be seen, not hidden behind
    // `%D0%B0`. A malformed escape is an unusable address, not a warning.
    String host;
    try {
      host = Uri.decodeComponent(parsed.host).toLowerCase();
    } on FormatException {
      findings.add(LoopUrlFinding.unsafeCharacters);
      return LoopUrlReview._(
        input: input,
        canonical: null,
        host: null,
        findings: findings,
      );
    }
    if (_unsafe.hasMatch(host)) {
      findings.add(LoopUrlFinding.unsafeCharacters);
      return LoopUrlReview._(
        input: input,
        canonical: null,
        host: null,
        findings: findings,
      );
    }
    if (host.isEmpty || !host.contains('.')) {
      findings.add(LoopUrlFinding.missingHost);
      return LoopUrlReview._(
        input: input,
        canonical: null,
        host: null,
        findings: findings,
      );
    }
    if (_ipv4.hasMatch(host) || host.contains(':')) {
      findings.add(LoopUrlFinding.ipLiteralHost);
    }
    if (parsed.hasPort && parsed.port != 443) {
      findings.add(LoopUrlFinding.nonStandardPort);
    }
    findings.addAll(_hostFindings(host));

    if (findings.any((f) => f.isBlocking)) {
      return LoopUrlReview._(
        input: input,
        canonical: null,
        host: host,
        findings: findings,
      );
    }

    // The canonical form drops the fragment and any default port. The path and
    // query are kept verbatim: rewriting them would change what is reviewed.
    final canonical = Uri(
      scheme: 'https',
      host: host,
      port: parsed.hasPort && parsed.port != 443 ? parsed.port : null,
      path: parsed.path.isEmpty ? '/' : parsed.path,
      query: parsed.query.isEmpty ? null : parsed.query,
    );
    return LoopUrlReview._(
      input: input,
      canonical: canonical,
      host: host,
      findings: findings,
    );
  }

  /// The ASCII letters a confusable host would be read as, e.g. `аpple.com`
  /// (Cyrillic а) reads as `apple.com`. `null` when nothing is confusable.
  String? get confusableReading {
    final source = host;
    if (source == null ||
        !findings.contains(LoopUrlFinding.confusableCharacters)) {
      return null;
    }
    final buffer = StringBuffer();
    for (final rune in source.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(confusables[character] ?? character);
    }
    return buffer.toString();
  }

  static List<LoopUrlFinding> _hostFindings(String host) {
    final findings = <LoopUrlFinding>[];
    var sawConfusable = false;
    var sawMixedScript = false;
    var sawPunycode = false;
    var sawNonAscii = false;
    for (final label in host.split('.')) {
      if (label.startsWith('xn--')) {
        sawPunycode = true;
        continue;
      }
      var hasLatin = false;
      var hasOtherScript = false;
      for (final rune in label.runes) {
        final character = String.fromCharCode(rune);
        if (rune < 0x80) {
          if (_latin.hasMatch(character)) hasLatin = true;
          continue;
        }
        sawNonAscii = true;
        hasOtherScript = true;
        if (confusables.containsKey(character)) sawConfusable = true;
      }
      if (hasLatin && hasOtherScript) sawMixedScript = true;
    }
    if (sawPunycode) findings.add(LoopUrlFinding.punycodeLabel);
    if (sawMixedScript) findings.add(LoopUrlFinding.mixedScriptLabel);
    if (sawConfusable) findings.add(LoopUrlFinding.confusableCharacters);
    if (sawNonAscii && !sawConfusable && !sawMixedScript) {
      findings.add(LoopUrlFinding.nonAsciiHost);
    }
    return findings;
  }
}

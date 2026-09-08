import 'package:flutter/foundation.dart';

/// `GET /v2/meta/about` (public, decision 0037).
///
/// The server publishes contract and rule-snapshot versions plus the
/// open-source register. The client version and build number are read locally;
/// the server neither sends nor compares them.
@immutable
final class LoopAboutConfigVersion {
  const LoopAboutConfigVersion({
    required this.module,
    required this.configVersion,
    required this.effectiveAt,
  });

  final String module;
  final String configVersion;
  final DateTime? effectiveAt;
}

/// The terms gate reuses the `client-policy` union: an unavailable gate has a
/// reason and no version, an available gate has a version slot and no reason.
@immutable
final class LoopAboutTermsGate {
  const LoopAboutTermsGate({
    required this.requiredVersion,
    required this.reasonCode,
  });

  final String? requiredVersion;
  final String? reasonCode;

  bool get isAvailable => requiredVersion != null;
}

/// One register row. There is no version field on the wire, so none is shown.
@immutable
final class LoopOpenSourceEntry {
  const LoopOpenSourceEntry({
    required this.name,
    required this.purpose,
    required this.license,
  });

  final String name;
  final String purpose;
  final String license;
}

@immutable
final class LoopOpenSourceRegister {
  LoopOpenSourceRegister({
    required this.source,
    required this.summary,
    required List<LoopOpenSourceEntry> entries,
  }) : entries = List<LoopOpenSourceEntry>.unmodifiable(entries);

  final String source;
  final String summary;
  final List<LoopOpenSourceEntry> entries;
}

@immutable
final class LoopAbout {
  const LoopAbout({
    required this.contractVersion,
    required this.configVersions,
    required this.termsGate,
    required this.openSource,
    required this.clientBuildReasonCode,
  });

  final String contractVersion;
  final List<LoopAboutConfigVersion> configVersions;
  final LoopAboutTermsGate termsGate;
  final LoopOpenSourceRegister openSource;

  /// Always `CLIENT_BUILD_IS_DEVICE_LOCAL`.
  final String clientBuildReasonCode;
}

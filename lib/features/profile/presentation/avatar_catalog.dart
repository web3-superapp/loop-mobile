import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One selectable preset avatar.
///
/// The catalog is server-owned (`GET /v2/profile/avatars`). Avatar upload has
/// no storage provider and stays unavailable, so this list is the complete set
/// of values a client may submit.
@immutable
final class AvatarPreset {
  const AvatarPreset({
    required this.avatarRef,
    required this.atlas,
    required this.slot,
    required this.label,
  });

  final String avatarRef;
  final String atlas;

  /// One-based row-major index into the 4x3 people atlas; null for the
  /// client-rendered monogram.
  final int? slot;
  final String label;

  bool get isMonogram => atlas == 'monogram';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarPreset &&
          other.avatarRef == avatarRef &&
          other.atlas == atlas &&
          other.slot == slot &&
          other.label == label;

  @override
  int get hashCode => Object.hash(avatarRef, atlas, slot, label);
}

enum AvatarCatalogFailureKind { unavailable, offline, invalidData, unexpected }

final class AvatarCatalogException implements Exception {
  const AvatarCatalogException(this.kind);

  final AvatarCatalogFailureKind kind;

  String get code => switch (kind) {
    AvatarCatalogFailureKind.unavailable => 'avatar_catalog_unavailable',
    AvatarCatalogFailureKind.offline => 'avatar_catalog_offline',
    AvatarCatalogFailureKind.invalidData => 'invalid_avatar_catalog_data',
    AvatarCatalogFailureKind.unexpected => 'avatar_catalog_request_failed',
  };

  @override
  String toString() => code;
}

abstract interface class AvatarCatalogGateway {
  Future<List<AvatarPreset>> load();
}

/// Production-safe default: no fabricated preset list.
final class UnavailableAvatarCatalogGateway implements AvatarCatalogGateway {
  const UnavailableAvatarCatalogGateway();

  @override
  Future<List<AvatarPreset>> load() => Future<List<AvatarPreset>>.error(
    const AvatarCatalogException(AvatarCatalogFailureKind.unavailable),
  );
}

final avatarCatalogGatewayProvider = Provider<AvatarCatalogGateway>(
  (ref) => const UnavailableAvatarCatalogGateway(),
);

/// Loads the catalog once per gateway. An error stays an [AsyncError]; the UI
/// renders an unavailable avatar picker instead of inventing presets.
final avatarCatalogProvider = FutureProvider<List<AvatarPreset>>((ref) {
  return ref.watch(avatarCatalogGatewayProvider).load();
});

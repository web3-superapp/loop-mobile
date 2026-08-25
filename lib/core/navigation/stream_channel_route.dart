/// A provider-neutral address for the only Stream Chat channel type that LOOP
/// currently exposes through application navigation.
final class LoopStreamChannelAddress {
  const LoopStreamChannelAddress._({required this.type, required this.id});

  final String type;
  final String id;

  String get cid => '$type:$id';

  @override
  bool operator ==(Object other) {
    return other is LoopStreamChannelAddress &&
        other.type == type &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

final RegExp _forbiddenChannelControlPattern = RegExp(
  r'[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff]',
);

/// Parses the only channel CID shape enabled by LOOP's current Chat product.
///
/// The application route and any future provider ingress must share this
/// parser so notification data cannot create a broader Chat navigation path.
LoopStreamChannelAddress? parseLoopStreamChannelCid(String cid) {
  if (cid.isEmpty ||
      cid.length > 255 ||
      cid != cid.trim() ||
      cid.contains('/') ||
      _forbiddenChannelControlPattern.hasMatch(cid)) {
    return null;
  }
  final separator = cid.indexOf(':');
  if (separator <= 0 || separator == cid.length - 1) return null;
  final type = cid.substring(0, separator);
  final id = cid.substring(separator + 1);
  if (type != 'messaging' || id.isEmpty || id.contains(':')) return null;
  return LoopStreamChannelAddress._(type: type, id: id);
}

import 'package:uuid/uuid.dart';

abstract interface class StreamCallIdGenerator {
  String next();
}

/// Generates a new call ID for each outgoing ringing intent.
///
/// Call IDs are never persisted for reuse after a call has rung. A retry that
/// represents a brand-new outgoing call must request another value.
final class UuidStreamCallIdGenerator implements StreamCallIdGenerator {
  const UuidStreamCallIdGenerator();

  @override
  String next() => const Uuid().v4();
}

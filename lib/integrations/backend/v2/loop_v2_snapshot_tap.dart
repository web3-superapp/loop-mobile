/// Receives the body of one successful read, after the strict decoder
/// accepted it (decision 0095).
///
/// Only the four cold-start reads call it. The body is handed over exactly as
/// it was decoded so a stored snapshot is re-decoded by the same decoder, and
/// can never hold a shape the live path would refuse.
typedef LoopV2SnapshotTap = void Function(String resource, Object? body);

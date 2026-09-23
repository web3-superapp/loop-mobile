/// How LOOP prints an instant a server named.
///
/// Every server timestamp arrives in UTC, and the pages used to print it that
/// way: the member directory said 「加入于 2026-09-23 03:11 UTC」 and the chat
/// two screens away said 20:06, which is the same moment. One account, two
/// clocks, and no page said which (device walkthrough 2026-09-23).
///
/// The instant is the server's; the wall clock it is read on is the reader's.
/// So the conversion is a display concern and belongs here, once, for every
/// page that prints one.
library;

String _two(int part) => part.toString().padLeft(2, '0');

/// `2026-09-23 11:11` — one server instant on the reader's own wall clock.
///
/// The zone is not printed: a local reading needs no suffix, and 「UTC」 on a
/// figure that is no longer UTC would be worse than none.
String loopLocalTimestampLabel(DateTime instant) {
  final local = instant.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// `11:11` — the time of day alone, for a row that already carries the date.
String loopLocalClockLabel(DateTime instant) {
  final local = instant.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

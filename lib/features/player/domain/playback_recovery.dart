
/// What to do about a picture that has stopped moving.
enum StallAction {
  /// Nothing yet. Either playback is fine or the stall is too young to act on.
  none,

  /// Re-issue the current position and resume, which forces a demuxer that
  /// dropped its request to start a new one.
  nudge,

  /// Hand the source to the failover ladder, which decides between reopening
  /// it and moving on.
  recover,
}

/// How long a source that has produced frames may sit at one position before
/// the engine gets a kick.
const Duration kStallNudgeAfter = Duration(seconds: 5);

/// How long any source may make no progress at all before it is abandoned.
const Duration kStallRecoverAfter = Duration(seconds: 15);

/// A torrent's first frame waits on pieces arriving, not on a socket, and on a
/// cold magnet that is measured in minutes. The ordinary deadline would
/// abandon every torrent before it had a chance to seed.
const Duration kTorrentStallRecoverAfter = Duration(minutes: 3);

/// Whether a stall of [stalledFor] warrants doing something about it yet.
///
/// [lastAction] is the highest rung already fired for this stall window, so
/// each rung fires once; the caller clears it the moment the position moves.
StallAction stallActionFor({
  required Duration stalledFor,
  required bool hadFrames,
  required StallAction lastAction,
  Duration recoverAfter = kStallRecoverAfter,
  Duration nudgeAfter = kStallNudgeAfter,
}) {
  if (stalledFor >= recoverAfter && lastAction != StallAction.recover) {
    return StallAction.recover;
  }
  if (!hadFrames) return StallAction.none;
  if (stalledFor >= nudgeAfter && lastAction == StallAction.none) {
    return StallAction.nudge;
  }
  return StallAction.none;
}

/// The next candidate to open after [from], or null once every one has had a
/// turn.
///
/// Walks the ring rather than counting upwards: the first source opened is
/// whichever the resolver picked, routinely not zero, so counting upwards
/// leaves every candidate before it permanently unreachable by failover.
int? nextFailoverIndex({
  required int from,
  required int total,
  required Set<int> tried,
}) {
  if (total <= 0) return null;
  for (var step = 1; step <= total; step++) {
    final candidate = (from + step) % total;
    if (!tried.contains(candidate)) return candidate;
  }
  return null;
}

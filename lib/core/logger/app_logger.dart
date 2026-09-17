import 'package:talker_flutter/talker_flutter.dart';
import 'package:flutter/foundation.dart';

/// Global Talker instance for logging across the app.
final talker = TalkerFlutter.init(
  settings: TalkerSettings(enabled: kDebugMode),
);

/// Marker substituted for anything that looks like a credential.
const String kRedactedPlaceholder = '<redacted>';

/// `name=value` pairs whose name looks like a credential, in a URL query, a
/// header dump, a JSON body or a `toString()`.
///
/// The `{0,40}` bounds on the name's prefix and suffix are not cosmetic. An
/// unbounded `*` there backtracks quadratically over a long line with no
/// keyword in it.
final RegExp _secretAssignment = RegExp(
  r'''([A-Za-z0-9_.\-]{0,40}(?:api[_-]?key|apikey|access[_-]?token|refresh[_-]?token|id[_-]?token|auth[_-]?token|client[_-]?secret|authorization|password|passwd|token|secret|signature)[A-Za-z0-9_.\-]{0,40})(["']?\s*[:=]\s*)(["']?)([^\s"'&,;}\)\]]+)\3''',
  caseSensitive: false,
);

/// `Authorization: Bearer xxx` style credentials, where the name is gone by the
/// time the value is printed.
final RegExp _bearerToken = RegExp(
  r'\b(Bearer|Basic|Token)\s+([A-Za-z0-9._\-+/=]{8,})',
  caseSensitive: false,
);

/// A JWT anywhere in the text, named or not.
final RegExp _jsonWebToken = RegExp(
  r'\beyJ[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]*',
);

/// Strips anything that looks like a credential out of [input].
///
/// Used by the global error boundary so an exception whose `toString()`
/// embeds a token cannot leak it into the crash screen a user screenshots.
String redactSecrets(String input) {
  if (input.isEmpty) return input;
  // Bearer first: `Authorization: Bearer xxx` would otherwise have its value
  // read as the single word `Bearer`, leaving the token itself in the clear.
  return input
      .replaceAllMapped(
        _bearerToken,
        (Match m) => '${m[1]} $kRedactedPlaceholder',
      )
      .replaceAllMapped(
        _secretAssignment,
        (Match m) => '${m[1]}${m[2]}${m[3]}$kRedactedPlaceholder${m[3]}',
      )
      .replaceAll(_jsonWebToken, kRedactedPlaceholder);
}

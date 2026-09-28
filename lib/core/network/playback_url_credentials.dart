/// Recognises a playback URL that carries what look like expiring
/// credentials, and therefore should not be treated as a durable link.
///
/// This exists because most of these are *single-use in time*: the CDN signs
/// the URL for a window, the window passes, and the same string 403s. Two
/// consequences follow, and both used to be missed:
///
///  - A result cache that stores one of these will happily hand back a link
///    that has already died, for as long as its TTL lasts.
///  - A player that "re-resolves" by normalising the same string has not
///    re-resolved anything; it has reopened the corpse.
///
/// The test is deliberately heuristic. A key like `token` is strong evidence.
/// A key like `t` is weak on its own — `t` is also a common cache-buster — so
/// short keys only count when the URL also looks signed (a long opaque value,
/// or a companion expiry key). False positives cost one re-resolve; false
/// negatives cost a dead link, so the balance leans towards matching.
library;

/// Query keys that mean the URL is signed, tokenised or time-limited, and
/// mean it on their own. These names are unambiguous: nothing else uses
/// `Signature` or `X-Amz-Expires` for anything.
const Set<String> kCredentialQueryKeys = {
  'accesskey',
  'auth_token',
  'authkey',
  'authorization',
  'credential',
  'expires',
  'exp',
  'expiry',
  'hdnts',
  'hdnts2',
  'hmac',
  'jwt',
  'policy',
  'sessionid',
  'sig',
  'sign',
  'signature',
  'token',
  'wmsauthsign',
  'wssecret',
  'wstime',
  'x-amz-credential',
  'x-amz-date',
  'x-amz-expires',
  'x-amz-signature',
  'x-goog-credential',
  'x-goog-signature',
};

/// Keys that only imply a credential alongside a token-shaped value. `key`,
/// `auth` and `session` are ordinary parameter names, and `t`/`st`/`h`/`k`
/// are ordinary cache-busters.
const Set<String> _weakCredentialKeys = {
  'auth',
  'h',
  'hash',
  'k',
  'key',
  'md5',
  'session',
  'st',
  't',
};

/// Substrings that mark a key as credential-ish even when the exact form is
/// not in the list above (`X-Amz-Signature`, `cloudfront_signature`, …).
const List<String> _credentialKeyFragments = [
  'token',
  'signature',
  'expires',
  'expiry',
  'credential',
  'hmac',
  'policy',
];

/// A value long enough to be a token rather than a flag or an id.
const int _opaqueValueThreshold = 24;

String _compact(String key) => key.replaceAll(RegExp(r'[-_.]'), '').toLowerCase();

String _decodeSafe(String value) {
  try {
    return Uri.decodeQueryComponent(value);
  } catch (_) {
    // A scraper-supplied URL is not a document we can trust to be well
    // formed, and a malformed escape is not a reason to throw here.
    return value;
  }
}

/// Whether [url] is a playback link whose validity is time- or token-bound.
///
/// Pure string logic over the query string: no network, no side effects.
bool hasLikelyExpiringPlaybackCredentials(String? url) {
  if (url == null || url.isEmpty) return false;
  final queryStart = url.indexOf('?');
  if (queryStart < 0 || queryStart == url.length - 1) return false;
  final query = url.substring(queryStart + 1).split('#').first;
  if (query.isEmpty) return false;

  var sawWeakKey = false;
  var sawOpaqueValue = false;

  for (final pair in query.split('&')) {
    if (pair.isEmpty) continue;
    final eq = pair.indexOf('=');
    final rawKey = (eq < 0 ? pair : pair.substring(0, eq)).trim();
    if (rawKey.isEmpty) continue;
    final value = eq < 0 ? '' : _decodeSafe(pair.substring(eq + 1));

    final lower = rawKey.toLowerCase();
    final compact = _compact(lower);

    // Unambiguous on its own: the NAME is the evidence, whatever the value.
    // Still needs a value though — a bare `?token` carries no credential and
    // re-resolving for it would be pure cost.
    final hasValue = value.isNotEmpty;
    if (hasValue &&
        (kCredentialQueryKeys.contains(lower) ||
            kCredentialQueryKeys.contains(compact) ||
            _credentialKeyFragments.any(compact.contains))) {
      return true;
    }

    // Everything else has to earn it with a token-shaped value.
    if (_weakCredentialKeys.contains(lower) ||
        _weakCredentialKeys.contains(compact)) {
      sawWeakKey = true;
      if (value.length >= _opaqueValueThreshold) sawOpaqueValue = true;
    }
  }

  // A bare `t=`/`st=` counts only when its value is long enough to be a
  // signature rather than an epoch.
  return sawWeakKey && sawOpaqueValue;
}

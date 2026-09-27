/// Catalogue of the regional "Movies & Series" shelves rendered on the home
/// page, underneath the hero carousel and above any provider-supplied rows.
///
/// Each shelf is fetched from TMDB's discover endpoints filtered by origin
/// country (and original language where a single country hosts several
/// distinct film industries, as India does).
///
/// Shelves are sorted newest-first so a fresh release appears at the top of
/// its section as soon as TMDB indexes it — no manual refresh needed, because
/// the home provider re-fetches whenever the page is opened.
library;

/// Keys are stable identifiers; [l10nKey] is resolved in the UI so the titles
/// are localised, while [originCountries] / [originalLanguages] drive the API.
class RegionalSection {
  /// Stable map key used by the home provider.
  final String key;

  /// Localisation getter name on `AppLocalizations`.
  final String l10nKey;

  /// Pipe-separated ISO 3166-1 country codes (OR semantics in TMDB).
  final String originCountries;

  /// Optional pipe-separated ISO 639-1 language codes.
  final String? originalLanguages;

  /// Minimum vote count used to filter out empty/obscure entries.
  final int minVotes;

  const RegionalSection({
    required this.key,
    required this.l10nKey,
    required this.originCountries,
    this.originalLanguages,
    this.minVotes = 20,
  });
}

/// The "Latest" shelf (newest movies + newest series everywhere).
class LatestSection {
  static const key = 'regional.latest';
  static const l10nKey = 'sectionLatest';

  /// Kept deliberately low so brand-new releases qualify, but non-zero so
  /// completely unrated placeholder entries stay out of the shelf.
  static const minVotes = 3;

  /// How far back "latest" looks.
  static const windowDays = 90;

  const LatestSection._();
}

/// Ordered list of regional shelves shown on the home page.
const List<RegionalSection> kRegionalSections = [
  RegionalSection(
    key: 'regional.hollywood',
    l10nKey: 'sectionHollywood',
    originCountries: 'US|CA|AU',
    minVotes: 30,
  ),
  RegionalSection(
    key: 'regional.bollywood',
    l10nKey: 'sectionBollywood',
    originCountries: 'IN',
    originalLanguages: 'hi',
    minVotes: 10,
  ),
  RegionalSection(
    key: 'regional.southIndian',
    l10nKey: 'sectionSouthIndian',
    originCountries: 'IN',
    originalLanguages: 'te|ta|ml|kn',
    minVotes: 5,
  ),
  RegionalSection(
    key: 'regional.indonesian',
    l10nKey: 'sectionIndonesian',
    originCountries: 'ID',
    minVotes: 5,
  ),
  RegionalSection(
    key: 'regional.korean',
    l10nKey: 'sectionKorean',
    originCountries: 'KR',
    minVotes: 15,
  ),
  RegionalSection(
    key: 'regional.turkish',
    l10nKey: 'sectionTurkish',
    originCountries: 'TR',
    minVotes: 10,
  ),
  RegionalSection(
    key: 'regional.british',
    l10nKey: 'sectionBritish',
    originCountries: 'GB',
    minVotes: 20,
  ),
  RegionalSection(
    key: 'regional.french',
    l10nKey: 'sectionFrench',
    originCountries: 'FR',
    minVotes: 20,
  ),
  RegionalSection(
    key: 'regional.german',
    l10nKey: 'sectionGerman',
    originCountries: 'DE',
    minVotes: 15,
  ),
  RegionalSection(
    key: 'regional.russian',
    l10nKey: 'sectionRussian',
    originCountries: 'RU',
    minVotes: 10,
  ),
  RegionalSection(
    key: 'regional.chinese',
    l10nKey: 'sectionChinese',
    originCountries: 'CN|HK|TW',
    minVotes: 15,
  ),
  RegionalSection(
    key: 'regional.japanese',
    l10nKey: 'sectionJapanese',
    originCountries: 'JP',
    minVotes: 15,
  ),
  RegionalSection(
    key: 'regional.arabic',
    l10nKey: 'sectionArabic',
    originCountries: 'AE|SA|EG|QA|KW|LB|MA|JO|IQ|OM|PS',
    minVotes: 5,
  ),
];

/// Every key owned by the regional shelves (including [LatestSection.key]).
final Set<String> kRegionalSectionKeys = {
  LatestSection.key,
  for (final s in kRegionalSections) s.key,
};

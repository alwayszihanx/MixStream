import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nuvio_scraper_stats.g.dart';

/// Per-scraper success telemetry.
///
/// Every Nuvio row is probed before it is shown, which makes the probe the
/// natural place to learn which scrapers actually deliver: a scraper that
/// answers but serves dead links is worse than one that returns nothing. These
/// counters let the sources sheet rank the reliable scraper first, which is how
/// people actually want sources ordered.
class ScraperStat {
  const ScraperStat({this.successes = 0, this.failures = 0});

  final int successes;
  final int failures;

  int get total => successes + failures;

  /// 0..1, with a small-sample prior so a single lucky probe doesn't outrank a
  /// long-running reliable scraper.
  double get reliability {
    const prior = 2.0;
    return (successes + prior) / (total + prior * 2);
  }
}

@Riverpod(keepAlive: true)
class NuvioScraperStats extends _$NuvioScraperStats {
  static const _prefsKey = 'nuvio_scraper_stats_v1';
  static const _maxTracked = 200;

  @override
  Map<String, ScraperStat> build() {
    _load();
    return const {};
  }

  void _load() {
    // Fire-and-forget: the first frame uses an empty map, then fills in.
    unawaitedLoad();
  }

  void unawaitedLoad() {
    SharedPreferences.getInstance().then((prefs) {
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final out = <String, ScraperStat>{};
        decoded.forEach((key, value) {
          if (value is Map) {
            out[key] = ScraperStat(
              successes: (value['s'] as num?)?.toInt() ?? 0,
              failures: (value['f'] as num?)?.toInt() ?? 0,
            );
          }
        });
        state = out;
      } catch (_) {
        // Corrupt payload: start fresh rather than crash on launch.
      }
    });
  }

  void record(String scraperId, {required bool success}) {
    if (scraperId.isEmpty) return;
    final current = state[scraperId] ?? const ScraperStat();
    final next = {
      ...state,
      scraperId: ScraperStat(
        successes: current.successes + (success ? 1 : 0),
        failures: current.failures + (success ? 0 : 1),
      ),
    };
    // Keep the map bounded; the least reliable entries are dropped first.
    if (next.length > _maxTracked) {
      final ranked = next.entries.toList()
        ..sort((a, b) => a.value.reliability.compareTo(b.value.reliability));
      state = {
        for (final e in ranked.skip(ranked.length - _maxTracked)) e.key: e.value,
      };
    } else {
      state = next;
    }
    _persist();
  }

  void _persist() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final e in state.entries)
            e.key: {'s': e.value.successes, 'f': e.value.failures},
        }),
      );
    });
  }

  void reset() {
    state = const {};
    SharedPreferences.getInstance().then((p) => p.remove(_prefsKey));
  }

  /// 0..1 reliability for a scraper, used as a sort boost.
  double reliabilityOf(String scraperId) =>
      (state[scraperId] ?? const ScraperStat()).reliability;
}

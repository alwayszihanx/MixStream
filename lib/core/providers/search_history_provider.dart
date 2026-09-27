import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'search_history_provider.g.dart';

@Riverpod(keepAlive: true)
class SearchHistory extends _$SearchHistory {
  static const int _maxHistory = 15;
  static const String _key = 'search_history';

  @override
  List<String> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    state = List.unmodifiable(raw);
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final updated = [trimmed, ...state.where((q) => q != trimmed)];
    if (updated.length > _maxHistory) {
      updated.removeRange(_maxHistory, updated.length);
    }
    state = List.unmodifiable(updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
  }

  Future<void> remove(String query) async {
    final updated = state.where((q) => q != query).toList();
    state = List.unmodifiable(updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
  }

  Future<void> clear() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

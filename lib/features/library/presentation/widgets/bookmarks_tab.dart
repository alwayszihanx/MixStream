import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/multimedia_card.dart';
import '../library_provider.dart';

import '../library_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';

enum _BookmarkSortMode { newest, name, rating }

class BookmarksTab extends ConsumerStatefulWidget {
  const BookmarksTab({super.key});

  @override
  ConsumerState<BookmarksTab> createState() => _BookmarksTabState();
}

class _BookmarksTabState extends ConsumerState<BookmarksTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  _BookmarkSortMode _sortMode = _BookmarkSortMode.newest;
  String _selectedCollection = 'All';
  bool _isGridView = true;
  static const String _collectionsKey = 'bookmark_collections';
  static const List<String> _defaultCollections = ['All', 'Watch Later', 'Favorites'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<List<String>> _loadCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_collectionsKey);
    if (saved == null || saved.isEmpty) {
      return List.from(_defaultCollections);
    }
    final all = ['All', ...saved.where((c) => c != 'All')];
    return all;
  }

  Future<void> _addCollection(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_collectionsKey) ?? [];
    if (!saved.contains(name) && name != 'All') {
      saved.add(name);
      await prefs.setStringList(_collectionsKey, saved);
    }
    setState(() => _selectedCollection = name);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final libraryState = ref.watch(libraryProvider);
    final isLarge = context.isTabletOrLarger;
    final double totalHeight = isLarge ? 180.0 : 150.0;

    return switch (libraryState) {
      LibraryLoading() => const Center(child: AppLoadingIndicator()),
      LibraryError(message: final msg) => Center(child: Text(msg)),
      LibraryEmpty() => _buildEmpty(context),
      LibrarySuccess(items: final items) => Column(
        children: [
          // ── Sort + Collection Header ──────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                // Sort button
                PopupMenuButton<_BookmarkSortMode>(
                  icon: AppIcon(
                    'sort_rounded',
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Sort',
                  onSelected: (mode) => setState(() => _sortMode = mode),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    _sortMenuItem(_BookmarkSortMode.newest, 'Newest', _sortMode),
                    _sortMenuItem(_BookmarkSortMode.name, 'A-Z', _sortMode),
                    _sortMenuItem(_BookmarkSortMode.rating, 'Rating', _sortMode),
                  ],
                ),
                const SizedBox(width: 4),
                // Grid/List toggle
                IconButton(
                  icon: AppIcon(
                    _isGridView ? 'view_list_rounded' : 'grid_view_rounded',
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  tooltip: _isGridView ? 'List view' : 'Grid view',
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                // Collection filter chips
                Expanded(
                  child: FutureBuilder<List<String>>(
                    future: _loadCollections(),
                    builder: (context, snapshot) {
                      final collections = snapshot.data ?? _defaultCollections;
                      return SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: collections.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            if (index == collections.length) {
                              return ActionChip(
                                avatar: const AppIcon('add_rounded', size: 16),
                                label: const Text('New', style: TextStyle(fontSize: 12)),
                                onPressed: _showAddCollectionDialog,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              );
                            }
                            final col = collections[index];
                            final isSelected = col == _selectedCollection;
                            return FilterChip(
                              label: Text(col, style: const TextStyle(fontSize: 12)),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedCollection = col),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              checkmarkColor: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Clear all
                IconButton(
                  icon: const AppIcon('delete_sweep_rounded', size: 20),
                  tooltip: 'Clear all bookmarks',
                  onPressed: () => _confirmClearAll(context, ref),
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // ── Bookmarks Grid ────────────────────────────
          Expanded(
            child: _buildGrid(context, items, totalHeight),
          ),
        ],
      ),
    };
  }

  Widget _buildGrid(BuildContext context, List<MultimediaItem> items, double totalHeight) {
    // Sort
    final sorted = List<MultimediaItem>.of(items);
    switch (_sortMode) {
      case _BookmarkSortMode.newest:
        // Already in insertion order from Hive
        break;
      case _BookmarkSortMode.name:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
      case _BookmarkSortMode.rating:
        sorted.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
        break;
    }

    if (!_isGridView) {
      return ListView.builder(
        padding: const EdgeInsets.all(LayoutConstants.spacingMd),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final item = sorted[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  AppImageFallbacks.poster(item.posterUrl, label: item.title) ?? '',
                  width: 40,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, __) => Container(
                    width: 40,
                    height: 60,
                    color: Theme.of(context).dividerColor,
                    child: const AppIcon('movie_outlined', size: 20),
                  ),
                ),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: item.score != null
                  ? Text('⭐ ${item.score!.toStringAsFixed(1)}')
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const AppIcon('share_rounded', size: 18),
                    onPressed: () => Share.share('${item.title}\n${item.url}'),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const AppIcon('delete_outline_rounded', size: 18),
                    onPressed: () {
                      ref.read(libraryProvider.notifier).removeItem(item.url);
                    },
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              onTap: () => DetailsRoute(
                $extra: DetailsRouteExtra(item: item),
              ).push<void>(context),
            ),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(LayoutConstants.spacingMd),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: totalHeight,
        childAspectRatio: 2 / 3.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MultimediaCard(
                key: ValueKey(item.url),
                imageUrl:
                    AppImageFallbacks.poster(item.posterUrl, label: item.title) ??
                        '',
                title: item.title,
                heroTag: 'lib_bookmark_${item.url}_$index',
                badgeText: item.score?.toStringAsFixed(1),
                rating: item.score?.toStringAsFixed(1),
                onTap: () => DetailsRoute(
                  $extra: DetailsRouteExtra(item: item),
                ).push<void>(context),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => Share.share('${item.title}\n${item.url}'),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const AppIcon('share_rounded', size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatController.value * 8 - 4),
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: AppIcon(
                'bookmark_outline_rounded',
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.libraryEmpty,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save movies and shows to watch later',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_BookmarkSortMode> _sortMenuItem(
    _BookmarkSortMode value,
    String label,
    _BookmarkSortMode current,
  ) {
    return PopupMenuItem<_BookmarkSortMode>(
      value: value,
      child: Row(
        children: [
          if (value == current)
            const AppIcon('check_rounded', size: 16, color: Colors.green)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  void _showAddCollectionDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('New Collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Collection name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              _addCollection(val.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addCollection(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final libraryState = ref.read(libraryProvider);
    final count = libraryState is LibrarySuccess ? libraryState.items.length : 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Clear all bookmarks'),
        content: Text('Delete all $count bookmarks? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(libraryProvider.notifier).clearAll();
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

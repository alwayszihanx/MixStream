import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mixstream/core/utils/responsive_breakpoints.dart';
import 'package:mixstream/core/router/app_router.dart';
import 'package:mixstream/core/utils/image_fallbacks.dart';
import 'package:mixstream/core/utils/layout_constants.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../shared/widgets/multimedia_card.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../features/library/presentation/library_provider.dart';
import '../../../../features/library/presentation/library_state.dart';

class HomeSection extends ConsumerStatefulWidget {
  final String title;
  final List<MultimediaItem> items;
  const HomeSection({super.key, required this.title, required this.items});

  @override
  ConsumerState<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends ConsumerState<HomeSection> {
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isLarge = context.isTabletOrLarger;
    final cs = Theme.of(context).colorScheme;

    final double totalHeight = isLarge ? 350.0 : 230.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: GestureDetector(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                // Brand accent gradient bar
                Container(
                  width: 4,
                  height: isLarge ? 18 : 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cs.primary,
                        cs.tertiary,
                        cs.secondary,
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: isLarge ? 20 : 17,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedRotation(
                  turns: _isCollapsed ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: SizedBox(
            height: totalHeight,
            child: DesktopScrollWrapper(
              controller: _scrollController,
              showButtons: isLarge,
              child: Builder(
                builder: (context) {
                  final double cardWidth = isLarge ? 200.0 : 130.0;
                  final double spacing = isLarge
                      ? LayoutConstants.spacingLg
                      : LayoutConstants.spacingSm;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: LayoutConstants.spacingMd,
                      vertical: LayoutConstants.spacingXs,
                    ),
                    scrollDirection: Axis.horizontal,
                    physics: const PageScrollPhysics(),
                    itemCount: widget.items.length,
                    itemExtent: cardWidth + spacing,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return Padding(
                        padding: EdgeInsets.only(right: spacing),
                        child: MultimediaCard(
                          key: ValueKey(item.url),
                          imageUrl:
                              AppImageFallbacks.poster(
                                item.posterUrl,
                                label: item.title,
                              ) ??
                              '',
                          title: item.title,
                          heroTag: 'home_${item.url}_$index',
                          badgeText: item.score?.toStringAsFixed(1),
                          contextMenuBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'open_source',
                              child: const Row(
                                children: [
                                  AppIcon('public_rounded', size: 16),
                                  SizedBox(width: 8),
                                  Text('Open Source'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'bookmark',
                              child: const Row(
                                children: [
                                  AppIcon('bookmark_border_rounded', size: 16),
                                  SizedBox(width: 8),
                                  Text('Bookmark'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share',
                              child: const Row(
                                children: [
                                  AppIcon('share_rounded', size: 16),
                                  SizedBox(width: 8),
                                  Text('Share'),
                                ],
                              ),
                            ),
                          ],
                          onContextMenuAction: (value) async {
                            switch (value) {
                              case 'open_source':
                                if (item.url.isNotEmpty) {
                                  await launchUrl(
                                    Uri.parse(item.url),
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              case 'bookmark':
                                final libraryNotifier =
                                    ref.read(libraryProvider.notifier);
                                if (libraryNotifier.isBookmarked(item.url)) {
                                  libraryNotifier.removeItem(item.url);
                                } else {
                                  libraryNotifier.addItem(item);
                                }
                              case 'share':
                                await Share.share(
                                  '${item.title}\n${item.url}',
                                );
                            }
                          },
                          onTap: () => DetailsRoute(
                            $extra: DetailsRouteExtra(item: item),
                          ).push<void>(context),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _isCollapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

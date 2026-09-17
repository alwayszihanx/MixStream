import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PosterZoomOverlay extends StatefulWidget {
  final String imageUrl;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;
  final VoidCallback? onAddToList;

  const PosterZoomOverlay({
    super.key,
    required this.imageUrl,
    this.onPlay,
    this.onDownload,
    this.isBookmarked = false,
    this.onBookmarkToggle,
    this.onAddToList,
  });

  @override
  State<PosterZoomOverlay> createState() => _PosterZoomOverlayState();
}

class _PosterZoomOverlayState extends State<PosterZoomOverlay> {
  bool _isZoomed = false;
  bool _showActions = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () {
        setState(() {
          _isZoomed = !_isZoomed;
          _showActions = _isZoomed;
        });
      },
      onTap: () {
        if (_isZoomed) {
          setState(() {
            _isZoomed = false;
            _showActions = false;
          });
        }
      },
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(200),
        minScale: 0.5,
        maxScale: 3.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey.shade800,
                ),
                errorWidget: (_, __, ___) =>
                    Icon(Icons.image, color: Colors.grey.shade600),
              ),
            ),
            if (_showActions && !_isZoomed)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionIcon(Icons.play_arrow, widget.onPlay),
                    const SizedBox(height: 12),
                    _buildActionIcon(
                      widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      widget.onBookmarkToggle,
                    ),
                    const SizedBox(height: 12),
                    _buildActionIcon(Icons.file_download, widget.onDownload),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback? onTap) {
    if (onTap == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

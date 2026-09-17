import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'shimmer_placeholder.dart';

/// Blur-up progressive image.
///
/// While the full-resolution image streams in, a tiny (w92) blurred thumbnail
/// is shown underneath, then the sharp image crossfades on top. This removes
/// the flat "hard fallback" look and gives every poster/backdrop an instant
/// recognizable colour wash. Non-TMDB hosts (no size segment in the URL) fall
/// back to a subtle shimmer pulse.
class ProgressiveImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String, Object)? errorBuilder;
  final Duration fadeIn;
  final double blurSigma;

  const ProgressiveImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.fadeIn = const Duration(milliseconds: 450),
    this.blurSigma = 14,
  });

  static final RegExp _sizeSegment = RegExp(r'/t/p/(original|w\d+|h\d+)/');

  /// Derives a tiny thumbnail URL from a TMDB image URL, or null when the URL
  /// doesn't come from TMDB's image CDN.
  static String? thumbnailUrlFor(String url) {
    if (!_sizeSegment.hasMatch(url)) return null;
    final thumb = url.replaceFirst(_sizeSegment, '/t/p/w92/');
    return thumb == url ? null : thumb;
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorBuilder?.call(context, imageUrl, '') ??
          const SizedBox.shrink();
    }

    final thumb = thumbnailUrlFor(imageUrl);
    final double dpr = MediaQuery.devicePixelRatioOf(context);

    // Decode at the size the image is actually painted at, not the size the
    // source happens to be. A w1280 backdrop in a 200 px card otherwise costs
    // ~6x the GPU memory it can show, which is what makes long horizontal
    // lists stutter on low-RAM phones and TVs. The layout is known here, so
    // the hint is derived rather than passed in by every caller.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool boundedWidth =
            constraints.hasBoundedWidth &&
            constraints.maxWidth.isFinite &&
            constraints.maxWidth > 0;
        final bool boundedHeight =
            constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight > 0;

        // Prefer the width: it preserves the aspect ratio on its own, whereas
        // constraining both axes can letterbox an oddly-sized decode.
        final int? decodeWidth =
            boundedWidth ? (constraints.maxWidth * dpr).ceil() : null;
        final int? decodeHeight = decodeWidth == null && boundedHeight
            ? (constraints.maxHeight * dpr).ceil()
            : null;

        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: fit,
          fadeInDuration: fadeIn,
          fadeOutDuration: const Duration(milliseconds: 200),
          memCacheWidth: decodeWidth,
          memCacheHeight: decodeHeight,
          maxWidthDiskCache: decodeWidth,
          maxHeightDiskCache: decodeHeight,
          placeholder: (context, url) {
            if (thumb == null) {
              return ShimmerPlaceholder(borderRadius: 0);
            }
            return ClipRect(
              child: Transform.scale(
                scale: 1.15,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: thumb,
                    fit: fit,
                    memCacheWidth: decodeWidth,
                    placeholder: (_, _) =>
                        ShimmerPlaceholder(borderRadius: 0),
                    errorWidget: (_, _, _) =>
                        ShimmerPlaceholder(borderRadius: 0),
                  ),
                ),
              ),
            );
          },
          errorWidget:
              errorBuilder ??
              (context, url, error) =>
                  const ColoredBox(color: Color(0xFF1F1F1F)),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final ShapeBorder shapeBorder;
  final int delayMs;

  ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    double borderRadius = 16,
    ShapeBorder shapeBorder = const RoundedRectangleBorder(),
    this.delayMs = 0,
  }) : shapeBorder = borderRadius > 0
           ? RoundedRectangleBorder(
               borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
             )
           : shapeBorder;

  ShimmerPlaceholder.rectangular({
    super.key,
    this.width,
    this.height,
    double borderRadius = 16,
    this.delayMs = 0,
  }) : shapeBorder = RoundedRectangleBorder(
         borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
       );

  const ShimmerPlaceholder.circular({
    super.key,
    this.width,
    this.height,
    this.delayMs = 0,
  }) : shapeBorder = const CircleBorder();

  ShimmerPlaceholder.card({
    super.key,
    this.delayMs = 0,
    bool isPortrait = true,
  })  : width = isPortrait ? 130.0 : 200.0,
        height = isPortrait ? 195.0 : 112.5,
        shapeBorder = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        );

  ShimmerPlaceholder.text({
    super.key,
    this.width,
    this.delayMs = 0,
  })  : height = 14,
        shapeBorder = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = isDark
        ? colorScheme.surfaceContainerHighest
        : Colors.grey[300]!;

    final waveBaseColor = isDark
        ? colorScheme.surfaceContainerHighest
        : Colors.grey[300]!;
    final waveHighlightColor = isDark
        ? colorScheme.surfaceContainerHighest.withAlpha(230)
        : Colors.grey[50]!;
    final waveShimmerColor = isDark
        ? colorScheme.surfaceContainerHighest.withAlpha(200)
        : Colors.grey;

    Widget shimmer = Shimmer.fromColors(
      baseColor: waveBaseColor,
      highlightColor: waveHighlightColor,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: waveShimmerColor,
          shape: shapeBorder,
        ),
      ),
    );

    if (delayMs > 0) {
      shimmer = FutureBuilder<bool>(
        future: Future<bool>.delayed(Duration(milliseconds: delayMs), () => true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) return shimmer;
          return Container(
            width: width,
            height: height,
            decoration: ShapeDecoration(
              color: baseColor,
              shape: shapeBorder,
            ),
          );
        },
      );
    }

    return shimmer;
  }
}

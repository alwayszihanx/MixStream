import 'package:flutter/material.dart';

class HeroStretch extends StatefulWidget {
  final Widget Function(double stretchFactor) builder;
  final Widget child;
  final double minHeight;
  final double maxHeight;

  const HeroStretch({
    super.key,
    required this.builder,
    required this.child,
    this.minHeight = 200,
    this.maxHeight = 600,
  });

  @override
  State<HeroStretch> createState() => _HeroStretchState();
}

class _HeroStretchState extends State<HeroStretch> {
  double _stretchFactor = 0.0;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final metrics = notification.metrics;
          final extentBefore = metrics.extentBefore;
          final maxStretch = widget.maxHeight - widget.minHeight;
          if (maxStretch > 0) {
            final newFactor = (extentBefore / maxStretch).clamp(0.0, 1.0);
            if (newFactor != _stretchFactor) {
              setState(() => _stretchFactor = newFactor);
            }
          }
        }
        return false;
      },
      child: widget.builder(_stretchFactor),
    );
  }
}

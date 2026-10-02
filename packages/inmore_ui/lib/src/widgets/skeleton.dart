import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A soft sheen that sweeps across its [child]'s placeholder shapes.
///
/// Placeholders shaped like the content they stand in for tell the reader
/// what is coming and stop the layout jumping when it arrives — a spinner in
/// an empty page does neither.
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, super.key});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.surfaceContainerHighest;
    final light = context.colors.surfaceContainerLow;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final x = _controller.value * 3 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x - 1, 0),
            end: Alignment(x + 1, 0),
            colors: [base, light, base],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// One grey placeholder shape.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.width,
    this.height = 12,
    this.radius = 6,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Placeholder rows for a list: a leading badge, a title and a subtitle.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.rows = 6,
    this.padding = const EdgeInsets.all(Space.lg),
    this.dense = false,
    super.key,
  });

  final int rows;
  final EdgeInsetsGeometry padding;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows; i++)
              Padding(
                padding: EdgeInsets.symmetric(vertical: dense ? 6 : 10),
                child: Row(
                  children: [
                    SkeletonBox(
                      width: dense ? 28 : 40,
                      height: dense ? 28 : 40,
                      radius: Radii.md,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vary the widths so it reads as text, not a grid.
                          FractionallySizedBox(
                            widthFactor: [0.55, 0.7, 0.45, 0.62][i % 4],
                            child: const SkeletonBox(height: 12),
                          ),
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: [0.35, 0.28, 0.4, 0.3][i % 4],
                            child: const SkeletonBox(height: 10),
                          ),
                        ],
                      ),
                    ),
                    if (!dense) ...[
                      const SizedBox(width: Space.md),
                      const SkeletonBox(width: 64, height: 20, radius: 10),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder figure tiles for a dashboard row.
class SkeletonFigures extends StatelessWidget {
  const SkeletonFigures({this.count = 2, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: Space.md),
            const Expanded(child: SkeletonBox(height: 88, radius: Radii.lg)),
          ],
        ],
      ),
    );
  }
}

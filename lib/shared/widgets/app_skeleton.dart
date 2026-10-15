import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_motion.dart';

/// A single pulsing skeleton bar — the base primitive every skeleton
/// placeholder in the app should build from.
class AppSkeletonBar extends StatelessWidget {
  final double opacity;
  final double? width;
  final double height;

  const AppSkeletonBar({super.key, required this.opacity, this.width, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.backgroundMid,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

/// A 2-row shimmer placeholder approximating the icon-chip + two-text-line
/// shape most cards in this app render once loaded. Promoted out of
/// `dashboard_section.dart`'s private `_SectionSkeleton` (used by every
/// dashboard card's `loading:` branch via `SectionMessage`) so any future
/// screen's loading state can reuse the exact same shimmer instead of a new
/// one-off `CircularProgressIndicator`.
class AppSkeleton extends StatefulWidget {
  final int rows;

  const AppSkeleton({super.key, this.rows = 2});

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.slow)..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + (_controller.value * 0.35);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < widget.rows; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _row(opacity, secondLineWidth: i.isEven ? 110 : 70),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(double opacity, {required double secondLineWidth}) {
    return Row(
      children: [
        AppSkeletonBar(opacity: opacity, width: 36, height: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonBar(opacity: opacity, width: double.infinity, height: 12),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: AppSkeletonBar(opacity: opacity, width: secondLineWidth, height: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

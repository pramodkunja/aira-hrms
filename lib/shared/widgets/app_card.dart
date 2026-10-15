import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_radius.dart';
import 'package:mobile_app/core/theme/app_shadows.dart';

/// The base rounded-surface-with-shadow shell used by every card in the
/// redesigned Dashboard (`SectionCard`'s outer chrome, `ConsoleHeaderShell`,
/// `ModuleIconCard`) — extracted so any future screen's cards start from the
/// exact same surface color, radius, and shadow instead of each hand-rolling
/// `Container(decoration: ...)`.
///
/// This is deliberately just the shell: no title row, no divider. Screens
/// that need a titled card should use [SectionCard]
/// (`dashboard/presentation/widgets/dashboard_section.dart`), which now
/// builds its outer chrome from this widget.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final Color? color;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.medium,
    this.boxShadow,
    this.border,
    this.color,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: boxShadow ?? AppShadows.card,
        border: border,
      ),
      child: child,
    );
  }
}

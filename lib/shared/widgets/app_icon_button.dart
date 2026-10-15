import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_shadows.dart';

/// A soft, circular icon button on an elevated white chip — the shell
/// `DashboardHeader`'s notification bell wrapper and `AppBottomNav`'s center
/// Menu button both already use ad hoc; this is that same shell, reusable,
/// with an optional small count badge (for notification-style buttons).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final int? badgeCount;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 44,
    this.badgeCount,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon),
          color: color ?? AppColors.textSecondary,
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );

    if (badgeCount == null || badgeCount! <= 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
            child: Text(
              badgeCount! > 99 ? '99+' : '$badgeCount',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'menu_sheet.dart';

/// Soft floating bottom nav — Home / Menu (center, elevated) / Profile.
/// Home and Profile are real destinations (navigated via the same
/// [goToDashboardSection] helper every other nav entry point in this app
/// already uses, so back-stack behavior stays identical). Menu never shows
/// "selected" — it opens [showMenuSheet] instead of navigating, replacing
/// the old Drawer as the one place every module lives.
///
/// Rendered by [DashboardShell] on every `/dashboard/*` route (not just
/// Home/Profile) so Menu stays reachable from anywhere the old
/// hamburger-drawer used to reach it from.
class AppBottomNav extends StatelessWidget {
  final String currentPath;

  const AppBottomNav({super.key, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final isHome = currentPath == AppRoutes.dashboard;
    final isProfile = currentPath == AppRoutes.profile;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppColors.elevatedShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavTab(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: isHome,
                onTap: () => goToDashboardSection(context, AppRoutes.dashboard),
              ),
              _CenterMenuButton(onTap: () => showMenuSheet(context)),
              _NavTab(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: isProfile,
                onTap: () => goToDashboardSection(context, AppRoutes.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textHint;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterMenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterMenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppColors.elevatedShadow,
              border: Border.all(color: AppColors.surface, width: 3),
            ),
            child: const Icon(Icons.apps_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Elevation tokens. `card`/`elevated` delegate straight to
/// [AppColors.cardShadow]/[AppColors.elevatedShadow] — those already exist
/// and are already theme-aware (dark mode swaps the tinted shadow for a
/// plain low-alpha black one); this file just gives the same two values
/// the semantic names the design system calls for, plus the two sizes it
/// was missing (`none`, `subtle`) and a name (`floating`) for the stronger
/// elevation already used by the bottom nav bar and its center button
/// (`AppBottomNav`), which today reuses `elevated` — kept numerically
/// identical rather than inventing an unaudited third shadow value.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> none = [];

  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: Colors.black.withValues(alpha: AppColors.isDark ? 0.2 : 0.05),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get card => AppColors.cardShadow;
  static List<BoxShadow> get elevated => AppColors.elevatedShadow;
  static List<BoxShadow> get floating => AppColors.elevatedShadow;
}

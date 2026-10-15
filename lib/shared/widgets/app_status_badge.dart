import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_radius.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';

/// A colored status pill — solid *Container background behind the matching
/// accent color (never a runtime alpha blend of the accent itself, which
/// reads as a barely-visible tint in dark mode since this app's dark accents
/// are already light/pastel). Generalizes the `(bg, fg)` switch-on-status
/// pattern that was duplicated almost verbatim in
/// `employee_dashboard_view.dart`'s `_StatusBadge` and `home_screen.dart`'s
/// generic `_RequestRow` — both now delegate to this.
///
/// The default status→color mapping covers this app's common request
/// lifecycle (pending/l2_pending, approved, rejected, cancelled); pass
/// [colorsFor] to override for a status set that doesn't fit that shape.
class AppStatusBadge extends StatelessWidget {
  final String status;
  final String label;
  final (Color background, Color foreground) Function(String status)? colorsFor;
  final EdgeInsetsGeometry padding;
  // Overrides the default labelSmall/10/w700 look — kept configurable
  // because the two existing call sites this consolidates
  // (`employee_dashboard_view.dart`'s action-items/recent-requests cards,
  // and `home_screen.dart`'s generic recent-leave-requests card) had each
  // independently picked a slightly different size/weight; this preserves
  // both exactly rather than silently resizing one of them.
  final TextStyle? textStyle;

  const AppStatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.colorsFor,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    this.textStyle,
  });

  static (Color, Color) defaultColorsFor(String s) => switch (s) {
        'approved' => (AppColors.successContainer, AppColors.success),
        'rejected' => (AppColors.errorContainer, AppColors.error),
        'cancelled' => (AppColors.backgroundMid, AppColors.textSecondary),
        _ => (AppColors.warningContainer, AppColors.warning), // 'pending', 'l2_pending'
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = (colorsFor ?? defaultColorsFor)(status);
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        label,
        style: (textStyle ?? AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700, fontSize: 10))
            .copyWith(color: fg),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_radius.dart';
import 'package:mobile_app/core/theme/app_spacing.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';

/// A tinted, bordered inline banner — icon chip, eyebrow label + meta,
/// title, subtitle, and an optional "View"/dismiss action pair. Generalizes
/// the shape already used by this app's real (API-backed) Announcement
/// banners on the Employee/HR/Admin dashboards (each currently its own
/// per-role private widget, since each binds a different provider and a
/// couple of role-specific fields) — new screens that need this same
/// "flat highlighted strip" look for real data should reach for this
/// instead of re-inlining the `Container`/`BoxDecoration` it wraps.
///
/// Deliberately presentational only: callers own fetching/dismiss-state and
/// simply don't render this at all when there's nothing to show (never pass
/// placeholder/fake content just to fill the slot).
class AppBannerCard extends StatelessWidget {
  final Widget icon;
  final String eyebrow;
  final String title;
  final String? subtitle;
  final String? meta;
  final VoidCallback? onView;
  final VoidCallback? onDismiss;
  final Color? accentColor;

  const AppBannerCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.meta,
    this.onView,
    this.onDismiss,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = this.accentColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 11),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.07),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: icon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      eyebrow,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: accentColor,
                      ),
                    ),
                    if (meta != null && meta!.isNotEmpty)
                      Text(meta!, style: AppTextStyles.labelSmall.copyWith(fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(title, style: AppTextStyles.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: AppTextStyles.cardSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (onView != null || onDismiss != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Column(
              children: [
                if (onView != null)
                  GestureDetector(
                    onTap: onView,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View', style: AppTextStyles.labelSmall.copyWith(color: accentColor, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward, size: 12, color: accentColor),
                      ],
                    ),
                  ),
                if (onView != null && onDismiss != null) const SizedBox(height: 6),
                if (onDismiss != null)
                  GestureDetector(onTap: onDismiss, child: Icon(Icons.close, size: 15, color: AppColors.textHint)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

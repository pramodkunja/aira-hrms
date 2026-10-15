import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_radius.dart';
import 'package:mobile_app/core/theme/app_spacing.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';

/// A single module tile — large rounded icon container + label, matching the
/// reference design's Menu/Quick-Access card look. Reusable anywhere a module
/// shortcut needs to render (Menu sheet grid today; any future screen that
/// wants the same tile look).
class ModuleIconCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  // Uploaded module artwork (assets/images/*.png) to show instead of [icon]
  // when the module has real, uploaded art — matches the full-color-image
  // treatment `QuickTile` (`quick_access.dart`) already gives the Dashboard's
  // Quick Access tiles for the same modules: no tinted background box behind
  // it (unlike the plain glyph case), since it's already a finished image.
  final String? imageAsset;

  const ModuleIconCard({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
    this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    // "3D" card: depth comes from a real, clearly-visible layered shadow
    // (a soft wide one for ambient lift + a tighter close one for a grounded
    // edge) — plain black at modest opacity, the standard elevation recipe,
    // not a new brand color. This has to live on a Container *outside* the
    // Material: a Material with `clipBehavior` clips its own child, and the
    // previous version put the shadow on a Container sized to exactly fill
    // that clipped Material — so the shadow was being clipped away to
    // nothing. Splitting them (shadow box outside, clipped ripple box
    // inside) is what actually makes it visible.
    final isDark = AppColors.isDark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    imageAsset != null
                        ? SizedBox(
                            width: 56,
                            height: 56,
                            child: Image.asset(imageAsset!, fit: BoxFit.contain),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (badge != null)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadius.pillAll,
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Text(
                        badge!,
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Responsive 3-column (phone) module grid — used by the Menu sheet's
/// searchable module list. Each item must know its own tap handler since
/// callers wire different navigation per module.
class ModuleGrid extends StatelessWidget {
  final List<Widget> tiles;

  const ModuleGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 3 columns on typical phone widths, more on wider/tablet screens —
        // keeps tiles from stretching too wide once the grid gets more room.
        final crossAxisCount = (constraints.maxWidth / 110).floor().clamp(3, 5);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            // Wider than before (was AppSpacing.md/12) — the tile's 3D
            // shadow needs room to breathe between cells instead of
            // crowding straight into the next tile.
            mainAxisSpacing: AppSpacing.lg,
            crossAxisSpacing: AppSpacing.lg,
            // Tall enough for icon(56) + gap(4) + a full 2-line label (real
            // module names, e.g. "Candidate Review & Onboarding", routinely
            // wrap) + the tile's own vertical padding(16) + border, with a
            // few px of slack for font-metric variance across platforms.
            mainAxisExtent: 128,
          ),
          itemBuilder: (context, index) => tiles[index],
        );
      },
    );
  }
}

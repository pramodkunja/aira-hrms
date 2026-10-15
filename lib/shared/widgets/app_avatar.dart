import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';

/// "Jane Doe" -> "JD", a single name -> its first letter, empty -> "?".
/// Shared by every avatar/initials chip in the app so initials are computed
/// identically everywhere (was duplicated with this exact logic in
/// `dashboard_section.dart`, `dashboard_header.dart`, and `menu_sheet.dart`
/// before this consolidation).
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (name.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// A circular initials avatar — the one avatar component every screen
/// should reach for. Consolidates what used to be three near-identical
/// inline `Container(shape: BoxShape.circle, child: Text(initials))` blocks
/// (the Dashboard header, the Menu sheet's account row, and the old
/// `InitialsAvatar`/`StatusRingAvatar` pair in `dashboard_section.dart`,
/// which now delegate here).
///
/// [activeRing] draws the green "currently active" ring `StatusRingAvatar`
/// used for the clocked-in indicator; [verifiedBadge] draws its small
/// overlapping badge. Both optional so plain call sites (Menu, Profile)
/// don't pay for either.
class AppAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool? activeRing;
  final bool verifiedBadge;

  const AppAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.activeRing,
    this.verifiedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final bg = backgroundColor ?? AppColors.primary;
    final fg = foregroundColor ?? Colors.white;

    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initialsOf(name),
          textAlign: TextAlign.center,
          style: AppTextStyles.label.copyWith(
            color: fg,
            // Audit finding: before this consolidation, the app's three
            // initials-avatar call sites each picked a different fixed font
            // size independent of their own radius — InitialsAvatar (r20)
            // used 11 (ratio .55), DashboardHeader (r24) and the Menu
            // sheet's account row (r22) both used 14 (ratios .58/.64). 0.58
            // is the consistent ratio all three now share, landing within
            // ~1px of every one of those original fixed values.
            fontSize: radius * 0.58,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final ringed = activeRing == null
        ? core
        : Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: activeRing! ? const Color(0xFF4ADE80) : Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Container(
              // A translucent glass fill, not a solid color — the ring
              // variant is always shown over a colored gradient hero card
              // (see ConsoleHeaderShell), never a plain background, so this
              // ignores `bg`/`backgroundColor` on purpose.
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
              child: Center(
                child: Text(
                  initialsOf(name),
                  style: AppTextStyles.h4.copyWith(color: fg, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          );

    if (!verifiedBadge) return ringed;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ringed,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.33,
              height: size * 0.33,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFDE68A),
                border: Border.all(color: const Color(0xFF6366F1), width: 2),
              ),
              child: Icon(Icons.verified, size: size * 0.18, color: const Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }
}

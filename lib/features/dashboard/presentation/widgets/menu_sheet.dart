import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_radius.dart';
import 'package:mobile_app/core/theme/app_spacing.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/core/theme/theme_mode_provider.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/shared/widgets/app_avatar.dart';
import 'package:mobile_app/shared/widgets/app_bottom_sheet.dart';
import 'package:mobile_app/shared/widgets/app_card.dart';
import 'package:mobile_app/shared/widgets/app_search_field.dart';
import 'package:mobile_app/shared/widgets/module_card.dart';
import '../navigation/nav_config.dart';

/// Opens the Menu sheet — the full module directory that replaces the old
/// Drawer (`AppSidebar`). [callerContext] is the long-lived route context
/// (from [AppBottomNav]/`DashboardShell`, still valid after the sheet
/// closes) that actual navigation happens through, since the sheet's own
/// `BuildContext` is gone the instant it's dismissed.
Future<void> showMenuSheet(BuildContext callerContext) {
  return showModalBottomSheet(
    context: callerContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MenuSheet(callerContext: callerContext),
  );
}

// A small palette, cycled by position, so every module tile gets a
// distinct-ish accent without hand-picking one per module (kAllNav has ~25
// items across 7 sections). A getter (not a top-level const list) because
// AppColors' fields are live mutable statics that flip with dark mode.
List<Color> get _kTilePalette => [
      AppColors.primary,
      AppColors.accentNavy,
      AppColors.warning,
      AppColors.success,
      AppColors.info,
      AppColors.accentPurple,
      AppColors.secondary,
    ];

// Real, uploaded module artwork (assets/images/) — keyed by the module's own
// path, same convention and same asset files as `quick_access.dart`'s
// `_kQuickItemImageByPath` (the Dashboard's Quick Access tiles), so a module
// shown in both places uses the exact same image. Only mapped where the
// asset unambiguously names that module; every other module keeps its plain
// Material icon, matched by [NavItem.icon] as before.
//
// '/dashboard/leave' uses "Leave Management.png" — a distinct asset from
// "Leave Approval.png", which specifically depicts the HR "Leave Approvals"
// quick action (see quick_access.dart) and is never used here. Every module
// in kAllNav (nav_config.dart) now has a matching asset.
const _kModuleImageByPath = <String, String>{
  '/dashboard': 'assets/images/Dashboard.png',
  '/dashboard/announcements': 'assets/images/Announcement.png',
  '/dashboard/interview-list': 'assets/images/Interview list.png',
  '/dashboard/candidate-review': 'assets/images/Review Candidate.png',
  '/dashboard/assessments': 'assets/images/Assessment.png',
  '/dashboard/email-logs': 'assets/images/Email log.png',
  '/dashboard/employees': 'assets/images/Employees.png',
  '/dashboard/org-chart': 'assets/images/Org Chart.png',
  '/dashboard/branches': 'assets/images/Branches.png',
  '/dashboard/attendance': 'assets/images/Attendance.png',
  '/dashboard/my-attendance': 'assets/images/Attendance.png',
  '/dashboard/leave': 'assets/images/Leave Management.png',
  '/dashboard/wfh': 'assets/images/Work From Home.png',
  '/dashboard/expenses': 'assets/images/Expenses.png',
  '/dashboard/approvals': 'assets/images/Approval.png',
  '/dashboard/separation': 'assets/images/Separation & Exit.png',
  '/dashboard/documents': 'assets/images/Document Centre.png',
  '/dashboard/referrals': 'assets/images/My Referrals.png',
  '/dashboard/face-id-registrations': 'assets/images/Face ID Registration.png',
  '/dashboard/my-payslip': 'assets/images/My Payslip.png',
  '/dashboard/my-requests': 'assets/images/My Request.png',
  '/dashboard/profile': 'assets/images/My Profile.png',
  '/dashboard/reports': 'assets/images/Reports.png',
  '/settings/audit': 'assets/images/Audit Log.png',
  '/dashboard/settings': 'assets/images/Settings.png',
};

// One representative image per real section title (nav_config.dart's
// NavSection titles: Main, Recruitment, Workforce, Time & Pay, HR Ops, My,
// System) for the new rounded section-header bar — NavSection itself has no
// icon field, so this is presentation-only, kept local to the Menu rather
// than added to nav_config.dart. Falls back to a generic icon (_kSectionIconFallback)
// for any title not listed here, so an unexpected section can never crash the header.
const _kSectionImage = <String, String>{
  'Main': 'assets/images/Main.png',
  'Recruitment': 'assets/images/Recruitment.png',
  'Workforce': 'assets/images/Workforce.png',
  'Time & Pay': 'assets/images/Time & Pay.png',
  'HR Ops': 'assets/images/HR Ops.png',
  'My': 'assets/images/My.png',
  'System': 'assets/images/System.png',
};
const _kSectionIconFallback = Icons.folder_outlined;

class MenuSheet extends ConsumerStatefulWidget {
  final BuildContext callerContext;

  const MenuSheet({super.key, required this.callerContext});

  @override
  ConsumerState<MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends ConsumerState<MenuSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigate(String path) {
    Navigator.of(context).pop();
    goToDashboardSection(widget.callerContext, path);
  }

  Future<void> _logout() async {
    Navigator.of(context).pop();
    await ref.read(authStateProvider.notifier).logout();
    if (widget.callerContext.mounted) widget.callerContext.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final permissions = user?.permissions ?? const [];
    final visibleNav = buildNav(permissions, role: user?.role);
    final allItems = visibleNav.whereType<NavItem>().toList();
    final isDarkMode = ref.watch(themeModeProvider);

    final query = _query.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final filtered = searching
        ? allItems.where((i) => i.label.toLowerCase().contains(query)).toList()
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return AppBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'What are you looking for?',
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
                  children: [
                    _AccountRow(
                      name: user?.fullName ?? '',
                      roleDisplay: user?.roleDisplay ?? '',
                      isDarkMode: isDarkMode,
                      onProfileTap: () => _navigate(AppRoutes.profile),
                      onThemeToggle: () => ref.read(themeModeProvider.notifier).toggle(),
                      onLogout: _logout,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (searching) ...[
                      if (filtered!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 40, color: AppColors.textHint),
                              const SizedBox(height: AppSpacing.sm),
                              Text('No modules match "$_query"', style: AppTextStyles.bodySecondary),
                            ],
                          ),
                        )
                      else
                        ModuleGrid(
                          tiles: [
                            for (var i = 0; i < filtered.length; i++)
                              ModuleIconCard(
                                label: filtered[i].label,
                                icon: filtered[i].icon,
                                color: _kTilePalette[i % _kTilePalette.length],
                                onTap: () => _navigate(filtered[i].path),
                                imageAsset: _kModuleImageByPath[filtered[i].path],
                              ),
                          ],
                        ),
                    ] else
                      _SectionedModules(
                        visibleNav: visibleNav,
                        onTap: _navigate,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The Menu's sectioned module list: one solid-teal [SectionHeader] followed
/// by its [ModuleGrid], repeated per section, all as normal scrolling
/// content inside the caller's ListView — not sticky, not pinned, no
/// separate floating header, no per-scroll recalculation of anything.
///
/// A plain, stateless, one-shot build. There used to be a whole scroll-
/// position-tracking StatefulWidget here driving a left-to-right color-fill
/// animation per header (GlobalKey + RenderBox measurement + a
/// ValueNotifier per section, recomputed on every scroll notification).
/// That doesn't belong: the reference design has no progressive fill at
/// all — every section header is simply always solid teal, the same way a
/// module card is simply always its own color, and it just scrolls with
/// its section like any other content. Removed entirely rather than
/// patched, since no amount of tuning the fill math fixes "there shouldn't
/// be a fill."
class _SectionedModules extends StatelessWidget {
  final List<NavEntry> visibleNav;
  final ValueChanged<String> onTap;

  const _SectionedModules({required this.visibleNav, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    var paletteIndex = 0;
    var pendingSectionTitle = '';
    var pendingItems = <NavItem>[];

    void flush() {
      if (pendingItems.isEmpty) return;
      final title = pendingSectionTitle;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: SectionHeader(title: title, imageAsset: _kSectionImage[title]),
      ));
      widgets.add(ModuleGrid(
        tiles: [
          for (final item in pendingItems)
            ModuleIconCard(
              label: item.label,
              icon: item.icon,
              color: _kTilePalette[(paletteIndex++) % _kTilePalette.length],
              onTap: () => onTap(item.path),
              badge: item.badge,
              imageAsset: _kModuleImageByPath[item.path],
            ),
        ],
      ));
      widgets.add(const SizedBox(height: AppSpacing.xl));
      pendingItems = [];
    }

    for (final entry in visibleNav) {
      switch (entry) {
        case NavSection():
          flush();
          pendingSectionTitle = entry.title;
        case NavItem():
          pendingItems.add(entry);
      }
    }
    flush();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}

/// The rounded, solid-teal section header — title + icon-in-circle. Always
/// rendered the same way regardless of scroll position; it scrolls with its
/// section as ordinary list content, exactly like a module card does.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? imageAsset;

  const SectionHeader({super.key, required this.title, required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: asset != null
                  ? Image.asset(asset, fit: BoxFit.contain)
                  : const Icon(_kSectionIconFallback, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String name;
  final String roleDisplay;
  final bool isDarkMode;
  final VoidCallback onProfileTap;
  final VoidCallback onThemeToggle;
  final VoidCallback onLogout;

  const _AccountRow({
    required this.name,
    required this.roleDisplay,
    required this.isDarkMode,
    required this.onProfileTap,
    required this.onThemeToggle,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.large,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onTap: onProfileTap,
            child: Row(
              children: [
                AppAvatar(name: name, radius: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isEmpty ? '—' : name,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        roleDisplay.isEmpty ? '—' : roleDisplay,
                        style: AppTextStyles.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
          Divider(height: AppSpacing.xxl, color: AppColors.border),
          Row(
            children: [
              Icon(
                isDarkMode ? Icons.wb_sunny_rounded : Icons.dark_mode_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(isDarkMode ? 'Switch to light mode' : 'Switch to dark mode', style: AppTextStyles.bodySmall),
              ),
              Switch.adaptive(value: isDarkMode, onChanged: (_) => onThemeToggle(), activeThumbColor: AppColors.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onTap: onLogout,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Sign out', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

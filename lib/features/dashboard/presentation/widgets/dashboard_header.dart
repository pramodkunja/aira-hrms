import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_spacing.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/shared/widgets/app_avatar.dart';

/// Slim, headerless-AppBar identity bar at the top of the Home dashboard —
/// real photo (falls back to initials), name, designation/role, a live
/// clock, and two circular action buttons (notifications, sign out).
///
/// The photo comes from myProfileProvider (the same self-service
/// `/employees/me/` data the Profile screen already fetches); this header
/// watches it independently so it still shows something (name + initials)
/// immediately from auth state while the photo loads in.
class DashboardHeader extends ConsumerWidget {
  final String name;
  final String roleDisplay;

  const DashboardHeader({super.key, required this.name, required this.roleDisplay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final designation = (profile?.designation ?? '').isNotEmpty ? profile!.designation : roleDisplay;
    final photoUrl = profile?.photoUrl;
    final hasPhoto = (photoUrl ?? '').isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
          child: hasPhoto
              ? null
              : Text(
                  initialsOf(name),
                  style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? 'there' : name,
                style: AppTextStyles.screenTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (designation.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  designation,
                  style: AppTextStyles.label.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 2),
              const _LiveClock(),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderCircleButton(child: NotificationBellButton(color: AppColors.primary)),
        const SizedBox(width: 10),
        _HeaderCircleButton(
          icon: Icons.logout_rounded,
          tooltip: 'Sign out',
          onTap: () => _handleLogout(context, ref),
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }
}

/// Light-teal circular icon button matching the reference's two action
/// buttons. Either [icon]+[onTap], or [child] to embed an existing
/// self-contained widget (NotificationBellButton owns its own tap handling).
class _HeaderCircleButton extends StatelessWidget {
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final Widget? child;

  const _HeaderCircleButton({this.icon, this.tooltip, this.onTap, this.child})
      : assert(child != null || (icon != null && onTap != null));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
      child: child ??
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Tooltip(
                message: tooltip ?? '',
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
            ),
          ),
    );
  }
}

/// "dd-MM-yyyy hh:mm:ss AM/PM", ticking every second — no `intl` dependency
/// in this app, so hand-rolled like every other date formatter already in
/// the codebase.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String get _formatted {
    final n = _now;
    final hour12 = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final period = n.hour < 12 ? 'AM' : 'PM';
    return '${_two(n.day)}-${_two(n.month)}-${n.year} ${_two(hour12)}:${_two(n.minute)}:${_two(n.second)} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted,
      style: AppTextStyles.caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

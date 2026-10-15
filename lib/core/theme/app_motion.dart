import 'package:flutter/material.dart';

/// Animation duration/curve tokens — extracted from what's already shipping:
/// the notification dropdown panel fades/scales in over 160ms
/// (`NotificationBellButton._openPanel`), and the attendance ring fill +
/// section loading skeleton both animate over 900ms
/// (`AttendanceRingCard`/`dashboard_section.dart`'s skeleton) — both already
/// using `Curves.easeOutCubic`, which is this codebase's one house curve.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 900);

  static const Curve standard = Curves.easeOutCubic;
}

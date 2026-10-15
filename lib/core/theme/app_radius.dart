import 'package:flutter/material.dart';

/// Corner-radius tokens — extracted from the values already shipping in the
/// redesigned Dashboard/Menu/Bottom-Nav (not invented): 8 (inputs/buttons —
/// `AppButton`, `AppTextField`), 12 (cards — `SectionCard`), 16 (tiles —
/// `ModuleIconCard`, `QuickTile`), 24 (hero cards — `ConsoleHeaderShell`),
/// 28 (floating sheets/bars — the Menu sheet's top corners, `AppBottomNav`'s
/// pill container).
class AppRadius {
  AppRadius._();

  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 24;
  static const double floating = 28;

  /// A radius large enough to always render fully round regardless of the
  /// element's height — use for pill-shaped badges/chips/buttons. Existing
  /// badges (e.g. status pills) use a fixed 20 today, which only reads as a
  /// pill because their height stays under ~40; this token is the
  /// height-independent equivalent for new code.
  static const double pill = 999;

  static BorderRadius get smallAll => BorderRadius.circular(small);
  static BorderRadius get mediumAll => BorderRadius.circular(medium);
  static BorderRadius get largeAll => BorderRadius.circular(large);
  static BorderRadius get extraLargeAll => BorderRadius.circular(extraLarge);
  static BorderRadius get pillAll => BorderRadius.circular(pill);

  /// Rounded-top-only corners, for bottom sheets (the Menu sheet).
  static BorderRadius get sheetTop => const BorderRadius.only(
        topLeft: Radius.circular(floating),
        topRight: Radius.circular(floating),
      );
}

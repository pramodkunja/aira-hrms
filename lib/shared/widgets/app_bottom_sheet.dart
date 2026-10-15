import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_radius.dart';

/// The rounded-top, drag-handle sheet chrome the Menu sheet already uses
/// (`MenuSheet`'s `DraggableScrollableSheet` builder) — extracted so any
/// future bottom sheet in the app starts from the exact same shell instead
/// of re-inlining the corner radius/handle/background.
///
/// Pass [scrollable] to wrap a [DraggableScrollableSheet] (the Menu sheet's
/// case, where content needs its own `scrollController`); omit it for a
/// fixed-height sheet that just needs the same chrome around plain content.
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const AppBottomSheet({super.key, required this.child, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.background,
        borderRadius: AppRadius.sheetTop,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }

  /// Shows [content] (typically built with a `scrollController` the caller
  /// wires into a scrollable) inside this chrome via
  /// [DraggableScrollableSheet] — the pattern `showMenuSheet` uses.
  static Future<T?> showDraggable<T>(
    BuildContext context, {
    required Widget Function(BuildContext context, ScrollController scrollController) builder,
    double initialChildSize = 0.86,
    double minChildSize = 0.5,
    double maxChildSize = 0.95,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) => AppBottomSheet(
          child: builder(context, scrollController),
        ),
      ),
    );
  }
}

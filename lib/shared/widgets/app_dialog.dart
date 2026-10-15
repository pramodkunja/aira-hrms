import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_radius.dart';

/// Confirmation-dialog helper — extracted from `DashboardShell`'s "Exit
/// Application?" dialog (the app's one existing confirm dialog at the time
/// of this consolidation) so any future destructive/confirm action reuses
/// the same shape, rounded corners, and button styling.
class AppDialog {
  AppDialog._();

  /// Shows a Cancel/confirm dialog, returning `true` only if the confirm
  /// action was tapped (`null`/`false` for dismissed or Cancel).
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: isDestructive ? AppColors.error : AppColors.primary),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }
}

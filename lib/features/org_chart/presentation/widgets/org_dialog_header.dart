import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Shared header for every Org Chart edit dialog/sheet (Add Org Unit,
/// Manage Job Templates, Add Position, Assign Holder, Unit/Position edit) —
/// one look for the whole feature instead of each sheet hand-rolling its own.
class OrgDialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  const OrgDialogHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Opens [child] as the standard Org Chart dialog (centered card, dismiss
/// on close button only) — the same showDialog/Dialog wrapping every sheet
/// in this feature uses, factored out so call sites are one line.
Future<void> showOrgDialog(BuildContext context, Widget child) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: child,
    ),
  );
}

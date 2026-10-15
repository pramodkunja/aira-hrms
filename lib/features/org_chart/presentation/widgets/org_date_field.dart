import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

String todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _isoOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _displayOf(String iso) {
  if (iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

/// A tap-to-open-date-picker text field, ISO (YYYY-MM-DD) in, ISO out —
/// used everywhere the Org Chart's holder/placement flows need a date
/// (Assign holder's effective from/to, Vacate's last day).
class OrgDateField extends StatelessWidget {
  final String label;
  final bool required;
  final String isoValue;
  final String? error;
  final ValueChanged<String> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final VoidCallback? onClear;

  const OrgDateField({
    super.key,
    required this.label,
    this.required = true,
    required this.isoValue,
    this.error,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.onClear,
  });

  Future<void> _pick(BuildContext context) async {
    final initial = DateTime.tryParse(isoValue) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (picked != null) onChanged(_isoOf(picked));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          errorText: error,
          labelStyle: AppTextStyles.caption,
          suffixIcon: onClear != null && isoValue.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClear)
              : const Icon(Icons.calendar_today_outlined, size: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          isoValue.isEmpty ? '—' : _displayOf(isoValue),
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_radius.dart';
import 'package:mobile_app/core/theme/app_spacing.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';

/// The rounded, filled search field used by the Menu sheet ("What are you
/// looking for?"). Generalizes what was inline `TextField` + `InputDecoration`
/// there — and the same look `heroSearchFieldDecoration`
/// (`shared/widgets/blue_hero_banner.dart`) already gives list/directory
/// screens' hero search bars — into one reusable widget so any future
/// screen's search bar (not just ones living inside a `BlueHeroBanner`)
/// matches exactly.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final showClear = controller.text.isNotEmpty;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
        prefixIcon: Icon(Icons.search, color: AppColors.textHint),
        suffixIcon: showClear
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
      ),
    );
  }
}

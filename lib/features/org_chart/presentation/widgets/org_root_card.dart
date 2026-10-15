import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The top-of-tree unit's chief position — whoever holds it is the
/// company/branch head. [holderName] is null when that chief seat is
/// vacant (or the top unit has no chief position at all), which is a
/// perfectly normal state (see OrgStructureClient's own "seat can stay
/// vacant" note) — shown as "Vacant" rather than hidden or guessed at.
class OrgRootCard extends StatelessWidget {
  final String unitName;
  final String? title;
  final String? holderName;
  final VoidCallback? onTap;
  final VoidCallback onEditUnit;

  const OrgRootCard({
    super.key,
    required this.unitName,
    this.title,
    this.holderName,
    this.onTap,
    required this.onEditUnit,
  });

  @override
  Widget build(BuildContext context) {
    final isVacant = holderName == null || holderName!.isEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isVacant ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    unitName.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onEditUnit,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.edit_outlined, size: 13, color: AppColors.textHint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isVacant ? 'Vacant' : holderName!,
                style: AppTextStyles.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: isVacant ? AppColors.textHint : null,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isVacant && title != null && title!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  title!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

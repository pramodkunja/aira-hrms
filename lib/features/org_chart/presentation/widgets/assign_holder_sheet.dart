import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';
import 'org_date_field.dart';
import 'org_dialog_header.dart';

/// "Assign holder" / "Reassign holder" — matches web's AssignHolderModal.
class AssignHolderSheet extends ConsumerStatefulWidget {
  final OrgPositionEntity position;
  const AssignHolderSheet({super.key, required this.position});

  @override
  ConsumerState<AssignHolderSheet> createState() => _AssignHolderSheetState();
}

class _AssignHolderSheetState extends ConsumerState<AssignHolderSheet> {
  String? _employeeUuid;
  String _effectiveFrom = todayIso();
  String _effectiveTo = '';
  String? _employeeError;
  String? _dateError;
  String? _submitError;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.position;
    final employeesAsync = ref.watch(orgChartEmployeeOptionsProvider);
    final isReassign = !p.isVacant;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrgDialogHeader(
            icon: Icons.person_search_outlined,
            title: isReassign ? 'Reassign Holder' : 'Assign Holder',
            subtitle: '${p.title} · ${p.orgUnitName}',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_submitError != null) ...[
                      _ErrorBanner(message: _submitError!),
                      const SizedBox(height: 12),
                    ],
                    employeesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => Text('Could not load employees.', style: AppTextStyles.bodySmall),
                      data: (employees) => DropdownButtonFormField<String>(
                        initialValue: _employeeUuid,
                        isExpanded: true,
                        style: AppTextStyles.body,
                        decoration: _dec('Employee', error: _employeeError),
                        items: employees
                            .map((e) => DropdownMenuItem(
                                  value: e.uuid,
                                  child: Text('${e.fullName} (${e.employeeId})', overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _employeeUuid = v;
                          _employeeError = null;
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OrgDateField(
                      label: 'Effective From',
                      isoValue: _effectiveFrom,
                      error: _dateError,
                      onChanged: (v) => setState(() {
                        _effectiveFrom = v;
                        _dateError = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    OrgDateField(
                      label: 'Effective To',
                      required: false,
                      isoValue: _effectiveTo,
                      firstDate: DateTime.tryParse(_effectiveFrom),
                      onClear: () => setState(() => _effectiveTo = ''),
                      onChanged: (v) => setState(() => _effectiveTo = v),
                    ),
                    if (p.holderName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${p.holderName}'s placement will be closed the day before the new start "
                          'date and kept in history.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      "Placing a person on a chief position makes them the unit's head automatically, "
                      'as of the effective date above. A future-dated start schedules the change '
                      "without affecting today's holder.",
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isReassign ? 'Reassign' : 'Assign',
                              style: AppTextStyles.label.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, {String? error}) => InputDecoration(
    labelText: label,
    errorText: error,
    labelStyle: AppTextStyles.caption,
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
  );

  Future<void> _submit() async {
    if (_employeeUuid == null || _employeeUuid!.isEmpty) {
      setState(() => _employeeError = 'Pick an employee.');
      return;
    }
    if (_effectiveFrom.isEmpty) {
      setState(() => _dateError = 'Effective from is required.');
      return;
    }
    if (_effectiveTo.isNotEmpty && _effectiveTo.compareTo(_effectiveFrom) < 0) {
      setState(() => _dateError = "Effective to can't be before effective from.");
      return;
    }
    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).assignHolder(
            widget.position.id,
            employeeUuid: _employeeUuid!,
            effectiveFrom: _effectiveFrom,
            effectiveTo: _effectiveTo.isEmpty ? null : _effectiveTo,
          );
      await ref.read(orgChartProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _submitError = userFriendlyMessage(e);
      });
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
    );
  }
}

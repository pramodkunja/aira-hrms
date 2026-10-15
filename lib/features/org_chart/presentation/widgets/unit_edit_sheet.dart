import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';
import 'add_position_sheet.dart';
import 'assign_holder_sheet.dart';
import 'org_dialog_header.dart';
import 'position_edit_sheet.dart';

/// "Org unit" detail + edit — matches web's OrgDetail (selected.type ===
/// "unit") field-for-field: head-of-unit box, editable name/code/parent/
/// cost_center, the is-department-level toggle (with its 409-confirm
/// flow), the positions list with an Add Position action, and delete.
class UnitEditSheet extends ConsumerStatefulWidget {
  final String unitId;
  const UnitEditSheet({super.key, required this.unitId});

  @override
  ConsumerState<UnitEditSheet> createState() => _UnitEditSheetState();
}

class _UnitEditSheetState extends ConsumerState<UnitEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _costCenterCtrl;
  String? _parentId;
  bool _initialized = false;
  bool _saving = false;
  bool _actionBusy = false;
  String? _error;

  void _syncFrom(OrgUnitEntity u) {
    _nameCtrl.text = u.name;
    _codeCtrl.text = u.code;
    _costCenterCtrl.text = '';
    _parentId = u.parentId;
    _initialized = true;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _codeCtrl = TextEditingController();
    _costCenterCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _costCenterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final structure = ref.watch(orgChartProvider).valueOrNull;
    final unit = structure?.units.where((u) => u.id == widget.unitId).firstOrNull;
    if (unit == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrgDialogHeader(icon: Icons.account_tree_outlined, title: 'Org Unit', onClose: () => Navigator.pop(context)),
            const Padding(padding: EdgeInsets.all(24), child: Text('This org unit no longer exists.')),
          ],
        ),
      );
    }
    if (!_initialized) _syncFrom(unit);

    final positions = structure?.positions.where((p) => p.orgUnitId == unit.id).toList() ?? const [];
    final chief = positions.where((p) => p.isChief).firstOrNull;
    final filled = positions.where((p) => !p.isVacant).length;
    final parentOptions = structure?.units.where((u) => u.id != unit.id).toList() ?? const [];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrgDialogHeader(
            icon: Icons.account_tree_outlined,
            title: unit.name,
            subtitle: unit.code.isEmpty ? 'Org unit' : 'Org unit · ${unit.code}',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      _ErrorBanner(message: _error!),
                      const SizedBox(height: 12),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _actionBusy ? null : () => _confirmDelete(unit),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppColors.error,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete org unit',
                      ),
                    ),
                    _SectionTitle('Head of Unit'),
                    if (chief == null)
                      _HeadOfUnitBox(
                        vacant: true,
                        label: 'No chief position yet',
                        actionLabel: 'Add chief position',
                        onAction: _actionBusy ? null : () => _addChiefPosition(unit, hasChief: false),
                      )
                    else if (chief.holderName != null)
                      _HeadOfUnitBox(
                        vacant: false,
                        label: chief.holderName!,
                        role: 'Head of unit · ${chief.title}${chief.holderSince != null ? " · since ${chief.holderSince}" : ""}',
                        actionLabel: 'Open position',
                        onAction: () => _openPosition(chief.id),
                      )
                    else
                      _HeadOfUnitBox(
                        vacant: true,
                        label: 'Vacant — no holder',
                        role: 'Head of unit · ${chief.title}',
                        actionLabel: 'Assign holder',
                        onAction: _actionBusy ? null : () => _assignChief(chief),
                      ),
                    _SectionTitle('Details'),
                    TextFormField(
                      controller: _nameCtrl,
                      style: AppTextStyles.body,
                      decoration: _dec('Unit name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeCtrl,
                      style: AppTextStyles.body,
                      decoration: _dec('Code'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: parentOptions.any((u) => u.id == _parentId) ? _parentId : null,
                      isExpanded: true,
                      style: AppTextStyles.body,
                      decoration: _dec('Parent unit'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('None — top level')),
                        ...parentOptions.map((u) => DropdownMenuItem<String?>(value: u.id, child: Text(u.name))),
                      ],
                      onChanged: (v) => setState(() => _parentId = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _costCenterCtrl,
                      style: AppTextStyles.body,
                      decoration: _dec('Cost center (optional)'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : () => _saveDetails(unit),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Save Details', style: AppTextStyles.label.copyWith(color: Colors.white)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.label.copyWith(fontSize: 13, color: AppColors.textPrimary),
                              children: const [
                                TextSpan(text: 'This unit counts as a '),
                                TextSpan(text: 'department', style: TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' for leave eligibility and reporting.'),
                              ],
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: unit.isDepartmentLevel,
                          onChanged: _actionBusy ? null : (v) => _toggleDepartmentLevel(unit, v),
                          activeTrackColor: AppColors.success,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _SectionTitleExpanded('Positions in This Unit'),
                        TextButton.icon(
                          onPressed: () => _openAddPosition(unit, positions),
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text('Add Position'),
                        ),
                      ],
                    ),
                    if (positions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('No positions yet in this unit.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
                      )
                    else
                      ...positions.map((p) => _PositionListRow(position: p, onTap: () => _openPosition(p.id))),
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                      child: Row(
                        children: [
                          _StatBlock(value: positions.length, label: 'positions'),
                          const SizedBox(width: 20),
                          _StatBlock(value: filled, label: 'filled'),
                          const SizedBox(width: 20),
                          _StatBlock(value: positions.length - filled, label: 'vacant'),
                        ],
                      ),
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

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
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
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _openPosition(String positionId) {
    return showOrgDialog(context, PositionEditSheet(positionId: positionId));
  }

  Future<void> _openAddPosition(OrgUnitEntity unit, List<OrgPositionEntity> positions) {
    final hasChief = positions.any((p) => p.isChief);
    return showOrgDialog(context, AddPositionSheet(unit: unit, hasChief: hasChief));
  }

  Future<void> _addChiefPosition(OrgUnitEntity unit, {required bool hasChief}) {
    return showOrgDialog(context, AddPositionSheet(unit: unit, hasChief: hasChief));
  }

  Future<void> _assignChief(OrgPositionEntity chief) {
    return showOrgDialog(context, AssignHolderSheet(position: chief));
  }

  Future<void> _saveDetails(OrgUnitEntity unit) async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Unit name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).updateUnit(unit.id, {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().toUpperCase(),
        'parent': _parentId,
        'cost_center': _costCenterCtrl.text.trim().toUpperCase(),
      });
      await ref.read(orgChartProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Unit updated.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Turning off is_department_level can 409 with an "N employees affected"
  // message — matches web's confirm-then-resubmit-with-confirm_department_change flow.
  Future<void> _toggleDepartmentLevel(OrgUnitEntity unit, bool value) async {
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).updateUnit(unit.id, {'is_department_level': value});
      await ref.read(orgChartProvider.notifier).refresh();
    } on DioException catch (dioError) {
      final parsed = parseDioException(dioError);
      if (parsed.statusCode != 409) {
        if (mounted) setState(() => _error = parsed.message);
        if (mounted) setState(() => _actionBusy = false);
        return;
      }
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Confirm change'),
          content: Text('${parsed.message}\n\nProceed anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Proceed')),
          ],
        ),
      );
      if (proceed == true) {
        try {
          await ref.read(orgChartRepositoryProvider).updateUnit(
            unit.id,
            {'is_department_level': value, 'confirm_department_change': true},
          );
          await ref.read(orgChartProvider.notifier).refresh();
        } catch (e) {
          if (mounted) setState(() => _error = userFriendlyMessage(e));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _confirmDelete(OrgUnitEntity unit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Org Unit?'),
        content: Text(
          'Permanently delete "${unit.name}"? This can\'t be undone, and only works if it has no '
          'sub-units and no position in it has ever been held by anyone — if any have, this will be '
          'rejected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).deleteUnit(unit.id);
      await ref.read(orgChartProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionBusy = false;
          _error = userFriendlyMessage(e);
        });
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppColors.border)),
        ],
      ),
    );
  }
}

class _SectionTitleExpanded extends StatelessWidget {
  final String text;
  const _SectionTitleExpanded(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textHint,
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _HeadOfUnitBox extends StatelessWidget {
  final bool vacant;
  final String label;
  final String? role;
  final String actionLabel;
  final VoidCallback? onAction;

  const _HeadOfUnitBox({
    required this.vacant,
    required this.label,
    this.role,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: vacant ? AppColors.warning.withValues(alpha: 0.08) : AppColors.background,
        border: Border.all(color: vacant ? AppColors.warning : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              vacant ? Icons.person_off_outlined : Icons.person_outline,
              color: vacant ? AppColors.warning : AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (role != null)
                  Text(role!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: vacant ? AppColors.warning : AppColors.textPrimary,
                    fontStyle: vacant ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _PositionListRow extends StatelessWidget {
  final OrgPositionEntity position;
  final VoidCallback onTap;
  const _PositionListRow({required this.position, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
              child: Center(
                child: Text('S', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(position.title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (position.isChief) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.workspace_premium, size: 12, color: AppColors.warning),
                      ],
                    ],
                  ),
                  Text(
                    position.holderName ?? 'Vacant',
                    style: AppTextStyles.caption.copyWith(
                      color: position.holderName == null ? AppColors.warning : AppColors.textSecondary,
                      fontStyle: position.holderName == null ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final int value;
  final String label;
  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
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

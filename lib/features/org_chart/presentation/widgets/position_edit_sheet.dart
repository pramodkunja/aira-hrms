import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';
import 'assign_holder_sheet.dart';
import 'org_date_field.dart';
import 'org_dialog_header.dart';

/// "Position" detail + edit — matches web's OrgDetail (selected.type ===
/// "position") field-for-field: holder box (assign/reassign/vacate),
/// scheduled-placement banner, reports-to (read-only), editable
/// title/grade/org_unit/job_template/branch, is-chief toggle, deactivate/
/// reactivate, delete, placement history.
class PositionEditSheet extends ConsumerStatefulWidget {
  final String positionId;
  const PositionEditSheet({super.key, required this.positionId});

  @override
  ConsumerState<PositionEditSheet> createState() => _PositionEditSheetState();
}

class _PositionEditSheetState extends ConsumerState<PositionEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _gradeCtrl;
  String? _orgUnitId;
  String? _jobTemplateId;
  int? _branchId;
  bool _initialized = false;
  bool _saving = false;
  bool _actionBusy = false;
  String? _error;

  void _syncFrom(OrgPositionEntity p) {
    _titleCtrl.text = p.title;
    _gradeCtrl.text = p.grade;
    _orgUnitId = p.orgUnitId;
    _jobTemplateId = p.jobTemplateId;
    _branchId = p.branch;
    _initialized = true;
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _gradeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final structure = ref.watch(orgChartProvider).valueOrNull;
    final position = structure?.positions.where((p) => p.id == widget.positionId).firstOrNull;
    if (position == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrgDialogHeader(icon: Icons.badge_outlined, title: 'Position', onClose: () => Navigator.pop(context)),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('This position no longer exists.'),
            ),
          ],
        ),
      );
    }
    if (!_initialized) _syncFrom(position);

    final units = structure?.units ?? const <OrgUnitEntity>[];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrgDialogHeader(
            icon: Icons.badge_outlined,
            title: position.title,
            subtitle: 'Position · ${position.orgUnitName}',
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
                    Row(
                      children: [
                        if (position.isChief) ...[
                          Icon(Icons.workspace_premium, size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                        ],
                        if (!position.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.textHint.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Inactive', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                          ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _actionBusy ? null : () => _toggleActive(position),
                          icon: Icon(position.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                          label: Text(position.isActive ? 'Deactivate' : 'Reactivate'),
                        ),
                        IconButton(
                          onPressed: _actionBusy ? null : () => _confirmDelete(position),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: AppColors.error,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete position',
                        ),
                      ],
                    ),
                    _SectionTitle('Holder'),
                    _HolderBox(
                      position: position,
                      busy: _actionBusy,
                      onAssign: () => _openAssign(position),
                      onVacate: () => _vacate(position),
                    ),
                    if (position.scheduled != null) ...[
                      const SizedBox(height: 10),
                      _ScheduledBanner(
                        scheduled: position.scheduled!,
                        busy: _actionBusy,
                        onCancel: () => _cancelScheduled(position.scheduled!.placementId),
                      ),
                    ],
                    _SectionTitle('Reporting'),
                    TextFormField(
                      enabled: false,
                      initialValue: position.reportsTo == null
                          ? '—'
                          : '${position.reportsTo!.holderName ?? "Vacant"} · ${position.reportsTo!.title}',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      decoration: _dec('Reports to'),
                    ),
                    _SectionTitle('Details'),
                    TextFormField(
                      controller: _titleCtrl,
                      style: AppTextStyles.body,
                      decoration: _dec('Position title'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gradeCtrl,
                      style: AppTextStyles.body,
                      decoration: _dec('Grade / band'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: units.any((u) => u.id == _orgUnitId) ? _orgUnitId : null,
                      isExpanded: true,
                      style: AppTextStyles.body,
                      decoration: _dec('Org unit'),
                      items: units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                      onChanged: (v) => setState(() => _orgUnitId = v),
                    ),
                    const SizedBox(height: 12),
                    Consumer(builder: (context, ref, _) {
                      final jobsAsync = ref.watch(orgChartJobTemplatesProvider);
                      return jobsAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (jobs) => DropdownButtonFormField<String?>(
                          initialValue: jobs.any((j) => j.id == _jobTemplateId) ? _jobTemplateId : null,
                          isExpanded: true,
                          style: AppTextStyles.body,
                          decoration: _dec('Job template'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('None')),
                            ...jobs.map((j) => DropdownMenuItem<String?>(
                                  value: j.id,
                                  child: Text(j.band.isEmpty ? j.name : '${j.name} · ${j.band}'),
                                )),
                          ],
                          onChanged: (v) => setState(() => _jobTemplateId = v),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Consumer(builder: (context, ref, _) {
                      final branchesAsync = ref.watch(orgChartBranchesProvider);
                      return branchesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (branches) => DropdownButtonFormField<int?>(
                          initialValue: _branchId,
                          isExpanded: true,
                          style: AppTextStyles.body,
                          decoration: _dec('Branch (optional — company-wide if unset)'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Company-wide')),
                            ...branches.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                          ],
                          onChanged: (v) => setState(() => _branchId = v),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : () => _saveDetails(position),
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
                              children: [
                                const TextSpan(text: 'This position is the '),
                                const TextSpan(text: 'head', style: TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' of ${position.orgUnitName}.'),
                              ],
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: position.isChief,
                          onChanged: _actionBusy ? null : (_) => _toggleChief(position),
                          activeTrackColor: AppColors.success,
                        ),
                      ],
                    ),
                    _SectionTitle('Placement History'),
                    Consumer(builder: (context, ref, _) {
                      final placementsAsync = ref.watch(orgChartPlacementsProvider(position.id));
                      return placementsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, __) => Text('Could not load placement history.', style: AppTextStyles.bodySmall),
                        data: (placements) => placements.isEmpty
                            ? Text('No placements yet on this seat.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint))
                            : Column(
                                children: placements.map((pl) => _PlacementRow(placement: pl)).toList(),
                              ),
                      );
                    }),
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
    disabledBorder: OutlineInputBorder(
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

  Future<void> _openAssign(OrgPositionEntity position) async {
    await showOrgDialog(context, AssignHolderSheet(position: position));
  }

  Future<void> _vacate(OrgPositionEntity position) async {
    var lastDay = todayIso();
    String? dateError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('End Placement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${position.title} — currently held by ${position.holderName ?? ""}',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 14),
              OrgDateField(
                label: 'Last Day',
                isoValue: lastDay,
                error: dateError,
                firstDate: DateTime.tryParse(position.holderSince ?? ''),
                onChanged: (v) => setDialogState(() {
                  lastDay = v;
                  dateError = null;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('End Placement'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).endPlacement(position.id, effectiveTo: lastDay);
      await ref.read(orgChartProvider.notifier).refresh();
      ref.invalidate(orgChartPlacementsProvider(position.id));
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _cancelScheduled(String placementId) async {
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).cancelPlacement(placementId);
      await ref.read(orgChartProvider.notifier).refresh();
      ref.invalidate(orgChartPlacementsProvider(widget.positionId));
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleActive(OrgPositionEntity position) async {
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      final repo = ref.read(orgChartRepositoryProvider);
      if (position.isActive) {
        await repo.deactivatePosition(position.id);
      } else {
        await repo.activatePosition(position.id);
      }
      await ref.read(orgChartProvider.notifier).refresh();
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _toggleChief(OrgPositionEntity position) async {
    setState(() {
      _actionBusy = true;
      _error = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).updatePosition(position.id, {'is_chief': !position.isChief});
      await ref.read(orgChartProvider.notifier).refresh();
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _saveDetails(OrgPositionEntity position) async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Position title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).updatePosition(position.id, {
        'title': _titleCtrl.text.trim(),
        'grade': _gradeCtrl.text.trim().toUpperCase(),
        'org_unit': _orgUnitId,
        'job_template': _jobTemplateId,
        'branch': _branchId,
      });
      await ref.read(orgChartProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Position updated.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(OrgPositionEntity position) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Position?'),
        content: Text(
          'Permanently delete "${position.title}"? This can\'t be undone, and only works if it has '
          "never had a holder — if it has any placement history, this will be rejected; deactivate it "
          'instead.',
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
      await ref.read(orgChartRepositoryProvider).deletePosition(position.id);
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

class _HolderBox extends StatelessWidget {
  final OrgPositionEntity position;
  final bool busy;
  final VoidCallback onAssign;
  final VoidCallback onVacate;

  const _HolderBox({required this.position, required this.busy, required this.onAssign, required this.onVacate});

  @override
  Widget build(BuildContext context) {
    final vacant = position.isVacant;
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
                Text(
                  vacant ? 'Vacant' : (position.holderSince != null ? 'Since ${position.holderSince}' : 'Current holder'),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  vacant ? 'No holder' : (position.holderName ?? ''),
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: vacant ? AppColors.warning : AppColors.textPrimary,
                    fontStyle: vacant ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (vacant)
            TextButton(onPressed: busy ? null : onAssign, child: const Text('Assign'))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: busy ? null : onAssign, child: const Text('Reassign')),
                TextButton(onPressed: busy ? null : onVacate, child: const Text('Vacate')),
              ],
            ),
        ],
      ),
    );
  }
}

class _ScheduledBanner extends StatelessWidget {
  final ScheduledPlacementEntity scheduled;
  final bool busy;
  final VoidCallback onCancel;
  const _ScheduledBanner({required this.scheduled, required this.busy, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontSize: 12),
                children: [
                  TextSpan(text: scheduled.employeeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' is scheduled to take this seat on '),
                  TextSpan(text: scheduled.effectiveFrom, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          TextButton(onPressed: busy ? null : onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _PlacementRow extends StatelessWidget {
  final PlacementEntity placement;
  const _PlacementRow({required this.placement});

  @override
  Widget build(BuildContext context) {
    final badge = switch (placement.status) {
      'current' => (label: 'Current', color: AppColors.success),
      'scheduled' => (label: 'Scheduled', color: AppColors.warning),
      _ => (label: 'Ended', color: AppColors.textHint),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(placement.employeeName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${placement.effectiveFrom} – ${placement.effectiveTo ?? "present"}'
                  '${placement.note.isNotEmpty ? " · ${placement.note}" : ""}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: badge.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(badge.label, style: AppTextStyles.caption.copyWith(color: badge.color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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

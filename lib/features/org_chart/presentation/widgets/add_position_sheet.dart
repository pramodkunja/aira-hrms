import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';
import 'org_dialog_header.dart';

/// "Add position" — matches web's AddPositionModal exactly (title, job
/// template, grade, branch, and an is-chief toggle defaulting on only when
/// the unit has no chief yet).
class AddPositionSheet extends ConsumerStatefulWidget {
  final OrgUnitEntity unit;
  final bool hasChief;
  const AddPositionSheet({super.key, required this.unit, required this.hasChief});

  @override
  ConsumerState<AddPositionSheet> createState() => _AddPositionSheetState();
}

class _AddPositionSheetState extends ConsumerState<AddPositionSheet> {
  final _titleCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  String? _jobTemplateId;
  int? _branchId;
  late bool _isChief;
  String? _titleError;
  String? _submitError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isChief = !widget.hasChief;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(orgChartJobTemplatesProvider);
    final branchesAsync = ref.watch(orgChartBranchesProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrgDialogHeader(
            icon: Icons.badge_outlined,
            title: 'Add Position',
            subtitle: 'In ${widget.unit.name}',
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.06),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_submitError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                      ),
                    ],
                    TextFormField(
                      controller: _titleCtrl,
                      style: AppTextStyles.body,
                      autofocus: true,
                      onChanged: (_) => setState(() => _titleError = null),
                      decoration: _dec('Position Title *', _titleError),
                    ),
                    const SizedBox(height: 12),
                    jobsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (jobs) => DropdownButtonFormField<String?>(
                        initialValue: _jobTemplateId,
                        isExpanded: true,
                        style: AppTextStyles.body,
                        decoration: _dec('Job Template'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None')),
                          ...jobs.where((j) => j.isActive).map((j) => DropdownMenuItem<String?>(
                                value: j.id,
                                child: Text(j.band.isEmpty ? j.name : '${j.name} · ${j.band}'),
                              )),
                        ],
                        onChanged: (v) => setState(() => _jobTemplateId = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gradeCtrl,
                      style: AppTextStyles.body,
                      decoration: _dec('Grade / Band (optional)'),
                    ),
                    const SizedBox(height: 12),
                    branchesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (branches) => DropdownButtonFormField<int?>(
                        initialValue: _branchId,
                        isExpanded: true,
                        style: AppTextStyles.body,
                        decoration: _dec('Branch (optional — leave unset for company-wide)'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Company-wide')),
                          ...branches.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                        ],
                        onChanged: (v) => setState(() => _branchId = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChiefToggle(
                      value: _isChief,
                      onChanged: (v) => setState(() => _isChief = v),
                      hint: widget.hasChief
                          ? 'This unit already has a chief; turning this on will replace it.'
                          : 'This unit has no head yet.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The position is created vacant. Assign a holder once someone is hired.',
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
                          : Text('Create Position', style: AppTextStyles.label.copyWith(color: Colors.white)),
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

  InputDecoration _dec(String label, [String? error]) => InputDecoration(
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
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _titleError = 'Position title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).createPosition({
        'org_unit': widget.unit.id,
        'job_template': _jobTemplateId,
        'title': _titleCtrl.text.trim(),
        'grade': _gradeCtrl.text.trim().toUpperCase(),
        'is_chief': _isChief,
        'branch': _branchId,
      });
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

class _ChiefToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String hint;
  const _ChiefToggle({required this.value, required this.onChanged, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.label.copyWith(fontSize: 13, color: AppColors.textPrimary),
                  children: const [
                    TextSpan(text: 'Make this the '),
                    TextSpan(text: 'head', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' of the unit.'),
                  ],
                ),
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppColors.success),
          ],
        ),
        Text(hint, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      ],
    );
  }
}

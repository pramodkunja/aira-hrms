import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/org_chart_form_data.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';

/// "Manage job templates" — matches web's ManageJobTemplatesModal: an add
/// row (name + band), then a list with an active/inactive toggle and a
/// delete action per row. Deleting one the backend still uses on a
/// position 409s with a clear message (surfaced via the same error banner
/// every other mutation on this screen uses) rather than silently failing.
class ManageJobTemplatesSheet extends ConsumerStatefulWidget {
  const ManageJobTemplatesSheet({super.key});

  @override
  ConsumerState<ManageJobTemplatesSheet> createState() => _ManageJobTemplatesSheetState();
}

class _ManageJobTemplatesSheetState extends ConsumerState<ManageJobTemplatesSheet> {
  final _nameCtrl = TextEditingController();
  final _bandCtrl = TextEditingController();
  bool _adding = false;
  String? _addError;
  String? _busyId;
  String? _rowError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(orgChartJobTemplatesProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(onClose: () => Navigator.pop(context)),
          Flexible(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reusable job titles offered when adding a position. Deactivate a '
                    "template to stop offering it for new positions without losing "
                    'history on positions that already use it.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameCtrl,
                          style: AppTextStyles.body,
                          onChanged: (_) => setState(() => _addError = null),
                          decoration: _dec('Name', _addError),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _bandCtrl,
                          style: AppTextStyles.body,
                          decoration: _dec('Band'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _adding ? null : _addTemplate,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _adding
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  if (_rowError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.06),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_rowError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Flexible(
                    child: templatesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('Could not load job templates.', style: AppTextStyles.bodySmall),
                      ),
                      data: (templates) => templates.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('No job templates yet.',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint)),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: templates.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _TemplateRow(
                                template: templates[i],
                                busy: _busyId == templates[i].id,
                                onToggleActive: (v) => _setActive(templates[i], v),
                                onDelete: () => _remove(templates[i]),
                              ),
                            ),
                    ),
                  ),
                ],
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

  Future<void> _addTemplate() async {
    final form = JobTemplateFormData(name: _nameCtrl.text, band: _bandCtrl.text);
    final error = form.validate();
    if (error != null) {
      setState(() => _addError = error);
      return;
    }
    setState(() {
      _adding = true;
      _rowError = null;
    });
    final result = await ref.read(orgChartJobTemplatesProvider.notifier).create(form);
    if (!mounted) return;
    setState(() => _adding = false);
    if (result == null) {
      _nameCtrl.clear();
      _bandCtrl.clear();
    } else {
      setState(() => _addError = result);
    }
  }

  Future<void> _setActive(JobTemplateEntity template, bool isActive) async {
    setState(() {
      _busyId = template.id;
      _rowError = null;
    });
    final result = await ref.read(orgChartJobTemplatesProvider.notifier).setActive(template.id, isActive);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      if (result != null) _rowError = result;
    });
  }

  Future<void> _remove(JobTemplateEntity template) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete job template?'),
        content: Text('Delete "${template.name}"? This can\'t be undone.'),
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
      _busyId = template.id;
      _rowError = null;
    });
    final result = await ref.read(orgChartJobTemplatesProvider.notifier).remove(template.id);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      if (result != null) _rowError = result;
    });
  }
}

class _TemplateRow extends StatelessWidget {
  final JobTemplateEntity template;
  final bool busy;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  const _TemplateRow({
    required this.template,
    required this.busy,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                if (template.band.isNotEmpty)
                  Text(template.band, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: template.isActive,
            onChanged: busy ? null : onToggleActive,
            activeTrackColor: AppColors.success,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.error,
            visualDensity: VisualDensity.compact,
            onPressed: busy ? null : onDelete,
          ),
        ],
      ),
    );
  }
}

class _DlgHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _DlgHeader({required this.onClose});

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
            child: const Icon(Icons.work_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Manage Job Templates',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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

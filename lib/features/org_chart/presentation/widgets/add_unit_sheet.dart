import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/org_chart_form_data.dart';
import '../../domain/entities/org_chart_entity.dart';
import '../providers/org_chart_providers.dart';

/// "Add org unit" — matches web's AddUnitModal field-for-field (name, code,
/// parent, cost center). No head/is_department_level here by design: you
/// don't assign a head at creation, and department-level is toggled later
/// from the unit's own detail view on web — this screen is a read-only
/// viewer plus creation, not a full editor.
class AddUnitSheet extends ConsumerStatefulWidget {
  const AddUnitSheet({super.key});

  @override
  ConsumerState<AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends ConsumerState<AddUnitSheet> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _costCenterCtrl = TextEditingController();
  String? _parentId;
  String? _nameError;
  bool _saving = false;
  String? _submitError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _costCenterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(orgChartProvider).valueOrNull?.units ?? const <OrgUnitEntity>[];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(
            icon: Icons.account_tree_outlined,
            title: 'Add Org Unit',
            subtitle: 'Organise your company structure',
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
                      controller: _nameCtrl,
                      style: AppTextStyles.body,
                      autofocus: true,
                      onChanged: (_) => setState(() => _nameError = null),
                      decoration: _dec('Unit Name *', _nameError),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeCtrl,
                      style: AppTextStyles.body,
                      decoration: _dec('Code (optional)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _parentId,
                      style: AppTextStyles.body,
                      isExpanded: true,
                      decoration: _dec('Parent Unit'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('None — top level')),
                        ...units.map((u) => DropdownMenuItem<String?>(value: u.id, child: Text(u.name))),
                      ],
                      onChanged: (v) => setState(() => _parentId = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _costCenterCtrl,
                      style: AppTextStyles.body,
                      decoration: _dec('Cost Center (optional)'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You don't assign a head here. Add a position next, then mark it chief.",
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
                          : Text('Create Unit', style: AppTextStyles.label.copyWith(color: Colors.white)),
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
    final form = OrgUnitFormData(
      name: _nameCtrl.text,
      code: _codeCtrl.text,
      parentId: _parentId,
      costCenter: _costCenterCtrl.text,
    );
    final error = form.validate();
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }
    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      await ref.read(orgChartRepositoryProvider).createUnit(form);
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

class _DlgHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader({required this.icon, required this.title, required this.subtitle, required this.onClose});

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
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

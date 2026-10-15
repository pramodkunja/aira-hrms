import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/validators/form_validators.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/models/my_profile_model.dart';
import '../providers/profile_providers.dart';
import 'profile_widgets.dart';

// Mirrors backend's User.PROFILE_PHOTO_MIN_SIZE/MAX_SIZE (accounts/models.py)
// so an out-of-range file is caught here instead of round-tripping to the
// API for a 422.
const int _kPhotoMinBytes = 100 * 1024;
const int _kPhotoMaxBytes = 200 * 1024;

String _s(String? v) => (v == null || v.isEmpty) ? '—' : v;

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  } catch (_) {
    return raw;
  }
}

String _fmtFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ── Profile completion (client-derived — no backend field exists) ────────────────
//
// The reference image shows a "Profile Completion" segmented bar + percentage
// bubble. The backend/API has no such field anywhere (confirmed by inspecting
// MyProfileEntity/MyProfileDetailEntity — there is no completion/percentage
// property), so this is computed here from the real, already-loaded profile
// fields rather than hardcoded — never the reference's example "46%".
double _profileCompletionPercent(MyProfileModel p) {
  final d = p.detail;
  final fields = <String?>[
    p.phone,
    p.photoUrl,
    d.currentAddress,
    d.permanentAddress,
    d.dateOfBirth,
    d.gender,
    d.maritalStatus,
    d.bloodGroup,
    d.fatherName,
    d.highestQualification,
    d.institution,
    d.emergencyName,
    d.emergencyPhone,
    d.accountNumber,
    d.bankName,
  ];
  final filled = fields.where((v) => (v ?? '').trim().isNotEmpty).length;
  return fields.isEmpty ? 0 : (filled / fields.length) * 100;
}

// ── Profile summary (large card: company header, photo, identity, ───────────────
// ── completion, contact, actions, edit) ──────────────────────────────────────────
//
// Pixel-geometry redesign matching the supplied reference screenshot exactly
// (teal company-header strip → white body with photo+identity → segmented
// completion bar → divider → contact rows → contact-action buttons + edit
// button), while every value plugged in is real existing data:
//  - Company header: real CompanyModel (companyProvider, already used by
//    MyPayslipScreen for the same self-service company info — falls back to
//    the employee's own branch if the tenant hasn't filled in a company name,
//    never a fabricated name).
//  - "Social" row: the reference has no equivalent real data (no social
//    links anywhere in this app — confirmed by search), so it's replaced
//    with real contact *actions* on the real phone/email already on file
//    (tap-to-call, tap-to-email) instead of decorative/fake icons.
//  - Edit button: wired to the screen's existing Save Changes action — this
//    app has no separate "edit mode", fields are always inline-editable, so
//    the reference's edit affordance maps onto the existing save flow.
// Owns exactly the same photo-picker logic (image_picker, client-side
// size/extension validation, uploadPhoto/removePhoto via myProfileProvider)
// that used to live directly in ProfilePersonalSection; only where its UI
// lives changed. DOB/gender/marital status/blood group/father's name live in
// the separate ProfilePersonalDetailsSection module-grid card.
class ProfileSummaryCard extends ConsumerStatefulWidget {
  final MyProfileModel profile;
  final TextEditingController phoneCtrl;
  final bool saving;
  final VoidCallback onSave;

  const ProfileSummaryCard({
    super.key,
    required this.profile,
    required this.phoneCtrl,
    required this.saving,
    required this.onSave,
  });

  @override
  ConsumerState<ProfileSummaryCard> createState() => _ProfileSummaryCardState();
}

class _ProfileSummaryCardState extends ConsumerState<ProfileSummaryCard> {
  bool _uploadingPhoto = false;
  String? _phoneError;

  void _onPhoneChanged(String value) {
    final error = FormValidators.lenientPhone(value);
    if (error != _phoneError) setState(() => _phoneError = error);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final file = File(picked.path);
    final ext = picked.path.split('.').last.toLowerCase();
    if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
      _showSnack('Only JPG and PNG files are allowed.', isError: true);
      return;
    }
    final size = await file.length();
    if (size < _kPhotoMinBytes) {
      _showSnack(
        'Image is too small (${(size / 1024).toStringAsFixed(0)} KB). Minimum size is 100 KB.',
        isError: true,
      );
      return;
    }
    if (size > _kPhotoMaxBytes) {
      _showSnack(
        'Image is too large (${(size / 1024).toStringAsFixed(0)} KB). Maximum size is 200 KB.',
        isError: true,
      );
      return;
    }

    setState(() => _uploadingPhoto = true);
    final error = await ref.read(myProfileProvider.notifier).uploadPhoto(file);
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    _showSnack(error ?? 'Profile photo updated.', isError: error != null);
  }

  Future<void> _removePhoto() async {
    setState(() => _uploadingPhoto = true);
    final error = await ref.read(myProfileProvider.notifier).removePhoto();
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    _showSnack(error ?? 'Profile photo removed.', isError: error != null);
  }

  Future<void> _showPhotoOptions() async {
    final hasPhoto = (widget.profile.photoUrl ?? '').isNotEmpty;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('Remove Photo', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _email(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final company = ref.watch(companyProvider).valueOrNull;
    final companyName = (company?.companyName ?? '').isNotEmpty ? company!.companyName : p.branch;
    final companyLocation = [
      if ((company?.address ?? '').isNotEmpty) company!.address,
      if ((company?.city ?? '').isNotEmpty) company!.city,
    ].join(', ');

    final designationLine = p.designation.isNotEmpty
        ? p.designation
        : (p.roleDisplay.isNotEmpty ? p.roleDisplay : p.roleName);
    final branchDeptLine = [
      if (p.branch.isNotEmpty) p.branch,
      if (p.department.isNotEmpty) p.department,
    ].join(' – ');
    final percent = _profileCompletionPercent(p);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.extraLarge),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Teal company header ─────────────────────────────────────────
          if (companyName.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyName,
                    style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (companyLocation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      companyLocation,
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

          // ── White body ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo + employee information
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileAvatar(
                      photoUrl: p.photoUrl,
                      initials: p.initials,
                      color: p.avatarColor,
                      radius: 38,
                      busy: _uploadingPhoto,
                      onTap: _showPhotoOptions,
                      badgeColor: AppColors.secondary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _s(p.fullName),
                            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (p.employeeId.isNotEmpty) ...[
                            Text('Employee ID :', style: AppTextStyles.caption),
                            Text(
                              p.employeeId,
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (designationLine.isNotEmpty)
                            Text(
                              designationLine,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (branchDeptLine.isNotEmpty)
                            Text(
                              branchDeptLine,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Existing fields the reference has no slot for (role, date
                // of joining, onboarding/assessment status) — continued
                // below in the same visual language rather than dropped.
                if (p.roleDisplay.isNotEmpty ||
                    p.roleName.isNotEmpty ||
                    (p.dateOfJoining ?? '').isNotEmpty ||
                    p.onboardingStatus.isNotEmpty ||
                    p.assessmentStatus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (p.roleDisplay.isNotEmpty || p.roleName.isNotEmpty)
                        _MiniChip(
                          icon: Icons.shield_outlined,
                          label: p.roleDisplay.isNotEmpty ? p.roleDisplay : p.roleName,
                        ),
                      if ((p.dateOfJoining ?? '').isNotEmpty)
                        _MiniChip(icon: Icons.event_outlined, label: 'Joined ${_fmtDate(p.dateOfJoining)}'),
                      if (p.onboardingStatus.isNotEmpty)
                        _MiniChip(
                          icon: Icons.checklist_outlined,
                          label: 'Onboarding: ${_titleCase(p.onboardingStatus)}',
                          accent: p.onboardingStatus == 'complete' ? AppColors.success : AppColors.warning,
                        ),
                      if (p.assessmentStatus.isNotEmpty)
                        _MiniChip(
                          icon: Icons.fact_check_outlined,
                          label: 'Assessment: ${_titleCase(p.assessmentStatus)}',
                          accent: p.assessmentStatus == 'complete' ? AppColors.success : AppColors.warning,
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                _ProfileCompletionBar(percent: percent),
                const SizedBox(height: 14),
                Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                // Contact
                _ContactRow(
                  icon: Icons.phone_outlined,
                  child: TextFormField(
                    controller: widget.phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: FormValidators.phoneInputFormatters,
                    onChanged: _onPhoneChanged,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Add phone number',
                      errorText: _phoneError,
                      errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ),
                ),
                if (p.email.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ContactRow(
                    icon: Icons.email_outlined,
                    child: Text(
                      p.email,
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                // Reference's social-icon row has no real equivalent (no
                // social links anywhere in this app) — real contact
                // *actions* on the existing phone/email instead, plus the
                // existing Save action as the reference's edit button.
                Row(
                  children: [
                    if (p.phone.isNotEmpty)
                      _ContactActionButton(icon: Icons.call_outlined, onTap: () => _call(p.phone)),
                    if (p.phone.isNotEmpty) const SizedBox(width: 10),
                    if (p.email.isNotEmpty)
                      _ContactActionButton(icon: Icons.mail_outline, onTap: () => _email(p.email)),
                    const Spacer(),
                    _EditActionButton(loading: widget.saving, onTap: widget.onSave),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Small pill for an existing field the reference layout has no dedicated
/// slot for (role, date of joining, onboarding/assessment status) — kept
/// visible rather than dropped, styled to sit quietly below the reference's
/// own identity block.
class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;
  const _MiniChip({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Icon + content contact row (phone/email) on the card's white body.
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _ContactRow({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

/// Circular contact-action button (tap-to-call / tap-to-email) — the honest
/// substitute for the reference's social-icon row (see class doc above).
class _ContactActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ContactActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundLow,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 17, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Circular outlined edit/save button — the reference's bottom-right edit
/// affordance, wired to the app's existing Save Changes action (this app has
/// no separate edit mode; fields are already inline-editable).
class _EditActionButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _EditActionButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: CircleBorder(side: BorderSide(color: AppColors.primary, width: 1.4)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : Icon(Icons.edit_outlined, size: 17, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Segmented "Profile Completion" bar + floating percentage bubble — visual
/// structure matches the reference (rounded segments, filled-vs-inactive
/// track, a marker bubble positioned at the actual percentage along the
/// bar). [percent] is always a real value derived from actual profile data
/// (see [_profileCompletionPercent]) — never the reference's hardcoded 46%.
class _ProfileCompletionBar extends StatelessWidget {
  final double percent;
  static const _segments = 5;

  const _ProfileCompletionBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    final fraction = (percent / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const bubbleSize = 34.0;
            final barWidth = constraints.maxWidth;
            final bubbleLeft = (fraction * barWidth - bubbleSize / 2).clamp(0.0, barWidth - bubbleSize);
            return SizedBox(
              height: bubbleSize + 8 + 10,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: bubbleLeft,
                    top: 0,
                    child: Column(
                      children: [
                        Container(
                          width: bubbleSize,
                          height: bubbleSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accentNavy,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Text(
                            '${percent.round()}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, size: 20, color: AppColors.accentNavy),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      children: List.generate(_segments, (i) {
                        final segStart = i / _segments;
                        final segEnd = (i + 1) / _segments;
                        final segFill = ((fraction - segStart) / (segEnd - segStart)).clamp(0.0, 1.0);
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == _segments - 1 ? 0 : 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                height: 8,
                                child: Stack(
                                  children: [
                                    Positioned.fill(child: Container(color: AppColors.backgroundMid)),
                                    if (segFill > 0)
                                      Positioned.fill(
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: segFill,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [AppColors.accentNavy, AppColors.primary],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Profile Completion',
          style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── Personal details (read-only extras, no longer hidden behind a toggle) ────────
//
// The DOB/gender/marital status/blood group/father's name fields that used
// to live behind ProfilePersonalSection's "Show more details" toggle — same
// data, now its own always-visible module-grid card.
class ProfilePersonalDetailsSection extends StatelessWidget {
  final MyProfileModel profile;
  const ProfilePersonalDetailsSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final d = profile.detail;
    return ProfileSectionCard(
      icon: Icons.manage_accounts_outlined,
      title: 'Personal Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileDisplayFieldRow(
            label1: 'Date of Birth', value1: _fmtDate(d.dateOfBirth),
            label2: 'Gender', value2: _s(d.gender),
          ),
          ProfileDisplayFieldRow(
            label1: 'Marital Status', value1: _s(d.maritalStatus),
            label2: 'Blood Group', value2: _s(d.bloodGroup),
          ),
          ProfileDisplayField(
            label: "Father's Name", value: _s(d.fatherName),
            padBottom: false,
          ),
        ],
      ),
    );
  }
}

// ── Teal section header (e.g. "Personal Information") ────────────────────────────
//
// Full-width teal bar introducing the module grid below — matches the
// reference's section-header treatment exactly. Deliberately a bespoke
// Profile widget rather than the shared dashboard `SectionCard` header
// (that one is a plain white card header, visually nothing like this) —
// per the redesign brief, an existing shared component is only reused where
// it actually produces the same visual result.
class ProfileSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const ProfileSectionHeader({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ── Module grid (reference-style quick-access tiles onto each section) ───────────
//
// Bespoke Profile-specific tile — the shared shared/widgets/module_card.dart
// ModuleIconCard (used by the Menu sheet) renders a flat tinted-square icon
// directly on the tile, which doesn't match the reference's raised/elevated
// white icon tile look, so this is a dedicated component instead of forcing
// the reference onto a visually-different shared one. Each tile scrolls the
// page to that section's existing widget instead of navigating anywhere new
// — there are no new screens/routes here, every section below still renders
// in full (see Step 18 of the brief: existing sections beyond what the
// screenshot shows stay reachable, just via scroll instead of a crop).
class ProfileModuleTile {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const ProfileModuleTile({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });
}

class ProfileModuleCard extends StatelessWidget {
  final ProfileModuleTile tile;
  const ProfileModuleCard({super.key, required this.tile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundLow,
      borderRadius: BorderRadius.circular(AppRadius.extraLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.extraLarge),
        onTap: tile.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.extraLarge),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Icon(tile.icon, size: 30, color: tile.color),
              ),
              const SizedBox(height: 10),
              Text(
                tile.label,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileModuleGrid extends StatelessWidget {
  final List<ProfileModuleTile> tiles;
  const ProfileModuleGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 110).floor().clamp(3, 5);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            mainAxisExtent: 148,
          ),
          itemBuilder: (context, index) => ProfileModuleCard(tile: tiles[index]),
        );
      },
    );
  }
}

// ── Address ───────────────────────────────────────────────────────────────────

class ProfileAddressSection extends StatelessWidget {
  final TextEditingController currentAddressCtrl;
  final TextEditingController permanentAddressCtrl;

  const ProfileAddressSection({
    super.key,
    required this.currentAddressCtrl,
    required this.permanentAddressCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.location_on_outlined,
      title: 'Address',
      child: Column(
        children: [
          ProfileField(
            label: 'Current Address',
            controller: currentAddressCtrl,
            hint: 'e.g. 42, 3rd Cross, HSR Layout, Bengaluru',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ProfileField(
            label: 'Permanent Address',
            controller: permanentAddressCtrl,
            hint: 'e.g. 42, 3rd Cross, HSR Layout, Bengaluru',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ── Education & Experience (read-only) ────────────────────────────────────────

class ProfileEducationSection extends StatelessWidget {
  final MyProfileModel profile;
  const ProfileEducationSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final d = profile.detail;
    return ProfileSectionCard(
      icon: Icons.school_outlined,
      title: 'Education & Experience',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileDisplayFieldRow(
            label1: 'Highest Qualification', value1: _s(d.highestQualification),
            label2: 'Specialization', value2: _s(d.specialization),
          ),
          ProfileDisplayField(label: 'Institution / University', value: _s(d.institution)),
          ProfileDisplayFieldRow(
            label1: 'Year of Passing', value1: _s(d.yearOfPassing?.toString()),
            label2: 'Total Experience (yrs)', value2: _s(d.totalExperienceYears),
          ),
          ProfileDisplayFieldRow(
            label1: 'Previous Employer', value1: _s(d.previousEmployer),
            label2: 'Previous Designation', value2: _s(d.previousDesignation),
          ),
          ProfileDisplayField(
            label: 'Reason for Leaving',
            value: _s(d.leavingReason),
            maxLines: 3,
            padBottom: false,
          ),
        ],
      ),
    );
  }
}

// ── Bank details (read-only, contact HR to update) ────────────────────────────

class ProfileBankSection extends StatelessWidget {
  final MyProfileModel profile;
  const ProfileBankSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final d = profile.detail;
    return ProfileSectionCard(
      icon: Icons.account_balance_outlined,
      title: 'Bank Details',
      trailing: Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileDisplayFieldRow(
            label1: 'Account Holder Name', value1: _s(d.accountHolderName),
            label2: 'Account Type', value2: _s(d.accountType),
          ),
          ProfileDisplayFieldRow(
            label1: 'Account Number', value1: _s(d.accountNumber),
            label2: 'IFSC Code', value2: _s(d.ifscCode),
          ),
          ProfileDisplayFieldRow(
            label1: 'Bank Name', value1: _s(d.bankName),
            label2: 'Bank Branch', value2: _s(d.bankBranchName),
            padBottom: false,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contact HR to update your bank details.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Emergency contact ──────────────────────────────────────────────────────────

class ProfileEmergencySection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController relationshipCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final String? phoneError;
  final String? emailError;
  final void Function(String)? onPhoneChanged;
  final void Function(String)? onEmailChanged;

  const ProfileEmergencySection({
    super.key,
    required this.nameCtrl,
    required this.relationshipCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    this.phoneError,
    this.emailError,
    this.onPhoneChanged,
    this.onEmailChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.local_phone_outlined,
      title: 'Emergency Contact',
      child: Column(
        children: [
          ProfileFieldRow(
            left: ProfileField(label: 'Contact Name', controller: nameCtrl),
            right: ProfileField(label: 'Relationship', controller: relationshipCtrl),
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
              label: 'Phone Number',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: FormValidators.phoneInputFormatters,
              onChanged: onPhoneChanged,
              errorText: phoneError,
            ),
            right: ProfileField(
              label: 'Email',
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              onChanged: onEmailChanged,
              errorText: emailError,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Change password ────────────────────────────────────────────────────────────

class ProfileChangePasswordSection extends StatelessWidget {
  final TextEditingController currentCtrl;
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final bool loading;
  final VoidCallback onSubmit;

  const ProfileChangePasswordSection({
    super.key,
    required this.currentCtrl,
    required this.newCtrl,
    required this.confirmCtrl,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.lock_outline,
      title: 'Change Password',
      child: Column(
        children: [
          ProfileField(
            label: 'Current Password',
            controller: currentCtrl,
            obscureText: true,
            hint: '••••••••',
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'New Password', controller: newCtrl, obscureText: true, hint: '••••••••'),
            right: ProfileField(
                label: 'Confirm Password',
                controller: confirmCtrl,
                obscureText: true,
                hint: '••••••••'),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: loading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline, size: 13),
              label: Text(loading ? 'Updating…' : 'Update Password'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle:
                    AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Documents (read-only list) ─────────────────────────────────────────────────

class ProfileDocumentsSection extends ConsumerWidget {
  const ProfileDocumentsSection({super.key});

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(myDocumentsProvider);
    return ProfileSectionCard(
      icon: Icons.folder_outlined,
      title: 'Documents',
      child: docsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return Text(
              'No documents uploaded yet.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.border),
                ProfileDocumentItem(
                  name: docs[i].documentTypeDisplay.isNotEmpty
                      ? docs[i].documentTypeDisplay
                      : docs[i].documentType,
                  subtitle: [
                    if (docs[i].uploadedAt.isNotEmpty) _fmtDate(docs[i].uploadedAt),
                    if (docs[i].fileSize > 0) _fmtFileSize(docs[i].fileSize),
                  ].join(' · '),
                  onView: docs[i].fileUrl.isEmpty
                      ? null
                      : () => _openDocument(docs[i].fileUrl),
                ),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(
          friendlyProfileError(e),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}

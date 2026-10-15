import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/validators/form_validators.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../separation/presentation/widgets/profile_separation_section.dart';
import '../../data/models/my_profile_model.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_face_id_section.dart';
import '../widgets/profile_sections.dart';

// ignore_for_file: use_build_context_synchronously

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Editable fields
  final _phoneCtrl = TextEditingController();
  final _currentAddressCtrl = TextEditingController();
  final _permanentAddressCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyRelationshipCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _emergencyEmailCtrl = TextEditingController();

  // Password
  final _curPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _cfmPassCtrl = TextEditingController();

  bool _saving = false;
  bool _changingPassword = false;
  String? _emergencyPhoneError;
  String? _emergencyEmailError;

  void _onEmergencyPhoneChanged(String value) {
    final error = FormValidators.lenientPhone(value);
    if (error != _emergencyPhoneError) setState(() => _emergencyPhoneError = error);
  }

  void _onEmergencyEmailChanged(String value) {
    final trimmed = value.trim();
    final error = trimmed.isEmpty ? null : FormValidators.email(trimmed);
    if (error != _emergencyEmailError) setState(() => _emergencyEmailError = error);
  }
  // Tracks which profile.id the controllers were last populated from, so we
  // don't clobber in-progress edits on every provider rebuild.
  String? _hydratedForId;

  // Anchors for the module grid's "jump to section" tiles — every section
  // still renders in place below, tapping a tile just scrolls to it rather
  // than navigating anywhere new.
  final _personalKey = GlobalKey();
  final _separationKey = GlobalKey();
  final _addressKey = GlobalKey();
  final _educationKey = GlobalKey();
  final _bankKey = GlobalKey();
  final _emergencyKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _faceIdKey = GlobalKey();
  final _documentsKey = GlobalKey();

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  @override
  void dispose() {
    for (final c in [
      _phoneCtrl, _currentAddressCtrl, _permanentAddressCtrl,
      _emergencyNameCtrl, _emergencyRelationshipCtrl,
      _emergencyPhoneCtrl, _emergencyEmailCtrl,
      _curPassCtrl, _newPassCtrl, _cfmPassCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(MyProfileModel profile) {
    if (_hydratedForId == profile.id) return;
    _hydratedForId = profile.id;
    _phoneCtrl.text = profile.phone;
    _currentAddressCtrl.text = profile.detail.currentAddress;
    _permanentAddressCtrl.text = profile.detail.permanentAddress;
    _emergencyNameCtrl.text = profile.detail.emergencyName;
    _emergencyRelationshipCtrl.text = profile.detail.emergencyRelationship;
    _emergencyPhoneCtrl.text = profile.detail.emergencyPhone;
    _emergencyEmailCtrl.text = profile.detail.emergencyEmail;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // Mirrors backend's lenient phone/email rules for these fields
  // (accounts/serializers.py _PHONE_RE_PROFILE for phone/emergency_phone,
  // Django's EmailField for emergency_email) so a bad value is caught here
  // instead of round-tripping to the API for a 400.
  String? _validateBeforeSave() {
    final phoneError = FormValidators.lenientPhone(_phoneCtrl.text);
    if (phoneError != null) return phoneError;
    final emergencyPhoneError = FormValidators.lenientPhone(_emergencyPhoneCtrl.text);
    if (emergencyPhoneError != null) return 'Emergency contact: $emergencyPhoneError';
    final emergencyEmailText = _emergencyEmailCtrl.text.trim();
    if (emergencyEmailText.isNotEmpty && FormValidators.email(emergencyEmailText) != null) {
      return 'Enter a valid emergency contact email address.';
    }
    return null;
  }

  Future<void> _onSave() async {
    if (_saving) return;
    final validationError = _validateBeforeSave();
    if (validationError != null) {
      _showSnack(validationError, isError: true);
      return;
    }
    setState(() => _saving = true);
    final data = MyProfileUpdateData(
      phone: _phoneCtrl.text.trim(),
      currentAddress: _currentAddressCtrl.text.trim(),
      permanentAddress: _permanentAddressCtrl.text.trim(),
      emergencyName: _emergencyNameCtrl.text.trim(),
      emergencyRelationship: _emergencyRelationshipCtrl.text.trim(),
      emergencyPhone: _emergencyPhoneCtrl.text.trim(),
      emergencyEmail: _emergencyEmailCtrl.text.trim(),
    );
    final err = await ref.read(myProfileProvider.notifier).updateProfile(data);
    if (!mounted) return;
    setState(() => _saving = false);
    _showSnack(err ?? 'Changes saved successfully', isError: err != null);
  }

  Future<void> _onChangePassword() async {
    final oldPass = _curPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _cfmPassCtrl.text;

    // Client-side validation order mirrors the web app: old required → new
    // required → new must equal confirm → new must differ from old. Server
    // enforces length/complexity — we don't duplicate that here.
    if (oldPass.isEmpty) {
      _showSnack('Current password is required.', isError: true);
      return;
    }
    if (newPass.isEmpty) {
      _showSnack('New password is required.', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showSnack('New password and confirm password do not match.', isError: true);
      return;
    }
    if (newPass == oldPass) {
      _showSnack('New password must be different from the current password.',
          isError: true);
      return;
    }

    setState(() => _changingPassword = true);
    final err = await changeMyPassword(
      ref,
      oldPassword: oldPass,
      newPassword: newPass,
      confirmPassword: confirmPass,
    );
    if (!mounted) return;
    setState(() => _changingPassword = false);

    if (err != null) {
      _showSnack(err, isError: true);
      return;
    }

    _curPassCtrl.clear();
    _newPassCtrl.clear();
    _cfmPassCtrl.clear();
    await _forceLogoutAfterPasswordChange();
  }

  // The backend blacklists the refresh token and clears auth cookies on a
  // successful password change — the session is already dead server-side,
  // so we must log out locally and send the user back to login rather than
  // leaving them on a screen backed by a session that no longer exists.
  Future<void> _forceLogoutAfterPasswordChange() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Password Changed'),
        content: const Text('Password changed. Please log in again.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await ref.read(authStateProvider.notifier).logout();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            _hydrate(profile);
            return RefreshIndicator(
              onRefresh: () => ref.read(myProfileProvider.notifier).refresh(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      child: Column(
                        children: [
                          ProfileSummaryCard(
                            profile: profile,
                            phoneCtrl: _phoneCtrl,
                            saving: _saving,
                            onSave: _onSave,
                          ),
                          const SizedBox(height: 22),
                          const ProfileSectionHeader(
                            title: 'Personal Information',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 16),
                          ProfileModuleGrid(
                            tiles: [
                              ProfileModuleTile(
                                label: 'Address',
                                icon: Icons.contact_page_outlined,
                                color: AppColors.accentNavy,
                                onTap: () => _scrollToSection(_addressKey),
                              ),
                              ProfileModuleTile(
                                label: 'Personal Details',
                                icon: Icons.assignment_ind_outlined,
                                color: AppColors.primary,
                                onTap: () => _scrollToSection(_personalKey),
                              ),
                              ProfileModuleTile(
                                label: 'Education & Experience',
                                icon: Icons.school_outlined,
                                color: AppColors.primary,
                                onTap: () => _scrollToSection(_educationKey),
                              ),
                              ProfileModuleTile(
                                label: 'Bank Details',
                                icon: Icons.account_balance_outlined,
                                color: AppColors.accentNavy,
                                onTap: () => _scrollToSection(_bankKey),
                              ),
                              ProfileModuleTile(
                                label: 'Emergency Contact',
                                icon: Icons.local_phone_outlined,
                                color: AppColors.primary,
                                onTap: () => _scrollToSection(_emergencyKey),
                              ),
                              ProfileModuleTile(
                                label: 'Change Password',
                                icon: Icons.lock_outline,
                                color: AppColors.accentNavy,
                                onTap: () => _scrollToSection(_passwordKey),
                              ),
                              ProfileModuleTile(
                                label: 'Face ID',
                                icon: Icons.face_outlined,
                                color: AppColors.primary,
                                onTap: () => _scrollToSection(_faceIdKey),
                              ),
                              ProfileModuleTile(
                                label: 'Documents',
                                icon: Icons.folder_outlined,
                                color: AppColors.accentNavy,
                                onTap: () => _scrollToSection(_documentsKey),
                              ),
                              ProfileModuleTile(
                                label: 'Separation',
                                icon: Icons.logout_outlined,
                                color: AppColors.primary,
                                onTap: () => _scrollToSection(_separationKey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          KeyedSubtree(
                            key: _personalKey,
                            child: ProfilePersonalDetailsSection(profile: profile),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _separationKey,
                            child: const ProfileSeparationSection(),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _addressKey,
                            child: ProfileAddressSection(
                              currentAddressCtrl: _currentAddressCtrl,
                              permanentAddressCtrl: _permanentAddressCtrl,
                            ),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _educationKey,
                            child: ProfileEducationSection(profile: profile),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _bankKey,
                            child: ProfileBankSection(profile: profile),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _emergencyKey,
                            child: ProfileEmergencySection(
                              nameCtrl: _emergencyNameCtrl,
                              relationshipCtrl: _emergencyRelationshipCtrl,
                              phoneCtrl: _emergencyPhoneCtrl,
                              emailCtrl: _emergencyEmailCtrl,
                              phoneError: _emergencyPhoneError,
                              emailError: _emergencyEmailError,
                              onPhoneChanged: _onEmergencyPhoneChanged,
                              onEmailChanged: _onEmergencyEmailChanged,
                            ),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _passwordKey,
                            child: ProfileChangePasswordSection(
                              currentCtrl: _curPassCtrl,
                              newCtrl: _newPassCtrl,
                              confirmCtrl: _cfmPassCtrl,
                              loading: _changingPassword,
                              onSubmit: _onChangePassword,
                            ),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _faceIdKey,
                            child: const ProfileFaceIdSection(),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _documentsKey,
                            child: const ProfileDocumentsSection(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState(
            message: friendlyProfileError(e),
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
        ),
      ),
    );
  }
}

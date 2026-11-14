import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../../services/domain/hospital_service.dart';
import '../domain/staff_user.dart';

class PatientProfileTab extends StatefulWidget {
  const PatientProfileTab({
    super.key,
    required this.user,
    required this.onSave,
    required this.onSignOut,
    this.isDoctorProfile = false,
    this.doctorServices = const [],
    this.onSwitchRole,
  });

  final StaffUser user;
  final Future<void> Function(Map<String, Object?> updates) onSave;
  final VoidCallback onSignOut;
  final bool isDoctorProfile;
  final List<HospitalService> doctorServices;
  final VoidCallback? onSwitchRole;

  @override
  State<PatientProfileTab> createState() => _PatientProfileTabState();
}

class _PatientProfileTabState extends State<PatientProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(
    text: widget.user.firstName.isNotEmpty
        ? widget.user.firstName
        : widget.user.displayName.split(' ').firstOrNull ?? '',
  );
  late final _lastName = TextEditingController(
    text: widget.user.lastName.isNotEmpty
        ? widget.user.lastName
        : widget.user.displayName.split(' ').skip(1).join(' '),
  );
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _address = TextEditingController(text: widget.user.address);
  late final _emergency = TextEditingController(
    text: widget.user.emergencyContact,
  );
  late final _insurance = TextEditingController(text: widget.user.insurance);
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  late DateTime? _birthDate = widget.user.birthDate;
  late String _language = widget.user.language;
  late bool _appointmentNotifications = widget.user.appointmentNotifications;
  late bool _resultNotifications = widget.user.resultNotifications;
  late bool _reminderNotifications = widget.user.reminderNotifications;
  bool _isSaving = false;

  bool get _isArabic => _language == 'ar';

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _emergency.dispose();
    _insurance.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime(today.year - 25, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPassword.text.isNotEmpty && _currentPassword.text.isEmpty) {
      _showMessage(
        _isArabic
            ? 'أدخل كلمة المرور الحالية لتغييرها.'
            : 'Saisissez le mot de passe actuel pour le modifier.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave({
        if (!widget.isDoctorProfile) ...{
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'birthDate': _birthDate == null ? null : _dateOnly(_birthDate!),
          'address': _address.text.trim(),
          'emergencyContact': _emergency.text.trim(),
          'insurance': _insurance.text.trim(),
        },
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'language': _language,
        'notificationPreferences': {
          'appointments': _appointmentNotifications,
          'results': _resultNotifications,
          'reminders': _reminderNotifications,
        },
        if (_newPassword.text.isNotEmpty) ...{
          'currentPassword': _currentPassword.text,
          'newPassword': _newPassword.text,
        },
      });
      _currentPassword.clear();
      _newPassword.clear();
      _showMessage(_isArabic ? 'تم حفظ الملف الشخصي.' : 'Profil mis à jour.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _text(String french, String arabic) => _isArabic ? arabic : french;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionIntro(
            title: widget.isDoctorProfile
                ? 'Profil médecin'
                : _text('Mon profil', 'ملفي الشخصي'),
            subtitle: _text(
              widget.isDoctorProfile
                  ? 'Informations professionnelles et coordonnées.'
                  : 'Consultez et mettez à jour vos informations personnelles.',
              'عرض وتحديث معلوماتك الشخصية.',
            ),
          ),
          const SizedBox(height: 16),
          if (widget.isDoctorProfile) ...[
            _doctorIdentity(),
            const SizedBox(height: 16),
          ] else ...[
            _sectionTitle(
              _text('Informations personnelles', 'المعلومات الشخصية'),
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _firstName,
                    _text('Prénom', 'الاسم الأول'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? _text('Le prénom est requis.', 'الاسم الأول مطلوب.')
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _field(_lastName, _text('Nom', 'اسم العائلة'))),
              ],
            ),
          ],
          _field(
            _email,
            _text('E-mail', 'البريد الإلكتروني'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                  ? null
                  : _text('E-mail invalide.', 'البريد الإلكتروني غير صالح.');
            },
          ),
          if (!widget.isDoctorProfile)
            OutlinedButton.icon(
              onPressed: _selectBirthDate,
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                _birthDate == null
                    ? _text('Date de naissance', 'تاريخ الميلاد')
                    : '${_text('Date de naissance', 'تاريخ الميلاد')} : ${_dateLabel(_birthDate!)}',
              ),
            ),
          _field(
            _phone,
            _text('Téléphone', 'الهاتف'),
            keyboardType: TextInputType.phone,
            requiredField: !widget.isDoctorProfile,
          ),
          if (!widget.isDoctorProfile) ...[
            _field(_address, _text('Adresse', 'العنوان'), maxLines: 2),
            _field(_emergency, _text('Contact d’urgence', 'جهة اتصال للطوارئ')),
            _field(_insurance, _text('Assurance / CNAM', 'التأمين / CNAM')),
          ],
          const SizedBox(height: 8),
          _sectionTitle(_text('Préférences', 'التفضيلات')),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: InputDecoration(
              labelText: _text('Langue', 'اللغة'),
              prefixIcon: const Icon(Icons.language),
            ),
            items: [
              DropdownMenuItem(
                value: 'fr',
                child: Text(_text('Français', 'الفرنسية')),
              ),
              DropdownMenuItem(
                value: 'ar',
                child: Text(_text('Arabe', 'العربية')),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _language = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('Rappels de rendez-vous', 'تذكيرات المواعيد')),
            value: _appointmentNotifications,
            onChanged: (value) =>
                setState(() => _appointmentNotifications = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('Nouveaux résultats', 'النتائج الجديدة')),
            value: _resultNotifications,
            onChanged: (value) => setState(() => _resultNotifications = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('Rappels et alertes', 'التنبيهات والتذكيرات')),
            value: _reminderNotifications,
            onChanged: (value) =>
                setState(() => _reminderNotifications = value),
          ),
          const SizedBox(height: 8),
          _sectionTitle(_text('Changer le mot de passe', 'تغيير كلمة المرور')),
          _field(
            _currentPassword,
            _text('Mot de passe actuel', 'كلمة المرور الحالية'),
            obscureText: true,
            requiredField: false,
          ),
          _field(
            _newPassword,
            _text('Nouveau mot de passe', 'كلمة المرور الجديدة'),
            obscureText: true,
            requiredField: false,
            validator: (value) =>
                value != null && value.isNotEmpty && value.length < 10
                ? _text(
                    '10 caractères minimum.',
                    'يجب أن تتكون كلمة المرور من 10 أحرف على الأقل.',
                  )
                : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_text('Enregistrer', 'حفظ')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.blue,
            ),
          ),
          const SizedBox(height: 10),
          if (widget.user.assignedRoles.length > 1 &&
              widget.onSwitchRole != null) ...[
            OutlinedButton.icon(
              onPressed: widget.onSwitchRole,
              icon: const Icon(Icons.switch_account_outlined),
              label: const Text('Changer de rôle'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(_text('Se déconnecter', 'تسجيل الخروج')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorIdentity() {
    final name = [
      widget.user.firstName,
      widget.user.lastName,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    final serviceNames = widget.doctorServices.map((service) => service.name);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFFE1F2EF),
              foregroundImage: widget.user.photoUrl.isEmpty
                  ? null
                  : NetworkImage(widget.user.photoUrl),
              child: widget.user.photoUrl.isEmpty
                  ? const Icon(Icons.person_outline, color: AppColors.blue)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? widget.user.displayName : name,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.user.specialty.isNotEmpty)
                    Text('Spécialité : ${widget.user.specialty}'),
                  Text(
                    serviceNames.isEmpty
                        ? 'Service(s) : Aucun service attribué'
                        : 'Service(s) : ${serviceNames.join(', ')}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    bool requiredField = true,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label),
      validator:
          validator ??
          (requiredField
              ? (value) => value == null || value.trim().isEmpty
                    ? _text('Champ requis.', 'هذا الحقل مطلوب.')
                    : null
              : null),
    ),
  );
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

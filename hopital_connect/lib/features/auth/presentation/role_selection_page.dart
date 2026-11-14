import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';
import '../data/auth_service.dart';
import 'login_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({
    super.key,
    required this.user,
    required this.selectionToken,
  });

  final StaffUser user;
  final String selectionToken;

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  StaffRole? _selectedRole;
  bool _isSubmitting = false;

  Future<void> _continue() async {
    final role = _selectedRole;
    if (role == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final session = await AuthService().selectRole(
        selectionToken: widget.selectionToken,
        role: role,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => DashboardPage(session: session),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _backToLogin() async {
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = widget.user.assignedRoles;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un profil'),
        foregroundColor: AppColors.navy,
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Retour à la connexion',
          onPressed: _isSubmitting ? null : _backToLogin,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Icon(
                  Icons.switch_account_outlined,
                  size: 52,
                  color: AppColors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bonjour ${widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ce compte possède plusieurs rôles. Choisissez le profil à ouvrir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF687B86), height: 1.5),
                ),
                const SizedBox(height: 24),
                RadioGroup<StaffRole>(
                  groupValue: _selectedRole,
                  onChanged: (value) {
                    if (!_isSubmitting) {
                      setState(() => _selectedRole = value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final role in roles) ...[
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: RadioListTile<StaffRole>(
                            value: role,
                            title: Text(role.label),
                            subtitle: Text(_descriptionFor(role)),
                            secondary: Icon(
                              _iconFor(role),
                              color: AppColors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _selectedRole == null || _isSubmitting
                      ? null
                      : _continue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.blue,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continuer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(StaffRole role) => switch (role) {
    StaffRole.administrator => Icons.admin_panel_settings_outlined,
    StaffRole.doctor => Icons.medical_services_outlined,
    StaffRole.nurse => Icons.health_and_safety_outlined,
    StaffRole.secretary => Icons.support_agent_outlined,
    StaffRole.serviceHead => Icons.manage_accounts_outlined,
    StaffRole.patient => Icons.person_outline,
  };

  String _descriptionFor(StaffRole role) => switch (role) {
    StaffRole.administrator => 'Administration et gestion de l’application',
    StaffRole.doctor => 'Espace médecin',
    StaffRole.nurse => 'Espace du personnel soignant',
    StaffRole.secretary => 'Espace secrétariat',
    StaffRole.serviceHead => 'Gestion de votre service',
    StaffRole.patient => 'Espace patient',
  };
}

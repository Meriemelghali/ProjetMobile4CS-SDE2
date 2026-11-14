import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../services/data/service_service.dart';
import '../../services/domain/hospital_service.dart';
import '../data/user_service.dart';
import '../domain/staff_role.dart';
import '../domain/staff_user.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key, required this.service});

  final UserService service;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<StaffUser> _users = const [];
  List<HospitalService> _services = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.list(),
        ServiceService().list(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<StaffUser>;
          _services = results[1] as List<HospitalService>;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createUser() async {
    final input = await showDialog<_NewUserInput>(
      context: context,
      builder: (_) => _UserDialog(services: _services),
    );
    if (input == null || !mounted) return;
    try {
      final user = await widget.service.create(
        username: input.username,
        email: input.email,
        password: input.password!,
        role: input.role.apiValue,
        serviceId: input.serviceId,
        serviceIds: input.serviceIds,
        specialty: input.specialty,
        photoUrl: input.photoUrl,
      );
      if (mounted) setState(() => _users = [..._users, user]);
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _editUser(StaffUser user) async {
    final edited = await showDialog<StaffUser>(
      context: context,
      builder: (_) => _UserDialog(user: user, services: _services),
    );
    if (edited == null || !mounted) return;
    try {
      final updated = await widget.service.update(edited);
      if (mounted) {
        setState(
          () => _users = [
            for (final item in _users)
              if (item.id == updated.id) updated else item,
          ],
        );
      }
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _toggleActive(StaffUser user) async {
    final updatedUser = StaffUser(
      id: user.id,
      displayName: user.displayName,
      email: user.email,
      role: user.role,
      serviceId: user.serviceId,
      serviceIds: user.serviceIds,
      specialty: user.specialty,
      photoUrl: user.photoUrl,
      isActive: !user.isActive,
    );
    try {
      final updated = await widget.service.update(updatedUser);
      if (mounted) {
        setState(
          () => _users = [
            for (final item in _users)
              if (item.id == updated.id) updated else item,
          ],
        );
      }
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes du personnel'),
        foregroundColor: AppColors.navy,
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Réessayer')),
                ],
              ),
            )
          : _users.isEmpty
          ? const Center(child: Text('Aucun compte pour le moment.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = _users[index];
                final assignedServiceIds = {
                  ...user.serviceIds,
                  if (user.serviceId != null) user.serviceId!,
                };
                final assignedServices = _services
                    .where((service) => assignedServiceIds.contains(service.id))
                    .map((service) => service.name)
                    .join(', ');
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.isActive
                          ? const Color(0xFFE1F2EF)
                          : const Color(0xFFECEFF1),
                      child: Text(
                        user.displayName
                            .split(' ')
                            .take(2)
                            .map((part) => part.isEmpty ? '' : part[0])
                            .join()
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(user.displayName),
                    subtitle: Text(
                      '${user.email}\n${user.role.label} · ${user.isActive ? 'Actif' : 'Désactivé'}${assignedServices.isEmpty ? '' : '\nServices : $assignedServices'}',
                    ),
                    isThreeLine: assignedServices.isNotEmpty,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Actions sur le compte',
                      onSelected: (value) {
                        if (value == 'edit') _editUser(user);
                        if (value == 'toggle') _toggleActive(user);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Modifier'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            user.isActive ? 'Désactiver' : 'Réactiver',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createUser,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Créer un compte'),
      ),
    );
  }
}

class _NewUserInput {
  const _NewUserInput({
    required this.username,
    required this.email,
    required this.role,
    required this.serviceIds,
    required this.specialty,
    required this.photoUrl,
    this.serviceId,
    this.password,
  });

  final String username;
  final String email;
  final StaffRole role;
  final String? serviceId;
  final List<String> serviceIds;
  final String specialty;
  final String photoUrl;
  final String? password;
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.services, this.user});

  final List<HospitalService> services;
  final StaffUser? user;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.user?.displayName ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.user?.email ?? '',
  );
  final _passwordController = TextEditingController();
  late final _specialtyController = TextEditingController(
    text: widget.user?.specialty ?? '',
  );
  late final _photoUrlController = TextEditingController(
    text: widget.user?.photoUrl ?? '',
  );
  late StaffRole _role = widget.user?.role ?? StaffRole.nurse;
  late String? _doctorServiceId = widget.user?.serviceId;
  String? _assignmentError;
  late final Set<String> _secretaryServiceIds = {
    if (widget.user != null) ...widget.user!.serviceIds,
    if (widget.user != null &&
        widget.user!.serviceIds.isEmpty &&
        widget.user!.serviceId != null)
      widget.user!.serviceId!,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _specialtyController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_role == StaffRole.secretary && _secretaryServiceIds.isEmpty) {
      setState(
        () =>
            _assignmentError = 'Affectez au moins un service à la secrétaire.',
      );
      return;
    }
    final serviceIds = _role == StaffRole.secretary
        ? _secretaryServiceIds.toList()
        : const <String>[];
    final serviceId = _role == StaffRole.doctor
        ? _doctorServiceId
        : _role == StaffRole.secretary && serviceIds.isNotEmpty
        ? serviceIds.first
        : null;
    if (widget.user case final user?) {
      Navigator.of(context).pop(
        StaffUser(
          id: user.id,
          displayName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _role,
          serviceId: serviceId,
          serviceIds: serviceIds,
          specialty: _specialtyController.text.trim(),
          photoUrl: _photoUrlController.text.trim(),
          isActive: user.isActive,
        ),
      );
    } else {
      Navigator.of(context).pop(
        _NewUserInput(
          username: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _role,
          serviceId: serviceId,
          serviceIds: serviceIds,
          specialty: _specialtyController.text.trim(),
          photoUrl: _photoUrlController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;
    return AlertDialog(
      title: Text(isEditing ? 'Modifier le compte' : 'Créer un compte'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Saisissez le nom complet.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.contains('@')
                        ? null
                        : 'Saisissez une adresse e-mail valide.';
                  },
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe temporaire',
                    ),
                    validator: (value) => (value?.length ?? 0) < 10
                        ? 'Utilisez au moins 10 caractères.'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<StaffRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rôle'),
                  items: [
                    for (final role in StaffRole.values)
                      DropdownMenuItem(value: role, child: Text(role.label)),
                  ],
                  onChanged: (role) {
                    if (role != null) setState(() => _role = role);
                  },
                ),
                if (_role == StaffRole.doctor) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _doctorServiceId,
                    decoration: const InputDecoration(labelText: 'Service'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Aucun service'),
                      ),
                      for (final service in widget.services)
                        DropdownMenuItem<String?>(
                          value: service.id,
                          child: Text(service.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _doctorServiceId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _specialtyController,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Spécialité du médecin',
                    ),
                  ),
                  TextFormField(
                    controller: _photoUrlController,
                    maxLength: 500,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL de la photo',
                    ),
                  ),
                ],
                if (_role == StaffRole.secretary) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Services affectés',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.services.isEmpty)
                    const Text('Créez un service avant l’affectation.')
                  else
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final service in widget.services)
                          FilterChip(
                            label: Text(service.name),
                            selected: _secretaryServiceIds.contains(service.id),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _secretaryServiceIds.add(service.id);
                              } else {
                                _secretaryServiceIds.remove(service.id);
                              }
                              _assignmentError = null;
                            }),
                          ),
                      ],
                    ),
                  if (_assignmentError != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _assignmentError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Enregistrer' : 'Créer le compte'),
        ),
      ],
    );
  }
}

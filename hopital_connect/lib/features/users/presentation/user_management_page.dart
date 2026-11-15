import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../services/data/service_service.dart';
import '../../services/domain/hospital_service.dart';
import '../../hospital/data/hospital_resource_service.dart';
import '../../hospital/domain/hospital_resources.dart';
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
  List<Hospital> _hospitals = const [];
  bool _isLoading = true;
  String? _error;

  List<String> get _existingSpecialties {
    final specialties = _users
        .map((user) => user.specialty.trim())
        .where((specialty) => specialty.isNotEmpty)
        .toSet()
        .toList();
    specialties.sort();
    return specialties;
  }

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
        HospitalResourceService().hospitals(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<StaffUser>;
          _services = results[1] as List<HospitalService>;
          _hospitals = results[2] as List<Hospital>;
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
      builder: (_) => _UserDialog(
        services: _services,
        hospitals: _hospitals,
        specialties: _existingSpecialties,
      ),
    );
    if (input == null || !mounted) return;
    try {
      final user = await widget.service.create(
        username: input.username,
        email: input.email,
        password: input.password!,
        role: input.role.apiValue,
        roles: input.roles.map((role) => role.apiValue).toList(),
        hospitalId: input.hospitalId,
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
      builder: (_) => _UserDialog(
        user: user,
        services: _services,
        hospitals: _hospitals,
        specialties: _existingSpecialties,
      ),
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
      roles: user.assignedRoles,
      hospitalId: user.hospitalId,
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
                      '${user.email}\n${user.assignedRoles.map((role) => role.label).join(', ')} · ${user.isActive ? 'Actif' : 'Désactivé'}${assignedServices.isEmpty ? '' : '\nServices : $assignedServices'}',
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
    required this.roles,
    this.hospitalId,
    required this.serviceIds,
    required this.specialty,
    required this.photoUrl,
    this.serviceId,
    this.password,
  });

  final String username;
  final String email;
  final StaffRole role;
  final List<StaffRole> roles;
  final String? hospitalId;
  final String? serviceId;
  final List<String> serviceIds;
  final String specialty;
  final String photoUrl;
  final String? password;
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({
    required this.services,
    required this.hospitals,
    required this.specialties,
    this.user,
  });

  final List<HospitalService> services;
  final List<Hospital> hospitals;
  final List<String> specialties;
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
  late String? _selectedSpecialty =
      widget.user?.specialty.trim().isNotEmpty == true
      ? widget.user!.specialty.trim()
      : null;
  late final _photoUrlController = TextEditingController(
    text: widget.user?.photoUrl ?? '',
  );
  late Set<StaffRole> _roles = Set.of(
    widget.user?.assignedRoles ?? [StaffRole.nurse],
  );
  late String? _hospitalId = widget.user?.hospitalId;
  late String? _managerServiceId =
      widget.user?.serviceId ??
      (widget.user?.serviceIds.isNotEmpty == true
          ? widget.user!.serviceIds.first
          : null);
  String? _assignmentError;

  List<String> get _specialtyOptions {
    final specialties = {...widget.specialties};
    final current = widget.user?.specialty.trim() ?? '';
    if (current.isNotEmpty) specialties.add(current);
    final values = specialties.toList()..sort();
    return values;
  }

  late final Set<String> _assignedServiceIds = {
    if (widget.user != null) ...widget.user!.serviceIds,
    if (widget.user != null &&
        widget.user!.serviceIds.isEmpty &&
        widget.user!.serviceId != null)
      widget.user!.serviceId!,
  };

  StaffRole get _primaryRole =>
      _roles.contains(widget.user?.role) ? widget.user!.role : _roles.first;
  List<HospitalService> get _hospitalServices {
    final hospital = widget.hospitals.where((item) => item.id == _hospitalId);
    if (hospital.isEmpty) return const [];
    final ids = hospital.first.serviceIds.toSet();
    return widget.services
        .where((service) => ids.contains(service.id))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _roles.isEmpty) return;
    if (_roles.contains(StaffRole.secretary) && _assignedServiceIds.isEmpty) {
      setState(
        () =>
            _assignmentError = 'Affectez au moins un service à la secrétaire.',
      );
      return;
    }
    if (_roles.contains(StaffRole.serviceHead) &&
        (_hospitalId == null ||
            _managerServiceId == null ||
            !_hospitalServices.any(
              (service) => service.id == _managerServiceId,
            ))) {
      setState(
        () => _assignmentError = 'Choisissez un hôpital et un service pour le responsable de service.',
      );
      return;
    }
    if (_roles.contains(StaffRole.operatingRoomManager) &&
        _hospitalId == null) {
      setState(
        () => _assignmentError =
            'Choisissez un hôpital pour le responsable de bloc.',
      );
      return;
    }
    final serviceIds =
        _roles.contains(StaffRole.doctor) ||
            _roles.contains(StaffRole.secretary)
        ? _assignedServiceIds.toList()
        : const <String>[];
    final serviceId = _roles.contains(StaffRole.serviceHead)
        ? _managerServiceId
        : (_roles.contains(StaffRole.doctor) ||
                  _roles.contains(StaffRole.secretary)) &&
              serviceIds.isNotEmpty
        ? serviceIds.first
        : null;
    if (widget.user case final user?) {
      Navigator.of(context).pop(
        StaffUser(
          id: user.id,
          displayName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _primaryRole,
          roles: _roles.toList(),
          hospitalId: _hospitalId,
          serviceId: serviceId,
          serviceIds: serviceIds,
          specialty: _selectedSpecialty ?? '',
          photoUrl: _photoUrlController.text.trim(),
          isActive: user.isActive,
        ),
      );
    } else {
      Navigator.of(context).pop(
        _NewUserInput(
          username: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _primaryRole,
          roles: _roles.toList(),
          hospitalId: _hospitalId,
          serviceId: serviceId,
          serviceIds: serviceIds,
          specialty: _selectedSpecialty ?? '',
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
                FormField<Set<StaffRole>>(
                  initialValue: _roles,
                  validator: (roles) => roles == null || roles.isEmpty
                      ? 'Sélectionnez au moins un rôle.'
                      : null,
                  builder: (field) => InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Rôles attribués',
                      errorText: field.errorText,
                      border: const OutlineInputBorder(),
                    ),
                    child: Column(
                      children: [
                        for (final role in StaffRole.values)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(role.label),
                            value: _roles.contains(role),
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _roles = {..._roles, role};
                                } else {
                                  _roles = {..._roles}..remove(role);
                                }
                              });
                              field.didChange(_roles);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                if (_roles.contains(StaffRole.doctor)) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _specialtyOptions.contains(_selectedSpecialty)
                        ? _selectedSpecialty
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Spécialité du médecin',
                    ),
                    items: _specialtyOptions
                        .map(
                          (specialty) => DropdownMenuItem<String>(
                            value: specialty,
                            child: Text(specialty),
                          ),
                        )
                        .toList(),
                    onChanged: _specialtyOptions.isEmpty
                        ? null
                        : (value) => setState(() => _selectedSpecialty = value),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Choisissez une spécialité existante.'
                        : null,
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
                if (_roles.contains(StaffRole.doctor) ||
                    _roles.contains(StaffRole.secretary)) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Services rattachés',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.services.isEmpty &&
                      _roles.contains(StaffRole.secretary))
                    const Text('Créez un service avant l’affectation.')
                  else if (widget.services.isEmpty)
                    const Text('Aucun service disponible.')
                  else
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final service in widget.services)
                          FilterChip(
                            label: Text(service.name),
                            selected: _assignedServiceIds.contains(service.id),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _assignedServiceIds.add(service.id);
                              } else {
                                _assignedServiceIds.remove(service.id);
                              }
                              _assignmentError = null;
                            }),
                          ),
                      ],
                    ),
                ],
                if (_roles.contains(StaffRole.serviceHead) ||
                    _roles.contains(StaffRole.operatingRoomManager)) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue:
                        widget.hospitals.any(
                          (hospital) => hospital.id == _hospitalId,
                        )
                        ? _hospitalId
                        : null,
                    decoration: const InputDecoration(labelText: 'Hôpital'),
                    items: widget.hospitals
                        .map(
                          (hospital) => DropdownMenuItem(
                            value: hospital.id,
                            child: Text(hospital.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _hospitalId = value;
                      if (!_hospitalServices.any(
                        (service) => service.id == _managerServiceId,
                      )) {
                        _managerServiceId = null;
                      }
                      _assignmentError = null;
                    }),
                    validator: (value) =>
                        value == null ? 'Choisissez un hôpital.' : null,
                  ),
                  if (_roles.contains(StaffRole.serviceHead)) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _hospitalServices.any(
                            (service) => service.id == _managerServiceId,
                          )
                          ? _managerServiceId
                          : null,
                      decoration: const InputDecoration(labelText: 'Service'),
                      items: _hospitalServices
                          .map(
                            (service) => DropdownMenuItem(
                              value: service.id,
                              child: Text(service.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _managerServiceId = value;
                        _assignmentError = null;
                      }),
                      validator: (value) =>
                          value == null ? 'Choisissez un service.' : null,
                    ),
                  ],
                ],
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

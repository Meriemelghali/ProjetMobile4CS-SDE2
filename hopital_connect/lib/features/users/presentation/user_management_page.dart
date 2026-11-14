import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
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
      final users = await widget.service.list();
      if (mounted) setState(() => _users = users);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createUser() async {
    final input = await showDialog<_NewUserInput>(
      context: context,
      builder: (_) => const _UserDialog(),
    );
    if (input == null || !mounted) return;
    try {
      final user = await widget.service.create(
        username: input.username,
        email: input.email,
        password: input.password!,
        roles: input.roles.map((role) => role.apiValue).toList(),
      );
      if (mounted) setState(() => _users = [..._users, user]);
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _editUser(StaffUser user) async {
    final edited = await showDialog<StaffUser>(
      context: context,
      builder: (_) => _UserDialog(user: user),
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
      serviceId: user.serviceId,
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
                      '${user.email}\n${user.assignedRoles.map((role) => role.label).join(', ')} · ${user.isActive ? 'Actif' : 'Désactivé'}',
                    ),
                    isThreeLine: true,
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
    required this.roles,
    this.password,
  });

  final String username;
  final String email;
  final List<StaffRole> roles;
  final String? password;
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({this.user});

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
  late Set<StaffRole> _roles = Set.of(
    widget.user?.assignedRoles ?? [StaffRole.nurse],
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _roles.isEmpty) return;
    if (widget.user case final user?) {
      Navigator.of(context).pop(
        StaffUser(
          id: user.id,
          displayName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _roles.first,
          roles: _roles.toList(),
          serviceId: user.serviceId,
          isActive: user.isActive,
        ),
      );
    } else {
      Navigator.of(context).pop(
        _NewUserInput(
          username: _nameController.text.trim(),
          email: _emailController.text.trim(),
          roles: _roles.toList(),
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

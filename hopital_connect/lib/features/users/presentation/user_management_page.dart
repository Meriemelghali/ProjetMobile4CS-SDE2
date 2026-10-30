import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/staff_role.dart';
import '../domain/staff_user.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({
    super.key,
    required this.users,
    required this.onUsersChanged,
  });

  final List<StaffUser> users;
  final ValueChanged<List<StaffUser>> onUsersChanged;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  late final List<StaffUser> _users = List.of(widget.users);

  Future<void> _createUser() async {
    final user = await showDialog<StaffUser>(
      context: context,
      builder: (context) => const _CreateUserDialog(),
    );
    if (user == null || !mounted) return;

    final emailAlreadyUsed = _users.any(
      (existing) => existing.email.toLowerCase() == user.email.toLowerCase(),
    );
    if (emailAlreadyUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cette adresse e-mail existe déjà.')),
      );
      return;
    }

    setState(() => _users.add(user));
    widget.onUsersChanged(List.unmodifiable(_users));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptes du personnel'),
        foregroundColor: AppColors.navy,
        backgroundColor: AppColors.background,
      ),
      body: _users.isEmpty
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
                      backgroundColor: const Color(0xFFE1F2EF),
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
                    subtitle: Text('${user.email}\n${user.role.label}'),
                    isThreeLine: true,
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

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  StaffRole _role = StaffRole.nurse;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      StaffUser(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un compte du personnel'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
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
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty || !email.contains('@')) {
                    return 'Saisissez une adresse e-mail valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<StaffRole>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Rôle',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: [
                  for (final role in StaffRole.values)
                    DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: (role) {
                  if (role != null) setState(() => _role = role);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Ce compte sera conservé en mémoire uniquement pendant cette session.',
                style: TextStyle(fontSize: 12, color: Color(0xFF687B86)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _save, child: const Text('Créer le compte')),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';

class ServiceTab extends StatelessWidget {
  const ServiceTab({super.key, required this.services});

  final List<HospitalService> services;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final service in services) ...[
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5ECEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: Color(0xFFE1F2EF),
                  child: Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  service.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  service.description,
                  style: const TextStyle(color: Color(0xFF687B86), height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  service.location,
                  style: const TextStyle(
                    color: Color(0xFF8797A0),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 24),
        const SectionIntro(
          title: 'Équipe de démonstration',
          subtitle: 'Membres fictifs, communs aux services de la maquette',
        ),
        const SizedBox(height: 12),
        const TeamMember(
          name: 'Samira Benali',
          role: 'Médecin',
          initials: 'SB',
        ),
        const TeamMember(
          name: 'Yassine Amrani',
          role: 'Infirmier',
          initials: 'YA',
        ),
        const TeamMember(
          name: 'Nour Haddad',
          role: 'Infirmière',
          initials: 'NH',
        ),
        const SizedBox(height: 12),
        const DemoNotice(),
      ],
    );
  }
}

class HospitalService {
  const HospitalService({
    required this.name,
    required this.location,
    required this.description,
  });

  final String name;
  final String location;
  final String description;
}

class NewServiceDialog extends StatefulWidget {
  const NewServiceDialog({super.key});

  @override
  State<NewServiceDialog> createState() => _NewServiceDialogState();
}

class _NewServiceDialogState extends State<NewServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      HospitalService(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un service'),
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
                  decoration: const InputDecoration(
                    labelText: 'Nom du service',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Saisissez un nom.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Emplacement',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Saisissez un emplacement.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Saisissez une description.'
                      : null,
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
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }
}

class TeamMember extends StatelessWidget {
  const TeamMember({
    super.key,
    required this.name,
    required this.role,
    required this.initials,
  });

  final String name;
  final String role;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE1F2EF),
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.blue,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(role),
    );
  }
}

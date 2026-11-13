import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/hospital_service.dart';

class ServiceTab extends StatelessWidget {
  const ServiceTab({
    super.key,
    required this.services,
    this.canEdit = false,
    this.onEdit,
  });

  final List<HospitalService> services;
  final bool canEdit;
  final ValueChanged<HospitalService>? onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (services.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Aucun service n’est encore enregistré.',
              textAlign: TextAlign.center,
            ),
          ),
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
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFE1F2EF),
                      child: Icon(
                        Icons.medical_services_outlined,
                        color: AppColors.blue,
                      ),
                    ),
                    const Spacer(),
                    if (canEdit)
                      IconButton(
                        tooltip: 'Modifier le service',
                        onPressed: () => onEdit?.call(service),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
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
      ],
    );
  }
}

class NewServiceDialog extends StatefulWidget {
  const NewServiceDialog({super.key, this.service});

  final HospitalService? service;

  @override
  State<NewServiceDialog> createState() => _NewServiceDialogState();
}

class _NewServiceDialogState extends State<NewServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.service?.name ?? '',
  );
  late final _locationController = TextEditingController(
    text: widget.service?.location ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.service?.description ?? '',
  );

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
        id: widget.service?.id ?? '',
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        isActive: widget.service?.isActive ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.service == null ? 'Ajouter un service' : 'Modifier le service',
      ),
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
        FilledButton(
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

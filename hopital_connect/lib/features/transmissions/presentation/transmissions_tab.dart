import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';

class HandoversTab extends StatelessWidget {
  const HandoversTab({super.key, required this.handovers});

  final List<Handover> handovers;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionIntro(
          title: 'Informations de l’équipe',
          subtitle: 'Consignes opérationnelles non médicales',
        ),
        const SizedBox(height: 14),
        for (final handover in handovers) ...[
          HandoverCard(handover: handover),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 72),
        const DemoNotice(),
      ],
    );
  }
}

class Handover {
  const Handover({
    required this.title,
    required this.message,
    required this.time,
    required this.author,
    this.important = false,
  });

  final String title;
  final String message;
  final String time;
  final String author;
  final bool important;
}

class HandoverCard extends StatelessWidget {
  const HandoverCard({super.key, required this.handover});

  final Handover handover;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: handover.important
              ? const Color(0xFFB9DFD6)
              : const Color(0xFFE5ECEF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  handover.title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (handover.important)
                const Icon(
                  Icons.push_pin_outlined,
                  color: AppColors.mint,
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            handover.message,
            style: const TextStyle(color: Color(0xFF536A77), height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            '${handover.author} · ${handover.time}',
            style: const TextStyle(color: Color(0xFF8797A0), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class NewHandoverDialog extends StatefulWidget {
  const NewHandoverDialog({super.key});

  @override
  State<NewHandoverDialog> createState() => _NewHandoverDialogState();
}

class _NewHandoverDialogState extends State<NewHandoverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Handover(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        time: 'À l’instant',
        author: 'Personnel connecté',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle transmission'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ajoutez un titre.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Information opérationnelle',
                  alignLabelWithHint: true,
                  helperText: 'Ne saisissez aucune donnée de patient.',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ajoutez une information.'
                    : null,
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
        FilledButton(onPressed: _save, child: const Text('Publier')),
      ],
    );
  }
}

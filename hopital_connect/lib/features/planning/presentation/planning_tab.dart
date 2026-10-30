import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';

class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key, required this.shifts});

  final List<Shift> shifts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionIntro(
          title: 'Cette semaine',
          subtitle: 'Vos horaires de démonstration',
        ),
        const SizedBox(height: 18),
        for (final shift in shifts) ...[
          ShiftCard(
            day: shift.day,
            time: shift.time,
            role: shift.role,
            service: shift.service,
            color: shift.color,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 18),
        const DemoNotice(),
      ],
    );
  }
}

class Shift {
  const Shift({
    required this.day,
    required this.time,
    required this.role,
    required this.service,
    required this.color,
  });

  final String day;
  final String time;
  final String role;
  final String service;
  final Color color;
}

class NewShiftDialog extends StatefulWidget {
  const NewShiftDialog({super.key, required this.services});

  final List<String> services;

  @override
  State<NewShiftDialog> createState() => _NewShiftDialogState();
}

class _NewShiftDialogState extends State<NewShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _staffController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 15, minute: 0);
  String _staffRole = 'Infirmier';
  late String _service = widget.services.first;

  @override
  void dispose() {
    _staffController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Choisir le jour de la garde',
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _chooseTime({required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Début de la garde' : 'Fin de la garde',
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  String _formatDate() {
    final today = DateTime.now();
    final dateOnly = DateTime(_date.year, _date.month, _date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (dateOnly == todayOnly) return 'Aujourd’hui';
    if (dateOnly == todayOnly.add(const Duration(days: 1))) return 'Demain';
    const weekdays = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    return '${weekdays[_date.weekday - 1]} ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final startMinutes = _start.hour * 60 + _start.minute;
    final endMinutes = _end.hour * 60 + _end.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’heure de fin doit suivre l’heure de début.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      Shift(
        day: _formatDate(),
        time: '${_start.format(context)} – ${_end.format(context)}',
        role: '$_staffRole · ${_staffController.text.trim()}',
        service: _service,
        color: _staffRole == 'Médecin' ? AppColors.blue : AppColors.mint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une garde'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _staffController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du membre du personnel',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Indiquez le nom du membre.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _staffRole,
                  decoration: const InputDecoration(labelText: 'Fonction'),
                  items: const [
                    DropdownMenuItem(value: 'Médecin', child: Text('Médecin')),
                    DropdownMenuItem(
                      value: 'Infirmier',
                      child: Text('Infirmier'),
                    ),
                    DropdownMenuItem(
                      value: 'Personnel',
                      child: Text('Personnel'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _staffRole = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _service,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: [
                    for (final service in widget.services)
                      DropdownMenuItem(value: service, child: Text(service)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _service = value);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Date'),
                  subtitle: Text(_formatDate()),
                  onTap: _chooseDate,
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _chooseTime(isStart: true),
                        icon: const Icon(Icons.login),
                        label: Text('Début ${_start.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _chooseTime(isStart: false),
                        icon: const Icon(Icons.logout),
                        label: Text('Fin ${_end.format(context)}'),
                      ),
                    ),
                  ],
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

class ShiftCard extends StatelessWidget {
  const ShiftCard({
    super.key,
    required this.day,
    required this.time,
    required this.role,
    required this.service,
    required this.color,
  });

  final String day;
  final String time;
  final String role;
  final String service;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(role, style: const TextStyle(color: Color(0xFF687B86))),
                const SizedBox(height: 4),
                Text(
                  service,
                  style: const TextStyle(
                    color: Color(0xFF8797A0),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

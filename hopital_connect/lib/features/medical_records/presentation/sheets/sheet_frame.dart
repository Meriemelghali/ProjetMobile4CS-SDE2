import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../widgets/record_ui.dart';

/// Ouvre une feuille modale plein écran-ish avec coins arrondis.
Future<T?> showRecordSheet<T>(BuildContext context, Widget sheet) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );

/// Cadre commun des formulaires : poignée, titre, contenu défilant et
/// bouton principal avec état de chargement et message d'erreur.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.isSaving = false,
    this.error,
    this.formKey,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool isSaving;
  final String? error;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7FAFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD3DDE1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: RecordColors.headerGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: RecordColors.ink,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(color: RecordColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: children,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: error == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(error),
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: RecordColors.critical.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(color: RecordColors.critical),
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSaving ? null : onSubmit,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        submitLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: RecordColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}

/// Bouton de sélection de date au style d'un champ.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Choisir une date',
    this.withTime = false,
    this.firstDate,
    this.lastDate,
    this.clearable = false,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String placeholder;
  final bool withTime;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(1900),
      lastDate: lastDate ?? DateTime(now.year + 5),
    );
    if (date == null || !context.mounted) return;
    if (!withTime) return onChanged(date);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? now),
    );
    onChanged(
      DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? (value ?? now).hour,
        time?.minute ?? (value ?? now).minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => _pick(context),
    child: InputDecorator(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.event_outlined),
        suffixIcon: clearable && value != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              )
            : null,
      ),
      child: Text(
        value == null
            ? placeholder
            : (withTime ? formatDayTime(value!) : formatDay(value!)),
        style: TextStyle(
          color: value == null ? RecordColors.muted : RecordColors.ink,
        ),
      ),
    ),
  );
}

String errorMessage(Object error) =>
    error is ApiException ? error.message : 'Une erreur est survenue.';

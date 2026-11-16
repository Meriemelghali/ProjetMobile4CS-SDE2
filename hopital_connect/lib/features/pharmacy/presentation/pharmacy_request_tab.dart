import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../services/domain/hospital_service.dart';
import '../../users/domain/staff_user.dart';
import '../data/pharmacy_service.dart';
import '../domain/pharmacy_models.dart';

class PharmacyRequestTab extends StatefulWidget {
  const PharmacyRequestTab({
    super.key,
    required this.user,
    required this.services,
  });

  final StaffUser user;
  final List<HospitalService> services;

  @override
  State<PharmacyRequestTab> createState() => _PharmacyRequestTabState();
}

class _PharmacyRequestTabState extends State<PharmacyRequestTab> {
  final _service = PharmacyService();
  final _search = TextEditingController();
  final Map<String, TextEditingController> _quantities = {};
  List<Medication> _medications = const [];
  String? _serviceId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  bool get _canChooseService =>
      widget.user.role.apiValue == 'admin' || widget.services.length > 1;

  @override
  void initState() {
    super.initState();
    final assigned = widget.services;
    _serviceId = widget.user.serviceId ??
        (assigned.length == 1 ? assigned.first.id : null);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await _service.medications();
      if (!mounted) return;
      setState(() {
        _medications = values;
        _loading = false;
        _error = null;
        for (final item in values) {
          _quantities.putIfAbsent(item.id, () => TextEditingController());
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _submit() async {
    if (_serviceId == null) {
      _message('Aucun service associé à votre compte.');
      return;
    }
    final selected = <Map<String, Object?>>[];
    for (final item in _medications) {
      final raw = _quantities[item.id]!.text.trim();
      if (raw.isEmpty) continue;
      final quantity = int.tryParse(raw);
      if (quantity == null || quantity <= 0) {
        _message('Saisissez une quantité entière positive pour ${item.name}.');
        return;
      }
      selected.add({'medicationId': item.id, 'quantity': quantity});
    }
    if (selected.isEmpty) {
      _message('Ajoutez au moins un médicament à la demande.');
      return;
    }

    setState(() => _sending = true);
    try {
      await _service.createRequest({
        'serviceId': _serviceId,
        'medications': selected,
      });
      if (!mounted) return;
      for (final controller in _quantities.values) {
        controller.clear();
      }
      _message('Demande envoyée à la pharmacie.');
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final medications = _medications.where((item) =>
        '${item.name} ${item.activeIngredient} ${item.form} ${item.dosage}'
            .toLowerCase()
            .contains(query)).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(_error!),
                ))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Demande de médicaments', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Choisissez les produits et quantités à transmettre à la pharmacie.', style: TextStyle(color: Color(0xFF687B86))),
                      if (_canChooseService) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _serviceId,
                          decoration: const InputDecoration(labelText: 'Service', border: OutlineInputBorder()),
                          items: widget.services.map((service) => DropdownMenuItem(value: service.id, child: Text(service.name))).toList(),
                          onChanged: (value) => setState(() => _serviceId = value),
                        ),
                      ] else if (_serviceId == null)
                        const Padding(padding: EdgeInsets.only(top: 12), child: Text('Aucun service n’est associé à ce compte.', style: TextStyle(color: Colors.red))),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un médicament', border: OutlineInputBorder()),
                      ),
                    ]),
                  ),
                  Expanded(child: medications.isEmpty
                      ? _EmptyRequest(message: _medications.isEmpty ? 'Le catalogue pharmacie est vide.' : 'Aucun résultat.')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: medications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final item = medications[index];
                            return Card(child: ListTile(
                              title: Text(item.name),
                              subtitle: Text('${item.activeIngredient} · ${item.form} ${item.dosage} · Disponible : ${item.stockQuantity}'),
                              trailing: SizedBox(width: 76, child: TextField(
                                controller: _quantities[item.id],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(labelText: 'Qté', border: OutlineInputBorder(), isDense: true),
                              )),
                            ));
                          },
                        )),
                  SafeArea(top: false, child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: _sending || _serviceId == null ? null : _submit,
                      icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_outlined),
                      label: Text(_sending ? 'Envoi…' : 'Envoyer la demande'),
                    )),
                  )),
                ]),
    );
  }
}

class _EmptyRequest extends StatelessWidget {
  const _EmptyRequest({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF687B86))),
        ),
      );
}

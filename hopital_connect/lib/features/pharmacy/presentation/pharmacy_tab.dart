import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../users/domain/staff_user.dart';
import '../data/pharmacy_service.dart';
import '../domain/pharmacy_models.dart';

class PharmacyTab extends StatefulWidget {
  const PharmacyTab({super.key, required this.user});
  final StaffUser user;

  @override
  State<PharmacyTab> createState() => _PharmacyTabState();
}

class _PharmacyTabState extends State<PharmacyTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);
  final _service = PharmacyService();
  List<Medication> _medications = const [];
  List<Medication> _alerts = const [];
  List<Prescription> _prescriptionItems = const [];
  List<Dispensation> _dispensations = const [];
  List<MedicationRequest> _requests = const [];
  List<SupplyOrder> _orders = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _service.medications(),
        _service.alerts(),
        _service.prescriptions(),
        _service.dispensations(),
        _service.requests(),
        _service.orders(),
      ]);
      if (!mounted) return;
      setState(() {
        _medications = values[0] as List<Medication>;
        _alerts = values[1] as List<Medication>;
        _prescriptionItems = values[2] as List<Prescription>;
        _dispensations = values[3] as List<Dispensation>;
        _requests = values[4] as List<MedicationRequest>;
        _orders = values[5] as List<SupplyOrder>;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted)
        setState(() {
          _error = error.message;
          _loading = false;
        });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Gestion Pharmacie'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Tableau de bord'),
          Tab(text: 'Stock'),
          Tab(text: 'Ordonnances'),
          Tab(text: 'Demandes'),
          Tab(text: 'Commandes'),
          Tab(text: 'Historique'),
        ],
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _errorView()
        : TabBarView(
            controller: _tabs,
            children: [
              _dashboard(),
              _stock(),
              _prescriptions(),
              _requestsView(),
              _ordersView(),
              _history(),
            ],
          ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );

  Widget _dashboard() {
    final pending = _prescriptionItems
        .where((item) => item.status == PrescriptionStatus.pending)
        .length;
    final out = _medications.where((item) => item.isOutOfStock).length;
    final low = _medications
        .where((item) => item.isUnderThreshold && !item.isOutOfStock)
        .length;
    final expiry = _medications.where((item) => item.isNearExpiry).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Bonjour ${widget.user.displayName}',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.navy),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric(
              'Ordonnances en attente',
              '$pending',
              Icons.receipt_long_outlined,
            ),
            _metric('Ruptures', '$out', Icons.warning_amber_outlined),
            _metric('Sous le seuil', '$low', Icons.inventory_2_outlined),
            _metric(
              'Péremption < 30 jours',
              '$expiry',
              Icons.event_busy_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Alertes stock',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_alerts.isEmpty)
          const _Empty(message: 'Aucune alerte actuellement.')
        else
          ..._alerts.map(_medicationTile),
      ],
    );
  }

  Widget _metric(String title, String value, IconData icon) => SizedBox(
    width: 180,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ),
  );

  Widget _stock() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _addMedication,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un médicament'),
        ),
      ),
      const SizedBox(height: 12),
      if (_medications.isEmpty)
        const _Empty(message: 'Aucun médicament dans cette pharmacie.')
      else
        ..._medications.map(_medicationTile),
    ],
  );

  Widget _medicationTile(Medication item) {
    final color = item.isOutOfStock
        ? Colors.red
        : item.isUnderThreshold
        ? Colors.orange
        : Colors.green;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Icon(Icons.medication_outlined, color: color),
        ),
        title: Text(item.name),
        subtitle: Text(
          '${item.activeIngredient} · ${item.form} ${item.dosage}\nLot ${item.lot} · Exp. ${_date(item.expirationDate)} · Stock ${item.stockQuantity}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'stock') _adjustStock(item);
            if (action == 'edit') _editMedication(item);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'stock', child: Text('Ajuster le stock')),
            PopupMenuItem(value: 'edit', child: Text('Modifier')),
          ],
        ),
      ),
    );
  }

  Widget _prescriptions() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (_prescriptionItems.isEmpty)
        const _Empty(message: 'Aucune ordonnance.')
      else
        ..._prescriptionItems.map(
          (item) => Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              onTap: () => _showPrescriptionDetails(item),
              title: Text(
                item.patientName.isEmpty
                    ? 'Patient non renseigné'
                    : item.patientName,
              ),
              subtitle: Text(
                '${item.medications.map(_lineLabel).join(', ')}\n${item.status.name}${item.rejectionReason.isEmpty ? '' : ' · ${item.rejectionReason}'}${item.patientAllergies.isEmpty ? '' : '\nAllergies : ${item.patientAllergies.join(', ')}'}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (action) => _prescriptionAction(item, action),
                itemBuilder: (_) => [
                  if (item.status == PrescriptionStatus.pending)
                    const PopupMenuItem(
                      value: 'validate',
                      child: Text('Valider'),
                    ),
                  if (item.status == PrescriptionStatus.pending ||
                      item.status == PrescriptionStatus.validated)
                    const PopupMenuItem(
                      value: 'dispense',
                      child: Text('Dispenser'),
                    ),
                  if (item.status != PrescriptionStatus.dispensed &&
                      item.status != PrescriptionStatus.rejected)
                    const PopupMenuItem(
                      value: 'reject',
                      child: Text('Refuser'),
                    ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _requestsView() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (_requests.isEmpty)
        const _Empty(message: 'Aucune demande de service.')
      else
        ..._requests.map(
          (item) => Card(
            child: ListTile(
              title: Text('Service ${item.serviceId}'),
              subtitle: Text(
                '${item.medications.map(_lineLabel).join(', ')} · ${item.status}',
              ),
              trailing: item.status == 'pending'
                  ? PopupMenuButton<String>(
                      onSelected: (action) =>
                          _run(() => _service.requestAction(item.id, action)),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'approve',
                          child: Text('Approuver'),
                        ),
                        PopupMenuItem(value: 'reject', child: Text('Refuser')),
                      ],
                    )
                  : item.status == 'approved'
                  ? TextButton(
                      onPressed: () => _run(
                        () => _service.requestAction(item.id, 'deliver'),
                      ),
                      child: const Text('Livrée'),
                    )
                  : null,
            ),
          ),
        ),
    ],
  );

  Widget _ordersView() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _newOrder,
          icon: const Icon(Icons.add),
          label: const Text('Nouvelle commande'),
        ),
      ),
      const SizedBox(height: 12),
      if (_orders.isEmpty)
        const _Empty(message: 'Aucune commande fournisseur.')
      else
        ..._orders.map(
          (item) => Card(
            child: ListTile(
              title: Text(item.supplier),
              subtitle: Text(
                '${item.medications.map(_lineLabel).join(', ')} · ${item.status}',
              ),
              trailing: item.status == 'ordered'
                  ? TextButton(
                      onPressed: () =>
                          _run(() => _service.receiveOrder(item.id)),
                      child: const Text('Réceptionner'),
                    )
                  : null,
            ),
          ),
        ),
    ],
  );

  Widget _history() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (_dispensations.isEmpty)
        const _Empty(message: 'Aucune dispensation enregistrée.')
      else
        ..._dispensations.map(
          (item) => Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text('Ordonnance ${item.prescriptionId}'),
              subtitle: Text(item.medications.map(_lineLabel).join(', ')),
              trailing: Text(
                item.dispensedAt == null ? '' : _date(item.dispensedAt!),
              ),
            ),
          ),
        ),
    ],
  );

  Future<void> _prescriptionAction(Prescription item, String action) async {
    if (action == 'dispense') return _run(() => _service.dispense(item.id));
    if (action == 'reject') {
      final reason = await _reasonDialog();
      if (reason == null) return;
      return _run(
        () => _service.prescriptionAction(item.id, action, reason: reason),
      );
    }
    return _run(() => _service.prescriptionAction(item.id, action));
  }

  Future<void> _showPrescriptionDetails(Prescription item) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Détail de l’ordonnance'),
      content: Text(
        'Patient : ${item.patientName}\nMédecin : ${item.doctorName}\n'
        'Allergies : ${item.patientAllergies.isEmpty ? 'Aucune renseignée' : item.patientAllergies.join(', ')}\n\n'
        'Traitement :\n${item.medications.map((line) => '• ${_lineLabel(line)}').join('\n')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );

  Future<String?> _reasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Motif du refus'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Motif obligatoire'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim().isEmpty ? null : controller.text.trim(),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMedication() async => _medicationDialog();
  Future<void> _editMedication(Medication item) async =>
      _medicationDialog(item);
  Future<void> _medicationDialog([Medication? item]) async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _MedicationDialog(item: item),
    );
    if (values == null) return;
    await _run(() async {
      if (item == null)
        await _service.createMedication(values);
      else
        await _service.updateMedication(item.id, values);
    });
  }

  Future<void> _adjustStock(Medication item) async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Ajuster ${item.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantité à ajouter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (value != null && value > 0)
      await _run(() => _service.adjustStock(item.id, value));
  }

  Future<void> _newOrder() async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _OrderDialog(medications: _medications),
    );
    if (values != null) await _run(() => _service.createOrder(values));
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _lineLabel(PharmacyLine line) =>
      '${line.name}${line.dosage.isEmpty ? '' : ' ${line.dosage}'} x${line.quantity}';
}

class _MedicationDialog extends StatefulWidget {
  const _MedicationDialog({this.item});
  final Medication? item;
  @override
  State<_MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<_MedicationDialog> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _ingredient = TextEditingController(
    text: widget.item?.activeIngredient,
  );
  late final _form = TextEditingController(text: widget.item?.form);
  late final _dosage = TextEditingController(text: widget.item?.dosage);
  late final _stock = TextEditingController(
    text: '${widget.item?.stockQuantity ?? 0}',
  );
  late final _threshold = TextEditingController(
    text: '${widget.item?.alertThreshold ?? 0}',
  );
  late final _lot = TextEditingController(text: widget.item?.lot);
  late final _expiry = TextEditingController(
    text: widget.item == null
        ? ''
        : '${widget.item!.expirationDate.year.toString().padLeft(4, '0')}-${widget.item!.expirationDate.month.toString().padLeft(2, '0')}-${widget.item!.expirationDate.day.toString().padLeft(2, '0')}',
  );
  late final _price = TextEditingController(text: '${widget.item?.price ?? 0}');
  @override
  void dispose() {
    for (final c in [
      _name,
      _ingredient,
      _form,
      _dosage,
      _stock,
      _threshold,
      _lot,
      _expiry,
      _price,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.item == null ? 'Ajouter un médicament' : 'Modifier le médicament',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_name, 'Nom'),
          _field(_ingredient, 'DCI'),
          _field(_form, 'Forme'),
          _field(_dosage, 'Dosage'),
          _field(_stock, 'Stock', number: true),
          _field(_threshold, 'Seuil d’alerte', number: true),
          _field(_lot, 'Lot'),
          _field(_expiry, 'Péremption (AAAA-MM-JJ)'),
          _field(_price, 'Prix', number: true),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          final result = <String, Object?>{
            'name': _name.text,
            'activeIngredient': _ingredient.text,
            'form': _form.text,
            'dosage': _dosage.text,
            'stockQuantity': int.tryParse(_stock.text) ?? 0,
            'alertThreshold': int.tryParse(_threshold.text) ?? 0,
            'lot': _lot.text,
            'expirationDate': _expiry.text,
            'price': double.tryParse(_price.text) ?? 0,
          };
          Navigator.pop(context, result);
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
  Widget _field(TextEditingController c, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({required this.medications});
  final List<Medication> medications;
  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  final _supplier = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  String? _medicationId;
  @override
  void dispose() {
    _supplier.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle commande fournisseur'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _supplier,
          decoration: const InputDecoration(labelText: 'Fournisseur'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _medicationId,
          decoration: const InputDecoration(labelText: 'Médicament'),
          items: widget.medications
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => _medicationId = value),
        ),
        TextField(
          controller: _quantity,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantité'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _medicationId == null
            ? null
            : () => Navigator.pop(context, {
                'supplier': _supplier.text.trim(),
                'medications': [
                  {
                    'medicationId': _medicationId,
                    'quantity': int.tryParse(_quantity.text) ?? 0,
                  },
                ],
              }),
        child: const Text('Créer'),
      ),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF687B86)),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  final _stockSearch = TextEditingController();
  String _stockFilter = 'Tous';
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
    _stockSearch.dispose();
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
    final expired = _medications.where((item) => item.isExpired).length;
    final stockValue = _medications.fold<double>(0, (total, item) => total + item.stockQuantity * item.price);
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
            _metric('Lots périmés', '', Icons.block_outlined),
            _metric('Valeur du stock', stockValue.toStringAsFixed(2), Icons.payments_outlined),
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

  Widget _stock() {
    final query = _stockSearch.text.trim().toLowerCase();
    final items = _medications.where((item) {
      final matchesQuery = query.isEmpty ||
          '${item.name} ${item.activeIngredient} ${item.lot}'.toLowerCase().contains(query);
      final matchesFilter = switch (_stockFilter) {
        'Rupture' => item.isOutOfStock,
        'Sous le seuil' => item.isUnderThreshold && !item.isOutOfStock,
        'Périmés' => item.isExpired,
        'Bientôt périmés' => item.isNearExpiry,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
        Text('${_medications.length} références · ${_medications.fold<int>(0, (sum, item) => sum + item.stockQuantity)} unités', style: const TextStyle(color: Color(0xFF687B86))),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(onPressed: _openStockCount, icon: const Icon(Icons.fact_check_outlined), label: const Text('Comptage rapide')),
          FilledButton.icon(onPressed: _addMedication, icon: const Icon(Icons.add), label: const Text('Ajouter un médicament')),
        ]),
      ]),
      const SizedBox(height: 12),
      TextField(controller: _stockSearch, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Nom, DCI ou numéro de lot', suffixIcon: _stockSearch.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _stockSearch.clear(); setState(() {}); }), border: const OutlineInputBorder())),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Tous', 'Rupture', 'Sous le seuil', 'Périmés', 'Bientôt périmés']
              .map((filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _stockFilter == filter,
                      onSelected: (_) => setState(() => _stockFilter = filter),
                    ),
                  ))
              .toList(),
        ),
      ),      const SizedBox(height: 8),
      if (items.isEmpty) _Empty(message: _medications.isEmpty ? 'Aucun médicament dans cette pharmacie.' : 'Aucun résultat pour ces filtres.') else ...items.map(_medicationTile),
    ]);
  }

  Widget _medicationTile(Medication item) {
    final color = item.isExpired || item.isOutOfStock ? Colors.red : item.isUnderThreshold ? Colors.orange : Colors.green;
    return Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(Icons.medication_outlined, color: color)),
      title: Text(item.name),
      subtitle: Text('${item.activeIngredient} · ${item.form} ${item.dosage}\nLot ${item.lot} · Exp. ${_date(item.expirationDate)} · Stock ${item.stockQuantity} / seuil ${item.alertThreshold} · ${item.price.toStringAsFixed(2)}'),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(onSelected: (action) { if (action == 'stock') _adjustStock(item); if (action == 'edit') _editMedication(item); }, itemBuilder: (_) => const [PopupMenuItem(value: 'stock', child: Text('Ajuster le stock')), PopupMenuItem(value: 'edit', child: Text('Modifier'))]),
    ));
  }
  Widget _prescriptions() {
    final pending = _prescriptionItems.where((item) => item.status == PrescriptionStatus.pending).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionIntro('Ordonnances', '$pending à traiter · ${_prescriptionItems.length} au total'),
        if (_prescriptionItems.isEmpty) const _Empty(message: 'Aucune ordonnance.')
        else ..._prescriptionItems.map((item) {
          final statusColor = switch (item.status) {
            PrescriptionStatus.pending => Colors.orange,
            PrescriptionStatus.validated => AppColors.blue,
            PrescriptionStatus.dispensed => AppColors.mint,
            PrescriptionStatus.rejected => Colors.red,
          };
          final statusLabel = switch (item.status) {
            PrescriptionStatus.pending => 'En attente',
            PrescriptionStatus.validated => 'Validée',
            PrescriptionStatus.dispensed => 'Délivrée',
            PrescriptionStatus.rejected => 'Refusée',
          };
          return Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: statusColor.withOpacity(.12), child: Icon(Icons.receipt_long_outlined, color: statusColor)),
            onTap: () => _showPrescriptionDetails(item),
            title: Text(item.patientName.isEmpty ? 'Patient non renseigné' : item.patientName),
            subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.medications.map(_lineLabel).join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (item.patientAllergies.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Allergies : ${item.patientAllergies.join(', ')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
              if (item.rejectionReason.isNotEmpty) Text('Motif : ${item.rejectionReason}'),
              const SizedBox(height: 4),
              Text('$statusLabel${item.createdAt == null ? '' : ' · ${_date(item.createdAt!)}'}', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
            ])),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(onSelected: (action) => _prescriptionAction(item, action), itemBuilder: (_) => [
              if (item.status == PrescriptionStatus.pending) const PopupMenuItem(value: 'validate', child: Text('Valider')),
              if (item.status == PrescriptionStatus.pending || item.status == PrescriptionStatus.validated) const PopupMenuItem(value: 'dispense', child: Text('Dispenser')),
              if (item.status != PrescriptionStatus.dispensed && item.status != PrescriptionStatus.rejected) const PopupMenuItem(value: 'reject', child: Text('Refuser')),
            ]),
          ));
        }),
      ],
    );
  }

  Widget _sectionIntro(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xFF687B86))),
    ]),
  );
  Widget _requestsView() {
    final pending = _requests.where((item) => item.status == 'pending').length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sectionIntro('Demandes des services', '$pending en attente · ${_requests.length} au total'),
      if (_requests.isEmpty) const _Empty(message: 'Aucune demande de service.')
      else ..._requests.map((item) => Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.blue.withOpacity(.1), child: const Icon(Icons.medical_services_outlined, color: AppColors.blue)),
        title: Text('Service ${item.serviceId}'),
        subtitle: Text('${item.medications.map(_lineLabel).join(', ')}\n${_statusLabel(item.status)}${item.rejectionReason.isEmpty ? '' : ' · ${item.rejectionReason}'}'),
        isThreeLine: true,
        trailing: item.status == 'pending'
            ? PopupMenuButton<String>(onSelected: (action) async {
                if (action == 'reject') {
                  final reason = await _reasonDialog();
                  if (reason == null) return;
                  await _run(() => _service.requestAction(item.id, action, reason: reason));
                } else {
                  await _run(() => _service.requestAction(item.id, action));
                }
              }, itemBuilder: (_) => const [PopupMenuItem(value: 'approve', child: Text('Approuver')), PopupMenuItem(value: 'reject', child: Text('Refuser'))])
            : item.status == 'approved'
                ? TextButton(onPressed: () => _run(() => _service.requestAction(item.id, 'deliver')), child: const Text('Livrer'))
                : null,
      ))),
    ]);
  }

  String _statusLabel(String status) => switch (status) {
    'pending' => 'En attente', 'approved' => 'Approuvée', 'delivered' => 'Livrée', 'rejected' => 'Refusée', _ => status,
  };
  Widget _ordersView() {
    final ordered = _orders.where((item) => item.status == 'ordered').length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
        _sectionIntro('Commandes fournisseur', '$ordered à réceptionner · ${_orders.length} au total'),
        FilledButton.icon(onPressed: _newOrder, icon: const Icon(Icons.add), label: const Text('Nouvelle commande')),
      ]),
      if (_orders.isEmpty) const _Empty(message: 'Aucune commande fournisseur.')
      else ..._orders.map((item) => Card(child: ExpansionTile(
        leading: Icon(item.status == 'received' ? Icons.inventory_rounded : Icons.local_shipping_outlined, color: item.status == 'received' ? AppColors.mint : AppColors.blue),
        title: Text(item.supplier),
        subtitle: Text('${_statusLabel(item.status)} · ${item.medications.length} référence(s)'),
        trailing: item.status == 'ordered' ? TextButton(onPressed: () => _run(() => _service.receiveOrder(item.id)), child: const Text('Réceptionner')) : null,
        children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: item.medications.map((line) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(line.name)), Text('× ${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w600))]))).toList()))],
      ))),
    ]);
  }

  Widget _history() {
    final received = _orders.where((item) => item.status == 'received').length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sectionIntro('Historique des mouvements', '${_dispensations.length} délivrances · $received commandes réceptionnées'),
      if (_dispensations.isEmpty && received == 0) const _Empty(message: 'Aucun mouvement enregistré.')
      else ...[
        if (_dispensations.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Délivrances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ..._dispensations.map((item) => Card(child: ListTile(leading: const Icon(Icons.outbox_outlined, color: AppColors.blue), title: Text('Ordonnance ${item.prescriptionId}'), subtitle: Text(item.medications.map(_lineLabel).join(', ')), trailing: Text(item.dispensedAt == null ? '' : _date(item.dispensedAt!))))),
        if (received > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Réceptions fournisseur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ..._orders.where((item) => item.status == 'received').map((item) => Card(child: ListTile(leading: const Icon(Icons.move_to_inbox_outlined, color: AppColors.mint), title: Text(item.supplier), subtitle: Text(item.medications.map(_lineLabel).join(', ')), trailing: const Text('Reçue')))),
      ],
    ]);
  }
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
    final result = await showDialog<String>(
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
    controller.dispose();
    return result;
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

  Future<void> _openStockCount() async {
    final differences = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StockCountSheet(medications: _medications),
    );
    if (differences == null || differences.isEmpty) return;
    try {
      for (final entry in differences.entries) {
        await _service.adjustStock(entry.key, entry.value);
      }
      await _load();
      if (mounted) _message('${differences.length} ajustement(s) de stock appliqué(s).');
    } on ApiException catch (error) {
      if (mounted) {
        await _load();
        _message('Comptage partiellement appliqué : ${error.message}');
      }
    }
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
          decoration: const InputDecoration(labelText: 'Variation (+ ajout, - retrait)'),
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
    if (value != null && value != 0)
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

class _StockCountSheet extends StatefulWidget {
  const _StockCountSheet({required this.medications});
  final List<Medication> medications;

  @override
  State<_StockCountSheet> createState() => _StockCountSheetState();
}

class _StockCountSheetState extends State<_StockCountSheet> {
  late final Map<String, TextEditingController> _counts = {
    for (final item in widget.medications)
      item.id: TextEditingController(text: '${item.stockQuantity}'),
  };
  String _query = '';
  final _barcodeEntry = TextEditingController();
  bool _cameraMode = false;
  bool _cameraCountStarted = false;
  int _scannedUnitCount = 0;

  Future<void> _beginCameraCount() async {
    if (_cameraMode) {
      await _scanNext();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Démarrer le comptage caméra ?'),
        content: const Text(
          'Les quantités comptées seront remises à zéro. Scannez ensuite chaque boîte une fois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Démarrer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final controller in _counts.values) {
      controller.text = '0';
    }
    setState(() {
      _cameraMode = true;
      _cameraCountStarted = true;
    });
    await _scanNext();
  }

  Future<void> _scanNext() async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (_) => const _BarcodeScannerDialog(),
    );
    if (barcode != null) await _recordBarcode(barcode);
  }

  Future<void> _recordBarcode(String value) async {
    final barcode = value.trim();
    if (barcode.isEmpty || !mounted) return;
    final matches = widget.medications.where((item) => item.barcode == barcode).toList();
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code $barcode inconnu. Associez-le à la fiche du médicament.')),
      );
      return;
    }
    final Medication? medication = matches.length == 1
        ? matches.first
        : await showModalBottomSheet<Medication>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Choisir le lot compté')),
                  for (final item in matches)
                    ListTile(
                      title: Text(item.name),
                      subtitle: Text('Lot ${item.lot} · Stock système : ${item.stockQuantity}'),
                      onTap: () => Navigator.pop(context, item),
                    ),
                ],
              ),
            ),
          );
    if (medication == null || !mounted) return;
    if (!_cameraCountStarted) {
      for (final controller in _counts.values) {
        controller.text = '0';
      }
      _cameraCountStarted = true;
    }
    final current = int.tryParse(_counts[medication.id]!.text) ?? 0;
    setState(() {
      _counts[medication.id]!.text = '${current + 1}';
      _scannedUnitCount++;
      _query = medication.name;
      _barcodeEntry.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${medication.name} · lot ${medication.lot} : ${current + 1} unité(s) comptée(s).')),
    );
  }
  @override
  void dispose() {
    _barcodeEntry.dispose();
    for (final controller in _counts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.medications.where((item) =>
      '${item.name} ${item.activeIngredient} ${item.lot}'.toLowerCase().contains(_query.trim().toLowerCase()),
    ).toList();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
            child: Row(children: [
              const Icon(Icons.fact_check_outlined, color: AppColors.blue),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Comptage rapide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy)),
                Text('Saisissez le stock réellement compté.', style: TextStyle(color: Color(0xFF687B86))),
              ])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Text(_cameraMode
                  ? '1 scan validé = 1 boîte. Total compté : $_scannedUnitCount.'
                  : 'Associez le code-barres à la fiche du médicament avant le scan.')),
              FilledButton.tonalIcon(
                onPressed: _beginCameraCount,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_cameraMode ? 'Scanner une boîte' : 'Caméra'),
              ),
            ]),
          ),
          if (_cameraMode) Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _barcodeEntry,
                keyboardType: TextInputType.text,
                onSubmitted: _recordBarcode,
                decoration: const InputDecoration(
                  labelText: 'Code-barres manuel',
                  hintText: 'Secours si la caméra ne détecte pas',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              )),
              IconButton.filledTonal(
                tooltip: 'Compter une boîte avec ce code',
                onPressed: () => _recordBarcode(_barcodeEntry.text),
                icon: const Icon(Icons.add),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(child: items.isEmpty
            ? const _Empty(message: 'Aucun médicament trouvé.')
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Stock système : ${item.stockQuantity} · Lot ${item.lot}'),
                    trailing: SizedBox(width: 92, child: TextField(
                      controller: _counts[item.id],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Compté', border: OutlineInputBorder(), isDense: true),
                    )),
                  );
                },
              ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () {
                  if (_cameraMode && _scannedUnitCount == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scannez au moins un code-barres avant d’appliquer le comptage.')),
                    );
                    return;
                  }
                  final differences = <String, int>{};
                  for (final item in widget.medications) {
                    final counted = int.tryParse(_counts[item.id]!.text.trim());
                    if (counted == null || counted < 0) return;
                    final difference = counted - item.stockQuantity;
                    if (difference != 0) differences[item.id] = difference;
                  }
                  Navigator.pop(context, differences);
                },
                icon: const Icon(Icons.check),
                label: const Text('Appliquer les écarts'),
              )),
            ),
          ),
        ]),
      ),
    );
  }
}
class _BarcodeScannerDialog extends StatefulWidget {
  const _BarcodeScannerDialog();

  @override
  State<_BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<_BarcodeScannerDialog> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Scanner un code-barres'),
        content: SizedBox(
          width: 360,
          height: 360,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(onDetect: _onDetect),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      );
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
  late final _barcode = TextEditingController(text: widget.item?.barcode);
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
      _barcode,
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
          _field(_barcode, 'Code-barres (EAN/UPC)'),
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
            'barcode': _barcode.text.trim(),
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
  final List<_OrderLineState> _lines = [_OrderLineState()];

  @override
  void dispose() {
    _supplier.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    final available = widget.medications.where(
      (item) => !_lines.any((line) => line.medicationId == item.id),
    );
    if (available.isEmpty) return;
    setState(() => _lines.add(_OrderLineState()));
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final line = _lines.removeAt(index);
    line.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle commande fournisseur'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _supplier,
            decoration: const InputDecoration(labelText: 'Fournisseur'),
          ),
          ..._lines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            final selected = _lines
                .where((item) => item != line)
                .map((item) => item.medicationId)
                .whereType<String>()
                .toSet();
            final options = widget.medications
                .where((item) => !selected.contains(item.id))
                .toList();
            return Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: line.medicationId,
                    decoration: InputDecoration(
                      labelText: 'Médicament ${index + 1}',
                    ),
                    items: options
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => line.medicationId = value),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: line.quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qté'),
                  ),
                ),
                IconButton(
                  onPressed: _lines.length == 1
                      ? null
                      : () => _removeLine(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _lines.length == widget.medications.length
                  ? null
                  : _addLine,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un médicament'),
            ),
          ),
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
          final medications = <Map<String, Object?>>[];
          for (final line in _lines) {
            final id = line.medicationId;
            final quantity = int.tryParse(line.quantity.text);
            if (id == null || quantity == null || quantity <= 0) return;
            medications.add({'medicationId': id, 'quantity': quantity});
          }
          Navigator.pop(context, {
            'supplier': _supplier.text.trim(),
            'medications': medications,
          });
        },
        child: const Text('Créer'),
      ),
    ],
  );
}

class _OrderLineState {
  String? medicationId;
  final quantity = TextEditingController(text: '1');

  void dispose() => quantity.dispose();
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

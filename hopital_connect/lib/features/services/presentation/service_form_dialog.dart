// =============================================================================
// WIDGET : ServiceFormDialog
// Dialog de création / édition d'un service hospitalier.
// Organisé en sections : Général · Localisation · Contact · Infos pratiques.
// Retourne un HospitalService validé, ou null si l'utilisateur annule.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour FilteringTextInputFormatter (champ numérique)

import '../../../core/theme/app_colors.dart';
import '../domain/hospital_service.dart';

/// Dialog modal permettant de créer ou modifier un service hospitalier.
/// En mode création : tous les champs sont vides sauf les défauts.
/// En mode édition  : les champs sont pré-remplis depuis [service].
class ServiceFormDialog extends StatefulWidget {
  const ServiceFormDialog({super.key, this.service});

  /// Service existant à modifier. Null = mode création.
  final HospitalService? service;

  @override
  State<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<ServiceFormDialog>
    with SingleTickerProviderStateMixin {

  // Clé du formulaire pour la validation globale
  final _formKey = GlobalKey<FormState>();

  // Contrôleur des onglets (sections du formulaire)
  late final TabController _tabCtrl = TabController(length: 4, vsync: this);

  // ---- Contrôleurs des champs texte ----
  late final _nameCtrl         = TextEditingController(text: widget.service?.name         ?? '');
  late final _descriptionCtrl  = TextEditingController(text: widget.service?.description  ?? '');
  late final _locationCtrl     = TextEditingController(text: widget.service?.location     ?? '');
  late final _buildingCtrl     = TextEditingController(text: widget.service?.building     ?? '');
  late final _floorCtrl        = TextEditingController(text: widget.service?.floor        ?? '');
  late final _phoneCtrl        = TextEditingController(text: widget.service?.phone        ?? '');
  late final _emailCtrl        = TextEditingController(text: widget.service?.email        ?? '');
  late final _headNameCtrl     = TextEditingController(text: widget.service?.headName     ?? '');
  late final _openingHoursCtrl = TextEditingController(text: widget.service?.openingHours ?? '');
  late final _notesCtrl        = TextEditingController(text: widget.service?.notes        ?? '');
  late final _capacityCtrl     = TextEditingController(
    text: (widget.service?.capacity ?? 0) > 0
        ? '${widget.service!.capacity}'
        : '', // Affiche vide si capacité = 0 (non renseignée)
  );

  // ---- État des champs non-texte ----
  late ServiceType _serviceType = widget.service?.serviceType ?? ServiceType.autre;
  late bool _isActive           = widget.service?.isActive    ?? true;

  // True si on modifie un service existant
  bool get _isEditing => widget.service != null;

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _buildingCtrl.dispose();
    _floorCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _headNameCtrl.dispose();
    _openingHoursCtrl.dispose();
    _notesCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Validation et soumission
  // --------------------------------------------------------------------------

  void _submit() {
    // Valide tous les champs de tous les onglets
    if (!_formKey.currentState!.validate()) {
      // Si erreur, retourne au premier onglet pour que l'utilisateur la voie
      _tabCtrl.animateTo(0);
      return;
    }

    final capacityText = _capacityCtrl.text.trim();

    // Construit le service avec les valeurs saisies
    final result = HospitalService(
      id:           widget.service?.id ?? '',
      name:         _nameCtrl.text.trim(),
      description:  _descriptionCtrl.text.trim(),
      location:     _locationCtrl.text.trim().isNotEmpty
                      ? _locationCtrl.text.trim()
                      : '${_buildingCtrl.text.trim()} – ${_floorCtrl.text.trim()}'.trim().replaceAll(RegExp(r'^[\s–]+|[\s–]+$'), ''),
      isActive:     _isActive,
      serviceType:  _serviceType,
      building:     _buildingCtrl.text.trim(),
      floor:        _floorCtrl.text.trim(),
      capacity:     capacityText.isEmpty ? 0 : int.tryParse(capacityText) ?? 0,
      phone:        _phoneCtrl.text.trim(),
      email:        _emailCtrl.text.trim(),
      headName:     _headNameCtrl.text.trim(),
      openingHours: _openingHoursCtrl.text.trim(),
      notes:        _notesCtrl.text.trim(),
    );

    Navigator.of(context).pop(result); // Retourne le service au code appelant
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: SizedBox(
        width: 520,       // Largeur max sur écrans larges
        height: 580,      // Hauteur fixe pour éviter les débordements
        child: Column(
          children: [
            // ----------------------------------------------------------------
            // En-tête : icône + titre + bouton fermer
            // ----------------------------------------------------------------
            _buildHeader(),

            // ----------------------------------------------------------------
            // Barre d'onglets : 4 sections
            // ----------------------------------------------------------------
            _buildTabBar(),

            // ----------------------------------------------------------------
            // Contenu des onglets (formulaire)
            // ----------------------------------------------------------------
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildTabGeneral(),     // Onglet 1 : infos générales
                    _buildTabLocalisation(),// Onglet 2 : localisation
                    _buildTabContact(),     // Onglet 3 : contact
                    _buildTabPratique(),    // Onglet 4 : infos pratiques
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Boutons d'action
            // ----------------------------------------------------------------
            _buildActions(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // En-tête
  // --------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
      child: Row(
        children: [
          // Icône médicale dans un container coloré
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F2EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medical_services_outlined,
                color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEditing ? 'Modifier le service' : 'Ajouter un service',
              style: const TextStyle(
                color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Bouton fermer (croix)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF8797A0)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Barre d'onglets
  // --------------------------------------------------------------------------

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5ECEF))),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.blue,
        unselectedLabelColor: const Color(0xFF8797A0),
        indicatorColor: AppColors.blue,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.info_outline, size: 18),    text: 'Général'),
          Tab(icon: Icon(Icons.place_outlined, size: 18),  text: 'Lieu'),
          Tab(icon: Icon(Icons.call_outlined, size: 18),   text: 'Contact'),
          Tab(icon: Icon(Icons.tune_rounded, size: 18),    text: 'Pratique'),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Onglet 1 : Général
  // --------------------------------------------------------------------------

  Widget _buildTabGeneral() {
    return _ScrollPad(
      child: Column(
        children: [
          // Champ : Nom du service (obligatoire)
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Nom du service *',
              prefixIcon: Icon(Icons.local_hospital_outlined),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Le nom est obligatoire.';
              if (v.trim().length > 120) return 'Maximum 120 caractères.';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Champ : Type de service (dropdown)
          DropdownButtonFormField<ServiceType>(
            initialValue: _serviceType,
            decoration: const InputDecoration(
              labelText: 'Type de service',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: ServiceType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) => setState(() => _serviceType = v ?? ServiceType.autre),
          ),
          const SizedBox(height: 14),

          // Champ : Description (multilignes)
          TextFormField(
            controller: _descriptionCtrl,
            minLines: 3, maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              hintText: 'Spécialités, activités, équipe…',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // Champ : Responsable du service
          TextFormField(
            controller: _headNameCtrl,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Chef / Responsable',
              prefixIcon: Icon(Icons.person_outlined),
              hintText: 'Dr Nom Prénom',
              counterText: '',
            ),
          ),

          // Switch actif/inactif (édition seulement)
          if (_isEditing) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Service actif',
                  style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600)),
              subtitle: Text(
                _isActive ? 'Visible par le personnel' : 'Masqué au personnel',
                style: const TextStyle(color: Color(0xFF687B86), fontSize: 12),
              ),
              value: _isActive,
              activeTrackColor: AppColors.mint,
              activeThumbColor: Colors.white,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Onglet 2 : Localisation
  // --------------------------------------------------------------------------

  Widget _buildTabLocalisation() {
    return _ScrollPad(
      child: Column(
        children: [
          // Bâtiment
          TextFormField(
            controller: _buildingCtrl,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Bâtiment',
              prefixIcon: Icon(Icons.apartment_outlined),
              hintText: 'Ex : Bâtiment A',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // Étage
          TextFormField(
            controller: _floorCtrl,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Étage',
              prefixIcon: Icon(Icons.stairs_outlined),
              hintText: 'Ex : 3e étage, RDC, Sous-sol',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // Localisation complète (champ libre — rempli automatiquement si vide)
          TextFormField(
            controller: _locationCtrl,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Emplacement complet (optionnel)',
              prefixIcon: Icon(Icons.place_outlined),
              hintText: 'Laissez vide pour générer depuis Bâtiment + Étage',
              counterText: '',
              helperText: 'Ex : Bâtiment A – 3e étage, Aile Nord',
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Onglet 3 : Contact
  // --------------------------------------------------------------------------

  Widget _buildTabContact() {
    return _ScrollPad(
      child: Column(
        children: [
          // Téléphone interne
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'Téléphone / Poste interne',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: 'Ex : Poste 3301',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // Email du service
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Adresse e-mail du service',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'service@hopital.fr',
              counterText: '',
            ),
            // Validation email basique (optionnel mais si renseigné doit être valide)
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null; // Optionnel
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(v.trim())) return 'Adresse e-mail invalide.';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Onglet 4 : Infos pratiques
  // --------------------------------------------------------------------------

  Widget _buildTabPratique() {
    return _ScrollPad(
      child: Column(
        children: [
          // Capacité (nombre de lits)
          TextFormField(
            controller: _capacityCtrl,
            keyboardType: TextInputType.number,
            // N'accepte que les chiffres entiers
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Capacité (nombre de lits / places)',
              prefixIcon: Icon(Icons.bed_outlined),
              hintText: 'Ex : 32',
              suffixText: 'lits',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return null; // Optionnel
              final n = int.tryParse(v);
              if (n == null || n < 0) return 'Entrez un nombre positif.';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Horaires d'ouverture
          TextFormField(
            controller: _openingHoursCtrl,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Horaires d\'ouverture',
              prefixIcon: Icon(Icons.schedule_outlined),
              hintText: 'Ex : Lun–Ven 08h00–18h00 · Urgences 24h/24',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // Notes internes
          TextFormField(
            controller: _notesCtrl,
            minLines: 2, maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes internes',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.sticky_note_2_outlined),
              hintText: 'Informations opérationnelles non médicales…',
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Boutons d'action
  // --------------------------------------------------------------------------

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5ECEF))),
      ),
      child: Row(
        children: [
          // Bouton Annuler
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF687B86),
              side: const BorderSide(color: Color(0xFFD6E0E5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            ),
            child: const Text('Annuler'),
          ),
          const Spacer(), // Pousse les boutons aux extrémités
          // Bouton Enregistrer / Créer
          FilledButton.icon(
            onPressed: _submit,
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.add_rounded, size: 18),
            label: Text(_isEditing ? 'Enregistrer' : 'Créer le service'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget utilitaire : conteneur scrollable avec padding pour chaque onglet
// =============================================================================

/// Enveloppe un onglet dans un SingleChildScrollView avec padding uniforme.
class _ScrollPad extends StatelessWidget {
  const _ScrollPad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: child,
    );
  }
}

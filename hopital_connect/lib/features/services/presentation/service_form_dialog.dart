// =============================================================================
// WIDGET : ServiceFormDialog
// Dialog de création / édition d'un service hospitalier.
// Organisé en 4 onglets : Général · Localisation · Contact · Infos pratiques.
// Retourne un HospitalService validé, ou null si l'utilisateur annule.
// =============================================================================

import 'package:flutter/material.dart';        // Widgets Flutter de base
import 'package:flutter/services.dart';        // FilteringTextInputFormatter (limite aux chiffres)

import '../../../core/theme/app_colors.dart';   // Couleurs du projet
import '../domain/hospital_service.dart';       // Modèle HospitalService + enum ServiceType

/// Dialog modal pour créer ou modifier un service.
/// Utilise [StatefulWidget] car il a un état interne (contrôleurs, onglets, switch).
class ServiceFormDialog extends StatefulWidget {
  const ServiceFormDialog({super.key, this.service}); // service = null → création

  /// Service existant à modifier. null = mode création (champs vides).
  final HospitalService? service;

  @override
  State<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

/// État interne du dialog.
/// Hérite de [SingleTickerProviderStateMixin] pour animer le TabController.
class _ServiceFormDialogState extends State<ServiceFormDialog>
    with SingleTickerProviderStateMixin {

  // ---- CLÉ DU FORMULAIRE ----
  // Permet d'appeler validate() sur tous les champs en une seule fois
  final _formKey = GlobalKey<FormState>();

  // ---- CONTRÔLEUR D'ONGLETS ----
  // length: 4 = nombre d'onglets, vsync: this = fourni par le mixin pour l'animation
  late final TabController _tabCtrl = TabController(length: 4, vsync: this);

  // ---- CONTRÔLEURS DES CHAMPS TEXTE ----
  // Chaque TextEditingController gère la valeur et la sélection d'un champ texte.
  // "?? ''" : si le service est null (création), le champ commence vide.

  late final _nameCtrl = TextEditingController(
    text: widget.service?.name ?? '', // Pré-rempli si édition, vide si création
  );
  late final _descriptionCtrl = TextEditingController(
    text: widget.service?.description ?? '',
  );
  late final _locationCtrl = TextEditingController(
    text: widget.service?.location ?? '',
  );
  late final _buildingCtrl = TextEditingController(
    text: widget.service?.building ?? '',
  );
  late final _floorCtrl = TextEditingController(
    text: widget.service?.floor ?? '',
  );
  late final _phoneCtrl = TextEditingController(
    text: widget.service?.phone ?? '',
  );
  late final _emailCtrl = TextEditingController(
    text: widget.service?.email ?? '',
  );
  late final _headNameCtrl = TextEditingController(
    text: widget.service?.headName ?? '',
  );
  late final _openingHoursCtrl = TextEditingController(
    text: widget.service?.openingHours ?? '',
  );
  late final _notesCtrl = TextEditingController(
    text: widget.service?.notes ?? '',
  );

  // Champ capacité : affiche vide si 0 (non renseigné), sinon affiche le nombre
  late final _capacityCtrl = TextEditingController(
    text: (widget.service?.capacity ?? 0) > 0
        ? '${widget.service!.capacity}' // Convertit l'int en String pour le champ texte
        : '',                           // Vide si 0 ou null
  );

  // ---- ÉTAT DES CHAMPS NON-TEXTE ----
  // Type de service : prend la valeur existante ou "autre" par défaut
  late ServiceType _serviceType = widget.service?.serviceType ?? ServiceType.autre;

  // Statut actif : true par défaut pour un nouveau service
  late bool _isActive = widget.service?.isActive ?? true;

  // Propriété calculée : true si on édite un service existant (widget.service != null)
  bool get _isEditing => widget.service != null;

  // --------------------------------------------------------------------------
  // CYCLE DE VIE : dispose()
  // Libère tous les contrôleurs quand le widget est retiré de l'arbre.
  // IMPORTANT : évite les fuites mémoire (memory leaks).
  // --------------------------------------------------------------------------
  @override
  void dispose() {
    _tabCtrl.dispose();          // Libère le contrôleur d'onglets
    _nameCtrl.dispose();         // Libère le contrôleur du nom
    _descriptionCtrl.dispose();  // Libère le contrôleur de la description
    _locationCtrl.dispose();     // Libère le contrôleur de l'emplacement
    _buildingCtrl.dispose();     // Libère le contrôleur du bâtiment
    _floorCtrl.dispose();        // Libère le contrôleur de l'étage
    _phoneCtrl.dispose();        // Libère le contrôleur du téléphone
    _emailCtrl.dispose();        // Libère le contrôleur de l'email
    _headNameCtrl.dispose();     // Libère le contrôleur du responsable
    _openingHoursCtrl.dispose(); // Libère le contrôleur des horaires
    _notesCtrl.dispose();        // Libère le contrôleur des notes
    _capacityCtrl.dispose();     // Libère le contrôleur de la capacité
    super.dispose();             // Appelle dispose() du parent (obligatoire)
  }

  // --------------------------------------------------------------------------
  // SOUMISSION DU FORMULAIRE
  // Valide tous les champs, construit le HospitalService, ferme le dialog.
  // --------------------------------------------------------------------------
  void _submit() {
    // Déclenche tous les validators. Si un champ est invalide → retourne false.
    if (!_formKey.currentState!.validate()) {
      _tabCtrl.animateTo(0); // Revient au 1er onglet pour montrer les erreurs
      return;                // Arrête ici sans fermer le dialog
    }

    // Lit le texte de la capacité et le nettoie (supprime espaces)
    final capacityText = _capacityCtrl.text.trim();

    // Construit l'objet HospitalService avec toutes les valeurs saisies
    final result = HospitalService(
      id: widget.service?.id ?? '',  // Garde l'id existant ou '' pour un nouveau

      name: _nameCtrl.text.trim(),   // .trim() supprime les espaces en début et fin

      description: _descriptionCtrl.text.trim(),

      // Logique intelligente pour l'emplacement :
      // Si le champ "emplacement complet" est renseigné → l'utilise directement.
      // Sinon → concatène bâtiment + "–" + étage.
      // .replaceAll(RegExp(...)) : nettoie les tirets orphelins si un des champs est vide.
      location: _locationCtrl.text.trim().isNotEmpty
          ? _locationCtrl.text.trim()
          : '${_buildingCtrl.text.trim()} – ${_floorCtrl.text.trim()}'
              .trim()
              .replaceAll(RegExp(r'^[\s–]+|[\s–]+$'), ''),

      isActive:     _isActive,                           // Valeur du switch
      serviceType:  _serviceType,                        // Type sélectionné dans le dropdown
      building:     _buildingCtrl.text.trim(),           // Bâtiment
      floor:        _floorCtrl.text.trim(),              // Étage
      // Si le champ capacité est vide → 0, sinon convertit en int (ou 0 si échec)
      capacity:     capacityText.isEmpty ? 0 : int.tryParse(capacityText) ?? 0,
      phone:        _phoneCtrl.text.trim(),              // Téléphone
      email:        _emailCtrl.text.trim(),              // Email
      headName:     _headNameCtrl.text.trim(),           // Responsable
      openingHours: _openingHoursCtrl.text.trim(),       // Horaires
      notes:        _notesCtrl.text.trim(),              // Notes internes
    );

    // Ferme le dialog et retourne le service au code qui a appelé showDialog()
    Navigator.of(context).pop(result);
  }

  // --------------------------------------------------------------------------
  // BUILD : construit l'arbre de widgets du dialog
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Dialog(
      // Coins arrondis du dialog à 24px
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

      // insetPadding : marges entre le dialog et les bords de l'écran
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),

      child: SizedBox(
        width: 520,  // Largeur max du dialog (utile sur écrans larges : web, tablette)
        height: 580, // Hauteur fixe pour éviter que le dialog change de taille selon l'onglet

        child: Column(
          children: [
            _buildHeader(),       // En-tête : icône + titre + bouton fermer
            _buildTabBar(),       // Barre d'onglets : Général · Lieu · Contact · Pratique
            Expanded(             // Expanded : prend tout l'espace vertical restant
              child: Form(
                key: _formKey,    // Associe la clé pour déclencher validate()
                child: TabBarView(
                  controller: _tabCtrl, // Synchronise avec la barre d'onglets
                  children: [
                    _buildTabGeneral(),      // Contenu onglet 1 : infos générales
                    _buildTabLocalisation(), // Contenu onglet 2 : localisation
                    _buildTabContact(),      // Contenu onglet 3 : contact
                    _buildTabPratique(),     // Contenu onglet 4 : infos pratiques
                  ],
                ),
              ),
            ),
            _buildActions(), // Boutons Annuler + Enregistrer/Créer
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EN-TÊTE DU DIALOG
  // --------------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12), // Marges asymétriques
      child: Row(
        children: [
          // Container carré arrondi contenant l'icône médicale
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F2EF),          // Fond vert très pâle
              borderRadius: BorderRadius.circular(12), // Coins arrondis
            ),
            child: const Icon(
              Icons.medical_services_outlined, // Icône croix médicale
              color: AppColors.blue,           // Bleu primaire du projet
              size: 22,
            ),
          ),

          const SizedBox(width: 12), // Espacement icône-titre

          // Titre dynamique : "Modifier" ou "Ajouter" selon le mode
          Expanded(
            child: Text(
              _isEditing ? 'Modifier le service' : 'Ajouter un service',
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Bouton fermer (croix) : ferme sans retourner de valeur (retourne null)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF8797A0)),
            onPressed: () => Navigator.of(context).pop(), // pop() sans argument = null
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // BARRE D'ONGLETS
  // --------------------------------------------------------------------------
  Widget _buildTabBar() {
    return Container(
      // Ligne de séparation sous la barre d'onglets
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5ECEF))),
      ),
      child: TabBar(
        controller: _tabCtrl,                          // Synchronisé avec le TabBarView
        labelColor: AppColors.blue,                    // Couleur de l'onglet sélectionné
        unselectedLabelColor: const Color(0xFF8797A0), // Couleur des onglets non sélectionnés
        indicatorColor: AppColors.blue,                // Couleur de la ligne indicatrice sous l'onglet actif
        indicatorWeight: 2.5,                          // Épaisseur de la ligne indicatrice
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(icon: Icon(Icons.info_outline, size: 18),   text: 'Général'),   // Onglet 1
          Tab(icon: Icon(Icons.place_outlined, size: 18), text: 'Lieu'),       // Onglet 2
          Tab(icon: Icon(Icons.call_outlined, size: 18),  text: 'Contact'),    // Onglet 3
          Tab(icon: Icon(Icons.tune_rounded, size: 18),   text: 'Pratique'),   // Onglet 4
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ONGLET 1 : GÉNÉRAL
  // Nom, type, description, responsable, statut actif
  // --------------------------------------------------------------------------
  Widget _buildTabGeneral() {
    return _ScrollPad( // Widget utilitaire qui ajoute le scroll et le padding
      child: Column(
        children: [

          // ---- Champ : Nom du service (obligatoire) ----
          TextFormField(
            controller: _nameCtrl,                          // Lie ce champ au contrôleur du nom
            textCapitalization: TextCapitalization.words,   // Majuscule au début de chaque mot
            maxLength: 120,                                 // Limite à 120 caractères
            decoration: const InputDecoration(
              labelText: 'Nom du service *',                // * indique que c'est obligatoire
              prefixIcon: Icon(Icons.local_hospital_outlined), // Icône hôpital à gauche
              counterText: '',                              // Cache le compteur "X/120"
            ),
            // validator : appelé par _formKey.currentState!.validate()
            // Retourne null si valide, sinon retourne le message d'erreur à afficher
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Le nom est obligatoire.';
              if (v.trim().length > 120) return 'Maximum 120 caractères.';
              return null; // null = pas d'erreur
            },
          ),

          const SizedBox(height: 14), // Espacement entre les champs

          // ---- Champ : Type de service (dropdown) ----
          DropdownButtonFormField<ServiceType>(
            initialValue: _serviceType,  // Valeur initiale sélectionnée
            decoration: const InputDecoration(
              labelText: 'Type de service',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            // items : génère la liste déroulante depuis tous les types de l'enum
            items: ServiceType.values.map((t) =>
              DropdownMenuItem(value: t, child: Text(t.label)) // t.label = libellé lisible
            ).toList(),
            // onChanged : appelé quand l'utilisateur sélectionne une option
            // setState() déclenche un rebuild pour mettre à jour _serviceType
            onChanged: (v) => setState(() => _serviceType = v ?? ServiceType.autre),
          ),

          const SizedBox(height: 14),

          // ---- Champ : Description (multilignes optionnel) ----
          TextFormField(
            controller: _descriptionCtrl,
            minLines: 3,   // Hauteur minimale de 3 lignes (même si vide)
            maxLines: 5,   // Hauteur maximale de 5 lignes (s'étire si besoin)
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences, // Majuscule en début de phrase
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true, // Aligne le label avec le texte (haut du champ multilignes)
              hintText: 'Spécialités, activités, équipe…',
              counterText: '',
            ),
            // Pas de validator → champ optionnel
          ),

          const SizedBox(height: 14),

          // ---- Champ : Responsable du service (optionnel) ----
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

          // ---- Switch actif/inactif (visible SEULEMENT en mode édition) ----
          // En création, le service est toujours actif par défaut → pas besoin du switch
          if (_isEditing) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero, // Supprime le padding interne
              title: const Text(
                'Service actif',
                style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
              ),
              // Sous-titre dynamique selon l'état du switch
              subtitle: Text(
                _isActive ? 'Visible par le personnel' : 'Masqué au personnel',
                style: const TextStyle(color: Color(0xFF687B86), fontSize: 12),
              ),
              value: _isActive,                           // Valeur actuelle du switch
              activeTrackColor: AppColors.mint,           // Piste verte quand activé
              activeThumbColor: Colors.white,             // Bouton blanc quand activé
              onChanged: (v) => setState(() => _isActive = v), // Met à jour l'état
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ONGLET 2 : LOCALISATION
  // Bâtiment, étage, emplacement complet
  // --------------------------------------------------------------------------
  Widget _buildTabLocalisation() {
    return _ScrollPad(
      child: Column(
        children: [

          // ---- Champ : Bâtiment ----
          TextFormField(
            controller: _buildingCtrl,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Bâtiment',
              prefixIcon: Icon(Icons.apartment_outlined), // Icône bâtiment
              hintText: 'Ex : Bâtiment A',
              counterText: '',
            ),
          ),

          const SizedBox(height: 14),

          // ---- Champ : Étage ----
          TextFormField(
            controller: _floorCtrl,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Étage',
              prefixIcon: Icon(Icons.stairs_outlined), // Icône escaliers
              hintText: 'Ex : 3e étage, RDC, Sous-sol',
              counterText: '',
            ),
          ),

          const SizedBox(height: 14),

          // ---- Champ : Emplacement complet (optionnel, généré automatiquement si vide) ----
          TextFormField(
            controller: _locationCtrl,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Emplacement complet (optionnel)',
              prefixIcon: Icon(Icons.place_outlined),
              hintText: 'Laissez vide pour générer depuis Bâtiment + Étage',
              counterText: '',
              // helperText : texte d'aide en petit sous le champ (toujours visible)
              helperText: 'Ex : Bâtiment A – 3e étage, Aile Nord',
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ONGLET 3 : CONTACT
  // Téléphone interne, email du service
  // --------------------------------------------------------------------------
  Widget _buildTabContact() {
    return _ScrollPad(
      child: Column(
        children: [

          // ---- Champ : Téléphone ----
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone, // Affiche le clavier téléphonique sur mobile
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: 'Téléphone / Poste interne',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: 'Ex : Poste 3301',
              counterText: '',
            ),
            // Optionnel → pas de validator
          ),

          const SizedBox(height: 14),

          // ---- Champ : Email du service ----
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress, // Clavier avec @ sur mobile
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Adresse e-mail du service',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'service@hopital.fr',
              counterText: '',
            ),
            // Validation : optionnel mais si renseigné doit être un email valide
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null; // Optionnel → toujours valide si vide
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$'); // Expression régulière email simple
              if (!emailRegex.hasMatch(v.trim())) return 'Adresse e-mail invalide.';
              return null; // Format valide
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ONGLET 4 : INFOS PRATIQUES
  // Capacité (lits), horaires d'ouverture, notes internes
  // --------------------------------------------------------------------------
  Widget _buildTabPratique() {
    return _ScrollPad(
      child: Column(
        children: [

          // ---- Champ : Capacité en nombre de lits ----
          TextFormField(
            controller: _capacityCtrl,
            keyboardType: TextInputType.number, // Clavier numérique sur mobile
            // FilteringTextInputFormatter.digitsOnly : accepte UNIQUEMENT les chiffres 0-9
            // Empêche de saisir des lettres ou des caractères spéciaux
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Capacité (nombre de lits / places)',
              prefixIcon: Icon(Icons.bed_outlined),
              hintText: 'Ex : 32',
              suffixText: 'lits', // Texte affiché à droite du champ
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return null; // Optionnel
              final n = int.tryParse(v);               // Tente de convertir en entier
              if (n == null || n < 0) return 'Entrez un nombre positif.';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // ---- Champ : Horaires d'ouverture ----
          TextFormField(
            controller: _openingHoursCtrl,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: "Horaires d'ouverture",
              prefixIcon: Icon(Icons.schedule_outlined), // Icône horloge
              hintText: 'Ex : Lun–Ven 08h00–18h00 · Urgences 24h/24',
              counterText: '',
            ),
          ),

          const SizedBox(height: 14),

          // ---- Champ : Notes internes ----
          TextFormField(
            controller: _notesCtrl,
            minLines: 2, maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes internes',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.sticky_note_2_outlined), // Icône post-it
              hintText: 'Informations opérationnelles non médicales…',
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // BOUTONS D'ACTION EN BAS DU DIALOG
  // --------------------------------------------------------------------------
  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),

      // Ligne de séparation au-dessus des boutons
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5ECEF))),
      ),

      child: Row(
        children: [

          // ---- Bouton ANNULER : ferme sans retourner de valeur ----
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(), // pop() sans argument → null
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF687B86), // Couleur du texte gris
              side: const BorderSide(color: Color(0xFFD6E0E5)), // Bordure grise
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            ),
            child: const Text('Annuler'),
          ),

          const Spacer(), // Pousse les deux boutons aux extrémités (gauche et droite)

          // ---- Bouton ENREGISTRER / CRÉER : valide et ferme ----
          FilledButton.icon(
            onPressed: _submit, // Appelle la méthode de validation et soumission

            // Icône dynamique : check si édition, + si création
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.add_rounded, size: 18),

            // Texte dynamique
            label: Text(_isEditing ? 'Enregistrer' : 'Créer le service'),

            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blue, // Fond bleu primaire
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
// WIDGET UTILITAIRE PRIVÉ : _ScrollPad
// Enveloppe le contenu d'un onglet dans un scroll + padding uniforme.
// Évite la duplication du même SingleChildScrollView dans chaque onglet.
// =============================================================================

class _ScrollPad extends StatelessWidget {
  const _ScrollPad({required this.child}); // child = contenu de l'onglet
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // SingleChildScrollView : rend le contenu scrollable si trop grand pour l'écran
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), // Marges : 20px H, 16px V
      child: child, // Affiche le contenu passé en paramètre
    );
  }
}

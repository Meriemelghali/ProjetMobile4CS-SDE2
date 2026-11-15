// =============================================================================
// WIDGET : ServiceTab
// Onglet principal du module Services hospitaliers.
// Contient : statistiques · recherche · filtres avancés · tri · liste · FAB
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';        // SectionIntro (widget partagé du projet)
import '../domain/hospital_service.dart';
import 'service_card.dart';
import 'service_detail_sheet.dart';

// =============================================================================
// ENUM : Options de tri disponibles pour la liste
// =============================================================================

/// Les 5 façons de trier la liste des services.
enum _SortOption {
  nameAsc,      // Alphabétique croissant : A → Z
  nameDesc,     // Alphabétique décroissant : Z → A
  activeFirst,  // Services actifs affichés avant les inactifs
  typeAsc,      // Par catégorie médicale : ordre alphabétique
  capacityDesc, // Par capacité : du plus grand au plus petit
}

// =============================================================================
// CLASSE : _FilterState
// Encapsule tous les critères de filtrage en un seul objet immuable.
// Utilise le pattern "copyWith" pour modifier un seul critère sans tout réécrire.
// =============================================================================

/// État complet des filtres actifs.
/// Immuable : chaque modification crée une nouvelle instance via copyWith().
class _FilterState {
  /// Crée un état de filtres. Tous les paramètres ont des valeurs par défaut
  /// qui correspondent à "aucun filtre actif".
  _FilterState({
    this.query       = '',            // Texte de recherche vide = pas de filtre texte
    this.showInactive = true,         // true = inclure les services inactifs
    this.types       = const {},      // Ensemble vide = tous les types affichés
    this.buildings   = const {},      // Ensemble vide = tous les bâtiments affichés
    this.minCapacity = 0,             // 0 = pas de filtre de capacité minimale
    this.sortOption  = _SortOption.nameAsc, // Tri par défaut : A → Z
  });

  final String query;           // Texte saisi dans la barre de recherche
  final bool showInactive;      // Inclure ou non les services inactifs
  final Set<ServiceType> types; // Types de service sélectionnés comme filtres
  final Set<String> buildings;  // Bâtiments sélectionnés comme filtres
  final int minCapacity;        // Capacité minimale en nombre de lits
  final _SortOption sortOption; // Option de tri actuellement sélectionnée

  /// Propriété calculée : retourne true si au moins un filtre non-défaut est actif.
  /// Utilisé pour afficher le badge rouge sur le bouton "Filtres".
  bool get hasActiveFilters =>
      !showInactive ||          // showInactive = false → filtre actif
      types.isNotEmpty ||       // Des types sont sélectionnés → filtre actif
      buildings.isNotEmpty ||   // Des bâtiments sont sélectionnés → filtre actif
      minCapacity > 0;          // Capacité minimale définie → filtre actif

  /// Retourne une copie avec seulement les champs fournis modifiés.
  /// Les champs non fournis gardent leur valeur actuelle.
  /// Exemple : _filters.copyWith(query: 'cardio') modifie seulement la recherche.
  _FilterState copyWith({
    String? query,
    bool? showInactive,
    Set<ServiceType>? types,
    Set<String>? buildings,
    int? minCapacity,
    _SortOption? sortOption,
  }) {
    return _FilterState(
      query:        query        ?? this.query,        // Garde la valeur actuelle si null
      showInactive: showInactive ?? this.showInactive,
      types:        types        ?? this.types,
      buildings:    buildings    ?? this.buildings,
      minCapacity:  minCapacity  ?? this.minCapacity,
      sortOption:   sortOption   ?? this.sortOption,
    );
  }
}

// =============================================================================
// WIDGET PRINCIPAL : ServiceTab (StatefulWidget car état local)
// =============================================================================

/// Onglet principal du module Services.
/// Reçoit la liste des services depuis le dashboard et gère l'affichage local.
class ServiceTab extends StatefulWidget {
  const ServiceTab({
    super.key,
    required this.services,     // Liste complète des services (obligatoire)
    this.canEdit = false,       // true = admin, affiche les boutons de modification
    this.canEditDetails = false,
    this.onEdit,                // Callback quand l'admin valide une modification
    this.onDelete,
    this.onToggleActive,        // Callback quand l'admin toggle actif/inactif
    this.onAdd,                 // Callback quand l'admin clique sur "Nouveau service"
  });

  final List<HospitalService> services;
  final bool canEdit;
  final bool canEditDetails;
  final ValueChanged<HospitalService>? onEdit;
  final ValueChanged<HospitalService>? onDelete;
  final ValueChanged<HospitalService>? onToggleActive;
  final VoidCallback? onAdd;

  @override
  State<ServiceTab> createState() => _ServiceTabState();
}

/// État interne de ServiceTab.
/// Gère la barre de recherche et l'état des filtres.
class _ServiceTabState extends State<ServiceTab> {
  // Contrôleur de la barre de recherche — permet d'effacer le champ programmatiquement
  final _searchCtrl = TextEditingController();

  // État global des filtres — commence sans aucun filtre actif
  _FilterState _filters = _FilterState();

  /// Libère le contrôleur quand le widget est retiré (évite les fuites mémoire)
  @override
  void dispose() {
    _searchCtrl.dispose(); // Important : toujours libérer les TextEditingController
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // PROPRIÉTÉ CALCULÉE : _filtered
  // Applique tous les filtres actifs et trie la liste résultante.
  // Recalculée à chaque rebuild (pas de cache car peu coûteuse).
  // --------------------------------------------------------------------------

  /// Retourne la liste des services après application des filtres et du tri.
  List<HospitalService> get _filtered {
    // Commence avec une copie de la liste complète (ne modifie pas l'original)
    var list = List<HospitalService>.from(widget.services);

    // FILTRE 1 : exclure les inactifs si showInactive = false
    if (!_filters.showInactive) {
      list = list.where((s) => s.isActive).toList(); // Garde seulement les actifs
    }

    // FILTRE 2 : types sélectionnés (si l'ensemble est vide → tous les types passent)
    if (_filters.types.isNotEmpty) {
      // Garde seulement les services dont le type est dans l'ensemble sélectionné
      list = list.where((s) => _filters.types.contains(s.serviceType)).toList();
    }

    // FILTRE 3 : bâtiments sélectionnés
    if (_filters.buildings.isNotEmpty) {
      list = list.where((s) => _filters.buildings.contains(s.building)).toList();
    }

    // FILTRE 4 : capacité minimale (garde les services avec au moins X lits)
    if (_filters.minCapacity > 0) {
      list = list.where((s) => s.capacity >= _filters.minCapacity).toList();
    }

    // FILTRE 5 : recherche textuelle dans plusieurs champs à la fois
    if (_filters.query.isNotEmpty) {
      final q = _filters.query.toLowerCase(); // Minuscules pour comparaison insensible à la casse
      list = list.where((s) =>
          s.name.toLowerCase().contains(q) ||          // Cherche dans le nom
          s.serviceType.label.toLowerCase().contains(q) || // Cherche dans le type
          s.location.toLowerCase().contains(q) ||      // Cherche dans l'emplacement
          s.building.toLowerCase().contains(q) ||      // Cherche dans le bâtiment
          s.description.toLowerCase().contains(q) ||   // Cherche dans la description
          s.headName.toLowerCase().contains(q),        // Cherche dans le nom du responsable
      ).toList();
    }

    // TRI selon l'option choisie
    switch (_filters.sortOption) {
      case _SortOption.nameAsc:
        // Tri alphabétique croissant par nom (insensible à la casse)
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      case _SortOption.nameDesc:
        // Tri alphabétique décroissant : b avant a
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));

      case _SortOption.activeFirst:
        // Actifs (true) avant inactifs (false)
        // compareTo(-1) : a avant b, compareTo(1) : b avant a
        list.sort((a, b) {
          if (a.isActive == b.isActive) return 0; // Même statut → ordre inchangé
          return a.isActive ? -1 : 1;              // Actif → monte dans la liste
        });

      case _SortOption.typeAsc:
        // Tri par libellé du type de service (alphabétique)
        list.sort((a, b) => a.serviceType.label.compareTo(b.serviceType.label));

      case _SortOption.capacityDesc:
        // Tri par capacité décroissante : plus grand en premier
        list.sort((a, b) => b.capacity.compareTo(a.capacity));
    }

    return list; // Retourne la liste filtrée et triée
  }

  // --------------------------------------------------------------------------
  // PROPRIÉTÉ CALCULÉE : liste dédupliquée des bâtiments disponibles
  // Utilisée pour remplir les FilterChips de bâtiments dans _FilterSheet
  // --------------------------------------------------------------------------

  /// Extrait tous les bâtiments uniques présents dans la liste des services.
  List<String> get _availableBuildings {
    return widget.services
        .map((s) => s.building)       // Extrait le champ "building" de chaque service
        .where((b) => b.isNotEmpty)   // Ignore les bâtiments non renseignés (chaîne vide)
        .toSet()                      // Déduplique : un même bâtiment n'apparaît qu'une fois
        .toList()                     // Convertit en liste pour pouvoir trier
      ..sort();                       // Tri alphabétique des bâtiments
  }

  // --------------------------------------------------------------------------
  // ACTION : ouvrir le bottom sheet de détail d'un service
  // --------------------------------------------------------------------------

  /// Affiche le bottom sheet de détail quand l'utilisateur tape sur une carte.
  void _showDetail(HospitalService service) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,          // Permet au bottom sheet d'occuper plus de 50% de l'écran
      backgroundColor: Colors.transparent, // Fond transparent pour voir les coins arrondis
      builder: (_) => ServiceDetailSheet(
        service: service,
        canEdit: widget.canEdit,
        canEditDetails: widget.canEditDetails,

        // Callback édition : ferme d'abord le bottom sheet, puis ouvre le formulaire
        onEdit: () {
          Navigator.of(context).pop();    // Ferme le bottom sheet
          widget.onEdit?.call(service);   // Déclenche le callback d'édition du parent
        },

        // Callback toggle : ferme le bottom sheet puis déclenche le toggle
        onToggleActive: () {
          Navigator.of(context).pop();
          widget.onToggleActive?.call(service);
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ACTION : ouvrir le bottom sheet des filtres avancés
  // --------------------------------------------------------------------------

  /// Ouvre le panneau de filtres avancés depuis le bas de l'écran.
  void _openFilterSheet() {
    showModalBottomSheet<_FilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: _filters,                    // Passe les filtres actuels (pré-sélection)
        allTypes: ServiceType.values.toList(), // Tous les types possibles pour les chips
        availableBuildings: _availableBuildings, // Bâtiments présents dans les données

        // Callback "Appliquer" : reçoit les nouveaux filtres et déclenche un rebuild
        onApply: (newFilters) {
          Navigator.of(context).pop();        // Ferme le panneau
          setState(() => _filters = newFilters); // Met à jour l'état → rebuild
        },

        // Callback "Réinitialiser" : remet tous les filtres à zéro
        onReset: () {
          Navigator.of(context).pop();
          setState(() => _filters = _FilterState()); // Crée un état vierge
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // BUILD : construit l'interface complète de l'onglet
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filtered     = _filtered;    // Calcule la liste filtrée+triée une seule fois
    final activeCount  = widget.services.where((s) => s.isActive).length; // Nombre de services actifs
    final inactiveCount = widget.services.length - activeCount;           // Nombre d'inactifs
    final hasFilters   = _filters.hasActiveFilters;                       // Des filtres sont actifs ?

    // Stack : superpose la liste ET le FAB (bouton flottant)
    return Stack(
      children: [

        // ----------------------------------------------------------------
        // LISTE PRINCIPALE (CustomScrollView pour les performances)
        // CustomScrollView avec Slivers = défilement optimisé pour les longues listes
        // ----------------------------------------------------------------
        CustomScrollView(
          slivers: [

            // Sliver 1 : en-tête non scrollable (titre + stats + recherche + filtres)
            SliverToBoxAdapter( // Encapsule un widget normal dans un Sliver
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ---- Titre + sous-titre ----
                    SectionIntro(
                      title: 'Services hospitaliers',
                      // Sous-titre dynamique : stats ou message si liste vide
                      subtitle: widget.services.isEmpty
                          ? 'Aucun service enregistré.'
                          : '$activeCount actif${activeCount > 1 ? 's' : ''} '
                            '· $inactiveCount inactif${inactiveCount > 1 ? 's' : ''}',
                    ),

                    const SizedBox(height: 14),

                    // ---- Cartes de statistiques (3 colonnes) ----
                    // Visibles seulement si des services existent
                    if (widget.services.isNotEmpty) ...[
                      Row(children: [

                        // Stat : nombre total de services
                        Expanded(child: _StatCard(
                          icon: Icons.medical_services_outlined,
                          label: 'Total',
                          value: '${widget.services.length}', // Nombre total
                          color: AppColors.blue,
                        )),

                        const SizedBox(width: 10),

                        // Stat : nombre de services actifs
                        Expanded(child: _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Actifs',
                          value: '$activeCount',
                          color: AppColors.mint,
                        )),

                        const SizedBox(width: 10),

                        // Stat : total des lits (somme de toutes les capacités)
                        Expanded(child: _StatCard(
                          icon: Icons.bed_outlined,
                          label: 'Lits',
                          // fold : parcourt la liste et accumule les capacités
                          value: '${widget.services.fold(0, (sum, s) => sum + s.capacity)}',
                          color: const Color(0xFF8B45A0), // Violet
                        )),

                      ]),
                      const SizedBox(height: 14),
                    ],

                    // ---- Barre de recherche ----
                    TextField(
                      controller: _searchCtrl, // Lie le champ au contrôleur

                      // onChanged : appelé à chaque frappe
                      // setState() déclenche un rebuild → _filtered est recalculé
                      onChanged: (v) =>
                          setState(() => _filters = _filters.copyWith(query: v.trim())),

                      decoration: InputDecoration(
                        hintText: 'Rechercher nom, type, lieu, responsable…',
                        prefixIcon: const Icon(Icons.search_rounded), // Icône loupe à gauche

                        // Bouton "X" pour effacer : visible seulement si du texte est saisi
                        suffixIcon: _filters.query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchCtrl.clear(); // Vide visuellement le champ
                                  setState(() => _filters =
                                      _filters.copyWith(query: '')); // Vide le filtre
                                },
                              )
                            : null, // null = pas de bouton si champ vide
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ---- Barre de contrôle : bouton filtres + menu tri + compteur ----
                    Row(
                      children: [

                        // Bouton FILTRES AVANCÉS avec badge rouge si des filtres sont actifs
                        Stack(
                          children: [
                            // Bouton principal
                            OutlinedButton.icon(
                              onPressed: _openFilterSheet, // Ouvre le panneau de filtres
                              icon: const Icon(Icons.filter_list_rounded, size: 18),
                              label: const Text('Filtres'),
                              style: OutlinedButton.styleFrom(
                                // Bleu si filtres actifs, gris sinon
                                foregroundColor: hasFilters
                                    ? AppColors.blue
                                    : const Color(0xFF687B86),
                                side: BorderSide(
                                  color: hasFilters
                                      ? AppColors.blue
                                      : const Color(0xFFD6E0E5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),

                            // Badge rouge (petit cercle) si des filtres sont actifs
                            if (hasFilters)
                              Positioned(
                                right: 4, top: 4, // Positionné en haut à droite du bouton
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD64045), // Rouge
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 8),

                        // Bouton TRI : menu déroulant avec les 5 options
                        _SortButton(
                          current: _filters.sortOption,
                          onChanged: (opt) => setState(() =>
                              _filters = _filters.copyWith(sortOption: opt)),
                        ),

                        const Spacer(), // Pousse le compteur à droite

                        // Compteur de résultats
                        Text(
                          '${filtered.length} résultat${filtered.length > 1 ? 's' : ''}',
                          style: const TextStyle(color: Color(0xFF8797A0), fontSize: 12),
                        ),
                      ],
                    ),

                    // ---- Chips des filtres actifs (affichées sous la barre de contrôle) ----
                    // Visible seulement si au moins un filtre ou une recherche est active
                    if (hasFilters || _filters.query.isNotEmpty)
                      _ActiveFilterChips(
                        filters: _filters,

                        // Callback pour supprimer un filtre de type
                        onRemoveType: (t) => setState(() => _filters =
                            _filters.copyWith(
                                types: Set.from(_filters.types)..remove(t))),

                        // Callback pour supprimer un filtre de bâtiment
                        onRemoveBuilding: (b) => setState(() => _filters =
                            _filters.copyWith(
                                buildings: Set.from(_filters.buildings)..remove(b))),

                        // Callback pour supprimer le filtre de capacité
                        onRemoveCapacity: () => setState(() =>
                            _filters = _filters.copyWith(minCapacity: 0)),

                        // Callback pour réafficher les inactifs
                        onRemoveInactive: () => setState(() =>
                            _filters = _filters.copyWith(showInactive: true)),

                        // Callback pour tout effacer
                        onClearAll: () {
                          _searchCtrl.clear();
                          setState(() => _filters = _FilterState());
                        },
                      ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // Sliver 2 : LISTE DES CARTES ou ÉTAT VIDE
            // ----------------------------------------------------------------
            if (filtered.isEmpty)
              // Aucun résultat : affiche un message adapté
              SliverFillRemaining(
                hasScrollBody: false, // Pas de scroll dans l'état vide
                child: _EmptyState(
                  hasFilters: _filters.query.isNotEmpty || hasFilters,
                  canAdd: widget.canEdit,
                  onAdd: widget.onAdd,
                  onReset: () {
                    _searchCtrl.clear();
                    setState(() => _filters = _FilterState());
                  },
                ),
              )
            else
              // Liste des cartes avec espacement
              SliverPadding(
                // Padding 110px en bas pour que le FAB ne cache pas la dernière carte
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                sliver: SliverList(
                  // SliverChildBuilderDelegate : construit les cartes à la demande (lazy loading)
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      final service = filtered[index]; // Service à l'index courant

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12), // Espacement entre cartes
                        child: ServiceCard(
                          service: service,
                          canEdit: widget.canEdit,
                          canEditDetails: widget.canEditDetails,
                          onEdit: () => widget.onEdit?.call(service),
                          onDelete: () => widget.onDelete?.call(service),
                          onToggleActive: () => widget.onToggleActive?.call(service),
                          onTap: () => _showDetail(service), // Ouvre le bottom sheet de détail
                        ),
                      );
                    },
                    childCount: filtered.length, // Nombre total de cartes à construire
                  ),
                ),
              ),
          ],
        ),

        // ----------------------------------------------------------------
        // FAB "Nouveau service" (positionné en bas à droite)
        // Visible seulement pour l'admin (canEdit = true)
        // ----------------------------------------------------------------
        if (widget.canEdit)
          Positioned(
            right: 20, bottom: 24, // Distance depuis les bords droit et bas
            child: FloatingActionButton.extended(
              heroTag: 'fab_service', // Tag unique pour éviter les conflits d'animation Hero
              onPressed: widget.onAdd, // Déclenche le callback de création
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau service',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// WIDGET : _FilterSheet
// Bottom sheet des filtres avancés. StatefulWidget car son état change
// quand l'utilisateur coche/décoche des filtres avant d'appliquer.
// =============================================================================

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.current,              // Filtres actuellement actifs (pour pré-sélection)
    required this.allTypes,             // Tous les types possibles (pour les FilterChips)
    required this.availableBuildings,   // Bâtiments disponibles dans les données
    required this.onApply,             // Callback quand l'utilisateur clique "Appliquer"
    required this.onReset,             // Callback quand l'utilisateur clique "Réinitialiser"
  });
  final _FilterState current;
  final List<ServiceType> allTypes;
  final List<String> availableBuildings;
  final ValueChanged<_FilterState> onApply;
  final VoidCallback onReset;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

/// État du panneau de filtres.
/// _draft = copie de travail des filtres (modifiée en temps réel mais pas encore appliquée)
class _FilterSheetState extends State<_FilterSheet> {
  late _FilterState _draft; // "Brouillon" des filtres en cours de modification

  @override
  void initState() {
    super.initState();
    _draft = widget.current; // Commence avec les filtres actuels comme point de départ
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80), // Laisse 80px visibles au-dessus
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Poignée de défilement
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6E0E5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // En-tête : titre + bouton "Réinitialiser"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Text('Filtres avancés',
                      style: TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Bouton "Réinitialiser" : efface tous les filtres sans fermer le panneau
                  TextButton(
                    onPressed: widget.onReset,
                    child: const Text('Réinitialiser',
                        style: TextStyle(color: Color(0xFF8797A0))),
                  ),
                ],
              ),
            ),

            // Contenu scrollable du panneau de filtres
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ---- FILTRE : Statut ----
                    const _FilterSectionTitle(label: 'Statut'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Inclure les services inactifs'),
                      value: _draft.showInactive, // Valeur actuelle du brouillon
                      activeTrackColor: AppColors.mint,
                      activeThumbColor: Colors.white,
                      // Modifie le brouillon (setState → rebuild du panneau)
                      onChanged: (v) =>
                          setState(() => _draft = _draft.copyWith(showInactive: v)),
                    ),

                    const SizedBox(height: 16),

                    // ---- FILTRE : Types de service ----
                    const _FilterSectionTitle(label: 'Type de service'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 6, // Espacements entre les chips
                      children: widget.allTypes.map((type) {
                        final selected = _draft.types.contains(type); // Ce type est-il sélectionné ?
                        return FilterChip(
                          label: Text(type.label),
                          selected: selected,
                          onSelected: (v) {
                            // Copie l'ensemble des types et ajoute/supprime le type cliqué
                            final newTypes = Set<ServiceType>.from(_draft.types);
                            v ? newTypes.add(type) : newTypes.remove(type);
                            setState(() => _draft = _draft.copyWith(types: newTypes));
                          },
                          selectedColor: AppColors.blue.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.blue,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.blue : const Color(0xFF687B86),
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected ? AppColors.blue : const Color(0xFFD6E0E5),
                          ),
                        );
                      }).toList(),
                    ),

                    // ---- FILTRE : Bâtiments (seulement si des bâtiments sont disponibles) ----
                    if (widget.availableBuildings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _FilterSectionTitle(label: 'Bâtiment'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 6,
                        children: widget.availableBuildings.map((b) {
                          final selected = _draft.buildings.contains(b);
                          return FilterChip(
                            label: Text(b),
                            selected: selected,
                            onSelected: (v) {
                              final newB = Set<String>.from(_draft.buildings);
                              v ? newB.add(b) : newB.remove(b);
                              setState(() => _draft = _draft.copyWith(buildings: newB));
                            },
                            selectedColor: AppColors.mint.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.mint,
                            labelStyle: TextStyle(
                              color: selected ? AppColors.mint : const Color(0xFF687B86),
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: selected ? AppColors.mint : const Color(0xFFD6E0E5),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // ---- FILTRE : Capacité minimale (curseur/slider) ----
                    const SizedBox(height: 16),
                    const _FilterSectionTitle(label: 'Capacité minimale (lits)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _draft.minCapacity.toDouble(), // Valeur actuelle (double requis)
                            min: 0,         // Valeur minimale : 0 = pas de filtre
                            max: 50,        // Valeur maximale : 50 lits
                            divisions: 10,  // 10 crans : 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50
                            activeColor: AppColors.blue,
                            // label : texte affiché au-dessus du curseur pendant le déplacement
                            label: _draft.minCapacity == 0
                                ? 'Tous'
                                : '≥ ${_draft.minCapacity}',
                            onChanged: (v) => setState(() =>
                                _draft = _draft.copyWith(minCapacity: v.round())), // round() : arrondi à l'entier
                          ),
                        ),
                        // Affichage textuel de la valeur à droite du curseur
                        Container(
                          width: 56,
                          alignment: Alignment.center,
                          child: Text(
                            _draft.minCapacity == 0 ? 'Tous' : '≥ ${_draft.minCapacity}',
                            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bouton "Appliquer" : transmet le brouillon au parent et ferme le panneau
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => widget.onApply(_draft), // Envoie le brouillon validé
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Appliquer les filtres',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET : _ActiveFilterChips
// Rangée de chips affichant les filtres actifs sous la barre de contrôle.
// Chaque chip a un bouton "X" pour supprimer ce filtre individuellement.
// =============================================================================

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.filters,
    required this.onRemoveType,
    required this.onRemoveBuilding,
    required this.onRemoveCapacity,
    required this.onRemoveInactive,
    required this.onClearAll,
  });

  final _FilterState filters;
  final ValueChanged<ServiceType> onRemoveType;    // Appelé pour supprimer un filtre de type
  final ValueChanged<String> onRemoveBuilding;     // Appelé pour supprimer un filtre de bâtiment
  final VoidCallback onRemoveCapacity;             // Appelé pour supprimer le filtre de capacité
  final VoidCallback onRemoveInactive;             // Appelé pour réafficher les inactifs
  final VoidCallback onClearAll;                   // Appelé pour tout effacer

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[]; // Liste vide qui accumulera les chips à afficher

    // Chip "Actifs seulement" (si les inactifs sont masqués)
    if (!filters.showInactive) {
      chips.add(_DismissChip(label: 'Actifs seulement', onRemove: onRemoveInactive));
    }

    // Chips pour chaque type sélectionné
    for (final t in filters.types) {
      chips.add(_DismissChip(label: t.label, onRemove: () => onRemoveType(t)));
    }

    // Chips pour chaque bâtiment sélectionné
    for (final b in filters.buildings) {
      chips.add(_DismissChip(label: b, onRemove: () => onRemoveBuilding(b)));
    }

    // Chip pour la capacité minimale
    if (filters.minCapacity > 0) {
      chips.add(_DismissChip(
          label: '≥ ${filters.minCapacity} lits',
          onRemove: onRemoveCapacity));
    }

    // Si aucun chip → retourne un widget vide (n'affiche rien)
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6, runSpacing: 4,
        children: [
          ...chips, // Affiche toutes les chips de filtres actifs

          // Bouton "Tout effacer" : efface la recherche + tous les filtres
          ActionChip(
            label: const Text('Tout effacer',
                style: TextStyle(fontSize: 12, color: Color(0xFF687B86))),
            onPressed: onClearAll,
            side: const BorderSide(color: Color(0xFFD6E0E5)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ],
      ),
    );
  }
}

/// Chip de filtre actif avec bouton de suppression (croix).
class _DismissChip extends StatelessWidget {
  const _DismissChip({required this.label, required this.onRemove});
  final String label;         // Texte du chip
  final VoidCallback onRemove; // Callback quand l'utilisateur clique la croix

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.blue)),
      deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppColors.blue),
      onDeleted: onRemove, // Appelé quand l'utilisateur tap la croix
      backgroundColor: AppColors.blue.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.blue.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Zone de tap compacte
    );
  }
}

// =============================================================================
// WIDGET : _SortButton
// Bouton ouvrant un menu déroulant pour choisir l'option de tri.
// =============================================================================

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onChanged});
  final _SortOption current;                // Option de tri actuellement sélectionnée
  final ValueChanged<_SortOption> onChanged; // Appelé quand l'utilisateur choisit une option

  // Map associant chaque option à son libellé affiché
  static const _labels = {
    _SortOption.nameAsc:      'A → Z',
    _SortOption.nameDesc:     'Z → A',
    _SortOption.activeFirst:  "Actifs d'abord",
    _SortOption.typeAsc:      'Par type',
    _SortOption.capacityDesc: 'Capacité ↓',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortOption>(
      initialValue: current,  // Option pré-sélectionnée dans le menu
      onSelected: onChanged,  // Appelé quand l'utilisateur sélectionne une option

      // itemBuilder : construit la liste des options du menu
      itemBuilder: (_) => _SortOption.values.map((opt) =>
        PopupMenuItem(
          value: opt,
          child: Row(children: [
            // Icône radio : plein si sélectionné, vide sinon
            Icon(
              opt == current
                  ? Icons.radio_button_checked      // Option actuellement sélectionnée
                  : Icons.radio_button_unchecked,   // Option non sélectionnée
              size: 16,
              color: opt == current ? AppColors.blue : const Color(0xFF8797A0),
            ),
            const SizedBox(width: 8),
            Text(_labels[opt]!), // Libellé de l'option (! : ne peut pas être null)
          ]),
        )
      ).toList(),

      // Widget déclencheur du menu (le "bouton" visible)
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD6E0E5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 16, color: Color(0xFF687B86)),
            const SizedBox(width: 4),
            Text(_labels[current]!, // Affiche le libellé de l'option courante
                style: const TextStyle(color: Color(0xFF687B86), fontSize: 13)),
            const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF687B86)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET : _StatCard
// Petite carte de statistique : icône + valeur numérique + label.
// =============================================================================

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,   // Icône Material
    required this.label,  // Label sous la valeur (ex : "Total", "Actifs")
    required this.value,  // Valeur numérique sous forme de String
    required this.color,  // Couleur de l'icône et de la valeur
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5ECEF)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),          // Icône colorée
          const SizedBox(height: 4),
          Text(value, style: TextStyle(               // Valeur en gros et gras
              color: color, fontWeight: FontWeight.w700, fontSize: 18)),
          Text(label, style: const TextStyle(         // Label en petit gris
              color: Color(0xFF8797A0), fontSize: 11)),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET : _FilterSectionTitle
// Titre de section dans le panneau de filtres (petites majuscules espacées).
// =============================================================================

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(), // Toujours en majuscules
      style: const TextStyle(
        color: Color(0xFF8797A0),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8, // Espacement entre les lettres pour l'effet "label"
      ),
    );
  }
}

// =============================================================================
// WIDGET : _EmptyState
// Affiché quand la liste filtrée est vide.
// Adapte son message selon la cause : filtres actifs ou liste vraiment vide.
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters, // true = aucun résultat à cause des filtres
    required this.canAdd,     // true = admin → peut ajouter
    this.onAdd,               // Callback pour créer le premier service
    this.onReset,             // Callback pour effacer les filtres
  });
  final bool hasFilters;
  final bool canAdd;
  final VoidCallback? onAdd;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Icône adaptée : loupe barrée si filtre, croix médicale si liste vide
            Icon(
              hasFilters
                  ? Icons.search_off_rounded          // Aucun résultat de recherche
                  : Icons.medical_services_outlined,  // Liste vraiment vide
              size: 56,
              color: const Color(0xFFCDD8DF),
            ),

            const SizedBox(height: 16),

            // Message adapté
            Text(
              hasFilters
                  ? 'Aucun service ne correspond aux filtres actifs.'
                  : 'Aucun service enregistré.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF687B86), fontSize: 15, height: 1.4),
            ),

            const SizedBox(height: 20),

            // Bouton "Effacer les filtres" si aucun résultat à cause des filtres
            if (hasFilters && onReset != null)
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.filter_list_off_rounded),
                label: const Text('Effacer les filtres'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

            // Bouton "Créer le premier service" si liste vide et admin
            if (!hasFilters && canAdd) ...[
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer le premier service'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

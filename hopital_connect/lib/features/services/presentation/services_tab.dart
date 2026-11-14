// =============================================================================
// WIDGET : ServiceTab
// Onglet principal du module Services hospitaliers.
// Fonctionnalités : liste, recherche textuelle, filtres avancés (type, bâtiment,
// capacité, statut), tri, statistiques, détail via bottom sheet.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../domain/hospital_service.dart';
import 'service_card.dart';
import 'service_detail_sheet.dart';

// =============================================================================
// Enum pour les options de tri
// =============================================================================

/// Options de tri disponibles pour la liste.
enum _SortOption {
  nameAsc,     // A → Z
  nameDesc,    // Z → A
  activeFirst, // Actifs en premier
  typeAsc,     // Par type A → Z
  capacityDesc,// Capacité décroissante (plus grand en premier)
}

// =============================================================================
// Modèle interne pour l'état des filtres avancés
// =============================================================================

/// Encapsule tous les critères de filtrage actifs.
class _FilterState {
  _FilterState({
    this.query       = '',
    this.showInactive = true,
    this.types       = const {},
    this.buildings   = const {},
    this.minCapacity = 0,
    this.sortOption  = _SortOption.nameAsc,
  });

  final String query;           // Texte de recherche
  final bool showInactive;      // Inclure les services inactifs
  final Set<ServiceType> types; // Types sélectionnés (vide = tous)
  final Set<String> buildings;  // Bâtiments sélectionnés (vide = tous)
  final int minCapacity;        // Capacité minimale (0 = pas de filtre)
  final _SortOption sortOption; // Option de tri

  /// Retourne true si au moins un filtre avancé est actif.
  bool get hasActiveFilters =>
      !showInactive ||
      types.isNotEmpty ||
      buildings.isNotEmpty ||
      minCapacity > 0;

  /// Retourne une copie avec les champs fournis modifiés.
  _FilterState copyWith({
    String? query,
    bool? showInactive,
    Set<ServiceType>? types,
    Set<String>? buildings,
    int? minCapacity,
    _SortOption? sortOption,
  }) {
    return _FilterState(
      query:        query        ?? this.query,
      showInactive: showInactive ?? this.showInactive,
      types:        types        ?? this.types,
      buildings:    buildings    ?? this.buildings,
      minCapacity:  minCapacity  ?? this.minCapacity,
      sortOption:   sortOption   ?? this.sortOption,
    );
  }
}

// =============================================================================
// Widget principal
// =============================================================================

/// Onglet liste des services avec filtres avancés, tri, stats et détail.
class ServiceTab extends StatefulWidget {
  const ServiceTab({
    super.key,
    required this.services,   // Liste fournie par le parent (dashboard ou démo)
    this.canEdit = false,     // true = admin peut créer/modifier/toggle
    this.onEdit,              // Callback édition
    this.onToggleActive,      // Callback toggle actif/inactif
    this.onAdd,               // Callback création
  });

  final List<HospitalService> services;
  final bool canEdit;
  final ValueChanged<HospitalService>? onEdit;
  final ValueChanged<HospitalService>? onToggleActive;
  final VoidCallback? onAdd;

  @override
  State<ServiceTab> createState() => _ServiceTabState();
}

class _ServiceTabState extends State<ServiceTab> {
  // Contrôleur de la barre de recherche
  final _searchCtrl = TextEditingController();

  // État global des filtres
  _FilterState _filters = _FilterState();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Logique de filtrage + tri
  // --------------------------------------------------------------------------

  /// Applique tous les filtres actifs et trie la liste résultante.
  List<HospitalService> get _filtered {
    var list = List<HospitalService>.from(widget.services);

    // Filtre 1 : exclure les inactifs si l'option est désactivée
    if (!_filters.showInactive) {
      list = list.where((s) => s.isActive).toList();
    }

    // Filtre 2 : types de service sélectionnés
    if (_filters.types.isNotEmpty) {
      list = list.where((s) => _filters.types.contains(s.serviceType)).toList();
    }

    // Filtre 3 : bâtiments sélectionnés
    if (_filters.buildings.isNotEmpty) {
      list = list.where((s) => _filters.buildings.contains(s.building)).toList();
    }

    // Filtre 4 : capacité minimale
    if (_filters.minCapacity > 0) {
      list = list.where((s) => s.capacity >= _filters.minCapacity).toList();
    }

    // Filtre 5 : recherche textuelle (nom, type, lieu, description, responsable)
    if (_filters.query.isNotEmpty) {
      final q = _filters.query.toLowerCase();
      list = list.where((s) =>
          s.name.toLowerCase().contains(q) ||
          s.serviceType.label.toLowerCase().contains(q) ||
          s.location.toLowerCase().contains(q) ||
          s.building.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.headName.toLowerCase().contains(q),
      ).toList();
    }

    // Tri
    switch (_filters.sortOption) {
      case _SortOption.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortOption.nameDesc:
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case _SortOption.activeFirst:
        list.sort((a, b) {
          if (a.isActive == b.isActive) return 0;
          return a.isActive ? -1 : 1;
        });
      case _SortOption.typeAsc:
        list.sort((a, b) => a.serviceType.label.compareTo(b.serviceType.label));
      case _SortOption.capacityDesc:
        list.sort((a, b) => b.capacity.compareTo(a.capacity));
    }

    return list;
  }

  // --------------------------------------------------------------------------
  // Liste dédupliquée des bâtiments présents dans les données
  // --------------------------------------------------------------------------

  /// Extrait la liste unique des bâtiments pour le filtre.
  List<String> get _availableBuildings {
    final buildings = widget.services
        .map((s) => s.building)
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return buildings;
  }

  // --------------------------------------------------------------------------
  // Actions
  // --------------------------------------------------------------------------

  /// Ouvre le bottom sheet de détail du service.
  void _showDetail(HospitalService service) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServiceDetailSheet(
        service: service,
        canEdit: widget.canEdit,
        onEdit: () {
          Navigator.of(context).pop();
          widget.onEdit?.call(service);
        },
        onToggleActive: () {
          Navigator.of(context).pop();
          widget.onToggleActive?.call(service);
        },
      ),
    );
  }

  /// Ouvre le bottom sheet des filtres avancés.
  void _openFilterSheet() {
    showModalBottomSheet<_FilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: _filters,
        allTypes: ServiceType.values.toList(),
        availableBuildings: _availableBuildings,
        onApply: (newFilters) {
          Navigator.of(context).pop();
          setState(() => _filters = newFilters);
        },
        onReset: () {
          Navigator.of(context).pop();
          setState(() => _filters = _FilterState());
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Build
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filtered     = _filtered;
    final activeCount  = widget.services.where((s) => s.isActive).length;
    final inactiveCount = widget.services.length - activeCount;
    final hasFilters   = _filters.hasActiveFilters;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // ----------------------------------------------------------------
            // En-tête : titre + stats + recherche + barre de contrôle
            // ----------------------------------------------------------------
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre + sous-titre
                    SectionIntro(
                      title: 'Services hospitaliers',
                      subtitle: widget.services.isEmpty
                          ? 'Aucun service enregistré.'
                          : '$activeCount actif${activeCount > 1 ? 's' : ''} '
                            '· $inactiveCount inactif${inactiveCount > 1 ? 's' : ''}',
                    ),
                    const SizedBox(height: 14),

                    // Cartes stats rapides
                    if (widget.services.isNotEmpty) ...[
                      Row(children: [
                        Expanded(child: _StatCard(
                          icon: Icons.medical_services_outlined,
                          label: 'Total', value: '${widget.services.length}',
                          color: AppColors.blue,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Actifs', value: '$activeCount',
                          color: AppColors.mint,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _StatCard(
                          icon: Icons.bed_outlined,
                          label: 'Lits',
                          value: '${widget.services.fold(0, (sum, s) => sum + s.capacity)}',
                          color: const Color(0xFF8B45A0),
                        )),
                      ]),
                      const SizedBox(height: 14),
                    ],

                    // Barre de recherche
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          setState(() => _filters = _filters.copyWith(query: v.trim())),
                      decoration: InputDecoration(
                        hintText: 'Rechercher nom, type, lieu, responsable…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _filters.query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _filters =
                                      _filters.copyWith(query: ''));
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Barre de contrôles : filtres avancés + tri + résultats
                    Row(
                      children: [
                        // Bouton filtres avancés avec badge si actifs
                        Stack(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openFilterSheet,
                              icon: const Icon(Icons.filter_list_rounded, size: 18),
                              label: const Text('Filtres'),
                              style: OutlinedButton.styleFrom(
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                            ),
                            // Badge rouge si filtres actifs
                            if (hasFilters)
                              Positioned(
                                right: 4, top: 4,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD64045),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),

                        // Menu de tri
                        _SortButton(
                          current: _filters.sortOption,
                          onChanged: (opt) => setState(() =>
                              _filters = _filters.copyWith(sortOption: opt)),
                        ),

                        const Spacer(),

                        // Compteur de résultats filtrés
                        Text(
                          '${filtered.length} résultat${filtered.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF8797A0),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Chips de filtres actifs (affichés sous la barre)
                    if (hasFilters || _filters.query.isNotEmpty)
                      _ActiveFilterChips(
                        filters: _filters,
                        onRemoveType: (t) => setState(() => _filters =
                            _filters.copyWith(
                                types: Set.from(_filters.types)..remove(t))),
                        onRemoveBuilding: (b) => setState(() => _filters =
                            _filters.copyWith(
                                buildings: Set.from(_filters.buildings)..remove(b))),
                        onRemoveCapacity: () => setState(() =>
                            _filters = _filters.copyWith(minCapacity: 0)),
                        onRemoveInactive: () => setState(() =>
                            _filters = _filters.copyWith(showInactive: true)),
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
            // Corps : liste ou état vide
            // ----------------------------------------------------------------
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      final service = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ServiceCard(
                          service: service,
                          canEdit: widget.canEdit,
                          onEdit: () => widget.onEdit?.call(service),
                          onToggleActive: () =>
                              widget.onToggleActive?.call(service),
                          onTap: () => _showDetail(service),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),

        // FAB admin
        if (widget.canEdit)
          Positioned(
            right: 20, bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'fab_service',
              onPressed: widget.onAdd,
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
// WIDGET : _FilterSheet — bottom sheet des filtres avancés
// =============================================================================

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.current,
    required this.allTypes,
    required this.availableBuildings,
    required this.onApply,
    required this.onReset,
  });
  final _FilterState current;
  final List<ServiceType> allTypes;
  final List<String> availableBuildings;
  final ValueChanged<_FilterState> onApply;
  final VoidCallback onReset;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterState _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.current; // Part des filtres actuels
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Poignée
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

            // Titre
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Text('Filtres avancés',
                      style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onReset,
                    child: const Text('Réinitialiser',
                        style: TextStyle(color: Color(0xFF8797A0))),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- Statut ----
                    const _FilterSectionTitle(label: 'Statut'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Inclure les services inactifs'),
                      value: _draft.showInactive,
                      activeTrackColor: AppColors.mint,
                      activeThumbColor: Colors.white,
                      onChanged: (v) =>
                          setState(() => _draft = _draft.copyWith(showInactive: v)),
                    ),

                    const SizedBox(height: 16),

                    // ---- Types de service ----
                    const _FilterSectionTitle(label: 'Type de service'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: widget.allTypes.map((type) {
                        final selected = _draft.types.contains(type);
                        return FilterChip(
                          label: Text(type.label),
                          selected: selected,
                          onSelected: (v) {
                            final newTypes = Set<ServiceType>.from(_draft.types);
                            v ? newTypes.add(type) : newTypes.remove(type);
                            setState(
                                () => _draft = _draft.copyWith(types: newTypes));
                          },
                          selectedColor: AppColors.blue.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.blue,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.blue
                                : const Color(0xFF687B86),
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.blue
                                : const Color(0xFFD6E0E5),
                          ),
                        );
                      }).toList(),
                    ),

                    // ---- Bâtiments ----
                    if (widget.availableBuildings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _FilterSectionTitle(label: 'Bâtiment'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: widget.availableBuildings.map((b) {
                          final selected = _draft.buildings.contains(b);
                          return FilterChip(
                            label: Text(b),
                            selected: selected,
                            onSelected: (v) {
                              final newB = Set<String>.from(_draft.buildings);
                              v ? newB.add(b) : newB.remove(b);
                              setState(() =>
                                  _draft = _draft.copyWith(buildings: newB));
                            },
                            selectedColor:
                                AppColors.mint.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.mint,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.mint
                                  : const Color(0xFF687B86),
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.mint
                                  : const Color(0xFFD6E0E5),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // ---- Capacité minimale ----
                    const SizedBox(height: 16),
                    const _FilterSectionTitle(label: 'Capacité minimale (lits)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _draft.minCapacity.toDouble(),
                            min: 0, max: 50,
                            divisions: 10,
                            activeColor: AppColors.blue,
                            label: _draft.minCapacity == 0
                                ? 'Tous'
                                : '≥ ${_draft.minCapacity}',
                            onChanged: (v) => setState(() => _draft =
                                _draft.copyWith(minCapacity: v.round())),
                          ),
                        ),
                        Container(
                          width: 56,
                          alignment: Alignment.center,
                          child: Text(
                            _draft.minCapacity == 0
                                ? 'Tous'
                                : '≥ ${_draft.minCapacity}',
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bouton Appliquer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => widget.onApply(_draft),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
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
// WIDGET : _ActiveFilterChips — chips des filtres actifs sous la barre
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
  final ValueChanged<ServiceType> onRemoveType;
  final ValueChanged<String> onRemoveBuilding;
  final VoidCallback onRemoveCapacity;
  final VoidCallback onRemoveInactive;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    // Chip "Actifs seulement"
    if (!filters.showInactive) {
      chips.add(_DismissChip(
          label: 'Actifs seulement', onRemove: onRemoveInactive));
    }

    // Chips des types sélectionnés
    for (final t in filters.types) {
      chips.add(
          _DismissChip(label: t.label, onRemove: () => onRemoveType(t)));
    }

    // Chips des bâtiments sélectionnés
    for (final b in filters.buildings) {
      chips.add(
          _DismissChip(label: b, onRemove: () => onRemoveBuilding(b)));
    }

    // Chip capacité minimale
    if (filters.minCapacity > 0) {
      chips.add(_DismissChip(
          label: '≥ ${filters.minCapacity} lits',
          onRemove: onRemoveCapacity));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          ...chips,
          // Bouton "Tout effacer"
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

/// Chip de filtre actif avec bouton de suppression.
class _DismissChip extends StatelessWidget {
  const _DismissChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.blue)),
      deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppColors.blue),
      onDeleted: onRemove,
      backgroundColor: AppColors.blue.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.blue.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// =============================================================================
// WIDGET : _SortButton — menu de tri
// =============================================================================

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onChanged});
  final _SortOption current;
  final ValueChanged<_SortOption> onChanged;

  static const _labels = {
    _SortOption.nameAsc:      'A → Z',
    _SortOption.nameDesc:     'Z → A',
    _SortOption.activeFirst:  'Actifs d\'abord',
    _SortOption.typeAsc:      'Par type',
    _SortOption.capacityDesc: 'Capacité ↓',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortOption>(
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (_) => _SortOption.values
          .map((opt) => PopupMenuItem(
                value: opt,
                child: Row(children: [
                  Icon(
                    opt == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: opt == current ? AppColors.blue : const Color(0xFF8797A0),
                  ),
                  const SizedBox(width: 8),
                  Text(_labels[opt]!),
                ]),
              ))
          .toList(),
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
            Text(_labels[current]!,
                style: const TextStyle(color: Color(0xFF687B86), fontSize: 13)),
            const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF687B86)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET : _StatCard — carte statistique compacte
// =============================================================================

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
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
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 18)),
        Text(label,
            style: const TextStyle(color: Color(0xFF8797A0), fontSize: 11)),
      ]),
    );
  }
}

// =============================================================================
// WIDGET : _FilterSectionTitle
// =============================================================================

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF8797A0),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// =============================================================================
// WIDGET : _EmptyState
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.canAdd,
    this.onAdd,
    this.onReset,
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
            Icon(
              hasFilters
                  ? Icons.search_off_rounded
                  : Icons.medical_services_outlined,
              size: 56,
              color: const Color(0xFFCDD8DF),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'Aucun service ne correspond aux filtres actifs.'
                  : 'Aucun service enregistré.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF687B86), fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (hasFilters && onReset != null)
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.filter_list_off_rounded),
                label: const Text('Effacer les filtres'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            if (!hasFilters && canAdd) ...[
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer le premier service'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET : ServiceCard
// Carte compacte affichant les informations clés d'un service hospitalier.
// Cliquable → ouvre le détail complet. Mode admin → boutons modifier/toggle.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/hospital_service.dart';

/// Palette de couleurs par type de service — aide à identifier visuellement
/// la catégorie médicale sans lire le texte.
const Map<ServiceType, Color> _typeColors = {
  ServiceType.medecine:    Color(0xFF176B87), // Bleu
  ServiceType.chirurgie:   Color(0xFF8B45A0), // Violet
  ServiceType.urgences:    Color(0xFFD64045), // Rouge
  ServiceType.pediatrie:   Color(0xFF36A98B), // Vert menthe
  ServiceType.gynecologie: Color(0xFFE0689A), // Rose
  ServiceType.radiologie:  Color(0xFF5B6BBF), // Bleu indigo
  ServiceType.laboratoire: Color(0xFFE8891A), // Orange
  ServiceType.reanimation: Color(0xFFC0392B), // Rouge foncé
  ServiceType.psychiatrie: Color(0xFF2E7D32), // Vert foncé
  ServiceType.autre:       Color(0xFF607D8B), // Gris bleuté
};

/// Icônes par type de service pour renforcer l'identité visuelle.
final Map<ServiceType, IconData> _typeIcons = {
  ServiceType.medecine:    Icons.favorite_outline,
  ServiceType.chirurgie:   Icons.cut_outlined,
  ServiceType.urgences:    Icons.emergency_outlined,
  ServiceType.pediatrie:   Icons.child_care_outlined,
  ServiceType.gynecologie: Icons.pregnant_woman_outlined,
  ServiceType.radiologie:  Icons.biotech_outlined,
  ServiceType.laboratoire: Icons.science_outlined,
  ServiceType.reanimation: Icons.monitor_heart_outlined,
  ServiceType.psychiatrie: Icons.psychology_outlined,
  ServiceType.autre:       Icons.medical_services_outlined,
};

/// Carte d'un service hospitalier dans la liste.
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.service,  // Service à afficher
    this.canEdit = false,   // true = affiche les boutons admin
    this.onEdit,            // Callback bouton Modifier
    this.onToggleActive,    // Callback bouton toggle actif/inactif
    this.onTap,             // Callback tap sur la carte → détail
  });

  final HospitalService service;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isActive  = service.isActive;
    // Couleur et icône selon le type de service
    final typeColor = _typeColors[service.serviceType] ?? const Color(0xFF607D8B);
    final typeIcon  = _typeIcons[service.serviceType]  ?? Icons.medical_services_outlined;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isActive ? 1.0 : 0.55, // Service inactif = semi-transparent

      child: InkWell(
        onTap: onTap, // Tap → ouvre le détail
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? const Color(0xFFE5ECEF) : const Color(0xFFD0D8DC),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----------------------------------------------------------------
              // Bandeau coloré en haut — couleur = type de service
              // ----------------------------------------------------------------
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: isActive ? typeColor : const Color(0xFFD0D8DC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --------------------------------------------------------
                    // Ligne haute : icône + nom + badge + boutons
                    // --------------------------------------------------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icône du type de service
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: isActive
                                ? typeColor.withValues(alpha: 0.12)
                                : const Color(0xFFEEF2F4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(typeIcon,
                              color: isActive ? typeColor : const Color(0xFF9AA9B0),
                              size: 22),
                        ),
                        const SizedBox(width: 12),

                        // Nom + type + badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nom du service en gras
                              Text(
                                service.name,
                                style: TextStyle(
                                  color: isActive ? AppColors.navy : const Color(0xFF687B86),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Ligne type + badge statut
                              Row(
                                children: [
                                  // Type de service en petit texte coloré
                                  Text(
                                    service.serviceType.label,
                                    style: TextStyle(
                                      color: isActive ? typeColor : const Color(0xFF9AA9B0),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Badge Actif / Inactif
                                  _StatusBadge(isActive: isActive),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Boutons admin (modifier + toggle)
                        if (canEdit)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Bouton Modifier
                              IconButton(
                                tooltip: 'Modifier',
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.blue,
                                visualDensity: VisualDensity.compact,
                                onPressed: onEdit,
                              ),
                              // Bouton toggle actif/inactif
                              IconButton(
                                tooltip: isActive ? 'Désactiver' : 'Réactiver',
                                icon: Icon(
                                  isActive
                                      ? Icons.toggle_on_rounded
                                      : Icons.toggle_off_rounded,
                                  size: 26,
                                ),
                                color: isActive ? AppColors.mint : const Color(0xFF9AA9B0),
                                visualDensity: VisualDensity.compact,
                                onPressed: onToggleActive,
                              ),
                            ],
                          ),
                      ],
                    ),

                    // --------------------------------------------------------
                    // Description tronquée à 2 lignes
                    // --------------------------------------------------------
                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        service.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF536A77),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // --------------------------------------------------------
                    // Ligne d'infos rapides : lieu · capacité · responsable
                    // --------------------------------------------------------
                    Wrap(
                      spacing: 14,  // Espacement horizontal entre chips
                      runSpacing: 4, // Espacement vertical si wrap
                      children: [
                        // Localisation
                        if (service.location.isNotEmpty)
                          _InfoChip(
                            icon: Icons.place_outlined,
                            label: service.location,
                          ),
                        // Capacité (si renseignée)
                        if (service.capacity > 0)
                          _InfoChip(
                            icon: Icons.bed_outlined,
                            label: '${service.capacity} lits',
                          ),
                        // Responsable (si renseigné)
                        if (service.headName.isNotEmpty)
                          _InfoChip(
                            icon: Icons.person_outline,
                            label: service.headName,
                          ),
                      ],
                    ),

                    // Lien "Voir le détail" à droite
                    if (onTap != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Voir le détail',
                              style: TextStyle(
                                color: typeColor.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 11,
                                color: typeColor.withValues(alpha: 0.85)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widgets privés
// =============================================================================

/// Badge coloré "Actif" (vert) ou "Inactif" (gris).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE6F7F3) : const Color(0xFFF0F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive ? AppColors.mint : const Color(0xFF8797A0),
        ),
      ),
    );
  }
}

/// Puce d'information avec icône + texte court.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8797A0)),
        const SizedBox(width: 3),
        ConstrainedBox(
          // Limite la largeur pour éviter les débordements
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8797A0), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET : ServiceCard
// Carte compacte affichant les informations d'un service hospitalier dans la liste.
// Cliquable → ouvre le détail. Mode admin → boutons modifier et activer/désactiver.
// =============================================================================

import 'package:flutter/material.dart'; // Bibliothèque principale Flutter (widgets, couleurs, icônes)

import '../../../core/theme/app_colors.dart'; // Couleurs personnalisées du projet (navy, blue, mint…)
import '../domain/hospital_service.dart';     // Modèle HospitalService + enum ServiceType

// -----------------------------------------------------------------------------
// Palettes de couleurs et d'icônes par type de service
// Définies en dehors de la classe car partagées entre plusieurs widgets de ce fichier.
// -----------------------------------------------------------------------------

/// Association type de service → couleur d'accentuation.
/// Permet d'identifier visuellement la catégorie médicale sans lire le texte.
/// Exemple : urgences = rouge, pédiatrie = vert menthe.
const Map<ServiceType, Color> _typeColors = {
  ServiceType.medecine:    Color(0xFF176B87), // Bleu — médecine générale
  ServiceType.chirurgie:   Color(0xFF8B45A0), // Violet — chirurgie
  ServiceType.urgences:    Color(0xFFD64045), // Rouge — urgences (couleur d'alerte)
  ServiceType.pediatrie:   Color(0xFF36A98B), // Vert menthe — pédiatrie (doux)
  ServiceType.gynecologie: Color(0xFFE0689A), // Rose — gynécologie
  ServiceType.radiologie:  Color(0xFF5B6BBF), // Bleu indigo — radiologie
  ServiceType.laboratoire: Color(0xFFE8891A), // Orange — laboratoire
  ServiceType.reanimation: Color(0xFFC0392B), // Rouge foncé — réanimation (critique)
  ServiceType.psychiatrie: Color(0xFF2E7D32), // Vert foncé — psychiatrie
  ServiceType.autre:       Color(0xFF607D8B), // Gris bleuté — catégorie non définie
};

/// Association type de service → icône Material.
/// final (pas const) car Icons.xxx ne sont pas des constantes de compilation.
final Map<ServiceType, IconData> _typeIcons = {
  ServiceType.medecine:    Icons.favorite_outline,       // Cœur → médecine
  ServiceType.chirurgie:   Icons.cut_outlined,           // Ciseau → chirurgie
  ServiceType.urgences:    Icons.emergency_outlined,     // Croix urgence → urgences
  ServiceType.pediatrie:   Icons.child_care_outlined,    // Bébé → pédiatrie
  ServiceType.gynecologie: Icons.pregnant_woman_outlined,// Femme enceinte → gynécologie
  ServiceType.radiologie:  Icons.biotech_outlined,       // Labo → radiologie
  ServiceType.laboratoire: Icons.science_outlined,       // Flacon → laboratoire
  ServiceType.reanimation: Icons.monitor_heart_outlined, // Moniteur → réanimation
  ServiceType.psychiatrie: Icons.psychology_outlined,    // Cerveau → psychiatrie
  ServiceType.autre:       Icons.medical_services_outlined, // Croix médicale → autre
};

// =============================================================================
// Widget principal : ServiceCard
// =============================================================================

/// Carte d'un service hospitalier affichée dans la liste de l'onglet Services.
/// Paramètres obligatoires : [service].
/// Paramètres optionnels  : [canEdit], [onEdit], [onToggleActive], [onTap].
class ServiceCard extends StatelessWidget {

  /// Constructeur constant — tous les paramètres sont déclarés ici.
  const ServiceCard({
    super.key,                  // Clé Flutter pour identifier ce widget dans l'arbre
    required this.service,      // Service hospitalier à afficher (obligatoire)
    this.canEdit = false,       // false = mode lecture seule, true = boutons admin visibles
    this.onEdit,                // Fonction appelée quand l'admin appuie sur "Modifier"
    this.onToggleActive,        // Fonction appelée quand l'admin appuie sur le toggle
    this.onTap,                 // Fonction appelée quand l'utilisateur tape la carte entière
  });

  final HospitalService service;    // Données du service à afficher
  final bool canEdit;               // Contrôle la visibilité des boutons admin
  final VoidCallback? onEdit;       // Callback "Modifier" (null = bouton ignoré)
  final VoidCallback? onToggleActive; // Callback toggle actif/inactif
  final VoidCallback? onTap;        // Callback tap général sur la carte

  @override
  Widget build(BuildContext context) {
    // Raccourci booléen pour savoir si ce service est actif
    final isActive = service.isActive;

    // Couleur thématique selon le type du service (utilise la palette _typeColors)
    // Si le type n'est pas dans la map (cas impossible ici), utilise le gris par défaut
    final typeColor = _typeColors[service.serviceType] ?? const Color(0xFF607D8B);

    // Icône thématique selon le type du service (utilise _typeIcons)
    final typeIcon = _typeIcons[service.serviceType] ?? Icons.medical_services_outlined;

    // AnimatedOpacity : anime la transparence quand isActive change
    // Transition douce de 250ms entre opaque (1.0) et semi-transparent (0.55)
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250), // Durée de la transition d'opacité
      opacity: isActive ? 1.0 : 0.55,              // Actif = plein, inactif = grisé à 55%

      // InkWell : rend la carte cliquable avec l'effet "ripple" (vague Material)
      child: InkWell(
        onTap: onTap,                              // Déclenche le callback au tap
        borderRadius: BorderRadius.circular(20),   // Coins arrondis de l'effet ripple

        // Container : boîte principale de la carte avec décoration visuelle
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,                   // Fond blanc de la carte
            borderRadius: BorderRadius.circular(20), // Coins arrondis à 20px

            // Bordure : bleue-grise si actif, plus foncée si inactif
            border: Border.all(
              color: isActive
                  ? const Color(0xFFE5ECEF)  // Bordure claire pour service actif
                  : const Color(0xFFD0D8DC), // Bordure plus marquée pour inactif
            ),

            // Ombre portée légère pour donner de la profondeur à la carte
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), // Noir à 4% d'opacité
                blurRadius: 8,                               // Rayon de flou de l'ombre
                offset: const Offset(0, 2),                 // Décalage : 0 horizontal, 2 vertical
              ),
            ],
          ),

          // Column : empile le bandeau coloré + le contenu principal verticalement
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Aligne tout à gauche
            children: [

              // ----------------------------------------------------------------
              // BANDEAU COLORÉ EN HAUT
              // Fine barre de 5px dont la couleur = type du service
              // Permet d'identifier la catégorie d'un coup d'œil
              // ----------------------------------------------------------------
              Container(
                height: 5, // Hauteur fixe de 5px pour le bandeau

                decoration: BoxDecoration(
                  // Couleur du bandeau = type si actif, gris si inactif
                  color: isActive ? typeColor : const Color(0xFFD0D8DC),

                  // Arrondi seulement en haut (correspond aux coins de la carte)
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20), // Arrondi les coins supérieurs gauche et droit
                  ),
                ),
              ),

              // ----------------------------------------------------------------
              // CONTENU PRINCIPAL DE LA CARTE
              // Padding : 16px gauche, 14px haut, 12px droit, 14px bas
              // ----------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),

                // Column : empile les différentes sections du contenu verticalement
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // --------------------------------------------------------
                    // LIGNE HAUTE : icône + nom + type + badge + boutons admin
                    // --------------------------------------------------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // Aligne les enfants en haut
                      children: [

                        // ---- ICÔNE DU TYPE DE SERVICE ----
                        Container(
                          width: 44,  // Largeur fixe du conteneur icône
                          height: 44, // Hauteur fixe du conteneur icône

                          decoration: BoxDecoration(
                            // Fond coloré à 12% d'opacité si actif, gris si inactif
                            color: isActive
                                ? typeColor.withValues(alpha: 0.12)
                                : const Color(0xFFEEF2F4),

                            borderRadius: BorderRadius.circular(12), // Coins arrondis du conteneur
                          ),

                          // Icon : affiche l'icône du type de service
                          child: Icon(
                            typeIcon,  // Icône déterminée par le type (médecine, urgences…)
                            // Icône colorée si actif, grise si inactif
                            color: isActive ? typeColor : const Color(0xFF9AA9B0),
                            size: 22,  // Taille de l'icône en pixels logiques
                          ),
                        ),

                        const SizedBox(width: 12), // Espacement horizontal de 12px entre icône et texte

                        // ---- BLOC NOM + TYPE + BADGE ----
                        // Expanded : prend tout l'espace horizontal restant entre l'icône et les boutons
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // NOM DU SERVICE en gras
                              Text(
                                service.name, // Texte : nom du service depuis le modèle

                                style: TextStyle(
                                  // Couleur navy si actif, gris si inactif
                                  color: isActive ? AppColors.navy : const Color(0xFF687B86),
                                  fontSize: 16,              // Taille du titre de la carte
                                  fontWeight: FontWeight.w700, // Gras (700 = bold)
                                  height: 1.2,               // Interligne serré (1.2× la taille de police)
                                ),
                              ),

                              const SizedBox(height: 4), // Espacement vertical de 4px

                              // LIGNE TYPE + BADGE STATUT côte à côte
                              Row(
                                children: [

                                  // TYPE DE SERVICE en petit texte coloré
                                  Text(
                                    service.serviceType.label, // Ex : "Médecine", "Chirurgie"…

                                    style: TextStyle(
                                      // Couleur du type si actif, gris si inactif
                                      color: isActive ? typeColor : const Color(0xFF9AA9B0),
                                      fontSize: 12,              // Petit texte discret
                                      fontWeight: FontWeight.w600, // Semi-gras
                                    ),
                                  ),

                                  const SizedBox(width: 8), // Espacement entre type et badge

                                  // BADGE ACTIF / INACTIF (widget privé défini plus bas)
                                  _StatusBadge(isActive: isActive),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ---- BOUTONS ADMIN (seulement si canEdit = true) ----
                        // if (canEdit) : n'affiche ces boutons que pour l'administrateur
                        if (canEdit)
                          Row(
                            mainAxisSize: MainAxisSize.min, // Largeur minimale (ne prend pas plus que nécessaire)
                            children: [

                              // BOUTON MODIFIER : ouvre le formulaire d'édition
                              IconButton(
                                tooltip: 'Modifier',                   // Bulle d'aide au survol
                                icon: const Icon(Icons.edit_outlined, size: 18), // Icône crayon
                                color: AppColors.blue,                  // Couleur bleue du projet
                                visualDensity: VisualDensity.compact,   // Réduit la zone de tap pour gagner de l'espace
                                onPressed: onEdit,                      // Appelle le callback onEdit
                              ),

                              // BOUTON TOGGLE ACTIF/INACTIF
                              IconButton(
                                // Tooltip adaptatif selon l'état actuel du service
                                tooltip: isActive ? 'Désactiver' : 'Réactiver',

                                icon: Icon(
                                  // Icône ON (actif) ou OFF (inactif) selon l'état
                                  isActive
                                      ? Icons.toggle_on_rounded  // Service actif → icône "allumé"
                                      : Icons.toggle_off_rounded, // Service inactif → icône "éteint"
                                  size: 26, // Plus grande que le bouton modifier pour être visible
                                ),

                                // Couleur vert menthe si actif, gris si inactif
                                color: isActive ? AppColors.mint : const Color(0xFF9AA9B0),
                                visualDensity: VisualDensity.compact, // Zone de tap compacte
                                onPressed: onToggleActive,            // Appelle le callback toggle
                              ),
                            ],
                          ),
                      ],
                    ),

                    // --------------------------------------------------------
                    // DESCRIPTION DU SERVICE (affichée seulement si non vide)
                    // --------------------------------------------------------
                    // if (condition) ...[] : syntaxe Dart pour ajouter conditionnellement des widgets
                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 10), // Espacement avant la description

                      Text(
                        service.description, // Texte de la description depuis le modèle

                        maxLines: 2,         // Limite à 2 lignes maximum (évite les cartes trop hautes)
                        overflow: TextOverflow.ellipsis, // Affiche "…" si le texte dépasse 2 lignes

                        style: const TextStyle(
                          color: Color(0xFF536A77), // Gris-bleu pour le corps de texte
                          fontSize: 13,            // Légèrement plus petit que le nom
                          height: 1.45,            // Interligne pour la lisibilité
                        ),
                      ),
                    ],

                    const SizedBox(height: 10), // Espacement avant les chips d'info

                    // --------------------------------------------------------
                    // LIGNE D'INFOS RAPIDES : lieu · capacité · responsable
                    // Wrap : dispose les chips en ligne, passe à la ligne si manque de place
                    // --------------------------------------------------------
                    Wrap(
                      spacing: 14,   // Espacement horizontal de 14px entre chaque chip
                      runSpacing: 4, // Espacement vertical de 4px si retour à la ligne

                      children: [

                        // CHIP LOCALISATION (si renseigné)
                        if (service.location.isNotEmpty)
                          _InfoChip(
                            icon: Icons.place_outlined, // Icône pin de localisation
                            label: service.location,    // Ex : "Bâtiment A – 3e étage"
                          ),

                        // CHIP CAPACITÉ (si capacité > 0, c'est-à-dire renseignée)
                        if (service.capacity > 0)
                          _InfoChip(
                            icon: Icons.bed_outlined,              // Icône lit
                            label: '${service.capacity} lits',     // Ex : "32 lits"
                          ),

                        // CHIP RESPONSABLE (si renseigné)
                        if (service.headName.isNotEmpty)
                          _InfoChip(
                            icon: Icons.person_outline,  // Icône personne
                            label: service.headName,     // Ex : "Dr Leila Mansouri"
                          ),
                      ],
                    ),

                    // --------------------------------------------------------
                    // LIEN "Voir le détail" à droite (si onTap est défini)
                    // --------------------------------------------------------
                    if (onTap != null) ...[
                      const SizedBox(height: 8), // Espacement avant le lien

                      // Align : aligne le contenu à droite de la carte
                      Align(
                        alignment: Alignment.centerRight, // Aligne à droite horizontalement

                        child: Row(
                          mainAxisSize: MainAxisSize.min, // Largeur minimale
                          children: [

                            // Texte "Voir le détail" coloré
                            Text(
                              'Voir le détail',

                              style: TextStyle(
                                color: typeColor.withValues(alpha: 0.85), // Couleur du type à 85%
                                fontSize: 12,              // Petit texte
                                fontWeight: FontWeight.w600, // Semi-gras
                              ),
                            ),

                            const SizedBox(width: 2), // Petit espacement entre texte et flèche

                            // Flèche droite indiquant qu'on peut naviguer
                            Icon(
                              Icons.arrow_forward_ios_rounded, // Icône chevron droit
                              size: 11,                        // Très petite (discrète)
                              color: typeColor.withValues(alpha: 0.85),
                            ),
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
// WIDGET PRIVÉ : _StatusBadge
// Badge coloré "Actif" (vert) ou "Inactif" (gris).
// Privé (préfixe _) car utilisé uniquement dans ce fichier.
// =============================================================================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive}); // isActive est obligatoire
  final bool isActive; // Détermine la couleur et le texte du badge

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding interne : 7px horizontal, 2px vertical → forme "pill" compacte
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),

      decoration: BoxDecoration(
        // Fond vert très pâle si actif, gris très pâle si inactif
        color: isActive
            ? const Color(0xFFE6F7F3) // Vert pâle pour "Actif"
            : const Color(0xFFF0F4F6), // Gris pâle pour "Inactif"

        borderRadius: BorderRadius.circular(20), // Forme ovale (pill shape)
      ),

      // Texte du badge
      child: Text(
        isActive ? 'Actif' : 'Inactif', // Texte dynamique selon le statut

        style: TextStyle(
          fontSize: 10,               // Très petit — badge discret
          fontWeight: FontWeight.w700, // Gras pour rester lisible malgré la petite taille
          // Vert menthe si actif, gris si inactif
          color: isActive ? AppColors.mint : const Color(0xFF8797A0),
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET PRIVÉ : _InfoChip
// Puce d'information compacte : icône + texte court.
// Utilisée pour afficher lieu, capacité, responsable sous la description.
// =============================================================================

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label}); // Les deux sont obligatoires
  final IconData icon;  // Icône Material à afficher à gauche du texte
  final String label;   // Texte court à afficher (ex : "Bâtiment A", "32 lits")

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min, // La puce prend le minimum de largeur nécessaire
      children: [

        // ICÔNE grise discrète à gauche
        Icon(
          icon,
          size: 13,                       // Très petite icône pour rester discrète
          color: const Color(0xFF8797A0), // Gris-bleu cohérent avec le texte
        ),

        const SizedBox(width: 3), // Espacement de 3px entre l'icône et le texte

        // TEXTE de la puce avec largeur maximale
        ConstrainedBox(
          // Limite à 160px pour éviter que la puce déborde sur toute la ligne
          constraints: const BoxConstraints(maxWidth: 160),

          child: Text(
            label,
            overflow: TextOverflow.ellipsis, // Troncature avec "…" si trop long
            style: const TextStyle(
              color: Color(0xFF8797A0), // Même gris-bleu que l'icône
              fontSize: 12,            // Petit texte discret
            ),
          ),
        ),
      ],
    );
  }
}

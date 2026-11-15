// =============================================================================
// WIDGET : ServiceDetailSheet
// Bottom sheet (feuille glissante depuis le bas) affichant le détail complet.
// Sections : En-tête · Boutons d'action · Description · Localisation · Contact
//            · Infos pratiques · Notes · Statut · Boutons admin
// =============================================================================

import 'package:flutter/material.dart';        // Widgets Flutter de base
import 'package:flutter/services.dart';        // Clipboard : copier dans le presse-papier

import '../../../core/theme/app_colors.dart';   // Couleurs du projet
import '../domain/hospital_service.dart';       // Modèle HospitalService
import '../utils/service_actions.dart';         // Actions : Maps, appel, email, partage
import 'service_qr_dialog.dart';               // Dialog QR code

/// Palette de couleurs par type de service (identique à service_card.dart).
/// Définie ici pour que le bottom sheet utilise les mêmes couleurs que les cartes.
const Map<ServiceType, Color> _typeColors = {
  ServiceType.medical: Color(0xFF176B87),
  ServiceType.surgical: Color(0xFF8B45A0),
  ServiceType.emergency: Color(0xFFD64045),
  ServiceType.intensiveCare: Color(0xFFC0392B),
  ServiceType.maternity: Color(0xFFE0689A),
  ServiceType.medicoTechnical: Color(0xFF5B6BBF),
  ServiceType.administrative: Color(0xFFE8891A),
  ServiceType.other: Color(0xFF607D8B),
};

/// Bottom sheet de détail complet d'un service hospitalier.
/// S'ouvre depuis la liste quand l'utilisateur tape sur une carte.
class ServiceDetailSheet extends StatelessWidget {
  const ServiceDetailSheet({
    super.key,
    required this.service,  // Service dont on affiche le détail (obligatoire)
    this.canEdit = false,   // false = lecture seule, true = boutons admin visibles
    this.canEditDetails = false,
    this.onEdit,            // Callback déclenché quand l'admin clique "Modifier"
    this.onToggleActive,    // Callback déclenché quand l'admin clique toggle
  });

  final HospitalService service;
  final bool canEdit;
  final bool canEditDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final isActive  = service.isActive; // Raccourci booléen pour le statut
    // Couleur thématique du type de service (utilise gris par défaut si type inconnu)
    final typeColor = _typeColors[service.serviceType] ?? const Color(0xFF607D8B);

    // Container : boîte principale du bottom sheet
    return Container(
      margin: const EdgeInsets.only(top: 60), // Laisse 60px visibles au-dessus (fond de la page)
      decoration: const BoxDecoration(
        color: Colors.white, // Fond blanc de la feuille
        // Coins arrondis seulement en haut (en bas : carré pour coller au bord de l'écran)
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),

      // SafeArea : évite que le contenu se cache derrière la barre système (notch, home indicator)
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Hauteur adaptée au contenu (pas plein écran)
          children: [

            // ----------------------------------------------------------------
            // POIGNÉE DE DÉFILEMENT (handle)
            // Petite barre grise en haut qui indique que la feuille est glissable
            // ----------------------------------------------------------------
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4), // Marges verticales
                width: 40,  // Largeur de la poignée
                height: 4,  // Hauteur très fine
                decoration: BoxDecoration(
                  color: const Color(0xFFD6E0E5), // Gris clair
                  borderRadius: BorderRadius.circular(2), // Extrémités arrondies
                ),
              ),
            ),

            // ----------------------------------------------------------------
            // CONTENU SCROLLABLE
            // Flexible : permet au contenu de défiler si trop grand pour l'écran
            // ----------------------------------------------------------------
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), // Marges : 24px H, 8px haut, 32px bas
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Aligne tout à gauche
                  children: [

                    // --------------------------------------------------------
                    // EN-TÊTE : icône + nom + badges type et statut
                    // --------------------------------------------------------
                    _buildHeader(isActive, typeColor),

                    const SizedBox(height: 20), // Espacement

                    // --------------------------------------------------------
                    // BOUTONS D'ACTION RAPIDE : Maps · Appel · Email · Partage · QR
                    // --------------------------------------------------------
                    _buildActionButtons(context),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFEEF2F4)), // Ligne séparatrice
                    const SizedBox(height: 20),

                    // --------------------------------------------------------
                    // SECTION : DESCRIPTION (si renseignée)
                    // if (...) ...[] : n'affiche cette section que si description non vide
                    // --------------------------------------------------------
                    if (service.description.isNotEmpty) ...[
                      const _SectionLabel(label: 'Description'), // Label section en majuscules
                      const SizedBox(height: 8),
                      Text(
                        service.description, // Texte complet (sans troncature ici)
                        style: const TextStyle(
                          color: Color(0xFF2C4A5A), // Bleu très foncé, bonne lisibilité
                          height: 1.6,             // Interligne large pour le confort de lecture
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // --------------------------------------------------------
                    // SECTION : LOCALISATION (si au moins un champ renseigné)
                    // --------------------------------------------------------
                    if (service.building.isNotEmpty ||
                        service.floor.isNotEmpty ||
                        service.location.isNotEmpty) ...[
                      const _SectionLabel(label: 'Localisation'),
                      const SizedBox(height: 10),

                      // Ligne Bâtiment (si renseigné)
                      if (service.building.isNotEmpty)
                        _DetailRow(
                          icon: Icons.apartment_outlined,
                          label: 'Bâtiment',
                          value: service.building,
                          color: typeColor,
                        ),

                      // Ligne Étage (si renseigné)
                      if (service.floor.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.stairs_outlined,
                          label: 'Étage',
                          value: service.floor,
                          color: typeColor,
                        ),
                      ],

                      // Ligne Emplacement avec bouton "Ouvrir Maps"
                      if (service.location.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _MapsRow(
                          value: service.location,
                          color: typeColor,
                          // Callback : ouvre Google Maps avec l'adresse du service
                          onTap: () => ServiceActions.openMaps(context, service),
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],

                    // --------------------------------------------------------
                    // SECTION : CONTACT (si au moins un champ renseigné)
                    // --------------------------------------------------------
                    if (service.headName.isNotEmpty ||
                        service.phone.isNotEmpty ||
                        service.email.isNotEmpty) ...[
                      const _SectionLabel(label: 'Contact'),
                      const SizedBox(height: 10),

                      // Ligne Responsable
                      if (service.headName.isNotEmpty)
                        _DetailRow(
                          icon: Icons.person_outlined,
                          label: 'Responsable',
                          value: service.headName,
                          color: typeColor,
                        ),

                      // Ligne Téléphone avec boutons Copier + Appeler
                      if (service.phone.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _PhoneRow(
                          value: service.phone,
                          color: typeColor,
                          onCall: () => ServiceActions.callService(context, service),
                          context: context,
                        ),
                      ],

                      // Ligne Email avec boutons Copier + Ouvrir client mail
                      if (service.email.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _EmailRow(
                          value: service.email,
                          color: typeColor,
                          onEmail: () => ServiceActions.emailService(context, service),
                          context: context,
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],

                    // --------------------------------------------------------
                    // SECTION : INFOS PRATIQUES (capacité et/ou horaires)
                    // --------------------------------------------------------
                    if (service.capacity > 0 || service.openingHours.isNotEmpty) ...[
                      const _SectionLabel(label: 'Infos pratiques'),
                      const SizedBox(height: 10),

                      // Ligne Capacité (si > 0)
                      if (service.capacity > 0)
                        _DetailRow(
                          icon: Icons.bed_outlined,
                          label: 'Capacité',
                          value: '${service.capacity} lits / places',
                          color: typeColor,
                        ),

                      // Ligne Horaires (si renseigné)
                      if (service.openingHours.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.schedule_outlined,
                          label: 'Horaires',
                          value: service.openingHours,
                          color: typeColor,
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],

                    // --------------------------------------------------------
                    // SECTION : NOTES INTERNES (bloc jaune si renseigné)
                    // --------------------------------------------------------
                    if (service.notes.isNotEmpty) ...[
                      const _SectionLabel(label: 'Notes internes'),
                      const SizedBox(height: 8),

                      // Container jaune pâle pour les notes (style post-it)
                      Container(
                        width: double.infinity, // Prend toute la largeur
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E7),  // Fond jaune très pâle
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE082)), // Bordure jaune
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined, // Icône post-it
                              color: Color(0xFFE8891A),     // Orange
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded( // Prend l'espace restant pour le texte
                              child: Text(
                                service.notes,
                                style: const TextStyle(
                                  color: Color(0xFF5D4037), // Marron foncé lisible sur jaune
                                  height: 1.5,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],

                    // --------------------------------------------------------
                    // LIGNE STATUT DU SERVICE (toujours visible)
                    // --------------------------------------------------------
                    _DetailRow(
                      // Icône check (vert) si actif, pause (gris) si inactif
                      icon: isActive
                          ? Icons.check_circle_outline_rounded
                          : Icons.pause_circle_outline_rounded,
                      label: 'Statut',
                      value: isActive
                          ? 'Actif – visible par le personnel'
                          : 'Inactif – masqué au personnel',
                      // Couleur vert menthe si actif, gris si inactif
                      color: isActive ? AppColors.mint : const Color(0xFF8797A0),
                    ),

                    // --------------------------------------------------------
                    // BOUTONS ADMIN (seulement si canEdit = true)
                    // --------------------------------------------------------
                    if (canEdit || canEditDetails) ...[
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: Color(0xFFEEF2F4)),
                      const SizedBox(height: 16),

                      // Bouton "Modifier ce service" pleine largeur
                      SizedBox(
                        width: double.infinity, // Bouton sur toute la largeur
                        child: FilledButton.icon(
                          onPressed: onEdit, // Déclenche le callback d'édition
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Modifier ce service'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                      if (canEdit) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onToggleActive,
                            icon: Icon(isActive
                                ? Icons.toggle_off_outlined
                                : Icons.toggle_on_outlined),
                            label: Text(isActive
                                ? 'Désactiver ce service'
                                : 'Réactiver ce service'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isActive
                                  ? const Color(0xFFD64045)
                                  : AppColors.mint,
                              side: BorderSide(
                                color: isActive
                                    ? const Color(0xFFD64045)
                                    : AppColors.mint,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ],

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MÉTHODE PRIVÉE : construit l'en-tête du bottom sheet
  // --------------------------------------------------------------------------
  Widget _buildHeader(bool isActive, Color typeColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Container arrondi contenant l'icône médicale (plus grand que dans la carte)
        Container(
          width: 56, height: 56, // Plus grand pour le détail (56 vs 44 dans la carte)
          decoration: BoxDecoration(
            color: isActive
                ? typeColor.withValues(alpha: 0.12)
                : const Color(0xFFEEF2F4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.medical_services_outlined,
            size: 28, // Plus grande icône pour le détail
            color: isActive ? typeColor : const Color(0xFF9AA9B0),
          ),
        ),

        const SizedBox(width: 16), // Espacement icône-titre

        Expanded( // Prend tout l'espace restant
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom du service en grand et gras
              Text(
                service.name,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,              // Plus grand que dans la carte (16px)
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  // Badge coloré du TYPE de service
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1), // Fond de la couleur du type
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      service.serviceType.label, // Ex : "Cardiologie", "Urgences"…
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Badge ACTIF / INACTIF
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFE6F7F3) // Vert pâle si actif
                          : const Color(0xFFF0F4F6), // Gris pâle si inactif
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.mint : const Color(0xFF8797A0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // MÉTHODE PRIVÉE : construit la rangée de 5 boutons d'action
  // --------------------------------------------------------------------------
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribue uniformément les 5 boutons
      children: [

        // Bouton Maps : grisé si aucune adresse renseignée
        _ActionButton(
          icon: Icons.map_outlined,
          label: 'Maps',
          color: const Color(0xFF4285F4),    // Bleu Google Maps
          enabled: service.location.isNotEmpty || service.building.isNotEmpty,
          onTap: () => ServiceActions.openMaps(context, service),
        ),

        // Bouton Appeler : grisé si aucun téléphone renseigné
        _ActionButton(
          icon: Icons.call_outlined,
          label: 'Appeler',
          color: const Color(0xFF34A853),    // Vert téléphone
          enabled: service.phone.isNotEmpty,
          onTap: () => ServiceActions.callService(context, service),
        ),

        // Bouton Email : grisé si aucun email renseigné
        _ActionButton(
          icon: Icons.email_outlined,
          label: 'Email',
          color: const Color(0xFFEA4335),    // Rouge Gmail
          enabled: service.email.isNotEmpty,
          onTap: () => ServiceActions.emailService(context, service),
        ),

        // Bouton Partager : toujours actif (on peut toujours partager le nom + type)
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Partager',
          color: AppColors.blue,
          enabled: true,
          onTap: () => ServiceActions.shareService(service),
        ),

        // Bouton QR Code : toujours actif
        _ActionButton(
          icon: Icons.qr_code_2_rounded,
          label: 'QR Code',
          color: AppColors.navy,
          enabled: true,
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => ServiceQrDialog(service: service), // Ouvre le dialog QR
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET PRIVÉ : _ActionButton
// Bouton circulaire avec icône + label texte en dessous.
// Style iOS/Android (comme les boutons de partage dans les apps natives).
// =============================================================================

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,     // Icône Material à afficher dans le cercle
    required this.label,    // Texte affiché sous le cercle
    required this.color,    // Couleur thématique (icône + fond)
    required this.enabled,  // false = grisé et non cliquable
    required this.onTap,    // Fonction appelée au tap
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // GestureDetector : capte les gestes (tap) sur tout le widget
    return GestureDetector(
      onTap: enabled ? onTap : null, // Si désactivé → null = aucune réaction au tap

      // Opacity : réduit l'opacité à 35% si désactivé pour indiquer que le bouton est inactif
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,

        child: Column(
          mainAxisSize: MainAxisSize.min, // Hauteur minimale
          children: [
            // Cercle coloré contenant l'icône
            Container(
              width: 52, height: 52, // Taille fixe du cercle

              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), // Fond de couleur très pâle
                shape: BoxShape.circle,               // Forme circulaire (pas carrée)
              ),

              child: Icon(icon, color: color, size: 24), // Icône colorée au centre
            ),

            const SizedBox(height: 6), // Espacement cercle-label

            // Label sous l'icône
            Text(
              label,
              style: TextStyle(
                // Couleur navy si actif, gris si désactivé
                color: enabled ? AppColors.navy : const Color(0xFF9AA9B0),
                fontSize: 11,              // Très petit
                fontWeight: FontWeight.w600, // Semi-gras pour lisibilité
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET PRIVÉ : _MapsRow
// Ligne "Emplacement" avec un bouton "Maps" à droite.
// =============================================================================

class _MapsRow extends StatelessWidget {
  const _MapsRow({required this.value, required this.color, required this.onTap});
  final String value;      // Texte de l'emplacement à afficher
  final Color color;       // Couleur thématique du type de service
  final VoidCallback onTap; // Callback pour ouvrir Maps

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icône pin dans container coloré
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10), // Fond teinté très pâle
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.place_outlined, color: color, size: 18),
        ),

        const SizedBox(width: 12),

        // Texte label + valeur
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Emplacement',
                  style: TextStyle(color: Color(0xFF8797A0), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: AppColors.navy, fontSize: 15, height: 1.4)),
            ],
          ),
        ),

        // Bouton textuel "Maps" à droite
        TextButton.icon(
          onPressed: onTap, // Ouvre Google Maps
          icon: const Icon(Icons.map_outlined, size: 15),
          label: const Text('Maps', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4285F4), // Bleu Google Maps
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,                   // Pas de taille minimale forcée
            tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Zone de tap compacte
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET PRIVÉ : _PhoneRow
// Ligne téléphone avec boutons Copier (presse-papier) et Appeler.
// =============================================================================

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.value,    // Numéro à afficher
    required this.color,    // Couleur thématique
    required this.onCall,   // Callback pour lancer l'appel
    required this.context,  // BuildContext pour le SnackBar de confirmation
  });
  final String value;
  final Color color;
  final VoidCallback onCall;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icône téléphone dans container coloré
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.phone_outlined, color: color, size: 18),
        ),

        const SizedBox(width: 12),

        // Label + valeur du téléphone
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Téléphone / Poste',
                  style: TextStyle(color: Color(0xFF8797A0), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: AppColors.navy, fontSize: 15, height: 1.4)),
            ],
          ),
        ),

        // Bouton COPIER : copie le numéro dans le presse-papier
        IconButton(
          tooltip: 'Copier',
          icon: const Icon(Icons.copy_outlined, size: 17),
          color: const Color(0xFF8797A0),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value)); // Copie dans le presse-papier

            // Affiche un SnackBar de confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$value" copié.'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),

        // Bouton APPELER : lance un appel téléphonique
        IconButton(
          tooltip: 'Appeler',
          icon: const Icon(Icons.call_outlined, size: 17),
          color: const Color(0xFF34A853), // Vert téléphone
          visualDensity: VisualDensity.compact,
          onPressed: onCall, // Déclenche ServiceActions.callService()
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET PRIVÉ : _EmailRow
// Ligne email avec boutons Copier et Ouvrir client mail.
// =============================================================================

class _EmailRow extends StatelessWidget {
  const _EmailRow({
    required this.value,    // Adresse email à afficher
    required this.color,    // Couleur thématique
    required this.onEmail,  // Callback pour ouvrir le client mail
    required this.context,  // BuildContext pour le SnackBar
  });
  final String value;
  final Color color;
  final VoidCallback onEmail;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icône email dans container coloré
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.email_outlined, color: color, size: 18),
        ),

        const SizedBox(width: 12),

        // Label + valeur de l'email
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Email',
                  style: TextStyle(color: Color(0xFF8797A0), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: AppColors.navy, fontSize: 15, height: 1.4)),
            ],
          ),
        ),

        // Bouton COPIER l'adresse email
        IconButton(
          tooltip: 'Copier',
          icon: const Icon(Icons.copy_outlined, size: 17),
          color: const Color(0xFF8797A0),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$value" copié.'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),

        // Bouton ENVOYER un email (ouvre le client mail)
        IconButton(
          tooltip: 'Envoyer un e-mail',
          icon: const Icon(Icons.send_outlined, size: 17),
          color: const Color(0xFFEA4335), // Rouge Gmail
          visualDensity: VisualDensity.compact,
          onPressed: onEmail, // Déclenche ServiceActions.emailService()
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET PARTAGÉ : _SectionLabel
// Label de section en MAJUSCULES avec espacement des lettres.
// Utilisé pour séparer visuellement les différentes sections du détail.
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label}); // Texte du label
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(), // Convertit en majuscules (ex : "contact" → "CONTACT")
      style: const TextStyle(
        color: Color(0xFF8797A0),  // Gris discret
        fontSize: 11,             // Très petit
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,       // Espacement entre les lettres pour l'effet "label"
      ),
    );
  }
}

// =============================================================================
// WIDGET PARTAGÉ : _DetailRow
// Ligne standard : conteneur icône coloré + label gris + valeur.
// Utilisé pour toutes les informations non-interactives.
// =============================================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,   // Icône Material à gauche
    required this.label,  // Label descriptif (petit, gris) : ex "Bâtiment"
    required this.value,  // Valeur affichée (plus grand) : ex "Bâtiment A"
    required this.color,  // Couleur thématique du type de service
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Aligne en haut si valeur multilignes
      children: [
        // Container coloré contenant l'icône
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10), // Fond de couleur très pâle
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),

        const SizedBox(width: 12), // Espacement icône-texte

        // Colonne label (petit, gris) + valeur (normal, navy)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Color(0xFF8797A0), fontSize: 12)), // Label gris
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(color: AppColors.navy, fontSize: 15, height: 1.4)), // Valeur
            ],
          ),
        ),
      ],
    );
  }
}

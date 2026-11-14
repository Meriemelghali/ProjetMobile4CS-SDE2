// =============================================================================
// WIDGET : ServiceDetailSheet
// Bottom sheet complet d'un service hospitalier.
// Boutons d'action : Google Maps · Appel · Email · Partage · QR Code
// Sections : Identification · Localisation · Contact · Pratique · Notes
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard

import '../../../core/theme/app_colors.dart';
import '../domain/hospital_service.dart';
import '../utils/service_actions.dart';  // Google Maps, appel, email, partage
import 'service_qr_dialog.dart';        // Dialog QR code

/// Palette de couleurs par type de service.
const Map<ServiceType, Color> _typeColors = {
  ServiceType.medecine:    Color(0xFF176B87),
  ServiceType.chirurgie:   Color(0xFF8B45A0),
  ServiceType.urgences:    Color(0xFFD64045),
  ServiceType.pediatrie:   Color(0xFF36A98B),
  ServiceType.gynecologie: Color(0xFFE0689A),
  ServiceType.radiologie:  Color(0xFF5B6BBF),
  ServiceType.laboratoire: Color(0xFFE8891A),
  ServiceType.reanimation: Color(0xFFC0392B),
  ServiceType.psychiatrie: Color(0xFF2E7D32),
  ServiceType.autre:       Color(0xFF607D8B),
};

/// Bottom sheet de détail complet d'un service hospitalier.
/// Accessible en tapant sur une carte dans la liste.
class ServiceDetailSheet extends StatelessWidget {
  const ServiceDetailSheet({
    super.key,
    required this.service,   // Service à afficher
    this.canEdit = false,    // true = affiche les boutons admin
    this.onEdit,             // Callback pour modifier le service
    this.onToggleActive,     // Callback pour activer/désactiver
  });

  final HospitalService service;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final isActive  = service.isActive;
    final typeColor = _typeColors[service.serviceType] ?? const Color(0xFF607D8B);

    return Container(
      margin: const EdgeInsets.only(top: 60),
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
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6E0E5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // --------------------------------------------------------
                    // En-tête : icône + nom + type + badge statut
                    // --------------------------------------------------------
                    _buildHeader(isActive, typeColor),

                    const SizedBox(height: 20),

                    // --------------------------------------------------------
                    // BOUTONS D'ACTION RAPIDE
                    // Maps · Appel · Email · Partage · QR Code
                    // --------------------------------------------------------
                    _buildActionButtons(context),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFEEF2F4)),
                    const SizedBox(height: 20),

                    // --------------------------------------------------------
                    // Description
                    // --------------------------------------------------------
                    if (service.description.isNotEmpty) ...[
                      const _SectionLabel(label: 'Description'),
                      const SizedBox(height: 8),
                      Text(
                        service.description,
                        style: const TextStyle(
                          color: Color(0xFF2C4A5A),
                          height: 1.6,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // --------------------------------------------------------
                    // Localisation
                    // --------------------------------------------------------
                    if (service.building.isNotEmpty ||
                        service.floor.isNotEmpty ||
                        service.location.isNotEmpty) ...[
                      const _SectionLabel(label: 'Localisation'),
                      const SizedBox(height: 10),
                      if (service.building.isNotEmpty)
                        _DetailRow(
                          icon: Icons.apartment_outlined,
                          label: 'Bâtiment',
                          value: service.building,
                          color: typeColor,
                        ),
                      if (service.floor.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.stairs_outlined,
                          label: 'Étage',
                          value: service.floor,
                          color: typeColor,
                        ),
                      ],
                      if (service.location.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        // Ligne localisation avec bouton "Ouvrir Maps"
                        _MapsRow(
                          value: service.location,
                          color: typeColor,
                          onTap: () => ServiceActions.openMaps(context, service),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],

                    // --------------------------------------------------------
                    // Contact
                    // --------------------------------------------------------
                    if (service.headName.isNotEmpty ||
                        service.phone.isNotEmpty ||
                        service.email.isNotEmpty) ...[
                      const _SectionLabel(label: 'Contact'),
                      const SizedBox(height: 10),
                      if (service.headName.isNotEmpty)
                        _DetailRow(
                          icon: Icons.person_outlined,
                          label: 'Responsable',
                          value: service.headName,
                          color: typeColor,
                        ),
                      if (service.phone.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        // Ligne téléphone : copier + appeler
                        _PhoneRow(
                          value: service.phone,
                          color: typeColor,
                          onCall: () => ServiceActions.callService(context, service),
                          context: context,
                        ),
                      ],
                      if (service.email.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        // Ligne email : copier + ouvrir client mail
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
                    // Infos pratiques
                    // --------------------------------------------------------
                    if (service.capacity > 0 || service.openingHours.isNotEmpty) ...[
                      const _SectionLabel(label: 'Infos pratiques'),
                      const SizedBox(height: 10),
                      if (service.capacity > 0)
                        _DetailRow(
                          icon: Icons.bed_outlined,
                          label: 'Capacité',
                          value: '${service.capacity} lits / places',
                          color: typeColor,
                        ),
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
                    // Notes internes
                    // --------------------------------------------------------
                    if (service.notes.isNotEmpty) ...[
                      const _SectionLabel(label: 'Notes internes'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sticky_note_2_outlined,
                                color: Color(0xFFE8891A), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                service.notes,
                                style: const TextStyle(
                                  color: Color(0xFF5D4037),
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
                    // Statut
                    // --------------------------------------------------------
                    _DetailRow(
                      icon: isActive
                          ? Icons.check_circle_outline_rounded
                          : Icons.pause_circle_outline_rounded,
                      label: 'Statut',
                      value: isActive
                          ? 'Actif – visible par le personnel'
                          : 'Inactif – masqué au personnel',
                      color: isActive ? AppColors.mint : const Color(0xFF8797A0),
                    ),

                    // --------------------------------------------------------
                    // Boutons admin
                    // --------------------------------------------------------
                    if (canEdit) ...[
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: Color(0xFFEEF2F4)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onEdit,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // En-tête coloré
  // --------------------------------------------------------------------------

  Widget _buildHeader(bool isActive, Color typeColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: isActive
                ? typeColor.withValues(alpha: 0.12)
                : const Color(0xFFEEF2F4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.medical_services_outlined,
              size: 28,
              color: isActive ? typeColor : const Color(0xFF9AA9B0)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  // Badge type de service
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      service.serviceType.label,
                      style: TextStyle(
                          color: typeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge actif/inactif
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFE6F7F3)
                          : const Color(0xFFF0F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppColors.mint
                            : const Color(0xFF8797A0),
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
  // Boutons d'action rapide
  // --------------------------------------------------------------------------

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Bouton Google Maps (actif seulement si localisation renseignée)
        _ActionButton(
          icon: Icons.map_outlined,
          label: 'Maps',
          color: const Color(0xFF4285F4), // Bleu Google Maps
          enabled: service.location.isNotEmpty || service.building.isNotEmpty,
          onTap: () => ServiceActions.openMaps(context, service),
        ),

        // Bouton Appel téléphonique
        _ActionButton(
          icon: Icons.call_outlined,
          label: 'Appeler',
          color: const Color(0xFF34A853), // Vert téléphone
          enabled: service.phone.isNotEmpty,
          onTap: () => ServiceActions.callService(context, service),
        ),

        // Bouton Email
        _ActionButton(
          icon: Icons.email_outlined,
          label: 'Email',
          color: const Color(0xFFEA4335), // Rouge Gmail
          enabled: service.email.isNotEmpty,
          onTap: () => ServiceActions.emailService(context, service),
        ),

        // Bouton Partager
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Partager',
          color: AppColors.blue,
          enabled: true, // Toujours disponible
          onTap: () => ServiceActions.shareService(service),
        ),

        // Bouton QR Code
        _ActionButton(
          icon: Icons.qr_code_2_rounded,
          label: 'QR Code',
          color: AppColors.navy,
          enabled: true, // Toujours disponible
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => ServiceQrDialog(service: service),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET PRIVÉ : _ActionButton
// Bouton d'action circulaire avec icône + label (style app iOS/Android).
// =============================================================================

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,    // Icône Material
    required this.label,   // Label sous l'icône
    required this.color,   // Couleur thématique
    required this.enabled, // false = grisé et non cliquable
    required this.onTap,   // Callback au tap
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null, // Désactive si enabled = false
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35, // Grisé si désactivé
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cercle coloré contenant l'icône
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), // Fond teinté
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            // Label sous l'icône
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.navy : const Color(0xFF9AA9B0),
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
// Ligne localisation avec bouton "Ouvrir dans Maps".
// =============================================================================

class _MapsRow extends StatelessWidget {
  const _MapsRow({
    required this.value,
    required this.color,
    required this.onTap,
  });
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icône pin dans container coloré
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.place_outlined, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Emplacement',
                  style: TextStyle(color: Color(0xFF8797A0), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.navy, fontSize: 15, height: 1.4)),
            ],
          ),
        ),
        // Bouton "Ouvrir Maps"
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.map_outlined, size: 15),
          label: const Text('Maps', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4285F4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET PRIVÉ : _PhoneRow
// Ligne téléphone avec boutons Copier + Appeler.
// =============================================================================

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.value,
    required this.color,
    required this.onCall,
    required this.context,
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
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.phone_outlined, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Téléphone / Poste',
                  style: TextStyle(color: Color(0xFF8797A0), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.navy, fontSize: 15, height: 1.4)),
            ],
          ),
        ),
        // Bouton copier
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
        // Bouton appeler
        IconButton(
          tooltip: 'Appeler',
          icon: const Icon(Icons.call_outlined, size: 17),
          color: const Color(0xFF34A853),
          visualDensity: VisualDensity.compact,
          onPressed: onCall,
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET PRIVÉ : _EmailRow
// Ligne email avec boutons Copier + Ouvrir client mail.
// =============================================================================

class _EmailRow extends StatelessWidget {
  const _EmailRow({
    required this.value,
    required this.color,
    required this.onEmail,
    required this.context,
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
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.email_outlined, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Email',
                  style: TextStyle(color: Color(0xFF8797A0), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.navy, fontSize: 15, height: 1.4)),
            ],
          ),
        ),
        // Bouton copier
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
        // Bouton ouvrir client mail
        IconButton(
          tooltip: 'Envoyer un e-mail',
          icon: const Icon(Icons.send_outlined, size: 17),
          color: const Color(0xFFEA4335),
          visualDensity: VisualDensity.compact,
          onPressed: onEmail,
        ),
      ],
    );
  }
}

// =============================================================================
// Widgets utilitaires partagés
// =============================================================================

/// Label de section en majuscules espacées.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF8797A0),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

/// Ligne icône + label + valeur standard.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF8797A0), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.navy, fontSize: 15, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET : ServiceQrDialog
// Dialog affichant un QR code contenant les informations clés d'un service.
// Le QR code encode une fiche contact vCard-like que n'importe quel scanner
// peut lire (téléphone, tablette, affichage dans le couloir…).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Génération du QR code

import '../../../core/theme/app_colors.dart';
import '../domain/hospital_service.dart';

/// Dialog affichant le QR code du service avec option d'impression/partage.
class ServiceQrDialog extends StatelessWidget {
  const ServiceQrDialog({super.key, required this.service});

  /// Service dont on génère le QR code.
  final HospitalService service;

  /// Construit les données encodées dans le QR code.
  /// Format lisible par tous les scanners standard.
  String _buildQrData() {
    final lines = <String>[];

    lines.add('SERVICE: ${service.name}');               // Nom du service
    lines.add('TYPE: ${service.serviceType.label}');     // Catégorie médicale

    if (service.location.isNotEmpty) {
      lines.add('LIEU: ${service.location}');            // Localisation
    }
    if (service.headName.isNotEmpty) {
      lines.add('RESPONSABLE: ${service.headName}');     // Chef de service
    }
    if (service.phone.isNotEmpty) {
      lines.add('TEL: ${service.phone}');                // Téléphone
    }
    if (service.email.isNotEmpty) {
      lines.add('EMAIL: ${service.email}');              // Email
    }
    if (service.openingHours.isNotEmpty) {
      lines.add('HORAIRES: ${service.openingHours}');    // Horaires
    }
    if (service.capacity > 0) {
      lines.add('CAPACITE: ${service.capacity} lits');   // Capacité
    }

    return lines.join('\n'); // Chaque champ sur une ligne
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _buildQrData(); // Génère les données une seule fois

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Hauteur adaptée au contenu
          children: [
            // ---- Titre ----
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: AppColors.navy, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QR Code du service',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        service.name, // Nom du service sous le titre
                        style: const TextStyle(
                          color: Color(0xFF687B86),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bouton fermer
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF8797A0)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ---- QR Code ----
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,              // Fond blanc obligatoire pour les scanners
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5ECEF)),
              ),
              child: QrImageView(
                data: qrData,                    // Données encodées dans le QR
                version: QrVersions.auto,        // Choisit automatiquement la version
                size: 220,                       // Taille du QR code en pixels
                backgroundColor: Colors.white,   // Fond blanc
                // Couleur des modules (carrés) du QR code
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.navy,         // Bleu foncé du projet
                ),
                // Style des coins du QR code
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.blue,         // Bleu primaire pour les coins
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Message explicatif ----
            const Text(
              'Scannez ce QR code pour accéder\naux informations de ce service.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF687B86),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 8),

            // ---- Données encodées (affichées en petit pour transparence) ----
            ExpansionTile(
              title: const Text(
                'Voir les données encodées',
                style: TextStyle(fontSize: 12, color: Color(0xFF8797A0)),
              ),
              tilePadding: EdgeInsets.zero,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    qrData,
                    style: const TextStyle(
                      fontFamily: 'monospace',    // Police monospace pour lisibilité
                      fontSize: 11,
                      color: Color(0xFF536A77),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

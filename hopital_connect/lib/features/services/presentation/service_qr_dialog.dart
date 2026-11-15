// =============================================================================
// WIDGET : ServiceQrDialog
// Affiche un QR code qui encode l'URL vers le PDF du service sur le backend.
// Quand quelqu'un scanne le QR → son navigateur ouvre le PDF directement.
// Le PDF est généré en temps réel par le backend (endpoint public sans auth).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Génération du QR code

import '../../../core/config/api_config.dart'; // URL de base du backend
import '../../../core/theme/app_colors.dart';
import '../domain/hospital_service.dart';
import '../utils/service_pdf.dart'; // Pour le bouton "Ouvrir PDF" dans l'app

/// Dialog affichant le QR code du service.
/// Le QR encode l'URL : {baseUrl}/services/{id}/pdf
/// Quand scanné → ouvre le PDF complet du service dans le navigateur.
class ServiceQrDialog extends StatefulWidget {
  const ServiceQrDialog({super.key, required this.service});

  /// Service dont on génère le QR code.
  final HospitalService service;

  @override
  State<ServiceQrDialog> createState() => _ServiceQrDialogState();
}

class _ServiceQrDialogState extends State<ServiceQrDialog> {
  /// Indique si le PDF est en cours de génération (pour le bouton spinner)
  bool _loadingPdf = false;

  /// URL complète vers le PDF du service sur le backend.
  /// Format : http://localhost:3000/services/{id}/pdf
  String get _pdfUrl =>
      '${ApiConfig.baseUrl}/services/${widget.service.id}/pdf';

  /// Ouvre le PDF directement dans l'app via le package printing.
  Future<void> _openPdf() async {
    setState(() => _loadingPdf = true); // Active le spinner
    try {
      await ServicePdf.openPdf(context, widget.service);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur PDF : $e'),
            backgroundColor: const Color(0xFFD64045),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ---- En-tête : icône + titre + bouton fermer ----
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
                        'QR Code — Fiche PDF',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      // Nom du service sous le titre
                      Text(
                        widget.service.name,
                        style: const TextStyle(
                            color: Color(0xFF687B86), fontSize: 13),
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
            // Fond blanc obligatoire pour que les scanners puissent lire le QR
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5ECEF)),
              ),
              child: QrImageView(
                data: _pdfUrl,              // URL encodée dans le QR code
                version: QrVersions.auto,   // Version automatique selon la longueur des données
                size: 200,                  // Taille du QR en pixels logiques
                backgroundColor: Colors.white,

                // Style des modules (carrés noirs du QR)
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.navy,    // Bleu foncé pour les modules
                ),

                // Style des coins du QR
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.blue,    // Bleu primaire pour les coins
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ---- Message explicatif ----
            const Text(
              'Scannez pour ouvrir la fiche PDF\ndu service dans votre navigateur.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF687B86),
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 8),

            // ---- URL encodée (affichée en petit pour transparence) ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _pdfUrl,                   // Affiche l'URL exacte encodée
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace', // Police monospace pour l'URL
                  fontSize: 10,
                  color: Color(0xFF536A77),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Bouton "Ouvrir le PDF dans l'app" ----
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // Désactivé pendant la génération (spinner affiché)
                onPressed: _loadingPdf ? null : _openPdf,
                icon: _loadingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(_loadingPdf
                    ? 'Génération en cours…'
                    : 'Ouvrir le PDF dans l\'app'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD64045), // Rouge PDF
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

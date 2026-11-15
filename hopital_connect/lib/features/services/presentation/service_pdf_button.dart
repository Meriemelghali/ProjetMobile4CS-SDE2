// =============================================================================
// WIDGET : ServicePdfButton
// Bouton "Fiche PDF" qui génère et ouvre le PDF du service.
// Affiche un indicateur de chargement pendant la génération.
// =============================================================================

import 'package:flutter/material.dart';

import '../domain/hospital_service.dart';
import '../utils/service_pdf.dart';

/// Bouton stylisé qui déclenche la génération et l'ouverture du PDF.
/// Affiche un spinner pendant la génération pour informer l'utilisateur.
class ServicePdfButton extends StatefulWidget {
  const ServicePdfButton({super.key, required this.service});

  /// Service dont on génère la fiche PDF.
  final HospitalService service;

  @override
  State<ServicePdfButton> createState() => _ServicePdfButtonState();
}

class _ServicePdfButtonState extends State<ServicePdfButton> {
  /// True pendant la génération du PDF — affiche un spinner.
  bool _loading = false;

  /// Déclenche la génération PDF et met à jour l'état de chargement.
  Future<void> _generate() async {
    setState(() => _loading = true); // Active le spinner
    try {
      // Génère et ouvre le PDF via le package printing
      await ServicePdf.openPdf(context, widget.service);
    } catch (e) {
      // En cas d'erreur, affiche un SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du PDF : $e'),
            backgroundColor: const Color(0xFFD64045),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false); // Désactive le spinner
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _loading ? null : _generate, // Désactivé pendant la génération
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white, // Spinner blanc sur fond bleu
              ),
            )
          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: Text(_loading ? 'Génération…' : 'Ouvrir la fiche PDF'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFD64045), // Rouge PDF
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

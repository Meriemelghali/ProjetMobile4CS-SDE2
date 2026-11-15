// =============================================================================
// WIDGET : ServiceQrDialog
// Dialog affichant un QR code contenant les informations clés d'un service.
// Le QR code encode une fiche lisible par n'importe quel scanner standard.
// =============================================================================

import 'package:flutter/material.dart';        // Widgets Flutter de base
import 'package:qr_flutter/qr_flutter.dart';   // Package externe pour générer des QR codes

import '../../../core/theme/app_colors.dart';   // Couleurs du projet (navy, blue…)
import '../domain/hospital_service.dart';       // Modèle HospitalService

/// Dialog affichant le QR code d'un service hospitalier.
/// Reçoit un [service] et génère dynamiquement le QR code à partir de ses données.
class ServiceQrDialog extends StatelessWidget {
  const ServiceQrDialog({super.key, required this.service}); // service obligatoire

  /// Service dont les informations seront encodées dans le QR code.
  final HospitalService service;

  // --------------------------------------------------------------------------
  // Méthode privée : construit le texte encodé dans le QR code
  // --------------------------------------------------------------------------

  /// Construit une chaîne de texte structurée avec les informations du service.
  /// Format : une clé par ligne (KEY: valeur), lisible par tous les scanners.
  String _buildQrData() {
    final lines = <String>[]; // Liste vide qui accumulera les lignes de données

    lines.add('SERVICE: ${service.name}');           // Toujours présent : nom du service
    lines.add('TYPE: ${service.serviceType.label}'); // Toujours présent : catégorie médicale

    // Champs optionnels : ajoutés seulement s'ils sont renseignés (non vides)
    if (service.location.isNotEmpty) {
      lines.add('LIEU: ${service.location}');        // Localisation dans l'hôpital
    }
    if (service.headName.isNotEmpty) {
      lines.add('RESPONSABLE: ${service.headName}'); // Nom du chef de service
    }
    if (service.phone.isNotEmpty) {
      lines.add('TEL: ${service.phone}');            // Numéro de téléphone
    }
    if (service.email.isNotEmpty) {
      lines.add('EMAIL: ${service.email}');          // Adresse email
    }
    if (service.openingHours.isNotEmpty) {
      lines.add('HORAIRES: ${service.openingHours}'); // Horaires d'ouverture
    }
    if (service.capacity > 0) {                      // 0 signifie "non renseigné"
      lines.add('CAPACITE: ${service.capacity} lits'); // Nombre de lits
    }

    return lines.join('\n'); // Réunit toutes les lignes avec un retour à la ligne entre chaque
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _buildQrData(); // Génère les données une seule fois (évite de recalculer)

    // Dialog : fenêtre modale centrée sur l'écran
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Coins arrondis à 24px
      child: Padding(
        padding: const EdgeInsets.all(24), // Marge intérieure de 24px sur tous les côtés
        child: Column(
          mainAxisSize: MainAxisSize.min, // La colonne prend la hauteur minimale nécessaire
          children: [

            // ----------------------------------------------------------------
            // EN-TÊTE : icône QR + titre + nom du service + bouton fermer
            // ----------------------------------------------------------------
            Row(
              children: [
                // Icône QR code en grand
                const Icon(Icons.qr_code_2_rounded, color: AppColors.navy, size: 28),
                const SizedBox(width: 10), // Espacement de 10px

                // Colonne contenant le titre et le nom du service
                Expanded( // Prend tout l'espace disponible entre l'icône et le bouton fermer
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre fixe du dialog
                      const Text(
                        'QR Code du service',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w700, // Gras
                        ),
                      ),
                      // Sous-titre : nom du service (pour savoir quel QR on regarde)
                      Text(
                        service.name,
                        style: const TextStyle(
                          color: Color(0xFF687B86), // Gris-bleu discret
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bouton fermer (croix) en haut à droite
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF8797A0)),
                  onPressed: () => Navigator.of(context).pop(), // Ferme le dialog
                ),
              ],
            ),

            const SizedBox(height: 20), // Espacement de 20px entre l'en-tête et le QR code

            // ----------------------------------------------------------------
            // QR CODE
            // Container blanc obligatoire : les scanners ont besoin d'un fond blanc
            // ----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(16), // Marge blanche autour du QR code (zone calme)
              decoration: BoxDecoration(
                color: Colors.white,              // Fond blanc impératif pour la lisibilité du QR
                borderRadius: BorderRadius.circular(16), // Coins arrondis du cadre
                border: Border.all(color: const Color(0xFFE5ECEF)), // Bordure grise légère
              ),

              // QrImageView : widget du package qr_flutter qui génère le QR code
              child: QrImageView(
                data: qrData,              // Données texte à encoder dans le QR code
                version: QrVersions.auto,  // Choisit automatiquement la version du QR (taille des données)
                size: 220,                 // Dimensions du QR code : 220×220 pixels logiques
                backgroundColor: Colors.white, // Fond blanc du QR code lui-même

                // Style des modules (les petits carrés noirs qui forment le QR)
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square, // Carrés (pas ronds)
                  color: AppColors.navy,  // Couleur des modules : bleu foncé du projet
                ),

                // Style des "yeux" (les trois grands carrés dans les coins du QR)
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square, // Forme carrée pour les yeux
                  color: AppColors.blue,       // Couleur des yeux : bleu primaire du projet
                ),
              ),
            ),

            const SizedBox(height: 16), // Espacement entre le QR et le message

            // ----------------------------------------------------------------
            // MESSAGE EXPLICATIF
            // ----------------------------------------------------------------
            const Text(
              'Scannez ce QR code pour accéder\naux informations de ce service.',
              textAlign: TextAlign.center, // Centré horizontalement
              style: TextStyle(
                color: Color(0xFF687B86), // Gris-bleu discret
                fontSize: 13,
                height: 1.4,             // Interligne de 1.4× pour la lisibilité
              ),
            ),

            const SizedBox(height: 8), // Petit espacement

            // ----------------------------------------------------------------
            // SECTION DÉPLIABLE : affiche les données brutes encodées
            // Utile pour vérifier ce qui est dans le QR code
            // ----------------------------------------------------------------
            ExpansionTile(
              // Titre du panneau dépliable
              title: const Text(
                'Voir les données encodées',
                style: TextStyle(fontSize: 12, color: Color(0xFF8797A0)), // Petit texte gris
              ),
              tilePadding: EdgeInsets.zero, // Supprime le padding interne du tile

              children: [
                // Container affichant les données texte du QR code
                Container(
                  width: double.infinity, // Prend toute la largeur disponible
                  padding: const EdgeInsets.all(12), // Marge intérieure de 12px

                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F8),  // Fond gris très pâle
                    borderRadius: BorderRadius.circular(10), // Coins arrondis
                  ),

                  child: Text(
                    qrData, // Affiche exactement les données encodées dans le QR

                    style: const TextStyle(
                      fontFamily: 'monospace', // Police à chasse fixe → alignement des colonnes
                      fontSize: 11,           // Très petite pour tenir dans le widget
                      color: Color(0xFF536A77), // Gris-bleu moyen
                      height: 1.6,            // Interligne large pour chaque ligne KEY: valeur
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

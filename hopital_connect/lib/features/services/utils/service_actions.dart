// =============================================================================
// UTILITAIRE : ServiceActions
// Regroupe toutes les actions externes du module services :
// - Ouvrir Google Maps avec l'adresse
// - Appeler le service (téléphone)
// - Envoyer un email au service
// - Partager les informations du service
// Ces actions utilisent url_launcher et share_plus.
// =============================================================================

import 'package:flutter/material.dart';        // Pour BuildContext / SnackBar
import 'package:share_plus/share_plus.dart';   // Partage natif iOS/Android
import 'package:url_launcher/url_launcher.dart'; // Ouverture d'URLs externes

import '../domain/hospital_service.dart';       // Modèle HospitalService

/// Classe statique regroupant toutes les actions externes sur un service.
/// Toutes les méthodes sont statiques — pas besoin d'instancier cette classe.
class ServiceActions {

  // --------------------------------------------------------------------------
  // Google Maps
  // --------------------------------------------------------------------------

  /// Ouvre Google Maps avec l'adresse du service.
  /// Utilise l'adresse complète (location) ou construit depuis bâtiment + étage.
  /// Affiche un SnackBar d'erreur si l'app Maps ne peut pas être ouverte.
  static Future<void> openMaps(
    BuildContext context,
    HospitalService service,
  ) async {
    // Construit le texte de recherche à passer à Maps
    final address = service.location.isNotEmpty
        ? service.location   // Utilise l'emplacement complet si disponible
        : '${service.building} ${service.floor} ${service.name}'.trim();

    // Si l'adresse est vide, on ne peut pas ouvrir Maps
    if (address.isEmpty) {
      _showError(context, 'Aucune adresse renseignée pour ce service.');
      return;
    }

    // Encode l'adresse pour l'URL (espaces → %20, etc.)
    final encoded = Uri.encodeComponent(address);

    // Essaie d'abord l'app Google Maps native (scheme geo:)
    final geoUri = Uri.parse('geo:0,0?q=$encoded');

    // Si geo: ne fonctionne pas (web/desktop), fallback sur maps.google.com
    final webUri = Uri.parse('https://www.google.com/maps/search/?q=$encoded');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);               // Ouvre l'app Maps native
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri,
          mode: LaunchMode.externalApplication); // Ouvre dans le navigateur
    } else {
      if (context.mounted) {
        _showError(context, 'Impossible d\'ouvrir Google Maps.');
      }
    }
  }

  // --------------------------------------------------------------------------
  // Appel téléphonique
  // --------------------------------------------------------------------------

  /// Lance un appel téléphonique vers le numéro du service.
  /// Sur Android/iOS, ouvre le composeur. Sur web, non supporté.
  static Future<void> callService(
    BuildContext context,
    HospitalService service,
  ) async {
    // Vérifie que le numéro de téléphone est renseigné
    if (service.phone.isEmpty) {
      _showError(context, 'Aucun numéro de téléphone renseigné.');
      return;
    }

    // Nettoie le numéro : supprime les espaces et les textes comme "Poste "
    // Ex : "Poste 3301" → "3301"
    final rawNumber = service.phone
        .replaceAll(RegExp(r'[Pp]oste\s*'), '') // Retire "Poste " ou "poste "
        .replaceAll(' ', '')                      // Retire les espaces
        .replaceAll('-', '');                     // Retire les tirets

    // Construit l'URI tel: pour déclencher l'appel
    final telUri = Uri.parse('tel:$rawNumber');

    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri); // Ouvre le composeur téléphonique
    } else {
      if (context.mounted) {
        _showError(context,
            'Impossible de lancer l\'appel. Vérifiez que vous êtes sur mobile.');
      }
    }
  }

  // --------------------------------------------------------------------------
  // Email
  // --------------------------------------------------------------------------

  /// Ouvre le client email avec l'adresse du service pré-remplie.
  /// Le sujet est pré-rempli avec le nom du service.
  static Future<void> emailService(
    BuildContext context,
    HospitalService service,
  ) async {
    // Vérifie que l'email est renseigné
    if (service.email.isEmpty) {
      _showError(context, 'Aucune adresse e-mail renseignée.');
      return;
    }

    // Sujet et corps de l'email pré-remplis
    final subject = Uri.encodeComponent('Contact – ${service.name}');
    final body = Uri.encodeComponent(
        'Bonjour,\n\nJe vous contacte au sujet du service ${service.name}.\n\n');

    // Construit l'URI mailto:
    final mailUri = Uri.parse(
        'mailto:${service.email}?subject=$subject&body=$body');

    if (await canLaunchUrl(mailUri)) {
      await launchUrl(mailUri); // Ouvre le client email
    } else {
      if (context.mounted) {
        _showError(context, 'Impossible d\'ouvrir le client e-mail.');
      }
    }
  }

  // --------------------------------------------------------------------------
  // Partage
  // --------------------------------------------------------------------------

  /// Partage les informations du service via les apps natives (WhatsApp, SMS…).
  static Future<void> shareService(HospitalService service) async {
    // Construit le texte de partage avec toutes les infos disponibles
    final buffer = StringBuffer();
    buffer.writeln('🏥 ${service.name}');                    // Nom
    buffer.writeln('Catégorie : ${service.serviceType.label}'); // Type

    if (service.location.isNotEmpty) {
      buffer.writeln('📍 ${service.location}');              // Localisation
    }
    if (service.headName.isNotEmpty) {
      buffer.writeln('👤 Responsable : ${service.headName}'); // Responsable
    }
    if (service.phone.isNotEmpty) {
      buffer.writeln('📞 ${service.phone}');                 // Téléphone
    }
    if (service.email.isNotEmpty) {
      buffer.writeln('✉️ ${service.email}');                  // Email
    }
    if (service.openingHours.isNotEmpty) {
      buffer.writeln('🕐 ${service.openingHours}');          // Horaires
    }
    if (service.capacity > 0) {
      buffer.writeln('🛏 ${service.capacity} lits');         // Capacité
    }
    if (service.description.isNotEmpty) {
      buffer.writeln('\n${service.description}');            // Description
    }

    // Ouvre la feuille de partage native (share_plus)
    await Share.share(buffer.toString());
  }

  // --------------------------------------------------------------------------
  // Utilitaire privé : affichage des erreurs
  // --------------------------------------------------------------------------

  /// Affiche un SnackBar d'erreur en rouge.
  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return; // Vérifie que le widget est encore monté
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD64045), // Rouge erreur
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

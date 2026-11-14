// =============================================================================
// SERVICE DATA : ServiceService
// Couche d'accès aux données pour les services hospitaliers.
// Communique avec l'API REST backend via ApiClient.
// =============================================================================

import '../../../core/network/api_client.dart'; // Client HTTP + gestion des erreurs
import '../domain/hospital_service.dart';        // Modèle domaine

/// Service de données responsable de toutes les opérations CRUD
/// sur les services hospitaliers via l'API REST.
///
/// Injecter un [ApiClient] personnalisé permet de tester cette classe
/// sans faire de vraies requêtes HTTP (injection de dépendance).
class ServiceService {
  // --------------------------------------------------------------------------
  // Constructeur avec injection de dépendance
  // --------------------------------------------------------------------------

  /// Crée un [ServiceService].
  /// Si [apiClient] est null, un client HTTP par défaut est créé.
  ServiceService({ApiClient? apiClient})
      : _api = apiClient ?? ApiClient(); // Crée un ApiClient si non fourni

  /// Client HTTP utilisé pour toutes les requêtes vers le backend.
  final ApiClient _api;

  // --------------------------------------------------------------------------
  // Lecture
  // --------------------------------------------------------------------------

  /// Récupère la liste complète des services depuis le backend.
  /// Endpoint : GET /services
  /// Retourne une liste vide si le backend renvoie une liste vide.
  Future<List<HospitalService>> list() async {
    // Appel GET /services — retourne un Map JSON
    final response = await _api.get('/services');

    // Extrait le tableau 'services' de la réponse JSON
    final values = response['services'];

    // Vérifie que la valeur est bien une List (pas null, pas un Map)
    if (values is! List) {
      throw const ApiException('Liste des services invalide.');
    }

    // Convertit chaque élément JSON en objet HospitalService
    return values
        .map((item) => HospitalService.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // --------------------------------------------------------------------------
  // Création
  // --------------------------------------------------------------------------

  /// Crée un nouveau service sur le backend.
  /// Endpoint : POST /services
  /// Valide le nom localement avant d'envoyer la requête.
  Future<HospitalService> create(HospitalService service) async {
    // Validation locale : le nom ne peut pas être vide
    if (service.name.trim().isEmpty) {
      throw const ApiException('Le nom du service est obligatoire.');
    }

    // Envoie le service sérialisé en JSON au backend
    final response = await _api.post('/services', body: service.toJson());

    // Extrait l'objet 'service' de la réponse (le backend renvoie { "service": {...} })
    final data = response['service'];

    // Vérifie que la réponse est bien un Map (objet JSON)
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Réponse invalide lors de la création.');
    }

    // Désérialise et retourne le service créé avec son id MongoDB assigné
    return HospitalService.fromJson(data);
  }

  // --------------------------------------------------------------------------
  // Modification
  // --------------------------------------------------------------------------

  /// Met à jour un service existant sur le backend.
  /// Endpoint : PUT /services/:id
  /// Valide l'id et le nom localement avant d'envoyer la requête.
  Future<HospitalService> update(HospitalService service) async {
    // Validation locale : l'id doit être présent (non vide)
    if (service.id.isEmpty) {
      throw const ApiException('Identifiant du service manquant.');
    }

    // Validation locale : le nom ne peut pas être vide
    if (service.name.trim().isEmpty) {
      throw const ApiException('Le nom du service est obligatoire.');
    }

    // Envoie la mise à jour avec l'id dans l'URL
    final response = await _api.put(
      '/services/${service.id}', // URL dynamique avec l'id du service
      body: service.toJson(),    // Corps de la requête : champs modifiés
    );

    // Extrait l'objet 'service' mis à jour de la réponse
    final data = response['service'];

    // Vérifie que la réponse est bien un Map
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Réponse invalide lors de la mise à jour.');
    }

    // Désérialise et retourne le service mis à jour
    return HospitalService.fromJson(data);
  }

  // --------------------------------------------------------------------------
  // Activation / désactivation
  // --------------------------------------------------------------------------

  /// Bascule le statut actif/inactif d'un service.
  /// Appelle [update] avec le statut inversé.
  /// Endpoint : PUT /services/:id (avec active = !service.isActive)
  Future<HospitalService> toggleActive(HospitalService service) {
    // Crée une copie du service avec le statut inversé et l'envoie au backend
    return update(service.copyWith(isActive: !service.isActive));
  }
}

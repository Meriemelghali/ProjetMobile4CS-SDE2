// =============================================================================
// REPOSITORY MOCK : MockServiceRepository
// Dépôt en mémoire avec données de démo riches (sans backend, sans réseau).
// Toutes les opérations sont synchrones et persistent en RAM pendant la session.
// Utilise le pattern Singleton pour partager l'état dans toute l'app de démo.
// =============================================================================

import '../domain/hospital_service.dart'; // Modèle enrichi

/// Dépôt de données en mémoire simulant une base MongoDB.
/// Fournit 8 services de démonstration avec tous les nouveaux champs remplis.
class MockServiceRepository {
  // --------------------------------------------------------------------------
  // Singleton
  // --------------------------------------------------------------------------

  /// Instance unique partagée — crée une seule fois à la première utilisation.
  static final MockServiceRepository instance = MockServiceRepository._();

  /// Constructeur privé : empêche l'instanciation directe depuis l'extérieur.
  MockServiceRepository._() {
    // Initialise la liste mutable à partir des données de démo immuables
    _services = List.from(_seed);
  }

  // --------------------------------------------------------------------------
  // Données initiales (seed)
  // --------------------------------------------------------------------------

  /// Services hospitaliers fictifs avec tous les champs renseignés.
  static final List<HospitalService> _seed = [
    HospitalService(
      id:           'mock-001',
      name:         'Cardiologie',
      serviceType:  ServiceType.medecine,
      building:     'Bâtiment A',
      floor:        '3e étage',
      location:     'Bâtiment A – 3e étage',
      description:  'Prise en charge des maladies cardiovasculaires : '
                    'infarctus, insuffisance cardiaque, arythmies, valvulopathies.',
      capacity:     32,
      phone:        'Poste 3301',
      email:        'cardiologie@hopital.fr',
      headName:     'Dr Leila Mansouri',
      openingHours: 'Lun–Ven 08h00–18h00 · Urgences 24h/24',
      notes:        'Unité de soins intensifs cardiologiques disponible.',
      isActive:     true,
    ),
    HospitalService(
      id:           'mock-002',
      name:         'Urgences',
      serviceType:  ServiceType.urgences,
      building:     'Bâtiment Principal',
      floor:        'RDC',
      location:     'Bâtiment Principal – RDC',
      description:  'Accueil et tri des patients en situation d\'urgence. '
                    'Prise en charge immédiate 24h/24, 7j/7.',
      capacity:     20,
      phone:        'Poste 1500',
      email:        'urgences@hopital.fr',
      headName:     'Dr Karim Bensaid',
      openingHours: '24h/24 – 7j/7',
      notes:        'Zone de déchocage accessible uniquement au personnel autorisé.',
      isActive:     true,
    ),
    HospitalService(
      id:           'mock-003',
      name:         'Pédiatrie',
      serviceType:  ServiceType.pediatrie,
      building:     'Bâtiment B',
      floor:        '1er étage',
      location:     'Bâtiment B – 1er étage',
      description:  'Soins médicaux et chirurgicaux pour enfants de 0 à 15 ans. '
                    'Consultation, hospitalisation et suivi de croissance.',
      capacity:     24,
      phone:        'Poste 2100',
      email:        'pediatrie@hopital.fr',
      headName:     'Dr Amira Chérif',
      openingHours: 'Lun–Ven 08h00–19h00 · Sam 09h00–13h00',
      notes:        'Accès restreint aux parents accompagnants uniquement.',
      isActive:     true,
    ),
    HospitalService(
      id:           'mock-004',
      name:         'Neurologie',
      serviceType:  ServiceType.medecine,
      building:     'Bâtiment A',
      floor:        '4e étage',
      location:     'Bâtiment A – 4e étage',
      description:  'Diagnostic et traitement des pathologies du système nerveux : '
                    'AVC, épilepsie, Parkinson, SEP.',
      capacity:     28,
      phone:        'Poste 3450',
      email:        'neurologie@hopital.fr',
      headName:     'Dr Youssef Hamdi',
      openingHours: 'Lun–Ven 08h30–17h30',
      notes:        'IRM dédiée disponible le mardi et jeudi après-midi.',
      isActive:     true,
    ),
    HospitalService(
      id:           'mock-005',
      name:         'Radiologie',
      serviceType:  ServiceType.radiologie,
      building:     'Bâtiment Principal',
      floor:        'Sous-sol',
      location:     'Bâtiment Principal – Sous-sol',
      description:  'Imagerie médicale : radiographies, scanners, IRM et échographies. '
                    'Résultats sous 24–48h.',
      capacity:     8,
      phone:        'Poste 0850',
      email:        'radiologie@hopital.fr',
      headName:     'Dr Nadia Boukhari',
      openingHours: 'Lun–Sam 07h00–20h00',
      notes:        'Équipement IRM 3T en maintenance jusqu\'au 20/12.',
      isActive:     false, // Temporairement inactif
    ),
    HospitalService(
      id:           'mock-006',
      name:         'Chirurgie générale',
      serviceType:  ServiceType.chirurgie,
      building:     'Bâtiment C',
      floor:        '2e étage',
      location:     'Bâtiment C – 2e étage',
      description:  'Interventions programmées et urgentes : appendicectomie, '
                    'hernie, vésicule biliaire, côlon.',
      capacity:     36,
      phone:        'Poste 4200',
      email:        'chirurgie.generale@hopital.fr',
      headName:     'Pr Jean-Marc Dubois',
      openingHours: 'Bloc opératoire : Lun–Ven 07h30–19h00',
      notes:        '5 salles d\'opération. Bloc de garde le week-end.',
      isActive:     true,
    ),
    HospitalService(
      id:           'mock-007',
      name:         'Laboratoire',
      serviceType:  ServiceType.laboratoire,
      building:     'Bâtiment Principal',
      floor:        '1er étage',
      location:     'Bâtiment Principal – 1er étage',
      description:  'Analyses biologiques : hématologie, biochimie, microbiologie. '
                    'Résultats urgents disponibles en 1h.',
      capacity:     0,
      phone:        'Poste 1200',
      email:        'laboratoire@hopital.fr',
      headName:     'Dr Soraya Meziane',
      openingHours: 'Lun–Ven 07h00–19h00 · Sam 08h00–12h00',
      notes:        'Prélèvements sans rendez-vous avant 11h.',
      isActive:     true,
    ),
    HospitalService(
      id:           'mock-008',
      name:         'Réanimation',
      serviceType:  ServiceType.reanimation,
      building:     'Bâtiment A',
      floor:        '2e étage',
      location:     'Bâtiment A – 2e étage',
      description:  'Prise en charge des patients en état critique nécessitant '
                    'une surveillance continue et un support vital.',
      capacity:     12,
      phone:        'Poste 3200',
      email:        'reanimation@hopital.fr',
      headName:     'Dr Farid Oukaci',
      openingHours: '24h/24 – 7j/7',
      notes:        'Accès strictement réservé au personnel soignant. Visites sur autorisation.',
      isActive:     true,
    ),
  ];

  // --------------------------------------------------------------------------
  // Stockage en mémoire
  // --------------------------------------------------------------------------

  /// Liste mutable des services — modifiée par create/update/toggleActive.
  late List<HospitalService> _services;

  /// Compteur auto-incrémenté pour générer des ids uniques aux nouveaux services.
  int _nextId = 100;

  // --------------------------------------------------------------------------
  // CRUD en mémoire
  // --------------------------------------------------------------------------

  /// Retourne une copie triée par nom (insensible à la casse).
  List<HospitalService> getAll() {
    return List<HospitalService>.from(_services)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Ajoute un service avec un id généré automatiquement.
  HospitalService create(HospitalService service) {
    // Génère un id unique de la forme 'mock-100', 'mock-101', etc.
    final created = service.copyWith(id: 'mock-${_nextId++}');
    _services.add(created); // Ajoute à la liste en mémoire
    return created;
  }

  /// Met à jour le service dont l'id correspond. Lance une exception si absent.
  HospitalService update(HospitalService updated) {
    final index = _services.indexWhere((s) => s.id == updated.id);
    if (index == -1) throw Exception('Service introuvable : ${updated.id}');
    _services[index] = updated; // Remplace à la même position
    return updated;
  }

  /// Inverse le statut actif/inactif du service.
  HospitalService toggleActive(HospitalService service) {
    return update(service.copyWith(isActive: !service.isActive));
  }

  /// Remet les données à l'état initial (utile pour les tests / reset démo).
  void reset() {
    _services = List.from(_seed);
    _nextId = 100;
  }
}

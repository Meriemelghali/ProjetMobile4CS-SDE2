// =============================================================================
// MODÈLE DOMAINE : HospitalService
// Représente un service hospitalier avec tous ses champs enrichis.
// Fichier purement Dart — aucune dépendance Flutter ni réseau.
// Compatible avec le backend étendu ET avec les anciens documents MongoDB
// (tous les nouveaux champs ont une valeur par défaut).
// =============================================================================

/// Enum des types de services hospitaliers.
/// Permet le filtre par catégorie dans la liste.
enum ServiceType {
  medical('Médical', 'medical'),
  surgical('Chirurgical', 'surgical'),
  emergency('Urgence', 'emergency'),
  intensiveCare('Soins intensifs', 'intensive_care'),
  maternity('Maternité', 'maternity'),
  medicoTechnical('Médico-technique', 'medico_technical'),
  administrative('Administratif', 'administrative'),
  other('Autre', 'other');

  const ServiceType(this.label, this.apiValue);

  final String label;
  final String apiValue;

  /// Accepte également les anciennes catégories déjà stockées dans MongoDB.
  static ServiceType fromString(String value) {
    final normalized = value.trim().toLowerCase();
    for (final type in ServiceType.values) {
      if (type.apiValue == normalized ||
          type.name == normalized ||
          type.label.toLowerCase() == normalized) {
        return type;
      }
    }

    return switch (normalized) {
      'medecine' ||
      'médecine' ||
      'medicine' ||
      'medicale' => ServiceType.medical,
      'chirurgie' || 'surgery' => ServiceType.surgical,
      'urgences' || 'urgence' || 'emergency' => ServiceType.emergency,
      'reanimation' ||
      'réanimation' ||
      'intensivecare' => ServiceType.intensiveCare,
      'gynecologie' || 'gynécologie' || 'obstetrics' => ServiceType.maternity,
      'radiologie' ||
      'laboratoire' ||
      'psychiatrie' ||
      'medico-technique' => ServiceType.medicoTechnical,
      'administratif' => ServiceType.administrative,
      _ => ServiceType.other,
    };
  }
}

/// Modèle immuable représentant un service hospitalier complet.
/// Tous les champs ajoutés sont optionnels avec valeur par défaut
/// pour rester compatibles avec les anciens documents MongoDB.
class HospitalService {
  // --------------------------------------------------------------------------
  // Constructeur
  // --------------------------------------------------------------------------

  /// Crée un [HospitalService] avec tous ses champs.
  /// Seuls [id], [name], [location] et [description] sont requis.
  const HospitalService({
    required this.id, // Identifiant MongoDB ('' si nouveau)
    required this.name, // Nom du service (obligatoire)
    required this.location, // Emplacement complet
    required this.description, // Description des activités
    this.isActive = true, // Actif par défaut
    this.hasAppointments = false,
    this.hasOperations = false,
    this.hasOnCall = false,
    // Nouveaux champs — tous optionnels avec valeur par défaut
    this.serviceType = ServiceType.other, // Type de service
    this.building = '', // Bâtiment
    this.floor = '', // Étage
    this.capacity = 0, // Nombre de lits/places (0 = non renseigné)
    this.phone = '', // Téléphone interne
    this.email = '', // Email du service
    this.headName = '', // Nom du chef de service
    this.headUserId, // Compte utilisateur du chef de service
    this.openingHours = '', // Horaires d'ouverture
    this.notes = '', // Notes internes
  });

  // --------------------------------------------------------------------------
  // Champs existants
  // --------------------------------------------------------------------------

  /// Identifiant unique MongoDB (hex ObjectId). Vide pour un nouveau service.
  final String id;

  /// Nom court du service affiché dans les cartes et listes.
  final String name;

  /// Localisation complète : bâtiment + étage (champ libre).
  final String location;

  /// Description longue : spécialités, activités, équipe, etc.
  final String description;

  /// True = service opérationnel et visible par le personnel.
  final bool isActive;
  final bool hasAppointments;
  final bool hasOperations;
  final bool hasOnCall;

  // --------------------------------------------------------------------------
  // Nouveaux champs
  // --------------------------------------------------------------------------

  /// Catégorie médicale du service (médecine, chirurgie, urgences…).
  final ServiceType serviceType;

  /// Nom du bâtiment hébergeant le service (ex : "Bâtiment A").
  final String building;

  /// Étage dans le bâtiment (ex : "3e étage", "RDC", "Sous-sol").
  final String floor;

  /// Capacité d'accueil en nombre de lits ou de places. 0 = non renseigné.
  final int capacity;

  /// Numéro de téléphone interne du service (poste direct).
  final String phone;

  /// Adresse email du service pour les transmissions et communications.
  final String email;

  /// Nom et prénom du chef ou responsable du service.
  final String headName;

  final String? headUserId;

  /// Horaires d'ouverture au format libre (ex : "Lun–Ven 08h–18h").
  final String openingHours;

  /// Notes opérationnelles internes (non médicales).
  final String notes;

  // --------------------------------------------------------------------------
  // Désérialisation JSON (depuis l'API backend)
  // --------------------------------------------------------------------------

  /// Construit un [HospitalService] depuis un Map JSON reçu du backend.
  /// Les nouveaux champs utilisent ?? '' pour gérer les anciens documents
  /// qui ne les contiennent pas encore.
  factory HospitalService.fromJson(Map<String, dynamic> json) {
    return HospitalService(
      // Priorité '_id' (MongoDB), sinon 'id', converti en String
      id: (json['_id'] ?? json['id']).toString(),

      // Champs existants avec valeurs par défaut sécurisées
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['active'] as bool? ?? true,
      hasAppointments: json['a_rdv'] == true,
      hasOperations: json['a_operations'] == true,
      hasOnCall: json['a_gardes'] == true,

      // Nouveaux champs — ?? pour les anciens documents sans ces champs
      serviceType: ServiceType.fromString(json['serviceType'] as String? ?? ''),
      building: json['building'] as String? ?? '',
      floor: json['floor'] as String? ?? '',
      capacity: (json['capacity'] as num? ?? 0).toInt(),
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      headName: json['headName'] as String? ?? '',
      headUserId: json['headUserId']?.toString(),
      openingHours: json['openingHours'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  // --------------------------------------------------------------------------
  // Sérialisation JSON (vers l'API backend)
  // --------------------------------------------------------------------------

  /// Convertit en Map JSON pour POST/PUT vers le backend.
  /// N'inclut pas 'id' (géré par MongoDB).
  Map<String, Object?> toJson() => {
    'name': name,
    'location': location,
    'description': description,
    'active': isActive,
    'a_rdv': hasAppointments,
    'a_operations': hasOperations,
    'a_gardes': hasOnCall,
    // Nouveaux champs — envoyés au backend étendu
    'serviceType': serviceType.apiValue,
    'building': building,
    'floor': floor,
    'capacity': capacity,
    'phone': phone,
    'email': email,
    'headName': headName,
    'headUserId': headUserId,
    'openingHours': openingHours,
    'notes': notes,
  };

  // --------------------------------------------------------------------------
  // copyWith — pattern immuable
  // --------------------------------------------------------------------------

  /// Retourne une copie avec les champs fournis modifiés.
  HospitalService copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    bool? isActive,
    bool? hasAppointments,
    bool? hasOperations,
    bool? hasOnCall,
    ServiceType? serviceType,
    String? building,
    String? floor,
    int? capacity,
    String? phone,
    String? email,
    String? headName,
    String? headUserId,
    String? openingHours,
    String? notes,
  }) {
    return HospitalService(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      hasAppointments: hasAppointments ?? this.hasAppointments,
      hasOperations: hasOperations ?? this.hasOperations,
      hasOnCall: hasOnCall ?? this.hasOnCall,
      serviceType: serviceType ?? this.serviceType,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      headName: headName ?? this.headName,
      headUserId: headUserId ?? this.headUserId,
      openingHours: openingHours ?? this.openingHours,
      notes: notes ?? this.notes,
    );
  }

  // --------------------------------------------------------------------------
  // Égalité et hashCode
  // --------------------------------------------------------------------------

  /// Deux services sont égaux s'ils ont le même id.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HospitalService &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'HospitalService(id: $id, name: $name, type: ${serviceType.label}, active: $isActive)';
}

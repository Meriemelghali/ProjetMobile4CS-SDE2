class HospitalService {
  const HospitalService({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String location;
  final String description;
  final bool isActive;

  factory HospitalService.fromJson(Map<String, dynamic> json) {
    return HospitalService(
      id: (json['_id'] ?? json['id']).toString(),
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['active'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'location': location,
    'description': description,
    'active': isActive,
  };
}

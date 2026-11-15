import 'staff_role.dart';

class StaffUser {
  const StaffUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    this.roles = const [],
    this.hospitalId,
    this.serviceId,
    this.serviceIds = const [],
    this.specialty = '',
    this.photoUrl = '',
    this.isActive = true,
    this.firstName = '',
    this.lastName = '',
    this.birthDate,
    this.phone = '',
    this.address = '',
    this.emergencyContact = '',
    this.insurance = '',
    this.language = 'fr',
    this.appointmentNotifications = true,
    this.resultNotifications = true,
    this.reminderNotifications = true,
  });

  final String id;
  final String displayName;
  final String email;
  final StaffRole role;
  final List<StaffRole> roles;
  final String? hospitalId;
  final String? serviceId;
  final List<String> serviceIds;
  final String specialty;
  final String photoUrl;
  final bool isActive;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final String phone;
  final String address;
  final String emergencyContact;
  final String insurance;
  final String language;
  final bool appointmentNotifications;
  final bool resultNotifications;
  final bool reminderNotifications;

  List<StaffRole> get assignedRoles => roles.isEmpty ? [role] : roles;

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    final service = json['serviceId'];
    final hospital = json['hospitalId'];
    final serviceValues = json['serviceIds'];
    final preferences = json['notificationPreferences'];
    final notificationPreferences = preferences is Map<String, dynamic>
        ? preferences
        : const <String, dynamic>{};
    final birthDate = json['birthDate'];
    final role = StaffRole.fromApiValue(json['role'] as String? ?? '');
    final rawRoles = json['roles'];
    final roles = rawRoles is List
        ? rawRoles.whereType<String>().map(StaffRole.fromApiValue).toList()
        : <StaffRole>[];
    return StaffUser(
      id: _id(json['_id'] ?? json['id']),
      displayName:
          (json['username'] ?? json['displayName'] ?? json['name'])
              as String? ??
          '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      birthDate: birthDate is String && birthDate.isNotEmpty
          ? DateTime.tryParse(birthDate)
          : null,
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      emergencyContact: json['emergencyContact'] as String? ?? '',
      insurance: json['insurance'] as String? ?? '',
      language: json['language'] as String? ?? 'fr',
      appointmentNotifications:
          notificationPreferences['appointments'] as bool? ?? true,
      resultNotifications: notificationPreferences['results'] as bool? ?? true,
      reminderNotifications:
          notificationPreferences['reminders'] as bool? ?? true,
      role: role,
      roles: roles.isEmpty ? [role] : roles,
      hospitalId: hospital == null
          ? null
          : hospital is Map<String, dynamic>
          ? _id(hospital['_id'] ?? hospital['id'])
          : hospital.toString(),
      serviceId: service == null
          ? null
          : service is Map<String, dynamic>
          ? _id(service['_id'] ?? service['id'])
          : service.toString(),
      serviceIds: serviceValues is List && serviceValues.isNotEmpty
          ? serviceValues
                .map(
                  (value) => value is Map<String, dynamic>
                      ? _id(value['_id'] ?? value['id'])
                      : value.toString(),
                )
                .toList()
          : service == null
          ? const []
          : [
              service is Map<String, dynamic>
                  ? _id(service['_id'] ?? service['id'])
                  : service.toString(),
            ],
      specialty: json['specialty'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      isActive: json['active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() => {
    'username': displayName,
    'email': email,
    'role': role.apiValue,
    'roles': assignedRoles.map((item) => item.apiValue).toList(),
    'hospitalId': hospitalId,
    'serviceId': serviceId,
    'serviceIds': serviceIds,
    'specialty': specialty,
    'photoUrl': photoUrl,
    'active': isActive,
  };

  Map<String, Object?> toProfileJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'birthDate': birthDate == null
        ? null
        : '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
    'phone': phone,
    'address': address,
    'emergencyContact': emergencyContact,
    'insurance': insurance,
    'language': language,
    'notificationPreferences': {
      'appointments': appointmentNotifications,
      'results': resultNotifications,
      'reminders': reminderNotifications,
    },
  };
}

class ServiceColleague {
  const ServiceColleague({
    required this.id,
    required this.name,
    required this.role,
    this.specialty = '',
  });

  final String id;
  final String name;
  final String role;
  final String specialty;

  factory ServiceColleague.fromJson(Map<String, dynamic> json) =>
      ServiceColleague(
        id: _id(json['_id'] ?? json['id']),
        name: json['username'] as String? ?? '',
        role: json['role'] as String? ?? '',
        specialty: json['specialty'] as String? ?? '',
      );
}

String _id(Object? value) {
  if (value is Map<String, dynamic>) return _id(value['_id'] ?? value['id']);
  return value?.toString() ?? '';
}

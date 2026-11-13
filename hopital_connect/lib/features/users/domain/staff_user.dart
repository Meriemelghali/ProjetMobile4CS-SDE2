import 'staff_role.dart';

class StaffUser {
  const StaffUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    this.serviceId,
    this.isActive = true,
  });

  final String id;
  final String displayName;
  final String email;
  final StaffRole role;
  final String? serviceId;
  final bool isActive;

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    final service = json['serviceId'];
    return StaffUser(
      id: _id(json['_id'] ?? json['id']),
      displayName: (json['username'] ?? json['displayName'] ?? json['name'])
              as String? ??
          '',
      email: json['email'] as String? ?? '',
      role: StaffRole.fromApiValue(json['role'] as String? ?? ''),
      serviceId: service == null
          ? null
          : service is Map<String, dynamic>
          ? _id(service['_id'] ?? service['id'])
          : service.toString(),
      isActive: json['active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, Object?> toJson() => {
    'username': displayName,
    'email': email,
    'role': role.apiValue,
    'serviceId': serviceId,
    'active': isActive,
  };
}

String _id(Object? value) {
  if (value is Map<String, dynamic>) return _id(value['_id'] ?? value['id']);
  return value?.toString() ?? '';
}

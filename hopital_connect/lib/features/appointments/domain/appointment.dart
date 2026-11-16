enum AppointmentStatus {
  pending('En attente', 'pending'),
  accepted('Confirmé', 'accepted'),
  inProgress('En cours', 'in_progress'),
  proposed('Créneau proposé', 'proposed'),
  rejected('Refusé', 'rejected'),
  cancelled('Annulé', 'cancelled'),
  completed('Terminé', 'completed');

  const AppointmentStatus(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static AppointmentStatus fromApiValue(String value) => switch (value) {
    'pending' => AppointmentStatus.pending,
    'accepted' => AppointmentStatus.accepted,
    'in_progress' => AppointmentStatus.inProgress,
    'proposed' => AppointmentStatus.proposed,
    'rejected' => AppointmentStatus.rejected,
    'cancelled' => AppointmentStatus.cancelled,
    'completed' => AppointmentStatus.completed,
    _ => AppointmentStatus.pending, // valeur inconnue → pending par défaut
  };
}

class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.serviceName,
    required this.serviceLocation,
    required this.servicePhone,
    required this.serviceEmail,
    this.serviceId = '',
    this.doctorSpecialty = '',
    this.doctorPhotoUrl = '',
    required this.startAt,
    required this.reason,
    required this.status,
    this.rejectionReason = '',
    this.proposedStartAt,
    this.proposalNote = '',
    this.claimedBy,
    this.claimedByName = '',
    this.claimedAt,
    this.createdAt,
    this.isOverdue = false,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String serviceName;
  final String serviceLocation;
  final String servicePhone;
  final String serviceEmail;
  final String serviceId;
  final String doctorSpecialty;
  final String doctorPhotoUrl;
  final DateTime startAt;
  final String reason;
  final AppointmentStatus status;
  final String rejectionReason;
  final DateTime? proposedStartAt;
  final String proposalNote;
  final String? claimedBy;
  final String claimedByName;
  final DateTime? claimedAt;
  final DateTime? createdAt;
  final bool isOverdue;

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['_id'] as String,
    patientId: json['patientId'] as String,
    patientName: json['patientName'] as String? ?? '',
    doctorId: json['doctorId'] as String,
    doctorName: json['doctorName'] as String? ?? '',
    serviceName: json['serviceName'] as String? ?? '',
    serviceLocation: json['serviceLocation'] as String? ?? '',
    servicePhone: json['servicePhone'] as String? ?? '',
    serviceEmail: json['serviceEmail'] as String? ?? '',
    serviceId: json['serviceId'] as String? ?? '',
    doctorSpecialty: json['doctorSpecialty'] as String? ?? '',
    doctorPhotoUrl: json['doctorPhotoUrl'] as String? ?? '',
    startAt: DateTime.parse(json['startAt'] as String).toLocal(),
    reason: json['reason'] as String,
    status: AppointmentStatus.fromApiValue(json['status'] as String),
    rejectionReason: json['rejectionReason'] as String? ?? '',
    proposedStartAt: json['proposedStartAt'] is String
        ? DateTime.parse(json['proposedStartAt'] as String).toLocal()
        : null,
    proposalNote: json['proposalNote'] as String? ?? '',
    claimedBy: json['claimedBy'] as String?,
    claimedByName: json['claimedByName'] as String? ?? '',
    claimedAt: json['claimedAt'] is String
        ? DateTime.parse(json['claimedAt'] as String).toLocal()
        : null,
    createdAt: json['createdAt'] is String
        ? DateTime.parse(json['createdAt'] as String).toLocal()
        : null,
    isOverdue: json['isOverdue'] as bool? ?? false,
  );
}

class AppointmentDoctor {
  const AppointmentDoctor({
    required this.id,
    required this.name,
    this.serviceName = '',
    this.serviceLocation = '',
    this.servicePhone = '',
    this.serviceEmail = '',
    this.serviceId = '',
    this.specialty = '',
    this.photoUrl = '',
  });

  final String id;
  final String name;
  final String serviceName;
  final String serviceLocation;
  final String servicePhone;
  final String serviceEmail;
  final String serviceId;
  final String specialty;
  final String photoUrl;

  factory AppointmentDoctor.fromJson(Map<String, dynamic> json) =>
      AppointmentDoctor(
        id: json['_id'] as String,
        name: json['username'] as String? ?? '',
        serviceName: json['serviceName'] as String? ?? '',
        serviceLocation: json['serviceLocation'] as String? ?? '',
        servicePhone: json['servicePhone'] as String? ?? '',
        serviceEmail: json['serviceEmail'] as String? ?? '',
        serviceId: json['serviceId']?.toString() ?? '',
        specialty: json['specialty'] as String? ?? '',
        photoUrl: json['photoUrl'] as String? ?? '',
      );
}

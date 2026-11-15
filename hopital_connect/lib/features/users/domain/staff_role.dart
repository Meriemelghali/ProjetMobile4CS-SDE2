enum StaffRole {
  administrator('Administrateur', 'admin'),
  doctor('Médecin', 'doctor'),
  nurse('Personnel soignant', 'nurse'),
  secretary('Secrétaire', 'secretary'),
  serviceHead('Responsable de service', 'service_head'),
  operatingRoomManager('Responsable de bloc', 'operating_room_manager'),
  patient('Patient', 'patient');

  const StaffRole(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static StaffRole fromApiValue(String value) => switch (value) {
    'admin' || 'administrator' => StaffRole.administrator,
    'doctor' => StaffRole.doctor,
    'nurse' => StaffRole.nurse,
    'secretary' => StaffRole.secretary,
    'service_head' => StaffRole.serviceHead,
    'operating_room_manager' => StaffRole.operatingRoomManager,
    'patient' => StaffRole.patient,
    _ => throw FormatException('Rôle utilisateur inconnu : $value'),
  };
}

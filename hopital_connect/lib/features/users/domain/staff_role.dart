enum StaffRole {
  administrator('Administrateur', 'admin'),
  doctor('Médecin', 'doctor'),
  nurse('Personnel soignant', 'nurse'),
  secretary('Secrétaire', 'secretary'),
  serviceHead('Chef de service', 'service_head'),
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
    'patient' => StaffRole.patient,
    _ => throw FormatException('Rôle utilisateur inconnu : $value'),
  };
}

enum StaffRole {
  administrator('Administrateur'),
  doctor('Médecin'),
  nurse('Personnel soignant');

  const StaffRole(this.label);
  final String label;
}

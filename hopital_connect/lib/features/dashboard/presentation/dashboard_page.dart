import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../../admin/presentation/admin_tab.dart';
import '../../appointments/data/appointment_service.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/domain/appointment_notification.dart';
import '../../appointments/data/notification_service.dart';
import '../../appointments/presentation/appointments_tab.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_page.dart';
import '../../hospital/data/hospital_resource_service.dart';
import '../../hospital/domain/hospital_resources.dart';
import '../../hospital/presentation/hospital_tab.dart';
import '../../medical_records/presentation/emergency_card_page.dart';
import '../../medical_records/presentation/medical_record_home_card.dart';
import '../../medical_records/presentation/medical_record_page.dart';
import '../../medical_records/presentation/patient_records_tab.dart';
import '../../planning/data/shift_service.dart';
import '../../planning/domain/shift.dart';
import '../../planning/presentation/planning_tab.dart';
import '../../pharmacy/presentation/pharmacy_tab.dart';
import '../../services/data/service_service.dart';
import '../../services/domain/hospital_service.dart';
import '../../services/presentation/service_form_dialog.dart';
import '../../services/presentation/services_tab.dart';
import '../../transmissions/data/handover_service.dart';
import '../../transmissions/domain/handover.dart';
import '../../transmissions/presentation/transmissions_tab.dart';
import '../../users/data/user_service.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';
import '../../users/presentation/user_management_page.dart';
import '../../users/presentation/patient_profile_tab.dart';
import '../../appointments/presentation/patient_home_tab.dart';
import 'doctor_space_tabs.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.session});

  final AppSession session;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _useMockHospitalData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isSwitchingRole = false;
  String? _error;
  late StaffUser _user = widget.session.user;
  List<StaffUser> _users = const [];
  List<HospitalService> _services = const [];
  List<Shift> _shifts = const [];
  List<Handover> _handovers = const [];
  List<Appointment> _appointments = const [];
  List<HospitalIntervention> _interventions = const [];
  List<AppointmentNotification> _notifications = const [];
  List<AppointmentDoctor> _doctors = const [];
  List<ServiceColleague> _colleagues = const [];
  PatientRecordType _followUpType = PatientRecordType.all;
  int _followUpRequest = 0;

  /// Raccourcis de l'accueil patient → onglet du dossier médical.
  static int _recordTabFor(PatientRecordType type) => switch (type) {
    PatientRecordType.consultations => 1,
    PatientRecordType.results => 2,
    PatientRecordType.treatments || PatientRecordType.prescriptions => 3,
    PatientRecordType.all || PatientRecordType.reports => 0,
  };

  List<StaffUser> get _doctorAccounts => _users
      .where(
        (user) =>
            user.isActive &&
            (user.role == StaffRole.doctor ||
                user.assignedRoles.contains(StaffRole.doctor)) &&
            user.specialty.trim().isNotEmpty,
      )
      .toList();

  List<HospitalService> get _managedServices =>
      _user.role == StaffRole.serviceHead
      ? _services
            .where(
              (service) =>
                  service.id == _user.serviceId ||
                  _user.serviceIds.contains(service.id) ||
                  service.headUserId == _user.id,
            )
            .toList()
      : _services;

  Set<String> _serviceIdsFor(StaffUser user) => {
    ...user.serviceIds,
    if (user.serviceId != null) user.serviceId!,
  };

  List<HospitalService> _assignedServicesFor(StaffUser user) {
    final serviceIds = _serviceIdsFor(user);
    return _services
        .where((service) => serviceIds.contains(service.id))
        .toList();
  }

  static const _titles = [
    'Mon espace',
    'Mon planning',
    'Mon service',
    'Transmissions',
    'Ressources hospitalières',
    'Administration',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await AuthService().currentUser();
      if (user.role == StaffRole.patient) {
        final results = await Future.wait([
          AppointmentService().list(),
          ServiceService().list(),
          NotificationService().list(),
        ]);
        if (!mounted) return;
        setState(() {
          _user = user;
          _users = const [];
          _services = results[1] as List<HospitalService>;
          _shifts = const [];
          _handovers = const [];
          _appointments = results[0] as List<Appointment>;
          _interventions = const [];
          _doctors = const [];
          _notifications = results[2] as List<AppointmentNotification>;
          _colleagues = const [];
        });
        return;
      }
      if (user.role == StaffRole.secretary) {
        final results = await Future.wait([
          AppointmentService().list(),
          AppointmentService().listDoctors(),
          ServiceService().list(),
          UserService().listInterventionParticipants(),
        ]);
        if (!mounted) return;
        setState(() {
          _user = user;
          _users = results[3] as List<StaffUser>;
          _services = results[2] as List<HospitalService>;
          _shifts = const [];
          _handovers = const [];
          _appointments = results[0] as List<Appointment>;
          _interventions = const [];
          _doctors = results[1] as List<AppointmentDoctor>;
          _colleagues = const [];
        });
        return;
      }
      if (user.role == StaffRole.pharmacist) {
        if (!mounted) return;
        setState(() {
          _user = user;
          _users = const [];
          _services = const [];
          _shifts = const [];
          _handovers = const [];
          _appointments = const [];
          _interventions = const [];
          _doctors = const [];
          _colleagues = const [];
          _notifications = const [];
        });
        return;
      }
      final isAdmin = user.role == StaffRole.administrator;
      final isDoctor = user.role == StaffRole.doctor;
      final services = await ServiceService().list();
      final doctorServiceIds = _serviceIdsFor(user);
      final doctorServices = isDoctor
          ? services
                .where((service) => doctorServiceIds.contains(service.id))
                .toList()
          : const <HospitalService>[];
      final doctorHasOperations = doctorServices.any(
        (service) => service.hasOperations,
      );
      final isOperatingRoomManager =
          user.role == StaffRole.operatingRoomManager;
      final isServiceHead = user.role == StaffRole.serviceHead;
      final shifts = isOperatingRoomManager
          ? <Shift>[]
          // Admin et chef de service : pas de filtre userId (le backend filtre par service pour service_head)
          : await ShiftService().list(userId: (isAdmin || isServiceHead) ? null : user.id);
      String? serviceHeadServiceId;
      if (user.role == StaffRole.serviceHead) {
        for (final service in services) {
          if (service.headUserId == user.id) {
            serviceHeadServiceId = service.id;
            break;
          }
        }
      }
      final handoverServiceId = isAdmin
          ? null
          : user.serviceId ?? serviceHeadServiceId;
      final handovers = isOperatingRoomManager
          ? <Handover>[]
          : (user.role == StaffRole.serviceHead ||
                    user.role == StaffRole.secretary) &&
                handoverServiceId == null
          ? <Handover>[]
          : await HandoverService().list(
              serviceId: isDoctor ? null : handoverServiceId,
            );
      final users = isAdmin
          ? await UserService().list()
          : isDoctor || user.role == StaffRole.secretary
          ? await UserService().listInterventionParticipants()
          : isServiceHead
          // Le chef de service a besoin de la liste des médecins (pour ajouter des gardes)
          // et des patients assignables.
          ? await UserService().list()
          : user.role == StaffRole.nurse
          ? await UserService().listAssignablePatients()
          : const <StaffUser>[];
      final appointments = isAdmin || isDoctor
          ? await AppointmentService().list()
          : const <Appointment>[];
      final interventions = isDoctor && doctorHasOperations
          ? await HospitalResourceService().interventions()
          : <HospitalIntervention>[];
      final colleagueLists = isDoctor
          ? await Future.wait(
              doctorServiceIds.map(
                (serviceId) => UserService().listServiceMembers(serviceId),
              ),
            )
          : const <List<ServiceColleague>>[];
      final colleagues = {
        for (final colleague in colleagueLists.expand((items) => items))
          colleague.id: colleague,
      }.values.toList();
      final doctors = isAdmin
          ? await AppointmentService().listDoctors()
          : const <AppointmentDoctor>[];
      if (!mounted) return;
      setState(() {
        _user = user;
        _services = services;
        _shifts = shifts;
        _handovers = handovers;
        _users = users;
        _appointments = appointments;
        _interventions = interventions;
        _doctors = doctors;
        _colleagues = colleagues;
        _notifications = const [];
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _signOut(confirm: false);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut({bool confirm = true}) async {
    if (confirm) {
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text('Voulez-vous vraiment vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Déconnexion'),
            ),
          ],
        ),
      );
      if (shouldSignOut != true) return;
    }
    await SessionManager.instance.clear();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _showRoleSwitcher() async {
    if (_user.assignedRoles.length < 2 || _isSwitchingRole) return;
    final selectedRole = await showModalBottomSheet<StaffRole>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Continuer en tant que…',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final role in _user.assignedRoles)
              ListTile(
                leading: Icon(
                  role == _user.role
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: AppColors.blue,
                ),
                title: Text(role.label),
                trailing: role == _user.role ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, role),
              ),
          ],
        ),
      ),
    );
    if (selectedRole != null && selectedRole != _user.role) {
      await _switchRole(selectedRole);
    }
  }

  Future<void> _switchRole(StaffRole role) async {
    setState(() => _isSwitchingRole = true);
    try {
      final session = await AuthService().switchRole(role);
      if (!mounted) return;
      setState(() => _isSwitchingRole = false);
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => DashboardPage(session: session),
        ),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSwitchingRole = false);
      if (error.statusCode == 401) {
        await _signOut(confirm: false);
      } else {
        _showError(error);
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is ApiException
        ? error.message
        : 'Une erreur inattendue est survenue.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addHandover() async {
    final availableServices = _user.role == StaffRole.administrator
        ? _services
        : _user.role == StaffRole.serviceHead
        ? _managedServices
        : _services
              .where((service) => _serviceIdsFor(_user).contains(service.id))
              .toList();
    if (availableServices.isEmpty) {
      _showError(
        ApiException(
          _user.role == StaffRole.serviceHead
              ? 'Aucun service ne vous est attribué.'
              : 'Ajoutez d’abord un service.',
        ),
      );
      return;
    }
    final draft = await showDialog<Handover>(
      context: context,
      builder: (_) => NewHandoverDialog(services: availableServices),
    );
    if (draft == null || !mounted) return;
    try {
      await HandoverService().create(draft);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _addShift() async {
    final isServiceHead = _user.role == StaffRole.serviceHead;
    // Pour le chef de service : filtrer les services et médecins à ceux de son service uniquement.
    final availableServices = isServiceHead ? _managedServices : _services;
    final managedServiceIds = availableServices.map((s) => s.id).toSet();
    final availableDoctors = isServiceHead
        ? _doctorAccounts
              .where(
                (doctor) =>
                    _serviceIdsFor(doctor)
                        .any((id) => managedServiceIds.contains(id)) ||
                    managedServiceIds.contains(doctor.serviceId),
              )
              .toList()
        : _doctorAccounts;
    if (availableServices.isEmpty || availableDoctors.isEmpty) {
      _showError(
        ApiException(
          isServiceHead
              ? "Aucun médecin actif avec une spécialité n'est rattaché à votre service."
              : "Ajoutez un service et un compte médecin actif avec une spécialité avant d'ajouter une garde.",
        ),
      );
      return;
    }
    final draft = await showDialog<Shift>(
      context: context,
      builder: (_) =>
          NewShiftDialog(services: availableServices, users: availableDoctors),
    );
    if (draft == null || !mounted) return;
    try {
      await ShiftService().create(draft);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }
  Future<void> _editShift(Shift shift) async {
    final isServiceHead = _user.role == StaffRole.serviceHead;
    final availableServices = isServiceHead ? _managedServices : _services;
    final managedServiceIds = availableServices.map((s) => s.id).toSet();
    final doctors = isServiceHead
        ? _doctorAccounts
              .where(
                (doctor) =>
                    _serviceIdsFor(doctor)
                        .any((id) => managedServiceIds.contains(id)) ||
                    managedServiceIds.contains(doctor.serviceId),
              )
              .toList()
        : _doctorAccounts;
    if (availableServices.isEmpty || doctors.isEmpty) {
      _showError(
        const ApiException(
          'Les services et les comptes médecin doivent être disponibles pour modifier une garde.',
        ),
      );
      return;
    }
    if (!doctors.any((user) => user.id == shift.userId)) {
      _showError(
        const ApiException(
          'Cette garde n’est pas liée à un médecin actif avec une spécialité.',
        ),
      );
      return;
    }
    final edited = await showDialog<Shift>(
      context: context,
      builder: (_) =>
          NewShiftDialog(services: availableServices, users: doctors, shift: shift),
    );
    if (edited == null || !mounted) return;
    try {
      await ShiftService().update(edited);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }
  Future<void> _deleteShift(Shift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la garde ?'),
        content: const Text('Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ShiftService().delete(shift.id);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _addService() async {
    List<HospitalRoom> rooms = const [];
    try {
      rooms = await HospitalResourceService().rooms();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error);
    }
    if (!mounted) return;
    final draft = await showDialog<HospitalService>(
      context: context,
      builder: (_) => ServiceFormDialog(users: _users, rooms: rooms),
    );
    if (draft == null || !mounted) return;
    try {
      await ServiceService().create(draft);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _editService(HospitalService service) async {
    List<HospitalRoom> serviceRooms = const [];
    List<HospitalBed> serviceBeds = const [];
    try {
      final resources = HospitalResourceService();
      final rooms = await resources.rooms();
      final serviceRoomIds = rooms
          .where((room) => room.serviceId == service.id)
          .map((room) => room.id)
          .toSet();
      serviceRooms = rooms
          .where((room) => room.serviceId == service.id)
          .toList();
      serviceBeds = (await resources.beds())
          .where((bed) => serviceRoomIds.contains(bed.roomId))
          .toList();
    } on ApiException catch (error) {
      _showError(error);
      return;
    }
    final edited = await showDialog<HospitalService>(
      context: context,
      builder: (_) => ServiceFormDialog(
        service: service,
        users: _users,
        rooms: serviceRooms,
        beds: serviceBeds,
        canManageAssignments: _user.role == StaffRole.administrator,
        canManageStatus: _user.role == StaffRole.administrator,
      ),
    );
    if (edited == null || !mounted) return;
    try {
      await ServiceService().update(
        edited,
        asServiceHead: _user.role == StaffRole.serviceHead,
      );
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleServiceActive(HospitalService service) async {
    try {
      await ServiceService().toggleActive(service);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteService(HospitalService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce service ?'),
        content: Text(
          'Le service « ${service.name} » sera supprimé définitivement. '
          'La suppression sera refusée s’il est encore utilisé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ServiceService().delete(service.id);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _createAppointment() async {
    final draft = await showDialog<AppointmentDraft>(
      context: context,
      builder: (_) => AppointmentFormDialog(
        isArabic: _user.language == 'ar' && _user.role == StaffRole.patient,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await AppointmentService().create(
        doctorId: draft.doctorId,
        startAt: draft.startAt,
        reason: draft.reason,
      );
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _editAppointment(Appointment appointment) async {
    final draft = await showDialog<AppointmentDraft>(
      context: context,
      builder: (_) => AppointmentFormDialog(
        appointment: appointment,
        isArabic: _user.language == 'ar' && _user.role == StaffRole.patient,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await AppointmentService().update(
        appointment,
        doctorId: draft.doctorId,
        startAt: draft.startAt,
        reason: draft.reason,
      );
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _updateAppointmentStatus(
    Appointment appointment,
    AppointmentStatus status,
  ) async {
    try {
      await AppointmentService().update(appointment, status: status);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _claimAppointment(Appointment appointment) async {
    try {
      await AppointmentService().claim(appointment);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _releaseAppointment(Appointment appointment) async {
    try {
      await AppointmentService().release(appointment);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _decideAppointment(
    Appointment appointment,
    String action,
    String? reason,
    DateTime? proposedStartAt,
  ) async {
    try {
      await AppointmentService().decide(
        appointment,
        action: action,
        reason: reason,
        proposedStartAt: proposedStartAt,
      );
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _respondToProposal(Appointment appointment, bool accept) async {
    try {
      await AppointmentService().respondToProposal(appointment, accept: accept);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _markNotificationsRead() async {
    try {
      await NotificationService().markAllRead();
      final notifications = await NotificationService().list();
      if (mounted) setState(() => _notifications = notifications);
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _updatePatientProfile(Map<String, Object?> updates) async {
    final user = await AuthService().updateProfile(updates);
    if (mounted) setState(() => _user = user);
  }

  Future<void> _confirmCancelAppointment(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le rendez-vous ?'),
        content: const Text('Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Garder le rendez-vous'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler le rendez-vous'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateAppointmentStatus(appointment, AppointmentStatus.cancelled);
    }
  }

  Future<void> _showPatientAppointmentDetails(
    Appointment appointment,
  ) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Détails du rendez-vous'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_appointmentDateTime(appointment.startAt)),
          Text('Médecin : ${appointment.doctorName}'),
          Text(
            'Service : ${appointment.serviceName.isEmpty ? 'Non renseigné' : appointment.serviceName}',
          ),
          Text(
            'Lieu : ${appointment.serviceLocation.isEmpty ? 'Non renseigné' : appointment.serviceLocation}',
          ),
          Text('Statut : ${appointment.status.label}'),
          Text('Motif : ${appointment.reason}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );

  Future<void> _openDirections(Appointment? appointment) async {
    final location = appointment?.serviceLocation ?? '';
    if (location.isEmpty) {
      _showError(
        const ApiException(
          'Aucune adresse n’est renseignée pour ce rendez-vous.',
        ),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _showError(const ApiException('Impossible d’ouvrir l’itinéraire.'));
    }
  }

  Future<void> _contactHospital(Appointment? appointment) async {
    final servicePhone = appointment?.servicePhone.isNotEmpty == true
        ? appointment!.servicePhone
        : _doctors.firstOrNull?.servicePhone ?? '';
    final serviceEmail = appointment?.serviceEmail.isNotEmpty == true
        ? appointment!.serviceEmail
        : _doctors.firstOrNull?.serviceEmail ?? '';
    final phone = servicePhone;
    final email = serviceEmail;
    final uri = phone.isNotEmpty
        ? Uri.parse('tel:${phone.replaceAll(RegExp(r'\s+'), '')}')
        : email.isNotEmpty
        ? Uri.parse('mailto:$email')
        : null;
    if (uri == null) {
      _showError(
        const ApiException(
          'Les coordonnées de l’hôpital ne sont pas renseignées.',
        ),
      );
      return;
    }
    if (!await launchUrl(uri) && mounted) {
      _showError(
        const ApiException('Impossible d’ouvrir l’application de contact.'),
      );
    }
  }

  Future<void> _manageUsers() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UserManagementPage(service: UserService()),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _handleValidateUser(StaffUser user) async {
    try {
      final updatedUser = StaffUser(
        id: user.id,
        displayName: user.displayName,
        email: user.email,
        role: user.role,
        roles: user.assignedRoles,
        hospitalId: user.hospitalId,
        pharmacyId: user.pharmacyId,
        serviceId: user.serviceId,
        serviceIds: user.serviceIds,
        specialty: user.specialty,
        photoUrl: user.photoUrl,
        isActive: true,
      );
      await UserService().update(updatedUser);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Compte de ${user.displayName.isNotEmpty ? user.displayName : user.email} validé avec succès.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la validation : $e')),
        );
      }
    }
  }

  Future<void> _handleRejectUser(StaffUser user) async {
    try {
      final updatedUser = StaffUser(
        id: user.id,
        displayName: user.displayName,
        email: user.email,
        role: user.role,
        roles: user.assignedRoles,
        hospitalId: user.hospitalId,
        pharmacyId: user.pharmacyId,
        serviceId: user.serviceId,
        serviceIds: user.serviceIds,
        specialty: user.specialty,
        photoUrl: user.photoUrl,
        isActive: false,
      );
      await UserService().update(updatedUser);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte refusé / désactivé.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _showShiftDetails(Shift shift) async {
    final isAdmin = _user.role == StaffRole.administrator;
    final isServiceHead = _user.role == StaffRole.serviceHead;
    // Le chef de service peut modifier/supprimer les gardes de son service.
    final canManage = isAdmin ||
        (isServiceHead &&
            _managedServices.any((s) => s.id == shift.serviceId));
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détail de la garde'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${shift.day} \u00b7 ${shift.time}'),
            const SizedBox(height: 8),
            Text(
              'Service : ${shift.serviceName.isEmpty ? 'Non renseigné' : shift.serviceName}',
            ),
            Text('Fonction : ${shift.role}'),
            Text(
              'Personnel : ${shift.userName.isEmpty ? _nameFor(shift.userId) : shift.userName}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          if (canManage) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'edit'),
              child: const Text('Modifier'),
            ),
          ],
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _editShift(shift);
    if (action == 'delete') await _deleteShift(shift);
  }

  Future<void> _showHandoverDetails(Handover handover) async {
    if (_user.role != StaffRole.administrator && !handover.isRead) {
      try {
        await HandoverService().markRead(handover.id);
        if (!mounted) return;
        setState(() {
          _handovers = _handovers
              .map(
                (item) =>
                    item.id == handover.id ? item.copyWith(isRead: true) : item,
              )
              .toList();
        });
      } on ApiException catch (error) {
        _showError(error);
        return;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(handover.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(handover.message),
            const SizedBox(height: 12),
            Text('${handover.author} · ${handover.time}'),
            if (handover.important) const Text('Important'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _nameFor(String userId) {
    for (final user in _users) {
      if (user.id == userId) return user.displayName;
    }
    return 'Non renseigné';
  }

  Future<void> _showMoreDestinations(
    List<NavigationDestination> destinations,
  ) async {
    final selectedPage = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var index = 4; index < destinations.length; index++)
              ListTile(
                leading: destinations[index].icon,
                title: Text(destinations[index].label),
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      ),
    );
    if (selectedPage != null && mounted) {
      setState(() => _selectedIndex = selectedPage);
    }
  }

  Widget? _buildFloatingActionButton(bool isPatient, bool isAdmin) {
    final isServiceHead = _user.role == StaffRole.serviceHead;
    // Admin : Planning est en index 4 ; chef de service : Planning est en index 1.
    final showAddShift = !isPatient &&
        ((isAdmin && _selectedIndex == 4) ||
         (isServiceHead && _selectedIndex == 1));
    if (showAddShift) {
      return FloatingActionButton.extended(
        onPressed: _addShift,
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une garde'),
      );
    }
    // Note de transmission (Transmissions = index 3 pour doctor/nurse, absent pour admin)
    final showAddHandover = !isPatient &&
        _user.role != StaffRole.secretary &&
        !isAdmin &&
        !isServiceHead &&
        _selectedIndex == 3;
    if (showAddHandover) {
      return FloatingActionButton.extended(
        onPressed: _addHandover,
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle note'),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPatient = _user.role == StaffRole.patient;
    final isSecretary = _user.role == StaffRole.secretary;
    final isPharmacist = _user.role == StaffRole.pharmacist;
    final isAdmin = _user.role == StaffRole.administrator;
    final isDoctor = _user.role == StaffRole.doctor;
    final isNurse = _user.role == StaffRole.nurse;
    // Dossier médical : onglet ajouté en dernière position pour ne pas
    // décaler les index des onglets existants.
    final medicalRecordsIndex = isDoctor ? 6 : (isAdmin ? 6 : (isNurse ? 4 : -1));
    final medicalRecordsTab = PatientRecordsTab(
      viewerRole: _user.role,
      viewerId: _user.id,
      viewerName: _user.lastName.isNotEmpty
          ? _user.lastName
          : _user.displayName,
    );
    final doctorServices = isDoctor
        ? _assignedServicesFor(_user)
        : const <HospitalService>[];
    final doctorHasService = doctorServices.isNotEmpty;
    final doctorHasOperations = doctorServices.any(
      (service) => service.hasOperations,
    );
    final operationServiceIds = doctorServices
        .where((service) => service.hasOperations)
        .map((service) => service.id)
        .toSet();
    final pendingAppointments = _appointments
        .where((appointment) => appointment.status == AppointmentStatus.pending)
        .length;
    final overdueAppointments = _appointments
        .where((appointment) => appointment.isOverdue)
        .length;
    final nextShift =
        _shifts.where((shift) => shift.end.isAfter(DateTime.now())).toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    final pages = isPatient
        ? <Widget>[
            PatientHomeTab(
              user: _user,
              appointments: _appointments,
              onBookAppointment: _createAppointment,
              onOpenAppointments: () => setState(() => _selectedIndex = 2),
              onOpenFollowUps: (type) => setState(() {
                _followUpType = type;
                _followUpRequest++;
                _selectedIndex = 1;
              }),
              onOpenProfile: () => setState(() => _selectedIndex = 3),
              onShowAppointmentDetails: _showPatientAppointmentDetails,
              onEditAppointment: _editAppointment,
              onCancelAppointment: _confirmCancelAppointment,
              onOpenDirections: _openDirections,
              onContactHospital: _contactHospital,
              onEmergency: () => openMyEmergencyCard(context),
              notifications: _notifications,
              onMarkNotificationsRead: _markNotificationsRead,
              onRespondToProposal: _respondToProposal,
              medicalRecordCard: MedicalRecordHomeCard(
                patientId: _user.id,
                isArabic: _user.language == 'ar',
                onOpen: () => setState(() {
                  _followUpType = PatientRecordType.all;
                  _followUpRequest++;
                  _selectedIndex = 1;
                }),
              ),
            ),
            // Onglet « Mon dossier » : module dossier médical (remplace
            // l'ancien écran « Mes suivis » qui n'affichait que des
            // emplacements vides).
            MedicalRecordPage(
              embedded: true,
              viewerRole: StaffRole.patient,
              viewerId: _user.id,
              initialTab: _recordTabFor(_followUpType),
              tabRequest: _followUpRequest,
            ),
            AppointmentsTab(
              appointments: _appointments,
              isPatient: true,
              isArabic: _user.language == 'ar',
              onEdit: _editAppointment,
              onStatusChange: _updateAppointmentStatus,
              onRespondProposal: _respondToProposal,
            ),
            PatientProfileTab(
              user: _user,
              onSave: _updatePatientProfile,
              onSignOut: () => _signOut(),
              onSwitchRole: _showRoleSwitcher,
            ),
          ]
        : isPharmacist
        ? <Widget>[
            PharmacyTab(user: _user),
            PatientProfileTab(
              user: _user,
              onSave: _updatePatientProfile,
              onSignOut: () => _signOut(),
              onSwitchRole: _showRoleSwitcher,
            ),
          ]
        : isDoctor
        ? <Widget>[
            DoctorHomeTab(
              user: _user,
              services: _services,
              appointments: _appointments,
              interventions: _interventions,
              shifts: _shifts,
              handovers: _handovers,
              onOpenPlanning: () => setState(() => _selectedIndex = 1),
              onHandoverTap: _showHandoverDetails,
            ),
            DoctorPlanningTab(
              appointments: _appointments,
              interventions: _interventions,
              shifts: _shifts,
              hasService: doctorHasService,
              hasOperations: doctorHasOperations,
              operationServiceIds: operationServiceIds,
            ),
            DoctorServiceTab(
              user: _user,
              services: _services,
              colleagues: _colleagues,
            ),
            HandoversTab(
              handovers: _handovers,
              onHandoverTap: _showHandoverDetails,
            ),
            PatientProfileTab(
              user: _user,
              onSave: _updatePatientProfile,
              onSignOut: () => _signOut(),
              isDoctorProfile: true,
              doctorServices: doctorServices,
              onSwitchRole: _showRoleSwitcher,
            ),
            HospitalTab(
              canManage: false,
              user: _user,
              isVisible: _selectedIndex == 5,
              hospitalsApi: HospitalResourceService(),
              services: _services,
              users: _users,
              useMockData: _useMockHospitalData,
            ),
            medicalRecordsTab,
          ]
        : isSecretary
        ? <Widget>[
            SecretaryHomeTab(
              userName: _user.displayName.isEmpty
                  ? _user.email
                  : _user.displayName,
              pendingCount: pendingAppointments,
              overdueCount: overdueAppointments,
              onOpenAppointments: () => setState(() => _selectedIndex = 1),
            ),
            AppointmentsTab(
              appointments: _appointments,
              isPatient: false,
              onEdit: _editAppointment,
              onStatusChange: _updateAppointmentStatus,
              onClaim: _claimAppointment,
              onRelease: _releaseAppointment,
              onDecision: _decideAppointment,
              currentUserId: _user.id,
            ),
            HospitalTab(
              canManage: false,
              isVisible: _selectedIndex == 2,
              hospitalsApi: HospitalResourceService(),
              services: _services,
              users: const [],
              user: _user,
              useMockData: _useMockHospitalData,
            ),
          ]
        : isAdmin
        ? <Widget>[
            HomeTab(
              user: _user,
              services: _services,
              nextShift: nextShift.isEmpty ? null : nextShift.first,
              shifts: _shifts,
              latestHandover: null,
              handovers: const [],
              onHandoverTap: _showHandoverDetails,
              users: _users,
              appointments: _appointments,
              onNavigateToTab: (index) =>
                  setState(() => _selectedIndex = index),
              onRefresh: _load,
              onValidateUser: _handleValidateUser,
              onRejectUser: _handleRejectUser,
            ),
            HospitalTab(
              canManage: true,
              isVisible: _selectedIndex == 1,
              hospitalsApi: HospitalResourceService(),
              services: _services,
              users: _users,
              user: _user,
              useMockData: _useMockHospitalData,
            ),
            AppointmentsTab(
              appointments: _appointments,
              services: _services,
              isPatient: false,
              onEdit: _editAppointment,
              onStatusChange: _updateAppointmentStatus,
              onClaim: _claimAppointment,
              onRelease: _releaseAppointment,
              onDecision: _decideAppointment,
              currentUserId: _user.id,
              isAdmin: true,
            ),
            AdminTab(
              usersCount: _users.length,
              shiftsCount: _shifts.length,
              servicesCount: _services.length,
              onManageUsers: _manageUsers,
              onAddShift: _addShift,
              onAddService: _addService,
            ),
            ScheduleTab(shifts: _shifts, onShiftTap: _showShiftDetails),
            ServiceTab(
              services: _services,
              canEdit: true,
              canEditDetails: false,
              onEdit: _editService,
              onDelete: _deleteService,
              onToggleActive: _toggleServiceActive,
              onAdd: _addService,
            ),
            medicalRecordsTab,
          ]
        : <Widget>[
            HomeTab(
              user: _user,
              services: _services,
              nextShift: nextShift.isEmpty ? null : nextShift.first,
              shifts: _shifts,
              latestHandover: null,
              handovers: const [],
              onHandoverTap: _showHandoverDetails,
              users: _users,
              appointments: _appointments,
              onNavigateToTab: (index) =>
                  setState(() => _selectedIndex = index),
              onRefresh: _load,
              onValidateUser: _handleValidateUser,
              onRejectUser: _handleRejectUser,
            ),
            ScheduleTab(shifts: _shifts, onShiftTap: _showShiftDetails),
            ServiceTab(
              services: _services,
              canEdit: false,
              canEditDetails: _user.role == StaffRole.serviceHead,
              onEdit: _editService,
              onDelete: _deleteService,
              onToggleActive: _toggleServiceActive,
              onAdd: _addService,
            ),
            HospitalTab(
              canManage: false,
              isVisible: _selectedIndex == 3,
              hospitalsApi: HospitalResourceService(),
              services: _services,
              users: _users,
              user: _user,
              useMockData: _useMockHospitalData,
            ),
            if (isNurse) medicalRecordsTab,
          ];
    final isArabic = isPatient && _user.language == 'ar';
    final destinations = isPatient
        ? isArabic
              ? const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'الرئيسية',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_shared_outlined),
                    selectedIcon: Icon(Icons.folder_shared),
                    label: 'سجلي الطبي',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'مواعيدي',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'ملفي',
                  ),
                ]
              : const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Accueil',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_shared_outlined),
                    selectedIcon: Icon(Icons.folder_shared),
                    label: 'Mon dossier',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Mes RDV',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Mon profil',
                  ),
                ]
        : isSecretary
        ? const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available),
              label: 'Rendez-vous',
            ),
            NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment),
              label: 'Hôpital',
            ),
          ]
        : isPharmacist
        ? const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication),
              label: 'Pharmacie',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ]
        : isAdmin
        ? const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment),
              label: 'Hôpital',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available),
              label: 'Rendez-vous',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Planning',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_hospital_outlined),
              selectedIcon: Icon(Icons.local_hospital_rounded),
              label: 'Service',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_shared_outlined),
              selectedIcon: Icon(Icons.folder_shared),
              label: 'Dossiers',
            ),
          ]
        : <NavigationDestination>[
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Accueil',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Planning',
            ),
            const NavigationDestination(
              icon: Icon(Icons.local_hospital_outlined),
              selectedIcon: Icon(Icons.local_hospital_rounded),
              label: 'Service',
            ),
            if (isDoctor)
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            const NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment),
              label: 'Hôpital',
            ),
            if (isDoctor || isNurse)
              const NavigationDestination(
                icon: Icon(Icons.folder_shared_outlined),
                selectedIcon: Icon(Icons.folder_shared),
                label: 'Dossiers',
              ),
          ];

    final hasMoreDestinations = destinations.length > 5;
    final visibleDestinations = hasMoreDestinations
        ? <NavigationDestination>[
            ...destinations.take(4),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Plus',
            ),
          ]
        : destinations;
    final visibleSelectedIndex = hasMoreDestinations && _selectedIndex >= 4
        ? 4
        : _selectedIndex;
    final titles = isPatient
        ? isArabic
              ? const ['مساحة المريض', 'سجلي الطبي', 'مواعيدي', 'ملفي']
              : const ['Accueil', 'Mon dossier médical', 'Mes RDV', 'Profil']
        : isPharmacist
        ? const ['Gestion Pharmacie', 'Profil']
        : isDoctor
        ? const [
            'Accueil',
            'Planning',
            'Service',
            'Transmissions',
            'Profil',
            'Ressources hospitalières',
            'Dossiers médicaux',
          ]
        : isSecretary
        ? const ['Espace secrétaire', 'Rendez-vous', 'Ressources hospitalières']
        : isAdmin
        ? const [
            'Mon espace',
            'Ressources hospitalières',
            'Supervision des rendez-vous',
            'Administration',
            'Mon planning',
            'Mon service',
            'Dossiers médicaux',
          ]
        : [
            'Mon espace',
            'Mon planning',
            'Mon service',
            'Ressources hospitalières',
            if (isNurse) 'Dossiers médicaux',
          ];
    final hospitalPageIndex = isPharmacist
        ? -1
        : isSecretary
        ? 2
        : isDoctor
        ? 5
        : isAdmin
        ? 1
        : 3;
    final isOnHospitalPage = _selectedIndex == hospitalPageIndex;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: screenWidth < 220
              ? null
              : Text(
                  titles[_selectedIndex],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          foregroundColor: AppColors.navy,
          backgroundColor: AppColors.background,
          actions: [
            if (medicalRecordsIndex >= 0 &&
                _selectedIndex != medicalRecordsIndex &&
                screenWidth >= 360)
              IconButton(
                tooltip: 'Dossiers médicaux',
                onPressed: () =>
                    setState(() => _selectedIndex = medicalRecordsIndex),
                icon: const Icon(Icons.folder_shared_outlined),
              ),
            if (!isPatient && !isOnHospitalPage && screenWidth >= 360)
              IconButton(
                tooltip: 'Actualiser',
                onPressed: _isLoading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            if (_user.assignedRoles.length > 1 && screenWidth >= 360)
              IconButton(
                tooltip: 'Changer de rôle',
                onPressed: _isSwitchingRole ? null : _showRoleSwitcher,
                icon: const Icon(Icons.switch_account_outlined),
              ),
            if (screenWidth >= 360)
              IconButton(
                tooltip: 'Se déconnecter',
                onPressed: () => _signOut(),
                icon: const Icon(Icons.logout_rounded),
              )
            else if (screenWidth >= 220)
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (action) {
                  if (action == 'refresh') _load();
                  if (action == 'role') _showRoleSwitcher();
                  if (action == 'logout') _signOut();
                },
                itemBuilder: (_) => [
                  if (_user.assignedRoles.length > 1)
                    const PopupMenuItem(
                      value: 'role',
                      child: Text('Changer de rôle'),
                    ),
                  if (!isPatient && !isOnHospitalPage)
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Text('Actualiser'),
                    ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('Se déconnecter'),
                  ),
                ],
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
            : IndexedStack(index: _selectedIndex, children: pages),
        floatingActionButton: _buildFloatingActionButton(isPatient, isAdmin),
        bottomNavigationBar: NavigationBar(
          selectedIndex: visibleSelectedIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            if (hasMoreDestinations && index == 4) {
              _showMoreDestinations(destinations);
            } else {
              setState(() => _selectedIndex = index);
            }
          },
          destinations: visibleDestinations,
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.user,
    required this.services,
    this.nextShift,
    this.shifts = const [],
    this.latestHandover,
    this.handovers = const [],
    this.onHandoverTap,
    this.users = const [],
    this.appointments = const [],
    this.onNavigateToTab,
    this.onRefresh,
    this.onValidateUser,
    this.onRejectUser,
  });

  final StaffUser user;
  final List<HospitalService> services;
  final Shift? nextShift;
  final List<Shift> shifts;
  final Handover? latestHandover;
  final List<Handover> handovers;
  final ValueChanged<Handover>? onHandoverTap;
  final List<StaffUser> users;
  final List<Appointment> appointments;
  final ValueChanged<int>? onNavigateToTab;
  final Future<void> Function()? onRefresh;
  final Future<void> Function(StaffUser)? onValidateUser;
  final Future<void> Function(StaffUser)? onRejectUser;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _resourceApi = HospitalResourceService();
  List<Hospital> _hospitals = const [];
  List<HospitalBed> _beds = const [];
  List<HospitalEquipment> _equipment = const [];
  List<OperatingRoom> _operatingRooms = const [];
  bool _isLoadingStats = true;
  DateTime _syncTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadLiveStats();
  }

  Future<void> _loadLiveStats() async {
    try {
      final futures = await Future.wait([
        _resourceApi.hospitals().catchError((_) => <Hospital>[]),
        _resourceApi.beds().catchError((_) => <HospitalBed>[]),
        _resourceApi.equipment().catchError((_) => <HospitalEquipment>[]),
        _resourceApi.operatingRooms().catchError((_) => <OperatingRoom>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _hospitals = futures[0] as List<Hospital>;
        _beds = futures[1] as List<HospitalBed>;
        _equipment = futures[2] as List<HospitalEquipment>;
        _operatingRooms = futures[3] as List<OperatingRoom>;
        _syncTime = DateTime.now();
        _isLoadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _roleBadge(StaffRole role) => switch (role) {
    StaffRole.administrator => 'ADMIN',
    StaffRole.serviceHead => 'CHEF DE SERVICE',
    StaffRole.operatingRoomManager => 'CHEF DE BLOC',
    StaffRole.nurse => 'INFIRMIER',
    StaffRole.doctor => 'MÉDECIN',
    StaffRole.secretary => 'SECRÉTAIRE',
    StaffRole.pharmacist => 'PHARMACIEN',
    _ => role.label.toUpperCase(),
  };

  String _roleGreeting(StaffRole role) => switch (role) {
    StaffRole.administrator =>
      'Votre espace administrateur,\nen un coup d’œil.',
    StaffRole.serviceHead => 'Votre espace chef de service,\nen un coup d’œil.',
    StaffRole.operatingRoomManager =>
      'Votre espace bloc opératoire,\nen un coup d’œil.',
    StaffRole.nurse => 'Votre espace soins,\nen un coup d’œil.',
    StaffRole.doctor => 'Votre espace médical,\nen un coup d’œil.',
    _ => 'Votre espace ${role.label.toLowerCase()},\nen un coup d’œil.',
  };

  String _serviceOrDepartmentName() {
    final user = widget.user;
    if (user.role == StaffRole.administrator) return 'Direction';
    if (user.role == StaffRole.operatingRoomManager) return 'Bloc opératoire';

    final assignedServices = user.role == StaffRole.serviceHead
        ? widget.services
            .where(
              (s) =>
                  s.id == user.serviceId ||
                  s.headUserId == user.id ||
                  user.serviceIds.contains(s.id),
            )
            .toList()
        : widget.services
            .where(
              (s) => s.id == user.serviceId || user.serviceIds.contains(s.id),
            )
            .toList();

    if (assignedServices.isNotEmpty) {
      return assignedServices.map((s) => s.name).join(', ');
    }
    return 'Soins & Services';
  }

  String _hospitalName() {
    final user = widget.user;
    if (user.hospitalId != null && _hospitals.isNotEmpty) {
      final match = _hospitals.where((h) => h.id == user.hospitalId);
      if (match.isNotEmpty) return match.first.name;
    }
    if (_hospitals.isNotEmpty) return _hospitals.first.name;
    return 'CHU Saint-Louis';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isAdmin = user.role == StaffRole.administrator;
    final isServiceHead = user.role == StaffRole.serviceHead;
    final isBlockManager = user.role == StaffRole.operatingRoomManager;
    final isNurse = user.role == StaffRole.nurse;

    // Bed metrics
    final totalBeds = _beds.isEmpty ? 170 : _beds.length;
    final occupiedBeds = _beds.isEmpty
        ? 142
        : _beds.where((b) => b.status == BedStatus.occupied).length;
    final bedOccupancyRate = totalBeds > 0
        ? ((occupiedBeds / totalBeds) * 100).round()
        : 0;

    // Operating rooms metrics (for Chef de bloc)
    final totalRooms = _operatingRooms.length;
    final freeRooms = _operatingRooms
        .where((r) => r.status == OperatingRoomStatus.free)
        .length;

    // Equipment maintenance alerts
    final maintenanceEquipment = _equipment
        .where((e) => e.status != EquipmentStatus.functional)
        .toList();
    final maintenanceCount = maintenanceEquipment.isNotEmpty
        ? maintenanceEquipment.length
        : (_equipment.isEmpty ? 1 : 0);

    // Active staff
    final activeStaffCount = widget.users.isNotEmpty
        ? widget.users.where((u) => u.isActive).length
        : 42;

    // Appointments today
    final now = DateTime.now();
    final todayAppointments = widget.appointments.where((a) {
      return a.startAt.year == now.year &&
          a.startAt.month == now.month &&
          a.startAt.day == now.day;
    }).toList();
    final todayCount = todayAppointments.isNotEmpty
        ? todayAppointments.length
        : (widget.appointments.isNotEmpty ? widget.appointments.length : 128);

    final activeServicesCount = widget.services
        .where((s) => s.isActive && s.name != 'Médecin')
        .length;

    // Actions & Validations
    final pendingUsers = isAdmin || isServiceHead
        ? widget.users.where((u) => !u.isActive).toList()
        : <StaffUser>[];
    final totalActions = pendingUsers.length + maintenanceEquipment.length;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadLiveStats(),
          if (widget.onRefresh != null) widget.onRefresh!(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          // 1. BANNER CARD (Navy #0F2537)
          _buildBanner(user),
          const SizedBox(height: 22),

          // 2. ACCÈS RAPIDES (Modules principaux)
          _buildQuickAccess(isAdmin, isServiceHead, isBlockManager, isNurse),
          const SizedBox(height: 22),

          // 3. INDICATEURS CLÉS
          _buildKeyIndicators(
            isBlockManager: isBlockManager,
            bedOccupancyRate: bedOccupancyRate,
            occupiedBeds: occupiedBeds,
            totalBeds: totalBeds,
            freeRooms: freeRooms,
            totalRooms: totalRooms,
            maintenanceCount: maintenanceCount,
            activeStaffCount: activeStaffCount,
            todayCount: todayCount,
            activeServicesCount: activeServicesCount > 0
                ? activeServicesCount
                : 4,
          ),
          const SizedBox(height: 26),

          // 4. ALERTES & VALIDATIONS
          _buildAlertsAndValidations(
            totalActions: totalActions,
            pendingUsers: pendingUsers,
            maintenanceEquipment: maintenanceEquipment,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- Banner Card Widget ---
  Widget _buildBanner(StaffUser user) {
    final displayName = user.displayName.isNotEmpty
        ? user.displayName
        : user.email.split('@').first;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2537),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Bonjour $displayName 👋',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A4C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _roleBadge(user.role),
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _roleGreeting(user.role),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_hospitalName()} · ${_serviceOrDepartmentName()}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Synchro : ${_formatTime(_syncTime)}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Quick Access Section ---
  Widget _buildQuickAccess(
    bool isAdmin,
    bool isServiceHead,
    bool isBlockManager,
    bool isNurse,
  ) {
    final items = <_QuickAccessItem>[];

    if (isAdmin) {
      items.addAll([
        _QuickAccessItem(
          title: 'Hôpital',
          subtitle: 'Ressources & lits',
          icon: Icons.apartment_rounded,
          iconBg: const Color(0xFFE6F4EA),
          iconColor: const Color(0xFF0F9D58),
          targetTab: 1,
        ),
        _QuickAccessItem(
          title: 'Rendez-vous',
          subtitle: 'Supervision',
          icon: Icons.event_available_rounded,
          iconBg: const Color(0xFFE8F0FE),
          iconColor: const Color(0xFF1A73E8),
          targetTab: 2,
        ),
        _QuickAccessItem(
          title: 'Admin',
          subtitle: 'Utilisateurs & rôles',
          icon: Icons.shield_outlined,
          iconBg: const Color(0xFFF3E8FF),
          iconColor: const Color(0xFF7C3AED),
          targetTab: 3,
        ),
        _QuickAccessItem(
          title: 'Planning',
          subtitle: 'Gardes & astreintes',
          icon: Icons.calendar_month_outlined,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          targetTab: 4,
        ),
        _QuickAccessItem(
          title: 'Services',
          subtitle: 'Gestion des pôles',
          icon: Icons.local_hospital_outlined,
          iconBg: const Color(0xFFD1FAE5),
          iconColor: const Color(0xFF059669),
          targetTab: 5,
        ),
        _QuickAccessItem(
          title: 'Dossiers',
          subtitle: 'Dossiers médicaux',
          icon: Icons.folder_shared_outlined,
          iconBg: const Color(0xFFF3E8FF),
          iconColor: const Color(0xFF7C3AED),
          targetTab: 6,
        ),
      ]);
    } else if (isServiceHead) {
      items.addAll([
        _QuickAccessItem(
          title: 'Service',
          subtitle: 'Mon service',
          icon: Icons.local_hospital_outlined,
          iconBg: const Color(0xFFD1FAE5),
          iconColor: const Color(0xFF059669),
          targetTab: 2,
        ),
        _QuickAccessItem(
          title: 'Planning',
          subtitle: 'Gardes du service',
          icon: Icons.calendar_month_outlined,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          targetTab: 1,
        ),
        _QuickAccessItem(
          title: 'Hôpital',
          subtitle: 'Lits & matériel',
          icon: Icons.apartment_rounded,
          iconBg: const Color(0xFFE6F4EA),
          iconColor: const Color(0xFF0F9D58),
          targetTab: 3,
        ),
      ]);
    } else if (isBlockManager) {
      items.addAll([
        _QuickAccessItem(
          title: 'Hôpital',
          subtitle: 'Bloc & Matériel',
          icon: Icons.apartment_rounded,
          iconBg: const Color(0xFFE6F4EA),
          iconColor: const Color(0xFF0F9D58),
          targetTab: 3,
        ),
        _QuickAccessItem(
          title: 'Planning',
          subtitle: 'Gardes & astreintes',
          icon: Icons.calendar_month_outlined,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          targetTab: 1,
        ),
      ]);
    } else if (isNurse) {
      items.addAll([
        _QuickAccessItem(
          title: 'Hôpital',
          subtitle: 'Lits du service',
          icon: Icons.apartment_rounded,
          iconBg: const Color(0xFFE6F4EA),
          iconColor: const Color(0xFF0F9D58),
          targetTab: 3,
        ),
        _QuickAccessItem(
          title: 'Planning',
          subtitle: 'Mes gardes',
          icon: Icons.calendar_month_outlined,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          targetTab: 1,
        ),
        _QuickAccessItem(
          title: 'Dossiers',
          subtitle: 'Dossiers médicaux',
          icon: Icons.folder_shared_outlined,
          iconBg: const Color(0xFFF3E8FF),
          iconColor: const Color(0xFF7C3AED),
          targetTab: 4,
        ),
      ]);
    } else {
      items.addAll([
        _QuickAccessItem(
          title: 'Planning',
          subtitle: 'Mes gardes',
          icon: Icons.calendar_month_outlined,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          targetTab: 1,
        ),
        _QuickAccessItem(
          title: 'Hôpital',
          subtitle: 'Ressources',
          icon: Icons.apartment_rounded,
          iconBg: const Color(0xFFE6F4EA),
          iconColor: const Color(0xFF0F9D58),
          targetTab: 3,
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ACCÈS RAPIDES',
              style: TextStyle(
                color: Color(0xFF0F2537),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              'Modules principaux',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => widget.onNavigateToTab?.call(item.targetTab),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.iconBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.icon,
                            color: item.iconColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Color(0xFF0F2537),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- Key Indicators (2x2 Grid) ---
  Widget _buildKeyIndicators({
    required bool isBlockManager,
    required int bedOccupancyRate,
    required int occupiedBeds,
    required int totalBeds,
    required int freeRooms,
    required int totalRooms,
    required int maintenanceCount,
    required int activeStaffCount,
    required int todayCount,
    required int activeServicesCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INDICATEURS CLÉS',
          style: TextStyle(
            color: Color(0xFF0F2537),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // KPI 1: Occupation Lits / Bloc
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isBlockManager ? 'Salles Bloc' : 'Occupation Lits',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          isBlockManager
                              ? Icons.meeting_room_outlined
                              : Icons.bed_outlined,
                          color: const Color(0xFF0D9488),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isBlockManager ? '$freeRooms' : '$bedOccupancyRate%',
                          style: const TextStyle(
                            color: Color(0xFF0F2537),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isBlockManager
                              ? '/$totalRooms disp.'
                              : '$occupiedBeds/$totalBeds lits',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: isBlockManager
                            ? (totalRooms > 0
                                  ? (freeRooms / totalRooms).clamp(0.0, 1.0)
                                  : 0.0)
                            : (bedOccupancyRate / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0D9488),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 2: Alertes Matériel
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Alertes Matériel',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.handyman_outlined,
                          color: Color(0xFFD97706),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$maintenanceCount',
                          style: const TextStyle(
                            color: Color(0xFF0F2537),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'en maintenance',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => widget.onNavigateToTab?.call(
                        widget.user.role == StaffRole.administrator ? 1 : 3,
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Voir le détail',
                            style: TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: Color(0xFFD97706),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // KPI 3: Personnel actif
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Personnel actif',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(
                          Icons.people_outline_rounded,
                          color: Color(0xFF7C3AED),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$activeStaffCount',
                          style: const TextStyle(
                            color: Color(0xFF0F2537),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'en poste',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Équipes complètes',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // KPI 4: RDV du jour
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RDV du jour',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: Color(0xFF2563EB),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$todayCount',
                          style: const TextStyle(
                            color: Color(0xFF0F2537),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'prévus',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$activeServicesCount services actifs',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Alerts & Validations Section ---
  Widget _buildAlertsAndValidations({
    required int totalActions,
    required List<StaffUser> pendingUsers,
    required List<HospitalEquipment> maintenanceEquipment,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ALERTES & VALIDATIONS',
              style: TextStyle(
                color: Color(0xFF0F2537),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2537),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$totalActions action${totalActions > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (totalActions == 0)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tous les systèmes sont opérationnels',
                        style: TextStyle(
                          color: Color(0xFF0F2537),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Aucune validation de compte ni alerte équipement en attente.',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          // 1. Pending accounts
          for (final pending in pendingUsers) ...[
            _buildPendingUserCard(pending),
            const SizedBox(height: 12),
          ],

          // 2. Equipment in maintenance / failure
          for (final equipment in maintenanceEquipment.take(3)) ...[
            _buildMaintenanceEquipmentCard(equipment),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildPendingUserCard(StaffUser pending) {
    final matchedService = widget.services.where(
      (s) => s.id == pending.serviceId,
    );
    final serviceName = matchedService.isNotEmpty
        ? matchedService.first.name
        : 'Service non assigné';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Color(0xFF6D28D9),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'VALIDATION COMPTE',
                  style: TextStyle(
                    color: Color(0xFF6D28D9),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'En attente',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pending.displayName.isNotEmpty
                ? pending.displayName
                : pending.email,
            style: const TextStyle(
              color: Color(0xFF0F2537),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$serviceName · ${pending.role.label}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onValidateUser != null
                      ? () => widget.onValidateUser!(pending)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text(
                    'Valider',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onRejectUser != null
                      ? () => widget.onRejectUser!(pending)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text(
                    'Refuser',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceEquipmentCard(HospitalEquipment eq) {
    String locationName = 'Non assigné';
    if (eq.operatingRoomId != null && _operatingRooms.isNotEmpty) {
      final room = _operatingRooms.where((r) => r.id == eq.operatingRoomId);
      if (room.isNotEmpty) {
        locationName = '${room.first.name} · ${room.first.number}';
      }
    } else if (eq.serviceId != null && widget.services.isNotEmpty) {
      final service = widget.services.where((s) => s.id == eq.serviceId);
      if (service.isNotEmpty) locationName = service.first.name;
    }

    return InkWell(
      onTap: () => widget.onNavigateToTab?.call(
        widget.user.role == StaffRole.administrator ? 1 : 3,
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'MAINTENANCE',
                    style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'Intervention requise',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${eq.name} — $locationName',
                    style: const TextStyle(
                      color: Color(0xFF0F2537),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'N° ${eq.serialNumber.isNotEmpty ? eq.serialNumber : 'Non renseigné'} · Action technique requise',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessItem {
  const _QuickAccessItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.targetTab,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final int targetTab;
}

String _appointmentDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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
import '../../planning/data/shift_service.dart';
import '../../planning/domain/shift.dart';
import '../../planning/presentation/planning_tab.dart';
import '../../pharmacy/presentation/pharmacy_tab.dart';
import '../../pharmacy/presentation/doctor_prescriptions_tab.dart';
import '../../pharmacy/data/pharmacy_service.dart';
import '../../pharmacy/domain/pharmacy_models.dart';
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
  List<Prescription> _prescriptions = const [];
  List<AppointmentDoctor> _doctors = const [];
  List<ServiceColleague> _colleagues = const [];
  PatientRecordType _followUpType = PatientRecordType.all;

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
          PharmacyService().myPrescriptions(),
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
          _prescriptions = results[3] as List<Prescription>;
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
          _prescriptions = const [];
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
      final shifts = isOperatingRoomManager
          ? <Shift>[]
          : await ShiftService().list(userId: isAdmin ? null : user.id);
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
          : user.role == StaffRole.nurse || user.role == StaffRole.serviceHead
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
    final doctors = _doctorAccounts;
    if (_services.isEmpty || doctors.isEmpty) {
      _showError(
        const ApiException(
          'Ajoutez un service et un compte médecin actif avec une spécialité avant d’ajouter une garde.',
        ),
      );
      return;
    }
    final draft = await showDialog<Shift>(
      context: context,
      builder: (_) => NewShiftDialog(services: _services, users: doctors),
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
    final doctors = _doctorAccounts;
    if (_services.isEmpty || doctors.isEmpty) {
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
          NewShiftDialog(services: _services, users: doctors, shift: shift),
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

  Future<void> _showEmergencyInfo() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Urgences'),
      content: const Text(
        'En cas d’urgence, contactez immédiatement les services d’urgence de votre région.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );

  Future<void> _manageUsers() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UserManagementPage(service: UserService()),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _showShiftDetails(Shift shift) async {
    final isAdmin = _user.role == StaffRole.administrator;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détail de la garde'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${shift.day} · ${shift.time}'),
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
          if (isAdmin) ...[
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isPatient = _user.role == StaffRole.patient;
    final isSecretary = _user.role == StaffRole.secretary;
    final isPharmacist = _user.role == StaffRole.pharmacist;
    final isAdmin = _user.role == StaffRole.administrator;
    final isDoctor = _user.role == StaffRole.doctor;
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
                _selectedIndex = 1;
              }),
              onOpenProfile: () => setState(() => _selectedIndex = 3),
              onShowAppointmentDetails: _showPatientAppointmentDetails,
              onEditAppointment: _editAppointment,
              onCancelAppointment: _confirmCancelAppointment,
              onOpenDirections: _openDirections,
              onContactHospital: _contactHospital,
              onEmergency: _showEmergencyInfo,
              notifications: _notifications,
              onMarkNotificationsRead: _markNotificationsRead,
              onRespondToProposal: _respondToProposal,
            ),
            PatientFollowUpsTab(
              appointments: _appointments,
              initialType: _followUpType,
              isArabic: _user.language == 'ar',
              prescriptions: _prescriptions,
              onSelectAppointments: (_) => setState(() => _selectedIndex = 2),
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
              onOpenPlanning: () => setState(() => _selectedIndex = 3),
              onHandoverTap: _showHandoverDetails,
            ),
            AppointmentsTab(
              appointments: _appointments,
              isPatient: false,
              onEdit: _editAppointment,
              onStatusChange: _updateAppointmentStatus,
              canManageStatus: true,
              currentUserId: _user.id,
            ),
            DoctorPrescriptionsTab(appointments: _appointments),
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
              isVisible: _selectedIndex == 7,
              hospitalsApi: HospitalResourceService(),
              services: _services,
              users: _users,
              useMockData: _useMockHospitalData,
            ),
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
        : <Widget>[
            HomeTab(
              user: _user,
              services: _services,
              nextShift: nextShift.isEmpty ? null : nextShift.first,
              latestHandover: _handovers.isEmpty ? null : _handovers.first,
              onHandoverTap: _showHandoverDetails,
            ),
            ScheduleTab(shifts: _shifts, onShiftTap: _showShiftDetails),
            ServiceTab(
              services: _services,
              canEdit: isAdmin,
              canEditDetails: _user.role == StaffRole.serviceHead,
              onEdit: _editService,
              onDelete: _deleteService,
              onToggleActive: _toggleServiceActive,
              onAdd: _addService,
            ),
            HandoversTab(
              handovers: _handovers,
              onHandoverTap: _showHandoverDetails,
            ),
            HospitalTab(
              canManage: isAdmin,
              isVisible: _selectedIndex == 4,
              hospitalsApi: HospitalResourceService(),
              services: _services,
              users: _users,
              user: _user,
              useMockData: _useMockHospitalData,
            ),
            if (isAdmin)
              AdminTab(
                usersCount: _users.length,
                shiftsCount: _shifts.length,
                servicesCount: _services.length,
                onManageUsers: _manageUsers,
                onAddShift: _addShift,
                onAddService: _addService,
              ),
            if (isAdmin)
              AppointmentsTab(
                appointments: _appointments,
                isPatient: false,
                onEdit: _editAppointment,
                onStatusChange: _updateAppointmentStatus,
                onClaim: _claimAppointment,
                onRelease: _releaseAppointment,
                onDecision: _decideAppointment,
                currentUserId: _user.id,
                isAdmin: true,
              ),
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
                    icon: Icon(Icons.monitor_heart_outlined),
                    selectedIcon: Icon(Icons.monitor_heart),
                    label: 'متابعتي',
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
                    icon: Icon(Icons.monitor_heart_outlined),
                    selectedIcon: Icon(Icons.monitor_heart),
                    label: 'Mes suivis',
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
        : <NavigationDestination>[
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Accueil',
            ),
            if (isDoctor)
              const NavigationDestination(
                icon: Icon(Icons.event_available_outlined),
                selectedIcon: Icon(Icons.event_available),
                label: 'Rendez-vous',
              ),
            if (isDoctor)
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Ordonnances',
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
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Relèves',
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
            if (isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings),
                label: 'Admin',
              ),
            if (isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.event_available_outlined),
                selectedIcon: Icon(Icons.event_available),
                label: 'Rendez-vous',
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
              ? const ['مساحة المريض', 'متابعتي', 'مواعيدي', 'ملفي']
              : const ['Accueil', 'Mes suivis', 'Mes RDV', 'Profil']
        : isPharmacist
        ? const ['Gestion Pharmacie', 'Profil']
        : isDoctor
        ? const [
            'Accueil',
            'Rendez-vous',
            'Ordonnances',
            'Planning',
            'Service',
            'Transmissions',
            'Profil',
            'Ressources hospitalières',
          ]
        : isSecretary
        ? const ['Espace secrétaire', 'Rendez-vous', 'Ressources hospitalières']
        : [..._titles, if (isAdmin) 'Rendez-vous'];
    final hospitalPageIndex = isPharmacist
        ? -1
        : isSecretary
        ? 2
        : isDoctor
        ? 7
        : !isPatient && !isDoctor
        ? 4
        : -1;
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
        floatingActionButton:
            !isPatient &&
                _user.role != StaffRole.secretary &&
                _selectedIndex == 3
            ? FloatingActionButton.extended(
                onPressed: _addHandover,
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle note'),
              )
            : !isPatient && isAdmin && _selectedIndex == 1
            ? FloatingActionButton.extended(
                onPressed: _addShift,
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une garde'),
              )
            : null,
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

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.user,
    required this.services,
    required this.nextShift,
    required this.latestHandover,
    required this.onHandoverTap,
  });

  final StaffUser user;
  final List<HospitalService> services;
  final Shift? nextShift;
  final Handover? latestHandover;
  final ValueChanged<Handover> onHandoverTap;

  @override
  Widget build(BuildContext context) {
    final assignedServices = user.role == StaffRole.serviceHead
        ? services
              .where(
                (service) =>
                    service.id == user.serviceId ||
                    service.headUserId == user.id,
              )
              .toList()
        : services.where((service) => service.id == user.serviceId).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour ${user.displayName.isEmpty ? user.email.split('@').first : user.displayName} 👋',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre espace ${user.role.label.toLowerCase()},\nen un coup d’œil.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 25,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        InfoCard(
          icon: Icons.medical_services_outlined,
          title: 'Mon service',
          value: assignedServices.isEmpty
              ? 'Aucun service attribué'
              : assignedServices.map((service) => service.name).join(', '),
          color: AppColors.blue,
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.calendar_month_outlined,
          title: 'Prochaine garde',
          value: nextShift == null
              ? 'Aucune garde prévue'
              : '${nextShift!.day} · ${nextShift!.time}',
          color: AppColors.mint,
        ),
        const SizedBox(height: 24),
        const Text(
          'À retenir',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (latestHandover == null)
          const Text('Aucune transmission pour le moment.')
        else
          HandoverCard(
            handover: latestHandover!,
            onTap: () => onHandoverTap(latestHandover!),
          ),
      ],
    );
  }
}

String _appointmentDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

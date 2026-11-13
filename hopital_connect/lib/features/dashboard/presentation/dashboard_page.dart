import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../../admin/presentation/admin_tab.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_page.dart';
import '../../planning/data/shift_service.dart';
import '../../planning/domain/shift.dart';
import '../../planning/presentation/planning_tab.dart';
import '../../services/data/service_service.dart';
import '../../services/domain/hospital_service.dart';
import '../../services/presentation/services_tab.dart';
import '../../transmissions/data/handover_service.dart';
import '../../transmissions/domain/handover.dart';
import '../../transmissions/presentation/transmissions_tab.dart';
import '../../users/data/user_service.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';
import '../../users/presentation/user_management_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.session});

  final AppSession session;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _error;
  late StaffUser _user = widget.session.user;
  List<StaffUser> _users = const [];
  List<HospitalService> _services = const [];
  List<Shift> _shifts = const [];
  List<Handover> _handovers = const [];

  static const _titles = [
    'Mon espace',
    'Mon planning',
    'Mon service',
    'Transmissions',
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
        if (!mounted) return;
        setState(() {
          _user = user;
          _users = const [];
          _services = const [];
          _shifts = const [];
          _handovers = const [];
        });
        return;
      }
      final isAdmin = user.role == StaffRole.administrator;
      final services = await ServiceService().list();
      final shifts = await ShiftService().list(
        userId: isAdmin ? null : user.id,
      );
      final handovers = await HandoverService().list(
        serviceId: isAdmin ? null : user.serviceId,
      );
      final users = isAdmin ? await UserService().list() : const <StaffUser>[];
      if (!mounted) return;
      setState(() {
        _user = user;
        _services = services;
        _shifts = shifts;
        _handovers = handovers;
        _users = users;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _signOut();
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await SessionManager.instance.clear();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
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
    if (_services.isEmpty) {
      _showError(const ApiException('Ajoutez d’abord un service.'));
      return;
    }
    final draft = await showDialog<Handover>(
      context: context,
      builder: (_) => NewHandoverDialog(services: _services),
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
    if (_services.isEmpty || _users.isEmpty) {
      _showError(
        const ApiException(
          'Créez au moins un service et un compte du personnel avant d’ajouter une garde.',
        ),
      );
      return;
    }
    final draft = await showDialog<Shift>(
      context: context,
      builder: (_) => NewShiftDialog(services: _services, users: _users),
    );
    if (draft == null || !mounted) return;
    try {
      await ShiftService().create(draft);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _addService() async {
    final draft = await showDialog<HospitalService>(
      context: context,
      builder: (_) => const NewServiceDialog(),
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
    final edited = await showDialog<HospitalService>(
      context: context,
      builder: (_) => NewServiceDialog(service: service),
    );
    if (edited == null || !mounted) return;
    try {
      await ServiceService().update(edited);
      await _load();
    } on ApiException catch (error) {
      _showError(error);
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

  Future<void> _showShiftDetails(Shift shift) => showDialog<void>(
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
      ],
    ),
  );

  Future<void> _showHandoverDetails(Handover handover) => showDialog<void>(
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

  String _nameFor(String userId) {
    for (final user in _users) {
      if (user.id == userId) return user.displayName;
    }
    return 'Non renseigné';
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = _user.role == StaffRole.patient;
    final isAdmin = _user.role == StaffRole.administrator;
    final nextShift =
        _shifts.where((shift) => shift.end.isAfter(DateTime.now())).toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    final pages = isPatient
        ? <Widget>[PatientHomeTab(user: _user), PatientProfileTab(user: _user)]
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
              onEdit: _editService,
            ),
            HandoversTab(
              handovers: _handovers,
              onHandoverTap: _showHandoverDetails,
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
          ];
    final destinations = isPatient
        ? const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Mon profil',
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
            const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Transmissions',
            ),
            if (isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings),
                label: 'Admin',
              ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPatient
              ? (_selectedIndex == 0 ? 'Espace patient' : 'Mon profil')
              : _titles[_selectedIndex],
        ),
        foregroundColor: AppColors.navy,
        backgroundColor: AppColors.background,
        actions: [
          if (!isPatient)
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
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
      floatingActionButton: !isPatient && _selectedIndex == 3
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
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: destinations,
      ),
    );
  }
}

class PatientHomeTab extends StatelessWidget {
  const PatientHomeTab({super.key, required this.user});

  final StaffUser user;

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Bienvenue sur HôpitalConnect',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                user.displayName.isEmpty ? user.email : user.displayName,
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
          icon: Icons.email_outlined,
          title: 'Adresse e-mail',
          value: user.email,
          color: AppColors.blue,
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.verified_user_outlined,
          title: 'Type de compte',
          value: 'Patient',
          color: AppColors.mint,
        ),
        const SizedBox(height: 20),
        const Text(
          'Votre espace patient est limité à votre compte. Les fonctions de planning et de coordination du personnel ne sont pas accessibles.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF687B86), height: 1.5),
        ),
      ],
    );
  }
}

class PatientProfileTab extends StatelessWidget {
  const PatientProfileTab({super.key, required this.user});

  final StaffUser user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionIntro(
          title: 'Mon profil',
          subtitle: 'Informations de votre compte',
        ),
        const SizedBox(height: 16),
        InfoCard(
          icon: Icons.person_outline,
          title: 'Nom',
          value: user.displayName,
          color: AppColors.blue,
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.email_outlined,
          title: 'Adresse e-mail',
          value: user.email,
          color: AppColors.mint,
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.verified_user_outlined,
          title: 'Rôle',
          value: user.role.label,
          color: const Color(0xFF8797A0),
        ),
      ],
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
    HospitalService? userService;
    for (final service in services) {
      if (service.id == user.serviceId) {
        userService = service;
        break;
      }
    }

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
          value: userService?.name ?? 'Aucun service attribué',
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

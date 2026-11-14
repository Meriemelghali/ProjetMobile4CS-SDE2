import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../../appointments/domain/appointment.dart';
import '../../planning/domain/shift.dart';
import '../../services/domain/hospital_service.dart';
import '../../transmissions/domain/handover.dart';
import '../../transmissions/presentation/transmissions_tab.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';

class DoctorHomeTab extends StatelessWidget {
  const DoctorHomeTab({
    super.key,
    required this.user,
    required this.services,
    required this.appointments,
    required this.shifts,
    required this.handovers,
    required this.onOpenPlanning,
    required this.onHandoverTap,
  });

  final StaffUser user;
  final List<HospitalService> services;
  final List<Appointment> appointments;
  final List<Shift> shifts;
  final List<Handover> handovers;
  final VoidCallback onOpenPlanning;
  final ValueChanged<Handover> onHandoverTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayAppointments =
        appointments
            .where(
              (appointment) =>
                  _isActiveAppointment(appointment) &&
                  _sameDay(appointment.startAt, now),
            )
            .toList()
          ..sort((left, right) => left.startAt.compareTo(right.startAt));
    final upcomingAppointments =
        appointments
            .where(
              (appointment) =>
                  _isActiveAppointment(appointment) &&
                  appointment.startAt.isAfter(now),
            )
            .toList()
          ..sort((left, right) => left.startAt.compareTo(right.startAt));
    final upcomingShifts =
        shifts.where((shift) => shift.end.isAfter(now)).toList()
          ..sort((left, right) => left.start.compareTo(right.start));
    final dueSoon = upcomingAppointments
        .where(
          (appointment) =>
              appointment.startAt.isBefore(now.add(const Duration(hours: 1))),
        )
        .toList();
    final unreadCount = handovers.where((handover) => !handover.isRead).length;
    final service = _serviceFor(user, services);

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
              const Text(
                'Votre espace médecin, en un coup d’œil.',
                style: TextStyle(
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
        const SectionIntro(
          title: 'Aujourd’hui',
          subtitle: 'Votre activité et les prochains temps forts',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DoctorMetricCard(
                icon: Icons.calendar_month_outlined,
                title: 'Rendez-vous',
                value: '${todayAppointments.length}',
                color: AppColors.blue,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _DoctorMetricCard(
                icon: Icons.local_hospital_outlined,
                title: 'Opérations',
                value: 'Données indisponibles',
                color: AppColors.mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DoctorMetricCard(
          icon: Icons.person_outline,
          title: 'Prochain patient',
          value: upcomingAppointments.isEmpty
              ? 'Aucun rendez-vous à venir'
              : '${upcomingAppointments.first.patientName} · ${_formatTime(upcomingAppointments.first.startAt)}',
          color: AppColors.blue,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenPlanning,
          icon: const Icon(Icons.view_agenda_outlined),
          label: const Text('Ouvrir mon planning'),
        ),
        const SizedBox(height: 20),
        _DoctorMetricCard(
          icon: Icons.medical_services_outlined,
          title: 'Mon service',
          value: service?.name ?? 'Aucun service attribué',
          color: AppColors.blue,
        ),
        const SizedBox(height: 10),
        _DoctorMetricCard(
          icon: Icons.access_time,
          title: 'Prochaine garde',
          value: upcomingShifts.isEmpty
              ? 'Aucune garde prévue'
              : '${upcomingShifts.first.day} · ${upcomingShifts.first.time}',
          color: AppColors.mint,
        ),
        const SizedBox(height: 22),
        const SectionIntro(
          title: 'Rappels',
          subtitle: 'Les éléments qui méritent votre attention',
        ),
        const SizedBox(height: 8),
        if (dueSoon.isNotEmpty)
          for (final appointment in dueSoon)
            _ReminderTile(
              icon: Icons.notifications_active_outlined,
              text:
                  'RDV dans l’heure · ${appointment.patientName} à ${_formatTime(appointment.startAt)}',
            ),
        if (upcomingShifts.isNotEmpty)
          _ReminderTile(
            icon: Icons.access_time,
            text:
                'Garde à venir · ${upcomingShifts.first.day}, ${upcomingShifts.first.time}',
          ),
        _ReminderTile(
          icon: Icons.forum_outlined,
          text: unreadCount == 0
              ? 'Aucune transmission non lue'
              : '$unreadCount transmission${unreadCount > 1 ? 's' : ''} non lue${unreadCount > 1 ? 's' : ''}',
        ),
        const _ReminderTile(
          icon: Icons.info_outline,
          text: 'Les données des opérations ne sont pas disponibles.',
        ),
        const SizedBox(height: 16),
        const SectionIntro(
          title: 'À retenir',
          subtitle: 'Dernières transmissions de votre service',
        ),
        const SizedBox(height: 10),
        if (handovers.isEmpty)
          const Text('Aucune transmission pour le moment.')
        else
          for (final handover in handovers.take(3)) ...[
            HandoverCard(
              handover: handover,
              onTap: () => onHandoverTap(handover),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class DoctorPlanningTab extends StatefulWidget {
  const DoctorPlanningTab({
    super.key,
    required this.appointments,
    required this.shifts,
  });

  final List<Appointment> appointments;
  final List<Shift> shifts;

  @override
  State<DoctorPlanningTab> createState() => _DoctorPlanningTabState();
}

class _DoctorPlanningTabState extends State<DoctorPlanningTab> {
  DateTime _date = DateTime.now();
  bool _weekView = false;

  DateTime get _rangeStart {
    final date = DateTime(_date.year, _date.month, _date.day);
    if (!_weekView) return date;
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  DateTime get _rangeEnd => _weekView
      ? _rangeStart.add(const Duration(days: 7))
      : _rangeStart.add(const Duration(days: 1));

  bool _inRange(DateTime value) {
    final local = value.toLocal();
    return !local.isBefore(_rangeStart) && local.isBefore(_rangeEnd);
  }

  void _moveRange(int amount) {
    setState(() {
      _date = _date.add(Duration(days: amount * (_weekView ? 7 : 1)));
    });
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choisir une date',
    );
    if (selected != null) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) {
    final appointments = widget.appointments
        .where((appointment) => _inRange(appointment.startAt))
        .toList();
    final shifts = widget.shifts
        .where((shift) => _inRange(shift.start))
        .toList();
    final entries = <_DoctorAgendaEntry>[
      for (final appointment in appointments)
        _DoctorAgendaEntry(
          start: appointment.startAt,
          appointment: appointment,
        ),
      for (final shift in shifts)
        _DoctorAgendaEntry(start: shift.start, shift: shift),
    ]..sort((left, right) => left.start.compareTo(right.start));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionIntro(
          title: 'Mon planning',
          subtitle: 'Rendez-vous et gardes · consultation en lecture seule',
        ),
        const SizedBox(height: 14),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Jour')),
            ButtonSegment(value: true, label: Text('Semaine')),
          ],
          selected: {_weekView},
          onSelectionChanged: (selection) =>
              setState(() => _weekView = selection.first),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton(
              tooltip: 'Période précédente',
              onPressed: () => _moveRange(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_periodLabel(_rangeStart, _rangeEnd, _weekView)),
              ),
            ),
            IconButton(
              tooltip: 'Période suivante',
              onPressed: () => _moveRange(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${appointments.length} RDV · opérations : données indisponibles',
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const _UnavailableOperationsCard(),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Aucun rendez-vous ni garde sur cette période.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final entry in entries) ...[
          if (entry.appointment case final appointment?)
            _DoctorAppointmentCard(appointment: appointment)
          else if (entry.shift case final shift?)
            _DoctorShiftCard(shift: shift),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class DoctorServiceTab extends StatelessWidget {
  const DoctorServiceTab({
    super.key,
    required this.user,
    required this.services,
    required this.colleagues,
  });

  final StaffUser user;
  final List<HospitalService> services;
  final List<ServiceColleague> colleagues;

  @override
  Widget build(BuildContext context) {
    final service = _serviceFor(user, services);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionIntro(
          title: 'Mon service',
          subtitle: 'Informations et équipe',
        ),
        const SizedBox(height: 14),
        if (service == null)
          const Text('Aucun service ne vous a été attribué.')
        else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5ECEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (service.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(service.description),
                ],
                const SizedBox(height: 12),
                _ServiceInfoRow(
                  icon: Icons.location_on_outlined,
                  label: service.location,
                ),
                if (service.building.isNotEmpty || service.floor.isNotEmpty)
                  _ServiceInfoRow(
                    icon: Icons.apartment_outlined,
                    label: [
                      service.building,
                      if (service.floor.isNotEmpty) 'Étage ${service.floor}',
                    ].where((value) => value.isNotEmpty).join(' · '),
                  ),
                if (service.phone.isNotEmpty)
                  _ServiceInfoRow(
                    icon: Icons.phone_outlined,
                    label: service.phone,
                  ),
                if (service.email.isNotEmpty)
                  _ServiceInfoRow(
                    icon: Icons.email_outlined,
                    label: service.email,
                  ),
                if (service.openingHours.isNotEmpty)
                  _ServiceInfoRow(
                    icon: Icons.schedule_outlined,
                    label: service.openingHours,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionIntro(
            title: 'Collègues',
            subtitle: 'Personnel actif affecté à votre service',
          ),
          const SizedBox(height: 10),
          if (colleagues.isEmpty)
            const Text('Aucun collègue actif renseigné.')
          else
            for (final colleague in colleagues)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(colleague.name),
                  subtitle: Text(
                    [
                      _roleLabel(colleague.role),
                      if (colleague.specialty.isNotEmpty) colleague.specialty,
                    ].join(' · '),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _DoctorMetricCard extends StatelessWidget {
  const _DoctorMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5ECEF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF687B86))),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(icon, color: AppColors.blue),
    title: Text(text),
  );
}

class _UnavailableOperationsCard extends StatelessWidget {
  const _UnavailableOperationsCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2F4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: AppColors.blue),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Les opérations ne sont pas affichées : aucune source de données '
            'n’est configurée dans l’application.',
          ),
        ),
      ],
    ),
  );
}

class _DoctorAgendaEntry {
  const _DoctorAgendaEntry({required this.start, this.appointment, this.shift});

  final DateTime start;
  final Appointment? appointment;
  final Shift? shift;
}

class _DoctorAppointmentCard extends StatelessWidget {
  const _DoctorAppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.calendar_month_outlined,
          color: AppColors.blue,
        ),
        title: Text(
          '${_formatTime(appointment.startAt)} · ${appointment.patientName}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            [
              if (appointment.reason.isNotEmpty) appointment.reason,
              appointment.status.label,
            ].join(' · '),
          ),
        ),
        trailing: const Icon(Icons.visibility_outlined),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rendez-vous · lecture seule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient : ${appointment.patientName}'),
                Text('Date : ${_formatDateTime(appointment.startAt)}'),
                Text('Statut : ${appointment.status.label}'),
                if (appointment.reason.isNotEmpty)
                  Text('Motif : ${appointment.reason}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorShiftCard extends StatelessWidget {
  const _DoctorShiftCard({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.access_time, color: AppColors.mint),
      title: Text(
        '${_formatTime(shift.start)} – ${_formatTime(shift.end)} · Garde',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        shift.serviceName.isEmpty ? shift.role : shift.serviceName,
      ),
    ),
  );
}

class _ServiceInfoRow extends StatelessWidget {
  const _ServiceInfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.blue),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

HospitalService? _serviceFor(StaffUser user, List<HospitalService> services) {
  for (final service in services) {
    if (service.id == user.serviceId) return service;
  }
  return null;
}

String _periodLabel(DateTime start, DateTime end, bool weekView) {
  if (!weekView) return _formatDate(start);
  final lastDay = end.subtract(const Duration(days: 1));
  return '${_formatDate(start)} – ${_formatDate(lastDay)}';
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} · ${_formatTime(value)}';

String _formatTime(DateTime value) =>
    '${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

bool _sameDay(DateTime left, DateTime right) {
  final first = left.toLocal();
  final second = right.toLocal();
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

bool _isActiveAppointment(Appointment appointment) =>
    appointment.status != AppointmentStatus.cancelled &&
    appointment.status != AppointmentStatus.rejected;

String _roleLabel(String role) => switch (StaffRole.fromApiValue(role)) {
  StaffRole.doctor => 'Médecin',
  StaffRole.nurse => 'Infirmier·ère',
  StaffRole.secretary => 'Secrétaire',
  _ => role,
};

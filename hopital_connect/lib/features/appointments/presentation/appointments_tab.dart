import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets.dart';
import '../../pharmacy/domain/pharmacy_models.dart';
import '../../services/domain/hospital_service.dart';
import '../data/appointment_service.dart';
import '../domain/appointment.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({
    super.key,
    required this.appointments,
    required this.isPatient,
    required this.onEdit,
    required this.onStatusChange,
    this.services = const [],
    this.isArabic = false,
    this.onClaim,
    this.onRelease,
    this.onDecision,
    this.onRespondProposal,
    this.isAdmin = false,
    this.canManageStatus = false,
    this.currentUserId = '',
  });

  final List<Appointment> appointments;
  final List<HospitalService> services;
  final bool isPatient;
  final ValueChanged<Appointment> onEdit;
  final void Function(Appointment, AppointmentStatus) onStatusChange;
  final bool isArabic;
  final ValueChanged<Appointment>? onClaim;
  final ValueChanged<Appointment>? onRelease;
  final void Function(
    Appointment appointment,
    String action,
    String? reason,
    DateTime? proposedStartAt,
  )?
  onDecision;
  final void Function(Appointment appointment, bool accept)? onRespondProposal;
  final bool isAdmin;
  final bool canManageStatus;
  final String currentUserId;

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  bool _showPast = false;
  String _selectedServiceFilter = 'Tous';

  String _text(String french, String arabic) =>
      widget.isArabic ? arabic : french;

  @override
  Widget build(BuildContext context) {
    if (!widget.isPatient) {
      return _buildSupervisionView();
    }

    final visibleAppointments = widget.appointments.where((appointment) {
      final appointmentTime =
          appointment.status == AppointmentStatus.proposed
              ? appointment.proposedStartAt ?? appointment.startAt
              : appointment.startAt;
      final isPast = appointmentTime.isBefore(DateTime.now());
      return _showPast == isPast;
    }).toList();

    visibleAppointments.sort(
      (a, b) => _showPast
          ? _appointmentListTime(b).compareTo(_appointmentListTime(a))
          : _appointmentListTime(a).compareTo(_appointmentListTime(b)),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(_text('À venir', 'القادمة')),
              ),
              ButtonSegment(
                value: true,
                label: Text(_text('Passés', 'السابقة')),
              ),
            ],
            selected: {_showPast},
            onSelectionChanged: (value) =>
                setState(() => _showPast = value.first),
          ),
        ),
        if (visibleAppointments.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _showPast
                    ? _text('Aucun rendez-vous passé.', 'لا توجد مواعيد سابقة.')
                    : _text(
                        'Aucun rendez-vous à venir.',
                        'لا توجد مواعيد قادمة.',
                      ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleAppointments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _appointmentCard(context, visibleAppointments[index]),
            ),
          ),
      ],
    );
  }

  // --- Vue Supervision (pour Admin & Personnel) ---
  Widget _buildSupervisionView() {
    final effectiveList = widget.appointments.isNotEmpty
        ? widget.appointments
        : _demoSupervisionAppointments;

    final visibleAppointments = _selectedServiceFilter == 'Tous'
        ? effectiveList
        : effectiveList
            .where((a) =>
                a.serviceName.toLowerCase() ==
                _selectedServiceFilter.toLowerCase())
            .toList();

    final now = DateTime.now();
    final todayList = effectiveList.where((a) {
      final t = a.status == AppointmentStatus.proposed
          ? a.proposedStartAt ?? a.startAt
          : a.startAt;
      return t.year == now.year && t.month == now.month && t.day == now.day;
    }).toList();

    final availableServices = <String>['Tous'];
    final knownServices = <String>{};
    for (final s in widget.services) {
      if (s.name != 'Médecin' && s.isActive && knownServices.add(s.name)) {
        availableServices.add(s.name);
      }
    }
    for (final a in effectiveList) {
      if (a.serviceName.isNotEmpty && knownServices.add(a.serviceName)) {
        availableServices.add(a.serviceName);
      }
    }
    if (availableServices.length <= 1) {
      availableServices.addAll(['Cardiologie', 'Chirurgie', 'Urgences', 'Pédiatrie']);
    }

    final countConsultations = todayList.isNotEmpty
        ? todayList.length
        : (effectiveList.length > 5 ? effectiveList.length : 128);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supervision des rendez-vous',
                    style: TextStyle(
                      color: Color(0xFF0F2537),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$countConsultations consultations prévues aujourd\'hui',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                border: Border.all(color: const Color(0xFFBAE6FD)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Aujourd\'hui',
                style: TextStyle(
                  color: Color(0xFF0284C7),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Service Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: availableServices.map((serviceName) {
              final isSelected =
                  _selectedServiceFilter.toLowerCase() == serviceName.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedServiceFilter = serviceName;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0F2537)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF0F2537)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      serviceName,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF334155),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Cards list
        if (visibleAppointments.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            child: const Text(
              'Aucun rendez-vous pour ce filtre.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          )
        else
          ...visibleAppointments.map((appointment) {
            return _buildSupervisionCard(appointment);
          }),
      ],
    );
  }

  Widget _buildSupervisionCard(Appointment appointment) {
    final timeStr =
        '${appointment.startAt.hour.toString().padLeft(2, '0')}:${appointment.startAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF0F2537),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Details column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.patientName,
                  style: const TextStyle(
                    color: Color(0xFF0F2537),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${appointment.serviceName} · ${appointment.doctorName}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Status badge
          _buildSupervisionStatusBadge(appointment),
        ],
      ),
    );
  }

  Widget _buildSupervisionStatusBadge(Appointment appointment) {
    final status = appointment.status;
    final (label, bg, border, text) = switch (status) {
      AppointmentStatus.inProgress => (
        'En cours',
        const Color(0xFFE0F2FE),
        const Color(0xFFBAE6FD),
        const Color(0xFF0284C7),
      ),
      AppointmentStatus.accepted => (
        'Confirmé',
        const Color(0xFFDCFCE7),
        const Color(0xFFBBF7D0),
        const Color(0xFF16A34A),
      ),
      AppointmentStatus.pending => (
        'En attente',
        const Color(0xFFFEF3C7),
        const Color(0xFFFDE68A),
        const Color(0xFFD97706),
      ),
      AppointmentStatus.cancelled => (
        'Annulé',
        const Color(0xFFFEE2E2),
        const Color(0xFFFECACA),
        const Color(0xFFDC2626),
      ),
      AppointmentStatus.rejected => (
        'Refusé',
        const Color(0xFFFEE2E2),
        const Color(0xFFFECACA),
        const Color(0xFFDC2626),
      ),
      AppointmentStatus.completed => (
        'Terminé',
        const Color(0xFFDCFCE7),
        const Color(0xFFBBF7D0),
        const Color(0xFF16A34A),
      ),
      AppointmentStatus.proposed => (
        'Proposé',
        const Color(0xFFF3E8FF),
        const Color(0xFFE9D5FF),
        const Color(0xFF7C3AED),
      ),
    };

    if (widget.isAdmin || widget.onDecision != null) {
      return PopupMenuButton<AppointmentStatus>(
        tooltip: 'Changer le statut',
        onSelected: (newStatus) => widget.onStatusChange(appointment, newStatus),
        itemBuilder: (_) => [
          for (final s in AppointmentStatus.values)
            PopupMenuItem(value: s, child: Text(s.label)),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  static List<Appointment> get _demoSupervisionAppointments {
    final now = DateTime.now();
    return [
      Appointment(
        id: 'demo-1',
        patientId: 'p1',
        patientName: 'M. Jean-Luc Bernard',
        doctorId: 'd1',
        doctorName: 'Dr. S. Moreau',
        serviceName: 'Cardiologie',
        serviceLocation: 'Bâtiment A · 2ème étage',
        servicePhone: '',
        serviceEmail: '',
        startAt: DateTime(now.year, now.month, now.day, 9, 0),
        reason: 'Consultation de suivi cardiologique',
        status: AppointmentStatus.inProgress,
      ),
      Appointment(
        id: 'demo-2',
        patientId: 'p2',
        patientName: 'Mme. Nadia Benali',
        doctorId: 'd2',
        doctorName: 'Dr. A. Perrin',
        serviceName: 'Chirurgie',
        serviceLocation: 'Bâtiment B · RDC',
        servicePhone: '',
        serviceEmail: '',
        startAt: DateTime(now.year, now.month, now.day, 9, 30),
        reason: 'Contrôle post-opératoire',
        status: AppointmentStatus.accepted,
      ),
      Appointment(
        id: 'demo-3',
        patientId: 'p3',
        patientName: 'Enfant Léo Martin',
        doctorId: 'd3',
        doctorName: 'Dr. C. Vasseur',
        serviceName: 'Pédiatrie',
        serviceLocation: 'Aile Sud · 1er étage',
        servicePhone: '',
        serviceEmail: '',
        startAt: DateTime(now.year, now.month, now.day, 10, 15),
        reason: 'Vaccination et contrôle annuel',
        status: AppointmentStatus.pending,
      ),
      Appointment(
        id: 'demo-4',
        patientId: 'p4',
        patientName: 'M. Thomas Dubois',
        doctorId: 'd4',
        doctorName: 'Dr. K. Mansouri',
        serviceName: 'Urgences',
        serviceLocation: 'Urgences Générales',
        servicePhone: '',
        serviceEmail: '',
        startAt: DateTime(now.year, now.month, now.day, 11, 0),
        reason: 'Traumatologie légère',
        status: AppointmentStatus.accepted,
      ),
      Appointment(
        id: 'demo-5',
        patientId: 'p5',
        patientName: 'Mme. Hélène Roy',
        doctorId: 'd5',
        doctorName: 'Dr. S. Moreau',
        serviceName: 'Cardiologie',
        serviceLocation: 'Bâtiment A · 2ème étage',
        servicePhone: '',
        serviceEmail: '',
        startAt: DateTime(now.year, now.month, now.day, 11, 45),
        reason: 'Électrocardiogramme',
        status: AppointmentStatus.cancelled,
      ),
    ];
  }

  Widget _appointmentCard(BuildContext context, Appointment appointment) {
    final canEdit = !{
      AppointmentStatus.cancelled,
      AppointmentStatus.rejected,
      AppointmentStatus.proposed,
    }.contains(appointment.status);
    final canCancel =
        widget.isPatient &&
        canEdit &&
        appointment.startAt.isAfter(DateTime.now());
    final displayedTime = appointment.status == AppointmentStatus.proposed
        ? appointment.proposedStartAt ?? appointment.startAt
        : appointment.startAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dateTimeLabel(displayedTime),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(
                  status: appointment.status,
                  isArabic: widget.isArabic,
                ),
                if ((widget.isAdmin ||
                        widget.canManageStatus ||
                        widget.onDecision != null) &&
                    appointment.status != AppointmentStatus.pending &&
                    canEdit)
                  PopupMenuButton<AppointmentStatus>(
                    tooltip: 'Modifier le statut',
                    onSelected: (status) =>
                        widget.onStatusChange(appointment, status),
                    itemBuilder: (_) => [
                      for (final status
                          in _nextStatuses(appointment.status).where(
                            (status) =>
                                widget.isAdmin ||
                                !widget.canManageStatus ||
                                status != AppointmentStatus.cancelled,
                          ))
                        PopupMenuItem(value: status, child: Text(status.label)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_text('Médecin', 'الطبيب')} : ${appointment.doctorName}'),
            if (appointment.serviceName.isNotEmpty)
              Text('${_text('Service', 'القسم')} : ${appointment.serviceName}'),
            if (appointment.serviceLocation.isNotEmpty)
              Text(
                '${_text('Lieu', 'المكان')} : ${appointment.serviceLocation}',
              ),
            if (!widget.isPatient && appointment.patientName.isNotEmpty)
              Text(
                '${_text('Patient', 'المريض')} : ${appointment.patientName}',
              ),
            const SizedBox(height: 4),
            if (appointment.reason.isNotEmpty)
              Text('${_text('Motif', 'السبب')} : ${appointment.reason}'),
            if (appointment.status == AppointmentStatus.proposed) ...[
              Text(
                _text(
                  'Un nouveau créneau vous est proposé.',
                  'تم اقتراح موعد جديد لك.',
                ),
              ),
              if (appointment.proposalNote.isNotEmpty)
                Text(appointment.proposalNote),
            ],
            if (appointment.status == AppointmentStatus.rejected &&
                appointment.rejectionReason.isNotEmpty)
              Text(
                '${_text('Motif du refus', 'سبب الرفض')} : ${appointment.rejectionReason}',
              ),
            if (appointment.isOverdue &&
                appointment.status == AppointmentStatus.pending)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _text(
                    'En attente depuis plus de 24 heures.',
                    'قيد الانتظار منذ أكثر من 24 ساعة.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFB3261E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (widget.isPatient) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showDetails(context, appointment),
                    icon: const Icon(Icons.info_outline),
                    label: Text(_text('Détails', 'التفاصيل')),
                  ),
                  if (canEdit && appointment.startAt.isAfter(DateTime.now()))
                    OutlinedButton.icon(
                      onPressed: () => widget.onEdit(appointment),
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: Text(_text('Reporter', 'تأجيل')),
                    ),
                  if (canCancel)
                    TextButton.icon(
                      onPressed: () => _confirmCancel(appointment),
                      icon: const Icon(Icons.event_busy_outlined),
                      label: Text(_text('Annuler', 'إلغاء')),
                    ),
                  if (appointment.serviceLocation.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _openDirections(context, appointment.serviceLocation),
                      icon: const Icon(Icons.directions_outlined),
                      label: Text(_text('Itinéraire', 'الاتجاهات')),
                    ),
                  if (appointment.status == AppointmentStatus.proposed &&
                      widget.onRespondProposal != null) ...[
                    FilledButton(
                      onPressed: () =>
                          widget.onRespondProposal!(appointment, true),
                      child: Text(_text('Accepter', 'قبول')),
                    ),
                    TextButton(
                      onPressed: () =>
                          widget.onRespondProposal!(appointment, false),
                      child: Text(_text('Refuser', 'رفض')),
                    ),
                  ],
                ],
              ),
            ] else if (appointment.status == AppointmentStatus.pending) ...[
              const SizedBox(height: 8),
              _secretaryActions(context, appointment),
            ] else if (canEdit && widget.isAdmin) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => widget.onEdit(appointment),
                icon: const Icon(Icons.edit_outlined),
                label: Text(_text('Modifier le rendez-vous', 'تعديل الموعد')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _secretaryActions(BuildContext context, Appointment appointment) {
    final claimedByMe = appointment.claimedBy == widget.currentUserId;
    final claimExpired =
        appointment.claimedAt == null ||
        DateTime.now().difference(appointment.claimedAt!) >
            const Duration(minutes: 15);
    if (!widget.isAdmin && !(claimedByMe && !claimExpired)) {
      if (appointment.claimedBy != null && !claimExpired) {
        return Text(
          '${_text('Prise en charge par', 'قيد المعالجة من قبل')} ${appointment.claimedByName}',
        );
      }
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.icon(
          onPressed: widget.onClaim == null
              ? null
              : () => widget.onClaim!(appointment),
          icon: const Icon(Icons.assignment_ind_outlined),
          label: Text(_text('Prendre en charge', 'تولي الطلب')),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilledButton.icon(
          onPressed: widget.onDecision == null
              ? null
              : () => widget.onDecision!(appointment, 'accept', null, null),
          icon: const Icon(Icons.check),
          label: Text(_text('Confirmer', 'تأكيد')),
        ),
        OutlinedButton.icon(
          onPressed: () => _rejectRequest(appointment),
          icon: const Icon(Icons.close),
          label: Text(_text('Refuser', 'رفض')),
        ),
        OutlinedButton.icon(
          onPressed: () => _proposeNewSlot(appointment),
          icon: const Icon(Icons.event_repeat_outlined),
          label: Text(_text('Proposer un créneau', 'اقتراح موعد')),
        ),
        if (!widget.isAdmin && widget.onRelease != null)
          TextButton(
            onPressed: () => widget.onRelease!(appointment),
            child: Text(_text('Libérer', 'تحرير الطلب')),
          ),
      ],
    );
  }

  Future<void> _rejectRequest(Appointment appointment) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        var value = '';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(_text('Refuser la demande', 'رفض الطلب')),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _text('Motif du refus', 'سبب الرفض'),
              ),
              onChanged: (text) => setDialogState(() => value = text.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_text('Retour', 'رجوع')),
              ),
              FilledButton(
                onPressed: value.isEmpty
                    ? null
                    : () => Navigator.pop(context, value),
                child: Text(_text('Confirmer le refus', 'تأكيد الرفض')),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    widget.onDecision?.call(appointment, 'reject', reason, null);
  }

  Future<void> _proposeNewSlot(Appointment appointment) async {
    final proposal = await showDialog<AppointmentProposal>(
      context: context,
      builder: (_) => AppointmentProposalDialog(
        appointment: appointment,
        isArabic: widget.isArabic,
      ),
    );
    if (proposal == null || !mounted) return;
    widget.onDecision?.call(
      appointment,
      'propose',
      proposal.reason,
      proposal.startAt,
    );
  }

  Future<void> _confirmCancel(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_text('Annuler le rendez-vous ?', 'إلغاء الموعد؟')),
        content: Text(
          _text(
            'Cette action ne peut pas être annulée.',
            'لا يمكن التراجع عن هذا الإجراء.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('Garder le rendez-vous', 'الاحتفاظ بالموعد')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('Annuler le rendez-vous', 'إلغاء الموعد')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onStatusChange(appointment, AppointmentStatus.cancelled);
    }
  }

  Future<void> _showDetails(
    BuildContext context,
    Appointment appointment,
  ) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(_text('Détails du rendez-vous', 'تفاصيل الموعد')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dateTimeLabel(
              appointment.status == AppointmentStatus.proposed
                  ? appointment.proposedStartAt ?? appointment.startAt
                  : appointment.startAt,
            ),
          ),
          Text('${_text('Médecin', 'الطبيب')} : ${appointment.doctorName}'),
          if (appointment.serviceName.isNotEmpty)
            Text('${_text('Service', 'القسم')} : ${appointment.serviceName}'),
          if (appointment.serviceLocation.isNotEmpty)
            Text('${_text('Lieu', 'المكان')} : ${appointment.serviceLocation}'),
          Text('${_text('Motif', 'السبب')} : ${appointment.reason}'),
          Text(
            '${_text('Statut', 'الحالة')} : ${_statusLabel(appointment.status, widget.isArabic)}',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_text('Fermer', 'إغلاق')),
        ),
      ],
    ),
  );

  Future<void> _openDirections(BuildContext context, String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text('Impossible d’ouvrir l’itinéraire.', 'تعذر فتح الاتجاهات.'),
          ),
        ),
      );
    }
  }
}

DateTime _appointmentListTime(Appointment appointment) =>
    appointment.status == AppointmentStatus.proposed
    ? appointment.proposedStartAt ?? appointment.startAt
    : appointment.startAt;

class AppointmentProposalDialog extends StatefulWidget {
  const AppointmentProposalDialog({
    super.key,
    required this.appointment,
    this.isArabic = false,
  });

  final Appointment appointment;
  final bool isArabic;

  @override
  State<AppointmentProposalDialog> createState() =>
      _AppointmentProposalDialogState();
}

class _AppointmentProposalDialogState extends State<AppointmentProposalDialog> {
  final _service = AppointmentService();
  final _noteController = TextEditingController();
  late DateTime _date = DateTime(
    widget.appointment.startAt.year,
    widget.appointment.startAt.month,
    widget.appointment.startAt.day,
  );
  List<DateTime> _slots = const [];
  DateTime? _selectedSlot;
  bool _loading = true;
  String? _error;
  int _request = 0;

  String _text(String french, String arabic) =>
      widget.isArabic ? arabic : french;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    final request = ++_request;
    final date = _date;
    setState(() {
      _loading = true;
      _error = null;
      _selectedSlot = null;
    });
    try {
      final slots = await _service.availableSlots(
        doctorId: widget.appointment.doctorId,
        date: date,
      );
      if (mounted &&
          request == _request &&
          date.year == _date.year &&
          date.month == _date.month &&
          date.day == _date.day) {
        setState(() => _slots = slots);
      }
    } on ApiException catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year, now.month, now.day)
          : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    setState(() => _date = DateTime(date.year, date.month, date.day));
    await _loadSlots();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_text('Proposer un autre créneau', 'اقتراح موعد آخر')),
    content: SizedBox(
      width: 420,
      height: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('${_text('Date', 'التاريخ')} : ${_dateLabel(_date)}'),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_slots.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _text(
                    'Aucun créneau libre pour ce médecin à cette date. Les créneaux passés ou déjà réservés ne sont pas affichés.',
                    'لا توجد مواعيد متاحة لهذا الطبيب في هذا اليوم. لا تظهر المواعيد الماضية أو المحجوزة.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in _slots)
                      ChoiceChip(
                        label: Text(
                          '${_twoDigits(slot.hour)}:${_twoDigits(slot.minute)}',
                        ),
                        selected:
                            _selectedSlot?.isAtSameMomentAs(slot) ?? false,
                        onSelected: (_) => setState(() => _selectedSlot = slot),
                      ),
                  ],
                ),
              ),
            ),
          TextField(
            controller: _noteController,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: _text(
                'Motif / note (facultatif)',
                'ملاحظة (اختيارية)',
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_text('Annuler', 'إلغاء')),
      ),
      FilledButton(
        onPressed: _selectedSlot == null
            ? null
            : () => Navigator.pop(
                context,
                AppointmentProposal(
                  startAt: _selectedSlot!,
                  reason: _noteController.text.trim(),
                ),
              ),
        child: Text(_text('Proposer', 'اقتراح')),
      ),
    ],
  );
}

class AppointmentProposal {
  const AppointmentProposal({required this.startAt, required this.reason});

  final DateTime startAt;
  final String reason;
}

enum PatientRecordType {
  all('Tout'),
  treatments('Traitements'),
  results('Résultats'),
  reports('Comptes rendus'),
  prescriptions('Ordonnances'),
  consultations('Consultations');

  const PatientRecordType(this.label);
  final String label;

  String labelFor(bool isArabic) => isArabic
      ? switch (this) {
          PatientRecordType.all => 'الكل',
          PatientRecordType.treatments => 'العلاجات',
          PatientRecordType.results => 'التحاليل',
          PatientRecordType.reports => 'التقارير',
          PatientRecordType.prescriptions => 'الوصفات الطبية',
          PatientRecordType.consultations => 'الاستشارات',
        }
      : label;
}

class PatientFollowUpsTab extends StatefulWidget {
  const PatientFollowUpsTab({
    super.key,
    required this.appointments,
    required this.onSelectAppointments,
    this.initialType = PatientRecordType.all,
    this.isArabic = false,
    this.prescriptions = const [],
  });

  final List<Appointment> appointments;
  final ValueChanged<PatientRecordType> onSelectAppointments;
  final PatientRecordType initialType;
  final bool isArabic;
  final List<Prescription> prescriptions;

  @override
  State<PatientFollowUpsTab> createState() => _PatientFollowUpsTabState();
}

class _PatientFollowUpsTabState extends State<PatientFollowUpsTab> {
  late PatientRecordType _type = widget.initialType;
  DateTimeRange? _dateRange;

  String _text(String french, String arabic) =>
      widget.isArabic ? arabic : french;

  @override
  void didUpdateWidget(covariant PatientFollowUpsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialType != widget.initialType) {
      _type = widget.initialType;
    }
  }

  Future<void> _selectDateRange() async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 2),
      initialDateRange: _dateRange,
    );
    if (range != null) setState(() => _dateRange = range);
  }

  @override
  Widget build(BuildContext context) {
    final nextAppointment = widget.appointments
        .where(
          (appointment) =>
              appointment.status != AppointmentStatus.cancelled &&
              appointment.startAt.isAfter(DateTime.now()),
        )
        .firstOrNull;
    final pastAppointments =
        widget.appointments
            .where(
              (appointment) => appointment.startAt.isBefore(DateTime.now()),
            )
            .where(
              (appointment) =>
                  _dateRange == null ||
                  (!appointment.startAt.isBefore(_dateRange!.start) &&
                      appointment.startAt.isBefore(
                        _dateRange!.end.add(const Duration(days: 1)),
                      )),
            )
            .toList()
          ..sort((left, right) => right.startAt.compareTo(left.startAt));
    final showConsultations =
        _type == PatientRecordType.all ||
        _type == PatientRecordType.consultations;
    final showPrescriptions =
        _type == PatientRecordType.all ||
        _type == PatientRecordType.prescriptions;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionIntro(
          title: _text('Mes suivis', 'متابعتي الصحية'),
          subtitle: _text(
            'Retrouvez vos documents de santé et l’historique de vos consultations.',
            'اطلع على ملفاتك الصحية وسجل الاستشارات.',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in PatientRecordType.values)
              ChoiceChip(
                label: Text(type.labelFor(widget.isArabic)),
                selected: _type == type,
                onSelected: (_) => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _selectDateRange,
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            _dateRange == null
                ? _text('Filtrer par date', 'تصفية حسب التاريخ')
                : '${_dateLabel(_dateRange!.start)} – ${_dateLabel(_dateRange!.end)}',
          ),
        ),
        if (_dateRange != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => setState(() => _dateRange = null),
              child: Text(_text('Effacer le filtre', 'مسح التصفية')),
            ),
          ),
        if (showConsultations) ...[
          const SizedBox(height: 18),
          Text(
            _text('Historique des consultations', 'سجل الاستشارات'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (pastAppointments.isEmpty)
            _EmptyRecordCard(
              icon: Icons.history,
              message: _text(
                'Aucune consultation passée disponible.',
                'لا توجد استشارات سابقة.',
              ),
            )
          else
            for (final appointment in pastAppointments)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.medical_services_outlined),
                  ),
                  title: Text(appointment.doctorName),
                  subtitle: Text(
                    '${_dateTimeLabel(appointment.startAt)}\n'
                    '${appointment.serviceName.isEmpty ? _text('Service non renseigné', 'القسم غير محدد') : appointment.serviceName}',
                  ),
                  isThreeLine: true,
                  trailing: _StatusChip(
                    status: appointment.status,
                    isArabic: widget.isArabic,
                  ),
                ),
              ),
        ],
        if (_type != PatientRecordType.consultations && !showPrescriptions) ...[
          const SizedBox(height: 18),
          _EmptyRecordCard(
            icon: _recordIcon(_type),
            message: _emptyRecordMessage(_type, widget.isArabic),
          ),
        ],
        if (showPrescriptions) ...[
          const SizedBox(height: 18),
          Text(
            _text('Mes ordonnances', 'وصفاتي الطبية'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.navy, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (widget.prescriptions.isEmpty)
            _EmptyRecordCard(
              icon: Icons.receipt_long_outlined,
              message: _text(
                'Aucune ordonnance disponible.',
                'لا توجد وصفات طبية متاحة.',
              ),
            )
          else
            for (final prescription in widget.prescriptions)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    prescription.medications
                        .map(
                          (item) =>
                              '${item.name}${item.dosage.isEmpty ? '' : ' ${item.dosage}'} x${item.quantity}',
                        )
                        .join(', '),
                  ),
                  subtitle: Text(
                    '${_prescriptionStatusLabel(prescription.status, widget.isArabic)}'
                    '${prescription.rejectionReason.isEmpty ? '' : '\n${prescription.rejectionReason}'}',
                  ),
                ),
              ),
        ],
        const SizedBox(height: 18),
        InfoCard(
          icon: _statusIcon(AppointmentStatus.pending),
          title: _text('Rendez-vous en attente', 'المواعيد قيد الانتظار'),
          value:
              '${widget.appointments.where((appointment) => appointment.status == AppointmentStatus.pending).length}',
          color: _statusColor(AppointmentStatus.pending),
        ),
        const SizedBox(height: 10),
        InfoCard(
          icon: Icons.event_available_outlined,
          title: _text('Prochain rendez-vous', 'الموعد القادم'),
          value: nextAppointment == null
              ? _text('Aucun rendez-vous à venir', 'لا توجد مواعيد قادمة')
              : '${nextAppointment.doctorName} · ${_dateTimeLabel(nextAppointment.startAt)}',
          color: AppColors.blue,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => widget.onSelectAppointments(_type),
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(_text('Voir mes rendez-vous', 'عرض مواعيدي')),
        ),
      ],
    );
  }
}

class _EmptyRecordCard extends StatelessWidget {
  const _EmptyRecordCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF687B86)),
            ),
          ),
        ],
      ),
    ),
  );
}

IconData _recordIcon(PatientRecordType type) => switch (type) {
  PatientRecordType.all => Icons.folder_open_outlined,
  PatientRecordType.treatments => Icons.medication_outlined,
  PatientRecordType.results => Icons.science_outlined,
  PatientRecordType.reports => Icons.article_outlined,
  PatientRecordType.prescriptions => Icons.receipt_long_outlined,
  PatientRecordType.consultations => Icons.history,
};

String _emptyRecordMessage(PatientRecordType type, bool isArabic) => isArabic
    ? switch (type) {
        PatientRecordType.all => 'لا توجد ملفات طبية متاحة حالياً.',
        PatientRecordType.treatments => 'لا توجد علاجات مسجلة حالياً.',
        PatientRecordType.results => 'لا توجد نتائج تحاليل متاحة.',
        PatientRecordType.reports => 'لا توجد تقارير متاحة.',
        PatientRecordType.prescriptions => 'لا توجد وصفات طبية متاحة.',
        PatientRecordType.consultations => 'لا توجد استشارات سابقة.',
      }
    : switch (type) {
        PatientRecordType.all =>
          'Aucun document médical disponible pour le moment.',
        PatientRecordType.treatments => 'Aucun traitement en cours disponible.',
        PatientRecordType.results => 'Aucun résultat d’analyse disponible.',
        PatientRecordType.reports => 'Aucun compte rendu disponible.',
        PatientRecordType.prescriptions => 'Aucune ordonnance disponible.',
        PatientRecordType.consultations =>
          'Aucune consultation passée disponible.',
      };

String _prescriptionStatusLabel(PrescriptionStatus status, bool isArabic) =>
    isArabic
    ? switch (status) {
        PrescriptionStatus.pending => 'قيد انتظار الصيدلية',
        PrescriptionStatus.validated => 'تمت المصادقة',
        PrescriptionStatus.dispensed => 'تم الصرف',
        PrescriptionStatus.rejected => 'مرفوضة',
      }
    : switch (status) {
        PrescriptionStatus.pending => 'En attente de la pharmacie',
        PrescriptionStatus.validated => 'Validée par la pharmacie',
        PrescriptionStatus.dispensed => 'Délivrée',
        PrescriptionStatus.rejected => 'Refusée',
      };

class SecretaryHomeTab extends StatelessWidget {
  const SecretaryHomeTab({
    super.key,
    required this.userName,
    required this.pendingCount,
    required this.onOpenAppointments,
    this.overdueCount = 0,
  });

  final String userName;
  final int pendingCount;
  final VoidCallback onOpenAppointments;
  final int overdueCount;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      SectionIntro(
        title: 'Bonjour $userName',
        subtitle: 'Gérez les demandes de rendez-vous des patients.',
      ),
      const SizedBox(height: 18),
      InfoCard(
        icon: Icons.pending_actions_outlined,
        title: 'En attente',
        value: '$pendingCount',
        color: AppColors.blue,
      ),
      if (overdueCount > 0) ...[
        const SizedBox(height: 10),
        Card(
          color: const Color(0xFFFFF1F0),
          child: ListTile(
            leading: const Icon(
              Icons.notification_important_outlined,
              color: Color(0xFFB3261E),
            ),
            title: Text(
              '$overdueCount demande(s) en attente depuis plus de 24 heures.',
              style: const TextStyle(
                color: Color(0xFF8C1D18),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: onOpenAppointments,
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Gérer les rendez-vous'),
      ),
    ],
  );
}

class AppointmentFormDialog extends StatefulWidget {
  const AppointmentFormDialog({
    super.key,
    this.appointment,
    this.isArabic = false,
  });

  final Appointment? appointment;
  final bool isArabic;

  @override
  State<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String _text(String french, String arabic) =>
      widget.isArabic ? arabic : french;
  late final TextEditingController _reasonController = TextEditingController(
    text: widget.appointment?.reason ?? '',
  );
  final _appointmentService = AppointmentService();
  String? _specialty;
  late String? _doctorId;
  late DateTime _date = _initialDate();
  DateTime? _slot;
  List<AppointmentDoctor> _availableDoctors = const [];
  List<DateTime> _slots = const [];
  int _step = 0;
  bool _isLoadingDoctors = false;
  bool _isLoadingSlots = false;
  String? _error;
  int _doctorRequest = 0;
  int _slotRequest = 0;

  @override
  void initState() {
    super.initState();
    _doctorId = widget.appointment?.doctorId;
    _loadDoctors();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  List<String> get _specialties =>
      _availableDoctors
          .map((doctor) => doctor.specialty.trim())
          .where((specialty) => specialty.isNotEmpty)
          .toSet()
          .toList()
        ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
        );

  List<AppointmentDoctor> get _doctors => _availableDoctors
      .where((doctor) => doctor.specialty.trim() == _specialty)
      .toList();

  DateTime _initialDate() {
    final appointmentDate = widget.appointment?.startAt;
    if (appointmentDate != null) {
      return DateTime(
        appointmentDate.year,
        appointmentDate.month,
        appointmentDate.day,
      );
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadDoctors() async {
    final request = ++_doctorRequest;
    setState(() {
      _isLoadingDoctors = true;
      _error = null;
      _availableDoctors = const [];
      _slots = const [];
      _slot = null;
    });
    try {
      final doctors = await _appointmentService.listDoctors();
      if (!mounted || request != _doctorRequest) return;
      final selectedDoctor = doctors
          .where((doctor) => doctor.id == _doctorId)
          .firstOrNull;
      setState(() {
        _availableDoctors = doctors;
        _specialty =
            selectedDoctor?.specialty ??
            (_specialties.contains(_specialty)
                ? _specialty
                : _specialties.firstOrNull);
        final specialtyDoctors = _doctors;
        if (!specialtyDoctors.any((doctor) => doctor.id == _doctorId)) {
          _doctorId = specialtyDoctors.firstOrNull?.id;
        }
      });
    } on ApiException catch (error) {
      if (mounted && request == _doctorRequest) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _doctorRequest) {
        setState(() => _isLoadingDoctors = false);
      }
    }
  }

  Future<void> _loadSlots() async {
    final doctorId = _doctorId;
    if (doctorId == null) return;
    final request = ++_slotRequest;
    final date = _date;
    setState(() {
      _isLoadingSlots = true;
      _error = null;
      _slots = const [];
      _slot = null;
    });
    try {
      final slots = await _appointmentService.availableSlots(
        doctorId: doctorId,
        date: date,
      );
      if (!mounted ||
          request != _slotRequest ||
          doctorId != _doctorId ||
          !_sameDay(date, _date)) {
        return;
      }
      if (widget.appointment?.doctorId == doctorId &&
          _sameDay(widget.appointment!.startAt, _date) &&
          !slots.any(
            (slot) => slot.isAtSameMomentAs(widget.appointment!.startAt),
          )) {
        slots.add(widget.appointment!.startAt);
        slots.sort();
      }
      setState(() {
        _slots = slots;
        if (widget.appointment != null) {
          _slot = slots
              .where(
                (slot) => slot.isAtSameMomentAs(widget.appointment!.startAt),
              )
              .firstOrNull;
        }
      });
    } on ApiException catch (error) {
      if (mounted && request == _slotRequest) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _slotRequest) {
        setState(() => _isLoadingSlots = false);
      }
    }
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year, now.month, now.day)
          : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _date = DateTime(selected.year, selected.month, selected.day);
      _slot = null;
    });
    if (_step == 2) await _loadSlots();
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (_specialty == null) return;
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_doctorId == null) return;
      setState(() => _step = 2);
      await _loadSlots();
      return;
    }
    if (_step == 2) {
      if (_slot == null) return;
      setState(() => _step = 3);
      return;
    }
    _save();
  }

  void _save() {
    if (_doctorId == null || _slot == null) return;
    Navigator.of(context).pop(
      AppointmentDraft(
        doctorId: _doctorId!,
        startAt: _slot!,
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.appointment != null;
    final steps = [
      _text('Spécialité', 'التخصص'),
      _text('Médecin', 'الطبيب'),
      _text('Créneau', 'الموعد'),
      _text('Confirmation', 'التأكيد'),
    ];
    return AlertDialog(
      title: Text(
        editing
            ? _text('Modifier le rendez-vous', 'تعديل الموعد')
            : _text('Prendre un rendez-vous', 'حجز موعد'),
      ),
      content: SizedBox(
        width: 480,
        height: 390,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_step + 1}/4 · ${steps[_step]}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_step + 1) / 4),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(child: _stepContent()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_text('Fermer', 'إغلاق')),
        ),
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: Text(_text('Retour', 'رجوع')),
          ),
        FilledButton(
          onPressed: _canAdvance ? _next : null,
          child: Text(
            _step == 3
                ? _text('Envoyer la demande', 'إرسال الطلب')
                : _text('Continuer', 'متابعة'),
          ),
        ),
      ],
    );
  }

  bool get _canAdvance => switch (_step) {
    0 => !_isLoadingDoctors && _specialty != null,
    1 => !_isLoadingDoctors && _doctorId != null,
    2 => !_isLoadingSlots && _slot != null,
    _ => true,
  };

  Widget _stepContent() => switch (_step) {
    0 => _specialtyStep(),
    1 => _doctorStep(),
    2 => _slotStep(),
    _ => _confirmationStep(),
  };

  Widget _specialtyStep() {
    if (_isLoadingDoctors) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_specialties.isEmpty) {
      return Center(
        child: Text(
          _text(
            'Aucun médecin réservable. Vérifiez qu’un médecin actif est '
                'affecté à cette spécialité, que le service est actif et que '
                '« Rendez-vous » est activé.',
            'لا يوجد طبيب متاح للحجز. تحقق من تعيين طبيب نشط لهذا التخصص، '
                'ومن تفعيل القسم وخيار «المواعيد».',
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView(
      children: [
        for (final specialty in _specialties)
          Card(
            child: ListTile(
              title: Text(specialty),
              trailing: _specialty == specialty
                  ? const Icon(Icons.check_circle, color: AppColors.blue)
                  : const Icon(Icons.circle_outlined),
              onTap: () {
                if (_specialty == specialty) return;
                setState(() {
                  _specialty = specialty;
                  _doctorId = _doctors.firstOrNull?.id;
                  _slot = null;
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _doctorStep() {
    if (_isLoadingDoctors) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_doctors.isEmpty) {
      return Center(
        child: Text(
          _text(
            'Aucun médecin disponible pour cette spécialité.',
            'لا يوجد طبيب متاح لهذا التخصص.',
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView(
      children: [
        for (final doctor in _doctors)
          Card(
            child: ListTile(
              selected: _doctorId == doctor.id,
              leading: _doctorAvatar(doctor),
              title: Text(doctor.name),
              subtitle: Text(doctor.specialty),
              trailing: _doctorId == doctor.id
                  ? const Icon(Icons.check_circle, color: AppColors.blue)
                  : null,
              onTap: () => setState(() {
                _doctorId = doctor.id;
                _slot = null;
              }),
            ),
          ),
      ],
    );
  }

  Widget _doctorAvatar(AppointmentDoctor doctor) {
    final initials = doctor.name.trim().isEmpty
        ? '?'
        : doctor.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0])
              .join();
    return CircleAvatar(
      backgroundColor: const Color(0xFFE1F2EF),
      child: doctor.photoUrl.isEmpty
          ? Text(initials)
          : ClipOval(
              child: Image.network(
                doctor.photoUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(initials),
              ),
            ),
    );
  }

  Widget _slotStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: _chooseDate,
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text('${_text('Date', 'التاريخ')} : ${_dateLabel(_date)}'),
      ),
      const SizedBox(height: 10),
      if (_isLoadingSlots)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_slots.isEmpty)
        Expanded(
          child: Center(
            child: Text(
              _text(
                'Aucun créneau disponible à cette date.',
                'لا توجد مواعيد متاحة في هذا اليوم.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        )
      else
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in _slots)
                  ChoiceChip(
                    label: Text(
                      '${_twoDigits(slot.hour)}:${_twoDigits(slot.minute)}',
                    ),
                    selected: _slot?.isAtSameMomentAs(slot) ?? false,
                    onSelected: (_) => setState(() => _slot = slot),
                  ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _confirmationStep() {
    final doctor = _doctors.where((item) => item.id == _doctorId).firstOrNull;
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text('${_text('Spécialité', 'التخصص')} : ${_specialty ?? ''}'),
          Text('${_text('Médecin', 'الطبيب')} : ${doctor?.name ?? ''}'),
          Text(
            '${_text('Date et heure', 'التاريخ والوقت')} : ${_slot == null ? '' : _dateTimeLabel(_slot!)}',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reasonController,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _text('Motif (facultatif)', 'السبب (اختياري)'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _text(
              'Votre demande sera envoyée avec le statut « En attente ». ',
              'سيتم إرسال طلبك بحالة « قيد الانتظار ». ',
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class AppointmentDraft {
  const AppointmentDraft({
    required this.doctorId,
    required this.startAt,
    required this.reason,
  });

  final String doctorId;
  final DateTime startAt;
  final String reason;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.isArabic = false});

  final AppointmentStatus status;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(_statusLabel(status, isArabic)),
    backgroundColor: _statusColor(status).withValues(alpha: 0.12),
    labelStyle: TextStyle(
      color: _statusColor(status),
      fontWeight: FontWeight.w600,
    ),
    visualDensity: VisualDensity.compact,
  );
}

String _statusLabel(AppointmentStatus status, bool isArabic) => isArabic
    ? switch (status) {
        AppointmentStatus.pending => 'قيد الانتظار',
        AppointmentStatus.accepted => 'مؤكد',
        AppointmentStatus.inProgress => 'جارٍ',
        AppointmentStatus.proposed => 'اقتُرح موعد جديد',
        AppointmentStatus.rejected => 'مرفوض',
        AppointmentStatus.cancelled => 'ملغى',
        AppointmentStatus.completed => 'منتهي',
      }
    : status.label;

List<AppointmentStatus> _nextStatuses(AppointmentStatus current) =>
    switch (current) {
      AppointmentStatus.pending => [
        AppointmentStatus.accepted,
        AppointmentStatus.cancelled,
      ],
      AppointmentStatus.accepted => [
        AppointmentStatus.inProgress,
        AppointmentStatus.cancelled,
      ],
      AppointmentStatus.inProgress => [
        AppointmentStatus.completed,
        AppointmentStatus.cancelled,
      ],
      AppointmentStatus.proposed => const [],
      AppointmentStatus.rejected => const [],
      AppointmentStatus.cancelled => const [],
      AppointmentStatus.completed => const [],
    };

Color _statusColor(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => const Color(0xFFC17A00),
  AppointmentStatus.accepted => AppColors.blue,
  AppointmentStatus.inProgress => AppColors.mint,
  AppointmentStatus.proposed => AppColors.blue,
  AppointmentStatus.rejected => const Color(0xFFB3261E),
  AppointmentStatus.cancelled => const Color(0xFF8797A0),
  AppointmentStatus.completed => const Color(0xFF2E7D32),
};

IconData _statusIcon(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => Icons.pending_actions_outlined,
  AppointmentStatus.accepted => Icons.event_available_outlined,
  AppointmentStatus.inProgress => Icons.medical_services_outlined,
  AppointmentStatus.proposed => Icons.event_repeat_outlined,
  AppointmentStatus.rejected => Icons.event_busy_outlined,
  AppointmentStatus.cancelled => Icons.event_busy_outlined,
  AppointmentStatus.completed => Icons.check_circle_outline,
};

String _dateTimeLabel(DateTime value) =>
    '${_dateLabel(value)} · ${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';

String _dateLabel(DateTime value) =>
    '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

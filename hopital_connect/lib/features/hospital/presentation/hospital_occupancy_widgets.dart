import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/hospital_occupancy.dart';
import '../domain/hospital_resources.dart';
import '../../services/domain/hospital_service.dart';

class OccupancyStatsRow extends StatelessWidget {
  const OccupancyStatsRow({super.key, required this.summary});

  final BedOccupancySummary summary;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _OccupancyStat(
          title: 'Lits occupés',
          value: '${summary.occupied}',
          icon: Icons.bed,
          color: AppColors.blue,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _OccupancyStat(
          title: 'Lits libres',
          value: '${summary.free}',
          icon: Icons.bed_outlined,
          color: AppColors.mint,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _OccupancyStat(
          title: 'Occupation',
          value: '${summary.percentage}%',
          icon: Icons.pie_chart_outline,
          color: AppColors.navy,
        ),
      ),
    ],
  );
}

class _OccupancyStat extends StatelessWidget {
  const _OccupancyStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF536873),
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.saturatedServicesCount});

  final int saturatedServicesCount;

  @override
  Widget build(BuildContext context) {
    final serviceLabel = saturatedServicesCount == 1
        ? 'service presque saturé'
        : 'services presque saturés';
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD99054)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFF8A3B12)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$saturatedServicesCount $serviceLabel',
                style: const TextStyle(
                  color: Color(0xFF71320F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceOccupancyCard extends StatelessWidget {
  const ServiceOccupancyCard({
    super.key,
    required this.occupancy,
    required this.onTap,
  });

  final ServiceOccupancy occupancy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = switch (occupancy.level) {
      OccupancyLevel.normal => (
        label: 'Normal',
        icon: Icons.check_circle_outline,
        color: const Color(0xFF176B4D),
      ),
      OccupancyLevel.attention => (
        label: 'Attention',
        icon: Icons.error_outline,
        color: const Color(0xFF805400),
      ),
      OccupancyLevel.saturated => (
        label: 'Saturé',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFB3261E),
      ),
    };

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_hospital_outlined,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      occupancy.service.name,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${occupancy.summary.percentage}%',
                    style: TextStyle(
                      color: status.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${occupancy.summary.occupied} / ${occupancy.summary.total} lits occupés',
                    style: const TextStyle(color: Color(0xFF536873)),
                  ),
                  const Spacer(),
                  Icon(status.icon, size: 18, color: status.color),
                  const SizedBox(width: 4),
                  Text(
                    status.label,
                    style: TextStyle(
                      color: status.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                label:
                    'Occupation du service ${occupancy.service.name} : ${occupancy.summary.percentage} pour cent, ${status.label}',
                child: LinearProgressIndicator(
                  value: occupancy.summary.rate,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: status.color,
                  backgroundColor: const Color(0xFFE6ECEE),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Voir les chambres et lits',
                  style: TextStyle(color: AppColors.blue, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HospitalLoadingSkeleton extends StatelessWidget {
  const HospitalLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SkeletonBlock(width: 220, height: 24),
          const SizedBox(height: 10),
          const _SkeletonBlock(width: 300, height: 18),
          const SizedBox(height: 24),
          Row(
            children: [
              for (var index = 0; index < 3; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                const Expanded(child: _SkeletonBlock(height: 102)),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const _SkeletonBlock(width: 180, height: 20),
          const SizedBox(height: 12),
          for (var index = 0; index < 3; index++) ...[
            const _SkeletonBlock(height: 100),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE2E9EC),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bed_outlined, size: 42, color: AppColors.blue),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.meeting_room_outlined),
            label: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: Color(0xFFB3261E),
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

class ServiceDetailSheet extends StatelessWidget {
  const ServiceDetailSheet({super.key, required this.occupancy});

  final ServiceOccupancy occupancy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            occupancy.service.name,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${occupancy.summary.occupied} occupés · ${occupancy.summary.free} libres · ${occupancy.summary.total} au total',
            style: const TextStyle(color: Color(0xFF536873)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: occupancy.rooms.isEmpty
                ? const Center(
                    child: Text('Aucune chambre rattachée à ce service.'),
                  )
                : ListView(
                    children: [
                      for (final room in occupancy.rooms)
                        _RoomBedsDetail(
                          room: room,
                          beds: occupancy.beds
                              .where((bed) => bed.roomId == room.id)
                              .toList(),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoomBedsDetail extends StatelessWidget {
  const _RoomBedsDetail({required this.room, required this.beds});

  final HospitalRoom room;
  final List<HospitalBed> beds;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text('Chambre ${room.number}'),
      subtitle: Text(
        '${room.type.label} · Etage ${room.floor} · ${room.status.label}',
      ),
      children: [
        if (beds.isEmpty)
          const ListTile(title: Text('Aucun lit enregistré'))
        else
          for (final bed in beds)
            ListTile(
              leading: Icon(
                bed.status == BedStatus.occupied
                    ? Icons.bed
                    : Icons.bed_outlined,
              ),
              title: Text('Lit ${bed.number} · ${bed.status.label}'),
            ),
      ],
    ),
  );
}

class RoomBedsStatusBar extends StatelessWidget {
  const RoomBedsStatusBar({
    super.key,
    required this.freeCount,
    required this.occupiedCount,
    required this.cleaningCount,
    required this.reservedCount,
    required this.services,
    this.lockServiceFilter = false,
    required this.floors,
    required this.selectedServiceId,
    required this.onServiceChanged,
    required this.selectedFloor,
    required this.onFloorChanged,
    required this.onlyAvailable,
    required this.onOnlyAvailableChanged,
    required this.onlyReserved,
    required this.onOnlyReservedChanged,
  });

  final int freeCount;
  final int occupiedCount;
  final int cleaningCount;
  final int reservedCount;
  final List<HospitalService> services;
  final bool lockServiceFilter;
  final List<String> floors;
  final String? selectedServiceId;
  final ValueChanged<String?> onServiceChanged;
  final String? selectedFloor;
  final ValueChanged<String?> onFloorChanged;
  final bool onlyAvailable;
  final ValueChanged<bool> onOnlyAvailableChanged;
  final bool onlyReserved;
  final ValueChanged<bool> onOnlyReservedChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F9),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E9ED)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _RoomStatusCount(
          label: 'Disponibles',
          count: freeCount,
          color: const Color(0xFF168B7D),
        ),
        _RoomStatusCount(
          label: 'Occupés',
          count: occupiedCount,
          color: const Color(0xFFE83E5B),
        ),
        _RoomStatusCount(
          label: 'Nettoyage',
          count: cleaningCount,
          color: const Color(0xFFDB8A00),
        ),
        if (reservedCount > 0)
          _RoomStatusCount(
            label: 'Réservés',
            count: reservedCount,
            color: const Color(0xFF7956A8),
          ),
        if (services.isNotEmpty || !lockServiceFilter)
          SizedBox(
            width: 190,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedServiceId ?? '',
                borderRadius: BorderRadius.circular(12),
                items: [
                  if (!lockServiceFilter)
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Tous les services'),
                    ),
                  for (final service in services)
                    DropdownMenuItem(
                      value: service.id,
                      child: Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: lockServiceFilter
                    ? null
                    : (value) => onServiceChanged(
                        value == null || value.isEmpty ? null : value,
                      ),
              ),
            ),
          ),
        SizedBox(
          width: 150,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedFloor ?? '',
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Tous les étages'),
                ),
                for (final floor in floors)
                  DropdownMenuItem(
                    value: floor,
                    child: Text(
                      floor.toLowerCase() == 'rdc' ? 'RDC' : 'Etage $floor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  onFloorChanged(value == null || value.isEmpty ? null : value),
            ),
          ),
        ),
        FilterChip(
          avatar: const Icon(Icons.filter_alt_outlined, size: 18),
          label: const Text('Lits dispo uniquement'),
          selected: onlyAvailable,
          showCheckmark: false,
          onSelected: onOnlyAvailableChanged,
        ),
        FilterChip(
          avatar: const Icon(Icons.event_available_outlined, size: 18),
          label: const Text('Lits réservés'),
          selected: onlyReserved,
          showCheckmark: false,
          onSelected: onOnlyReservedChanged,
        ),
      ],
    ),
  );
}

class _RoomStatusCount extends StatelessWidget {
  const _RoomStatusCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label : $count',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$label : '),
        Text(
          '$count',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class RoomBedCard extends StatelessWidget {
  const RoomBedCard({
    super.key,
    required this.room,
    required this.hospitalName,
    required this.serviceName,
    required this.beds,
    required this.displayedBeds,
    required this.canManage,
    this.canChangeBedStatus = false,
    this.canAssignPatient = false,
    required this.onAddBed,
    required this.onEditRoom,
    required this.onDeleteRoom,
    required this.onEditBed,
    required this.onAssignBed,
    required this.onReleaseBed,
    required this.onDeleteBed,
    required this.userName,
  });

  final HospitalRoom room;
  final String hospitalName;
  final String serviceName;
  final List<HospitalBed> beds;
  final List<HospitalBed> displayedBeds;
  final bool canManage;
  final bool canChangeBedStatus;
  final bool canAssignPatient;
  final VoidCallback onAddBed;
  final VoidCallback onEditRoom;
  final VoidCallback onDeleteRoom;
  final ValueChanged<HospitalBed> onEditBed;
  final ValueChanged<HospitalBed> onAssignBed;
  final ValueChanged<HospitalBed> onReleaseBed;
  final ValueChanged<HospitalBed> onDeleteBed;
  final String Function(String id) userName;

  @override
  Widget build(BuildContext context) {
    final freeCount = beds.where((bed) => bed.status == BedStatus.free).length;
    final hasFreeBeds = freeCount > 0;
    final capacityReached = beds.length >= room.bedCapacity;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E8ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chambre ${room.number}',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$serviceName · Etage ${room.floor} · ${room.type.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF536873),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasFreeBeds
                      ? const Color(0xFFD8F6F0)
                      : const Color(0xFFFFE6EA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$freeCount/${room.bedCapacity} dispo',
                  style: TextStyle(
                    color: hasFreeBeds
                        ? const Color(0xFF08796E)
                        : const Color(0xFFB32645),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Actions sur la chambre',
                  onSelected: (action) {
                    if (action == 'edit') onEditRoom();
                    if (action == 'delete') onDeleteRoom();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (displayedBeds.isEmpty)
                    SizedBox(
                      width: tileWidth,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Aucun lit dans cette chambre.'),
                      ),
                    ),
                  for (final bed in displayedBeds)
                    SizedBox(
                      width: tileWidth,
                      child: _BedStatusTile(
                        bed: bed,
                        canManage: canManage,
                        canChangeBedStatus: canChangeBedStatus,
                        canAssignPatient: canAssignPatient,
                        patientName: bed.patientId == null
                            ? null
                            : userName(bed.patientId!),
                        onEdit: () => onEditBed(bed),
                        onAssign: () => onAssignBed(bed),
                        onRelease: () => onReleaseBed(bed),
                        onDelete: () => onDeleteBed(bed),
                      ),
                    ),
                  if (canManage && !capacityReached)
                    SizedBox(
                      width: tileWidth,
                      child: _AddBedTile(onTap: onAddBed),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                hospitalName,
                style: const TextStyle(color: Color(0xFF718493), fontSize: 12),
              ),
              if (canManage)
                Text(
                  capacityReached
                      ? 'Capacité maximale atteinte (${room.bedCapacity} lit${room.bedCapacity > 1 ? 's' : ''})'
                      : 'Cliquer sur un lit pour éditer',
                  style: const TextStyle(
                    color: Color(0xFF718493),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BedStatusTile extends StatelessWidget {
  const _BedStatusTile({
    required this.bed,
    required this.canManage,
    required this.canChangeBedStatus,
    required this.canAssignPatient,
    required this.patientName,
    required this.onEdit,
    required this.onAssign,
    required this.onRelease,
    required this.onDelete,
  });

  final HospitalBed bed;
  final bool canManage;
  final bool canChangeBedStatus;
  final bool canAssignPatient;
  final String? patientName;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onRelease;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final style = switch (bed.status) {
      BedStatus.free => (
        label: 'Disponible',
        icon: Icons.bed_outlined,
        foreground: const Color(0xFF08796E),
        background: const Color(0xFFECF9F6),
      ),
      BedStatus.occupied => (
        label: patientName?.isNotEmpty == true ? patientName! : 'Occupé',
        icon: Icons.bed,
        foreground: const Color(0xFFD92347),
        background: const Color(0xFFFFF0F2),
      ),
      BedStatus.cleaning => (
        label: 'Nettoyage',
        icon: Icons.cleaning_services_outlined,
        foreground: const Color(0xFFB06A00),
        background: const Color(0xFFFFF9E9),
      ),
      BedStatus.reserved => (
        label: 'Réservé',
        icon: Icons.event_available_outlined,
        foreground: const Color(0xFF7956A8),
        background: const Color(0xFFF4EFFA),
      ),
    };

    return Material(
      color: style.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: canChangeBedStatus && (bed.patientId == null || canManage)
            ? onEdit
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lit ${bed.number}',
                      style: TextStyle(
                        color: style.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(style.icon, color: style.foreground, size: 18),
                  if (canManage ||
                      canAssignPatient ||
                      (canChangeBedStatus && bed.patientId == null))
                    PopupMenuButton<String>(
                      tooltip: 'Actions sur le lit ${bed.number}',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onSelected: (action) {
                        if (action == 'edit') onEdit();
                        if (action == 'assign') onAssign();
                        if (action == 'release') onRelease();
                        if (action == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        if (canManage ||
                            (canChangeBedStatus && bed.patientId == null))
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Changer le statut'),
                          ),
                        if (canAssignPatient && bed.status == BedStatus.free)
                          const PopupMenuItem(
                            value: 'assign',
                            child: Text('Affecter un patient'),
                          ),
                        if (canAssignPatient && bed.patientId != null)
                          const PopupMenuItem(
                            value: 'release',
                            child: Text('Libérer le lit'),
                          ),
                        if (canManage)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Supprimer'),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                style.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: style.foreground, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddBedTile extends StatelessWidget {
  const _AddBedTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCFDCE3)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.blue, size: 20),
            Text(
              'Ajouter un lit',
              style: TextStyle(color: AppColors.blue, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';

bool canViewHospitalResources(StaffUser user) => user.role != StaffRole.patient;

bool canManageRooms(StaffUser user) =>
    user.role == StaffRole.administrator || user.role == StaffRole.serviceHead;

bool canManageBeds(StaffUser user) => canManageRooms(user);

bool canChangeBedStatus(StaffUser user) =>
    canManageBeds(user) ||
    user.role == StaffRole.doctor ||
    user.role == StaffRole.nurse;

bool canAssignPatient(StaffUser user) =>
    canManageBeds(user) || user.role == StaffRole.nurse;

bool canManageOperatingRooms(StaffUser user) =>
    user.role == StaffRole.administrator ||
    user.role == StaffRole.operatingRoomManager;

bool canChangeOperatingRoomStatus(StaffUser user) =>
    canManageOperatingRooms(user) || user.role == StaffRole.nurse;

bool canManageEquipment(StaffUser user) =>
    user.role == StaffRole.administrator ||
    user.role == StaffRole.serviceHead ||
    user.role == StaffRole.operatingRoomManager;

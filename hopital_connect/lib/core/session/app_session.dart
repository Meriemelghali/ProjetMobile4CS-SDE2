import '../../features/users/domain/staff_role.dart';
import '../../features/users/domain/staff_user.dart';

class AppSession {
  const AppSession({required this.token, required this.user});

  final String token;
  final StaffUser user;

  String get email => user.email;
  StaffRole get role => user.role;
}

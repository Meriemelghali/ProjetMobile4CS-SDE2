import '../../../core/network/api_client.dart';
import '../../../core/session/app_session.dart';
import '../../../core/session/session_manager.dart';
import '../../users/domain/staff_role.dart';
import '../../users/domain/staff_user.dart';

class AuthService {
  AuthService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<LoginResult> login(String email, String password) async {
    final response = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final token = response['token'];
    final user = response['user'];
    if (user is! Map<String, dynamic>) {
      throw const ApiException('Réponse de connexion invalide.');
    }
    final staffUser = StaffUser.fromJson(user);
    final selectionToken = response['selectionToken'];
    if (selectionToken is String && selectionToken.isNotEmpty) {
      return LoginResult(user: staffUser, selectionToken: selectionToken);
    }
    if (token is! String) {
      throw const ApiException('Réponse de connexion invalide.');
    }
    await SessionManager.instance.save(token, staffUser);
    return LoginResult(
      user: staffUser,
      session: AppSession(token: token, user: staffUser),
    );
  }

  Future<AppSession> selectRole({
    required String selectionToken,
    required StaffRole role,
  }) async {
    final response = await _api.post(
      '/auth/select-role',
      body: {'selectionToken': selectionToken, 'role': role.apiValue},
    );
    final token = response['token'];
    final user = response['user'];
    if (token is! String || user is! Map<String, dynamic>) {
      throw const ApiException('Réponse de sélection du rôle invalide.');
    }
    final staffUser = StaffUser.fromJson(user);
    await SessionManager.instance.save(token, staffUser);
    return AppSession(token: token, user: staffUser);
  }

  Future<AppSession> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/register',
      body: {'username': username, 'email': email, 'password': password},
    );
    final token = response['token'];
    final user = response['user'];
    if (token is! String || user is! Map<String, dynamic>) {
      throw const ApiException('Réponse d’inscription invalide.');
    }
    final staffUser = StaffUser.fromJson(user);
    if (staffUser.role.apiValue != 'patient') {
      throw const ApiException(
        'Le compte inscrit doit être un compte patient.',
      );
    }
    await SessionManager.instance.save(token, staffUser);
    return AppSession(token: token, user: staffUser);
  }

  Future<StaffUser> currentUser() async {
    final response = await _api.get('/auth/me');
    final user = response['user'];
    if (user is! Map<String, dynamic>) {
      throw const ApiException('Réponse de profil invalide.');
    }
    return StaffUser.fromJson(user);
  }
}

class LoginResult {
  const LoginResult({required this.user, this.session, this.selectionToken});

  final StaffUser user;
  final AppSession? session;
  final String? selectionToken;

  bool get requiresRoleSelection => selectionToken != null;
}

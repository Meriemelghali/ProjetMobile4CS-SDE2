import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  // URL du backend — surchargeable via la variable d'environnement API_BASE_URL.
  // Flutter web utilise localhost ; l'émulateur Android utilise 10.0.2.2.
  // Pour appareil physique    : lancer avec --dart-define=API_BASE_URL=http://192.168.X.X:3000
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : kIsWeb
      ? 'http://localhost:3000'
      : 'http://10.0.2.2:3000';
}

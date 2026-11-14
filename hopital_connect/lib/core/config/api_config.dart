class ApiConfig {
  const ApiConfig._();

  // URL du backend — surchargeable via la variable d'environnement API_BASE_URL.
  // Valeur par défaut : 10.0.2.2:3000 (émulateur Android standard).
  // Pour Flutter web (Chrome) : lancer avec --dart-define=API_BASE_URL=http://localhost:3000
  // Pour appareil physique    : lancer avec --dart-define=API_BASE_URL=http://192.168.X.X:3000
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}

class ApiConfig {
  const ApiConfig._();

  // URL du backend selon la plateforme :
  // - Chrome / web  → http://localhost:3000  ← actif
  // - Émulateur Android → http://10.0.2.2:3000
  // - Appareil physique → http://192.168.X.X:3000  (IP locale de ta machine)
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}

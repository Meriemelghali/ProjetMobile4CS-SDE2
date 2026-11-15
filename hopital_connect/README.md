# HôpitalConnect — application Flutter

Le code de l'application se trouve dans `lib/`. Chaque fonctionnalité est rangée dans son propre dossier sous `lib/features/` ; `lib/main.dart` démarre l'application.

Consultez [`../docs/architecture.md`](../docs/architecture.md) pour savoir où se trouve chaque module et où ajouter l'écran de création des comptes du personnel.

## Lancer l'application

Depuis PowerShell, dans ce dossier :

```powershell
flutter pub get
flutter run
```

Pour afficher les données hospitalières de démonstration (quatre services,
occupation et équipements fictifs), lancer l'application avec :

```powershell
flutter run -d chrome --dart-define=USE_MOCK_DATA=true
```

Sur un appareil ou émulateur, remplacer `chrome` par l'identifiant de la cible :

```powershell
flutter devices
flutter run -d VOTRE_IDENTIFIANT --dart-define=USE_MOCK_DATA=true
```

Le flag ne remplace que les ressources de l'écran Hôpital ; la connexion et les
autres écrans continuent d'utiliser le backend configuré.

## Vérifier l'écran Ressources hospitalières

```powershell
flutter test test/hospital_resources_test.dart
```

Les tests couvrent les états de chargement, vide, erreur et données chargées,
ainsi que l'alerte de saturation et le détail des lits. Pour vérifier le mode
réel, lancer l'application avec le backend disponible. Pour l'état vide,
utiliser un backend sans chambres ni lits. Pour l'erreur, faire échouer un
endpoint de ressources (le backend général doit rester disponible pour charger
le tableau de bord) ; le test Flutter utilise une réponse HTTP 503 simulée.

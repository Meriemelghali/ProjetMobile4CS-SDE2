# Architecture de l’application

Le dépôt contient deux applications : l’application mobile Flutter dans
`hopital_connect/` et une API Express 5 / MongoDB dans `backend/`.

## Application Flutter

Le code est dans `hopital_connect/lib/`. Chaque fonctionnalité possède ses
modèles métier (`domain/`), ses appels API (`data/`) et ses écrans
(`presentation/`).

```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/api_config.dart       # URL du backend
│   ├── network/api_client.dart      # Requêtes HTTP et erreurs
│   ├── session/                     # Session persistée localement
│   └── theme/app_colors.dart
├── shared/widgets.dart
└── features/
    ├── auth/data/                   # Connexion et profil courant
    ├── auth/presentation/           # Écran de connexion
    ├── users/domain/                # Rôles et modèle utilisateur
    ├── users/data/                  # Comptes du personnel
    ├── users/presentation/          # Création, modification, désactivation
    ├── dashboard/presentation/      # Tableau de bord et navigation
    ├── admin/presentation/          # Actions d'administration
    ├── services/domain/             # Modèle Service
    ├── services/data/               # Requêtes des services
    ├── services/presentation/
    ├── planning/domain/              # Gardes avec dates réelles
    ├── planning/data/
    ├── planning/presentation/
    ├── transmissions/domain/         # Transmissions avec date et auteur
    ├── transmissions/data/
    └── transmissions/presentation/
```

La configuration de l’API se fait avec `--dart-define=API_BASE_URL=...`.
L’adresse par défaut, `http://10.0.2.2:3000`, convient à l’émulateur Android.
La session JWT est enregistrée avec `shared_preferences` et chaque requête
protégée envoie le token comme bearer token. Les droits ne sont pas déduits
du formulaire : l’API contrôle le rôle côté serveur.

## Backend

Le backend est dans `backend/`. Les routes relient les middlewares
d’authentification/autorisation aux contrôleurs, qui valident les requêtes et
utilisent les modèles Mongoose. Les mots de passe sont hachés avec bcryptjs ;
les routes protégées exigent un JWT.

Voir [backend/README.md](../backend/README.md) pour les prérequis, la procédure
de création du premier administrateur, les routes et leurs rôles.

## Ajouter une fonctionnalité

- Définir les données et leur sérialisation JSON dans le modèle `domain/`.
- Ajouter les appels HTTP dans `data/` en réutilisant `ApiClient`.
- Construire l’interface dans `presentation/`.
- Vérifier l’authentification et les rôles dans les middlewares du backend,
  même si une action ou un onglet est masqué dans Flutter.

Les modules `hospital`, `appointments`, `medical_records` et `pharmacy` restent
hors du MVP. Ne stockez ni n’envoyez de données médicales réelles dans cette
application de démonstration.

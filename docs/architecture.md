# Architecture du code Flutter

Le code Flutter est dans `hopital_connect/lib/`. Chaque fonctionnalité a son dossier. `main.dart` sert uniquement à démarrer l'application.

```text
lib/
├── main.dart                         # Démarre l'application
├── app.dart                          # Thème global et première page
├── core/theme/app_colors.dart         # Couleurs partagées
├── shared/widgets.dart               # Composants réutilisés
└── features/
    ├── auth/presentation/             # Écran de connexion
    ├── users/domain/                  # Rôles et modèles des comptes
    ├── users/presentation/            # À créer : écran de gestion des comptes
    ├── dashboard/presentation/        # Tableau de bord et navigation
    ├── admin/presentation/            # Vue d'administration
    ├── services/presentation/         # Consultation/ajout de services
    ├── planning/presentation/         # Planning et ajout de gardes
    ├── transmissions/presentation/    # Notes de transmission
    ├── hospital/                      # À développer si validé
    ├── appointments/                  # À développer si validé
    ├── medical_records/               # À développer si validé
    └── pharmacy/                      # À développer si validé
```

## Où créer un utilisateur ?

La gestion des comptes appartient au module **users**. Le rôle de chaque compte est défini dans `lib/features/users/domain/staff_role.dart`, ses données sont décrites dans `staff_user.dart`, et l'écran de gestion se trouve dans `lib/features/users/presentation/user_management_page.dart`. Depuis l'onglet Administration, appuie sur **Gérer les comptes**, puis sur **Créer un compte**.

L'écran permet de saisir un nom, une adresse e-mail et un rôle. Les nouveaux comptes sont gardés en mémoire uniquement pendant la session. Il n'y a pas encore de mot de passe, de connexion réelle, de modification/suppression de compte ni de base de données ; ces éléments demanderont un backend.

## Qui fait quoi ?

- `auth` gère l'écran de connexion de démonstration.
- `dashboard` assemble les onglets et décide si l'onglet Administration est visible.
- `services`, `planning` et `transmissions` portent chacun leur écran, leurs formulaires et leurs modèles de démonstration.
- `admin` présente les actions de gestion disponibles dans la maquette.
- `core` contient les éléments techniques communs ; `shared` contient les composants d'interface réutilisés.
- `hospital`, `appointments`, `medical_records` et `pharmacy` sont des modules futurs, pas des fonctions réalisées.

Les données sont actuellement temporaires et gardées en mémoire dans le tableau de bord. Une fermeture de l'application les efface. Cette architecture sépare le code par fonctionnalité, mais elle ne constitue pas encore une architecture backend ni une vraie sécurité des rôles.

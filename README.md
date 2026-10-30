# HôpitalConnect

Application mobile interne pour aider le personnel hospitalier à coordonner les équipes, consulter les plannings et transmettre les informations de service.

## Objectif du projet

Le projet doit démontrer un parcours mobile complet et réalisable dans le temps du cours. Le premier livrable (MVP) se concentre sur le personnel et la coordination quotidienne. Les fonctions destinées aux patients et les données médicales sensibles ne font pas partie du MVP.

## Périmètre fonctionnel

### MVP — à réaliser en premier

- Connexion et déconnexion du personnel.
- Accès contrôlé par rôle : administrateur, médecin, infirmier/personnel.
- Consultation des services hospitaliers et des équipes.
- Consultation des plannings et des gardes.
- Création et consultation de transmissions de service (consignes opérationnelles non médicales, avec auteur et date).
- Tableau de bord adapté au rôle de l’utilisateur.

### Extensions — seulement après validation du MVP

- Gestion des rendez-vous des patients.
- Dossier médical, uniquement avec accord explicite de l’enseignant et règles de sécurité adaptées.
- Gestion de pharmacie et de stocks.
- Gestion administrative complète de l’hôpital.

## Rôles proposés

| Rôle | Capacités principales |
| --- | --- |
| Administrateur | Gérer les comptes, rôles, services et équipes. |
| Médecin | Consulter son service et son planning, lire et publier des transmissions autorisées. |
| Personnel soignant | Consulter son service et son planning, lire et publier des transmissions autorisées. |
| Patient | Hors MVP ; à ajouter seulement si l’application devient aussi une application destinée au public. |
| Professeur | Acteur de suivi/évaluation du projet, pas un rôle métier dans l’application, sauf demande contraire de l’enseignant. |

## Démarrage

La pile mobile choisie est **Flutter**. Le projet se trouve dans `hopital_connect/`. Le prototype contient une connexion de démonstration avec choix de rôle, puis les onglets accueil, planning, service et transmissions. L’onglet Administration apparaît uniquement lorsque le rôle Administrateur est sélectionné. L’administrateur peut ajouter des services et des gardes. Les services, transmissions et gardes ajoutés restent en mémoire pendant la session et ne sont pas envoyés à un serveur.

Pour découvrir les écrans, utilisez une adresse e-mail valide et un mot de passe de six caractères minimum, puis essayez les trois rôles : Administrateur, Médecin et Personnel soignant. Il s’agit d’une simulation d’interface : le rôle choisi n’est pas vérifié par un serveur et ne constitue pas un véritable contrôle de sécurité.

Pour lancer l’application depuis PowerShell :

```powershell
cd "C:\Users\windows 10\Documents\ChatGPT\HôpitalConnect\hopital_connect"
flutter pub get
flutter run
```

Si `flutter run` ne détecte aucun appareil Android, ouvrez Android Studio et démarrez un appareil dans **Device Manager**. Le dépôt a été préparé avec un émulateur **Medium Phone API 37.0** ; son démarrage reste à résoudre si Flutter l’indique encore « offline ». En attendant, vous pouvez lancer la version navigateur avec `flutter run -d chrome`.

Ordre de travail recommandé :

1. Valider les besoins et le périmètre MVP (`docs/cadrage.md`).
2. Lancer l’écran prototype dans Chrome ou sur un émulateur Android.
3. Dessiner les écrans définitifs et les parcours principaux avec l’équipe.
4. Ajouter l’authentification réelle et les permissions par rôle après le choix du backend.
5. Remplacer progressivement les données de démonstration par des fonctions de gestion de services, plannings et transmissions.
6. Préparer des données fictives et une démonstration pour chaque rôle.

## Documentation

- [Architecture Flutter](docs/architecture.md) — dossiers du code et emplacement de chaque module.
- [Modules et fonctionnalités](docs/modules-et-fonctionnalites.md)
- [Cadrage fonctionnel et plan de réalisation](docs/cadrage.md)
- [Index de la documentation](docs/README.md)

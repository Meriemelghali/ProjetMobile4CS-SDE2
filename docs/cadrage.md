# Cadrage du projet HôpitalConnect

## 1. Contexte et problème

Dans un hôpital, les équipes doivent connaître leur planning, leur service d’affectation et les informations utiles laissées par l’équipe précédente. HôpitalConnect propose une application mobile interne qui rassemble ces informations au même endroit.

## 2. Utilisateurs et besoin

- **Administrateur** : configurer les comptes, les rôles et les services.
- **Médecin** : consulter son planning et les transmissions de son service.
- **Personnel soignant** : consulter son planning et les transmissions de son service.
- **Patient** : créer un compte avec le rôle patient par défaut et consulter un espace de compte minimal. Seul l’administrateur peut modifier son rôle.

Le mode patient minimal n’expose ni les plannings ni les transmissions du personnel. Le professeur évalue le projet, mais n’a pas besoin d’un compte dans l’application, sauf consigne spécifique.

## 3. Fonctions du MVP

### F1 — Authentification et autorisations

Un utilisateur se connecte ou crée un compte patient. L’inscription attribue toujours le rôle patient côté serveur ; seul un administrateur peut modifier le rôle. L’application affiche les fonctions permises pour le rôle courant et l’API vérifie les autorisations côté serveur.

### F2 — Services et équipes

L’utilisateur consulte les services et les membres de son équipe. L’administrateur peut créer, modifier et désactiver un service ou une affectation.

### F3 — Plannings

Le personnel consulte ses gardes/horaires par date. L’administrateur peut créer ou modifier une affectation. Prévoir au minimum date, heure de début, heure de fin, service et utilisateur affecté.

### F4 — Transmissions de service

Un utilisateur autorisé publie une note opérationnelle liée à un service. Une note comprend un titre, un contenu, son auteur, sa date de création et éventuellement un indicateur « important ». Les utilisateurs autorisés du service peuvent la consulter.

Pour le prototype étudiant, ne saisir aucune donnée réelle de patient ni information médicale identifiable.

## 4. Fonctions hors MVP

- Prise de rendez-vous par les patients.
- Dossiers médicaux et prescriptions.
- Pharmacie, commandes et stock.
- Gestion exhaustive de l’hôpital.

Ces fonctions représentent des domaines distincts et augmentent fortement le travail de conception, les règles d’accès et les données à protéger. Les reconsidérer comme extensions après démonstration du MVP ou si l’enseignant les exige explicitement.

## 5. Écrans à maquetter

1. Connexion.
2. Accueil / tableau de bord.
3. Mon planning (liste par date, puis détail d’une garde).
4. Mon service (équipe et informations du service).
5. Transmissions (liste, détail, création).
6. Administration (comptes, rôles, services, affectations), visible uniquement pour l’administrateur.

Commencer par des maquettes papier ou Figma, puis faire valider les parcours avant de coder.

## 6. Modèle de données initial

- **User** : id, nom, email, rôle, serviceId, actif.
- **Service** : id, nom, description, actif.
- **Shift** : id, userId, serviceId, début, fin, rôle de garde.
- **Handover** : id, serviceId, auteurId, titre, contenu, dateCréation, important.

Les identifiants relient les entités. La technologie de stockage reste à choisir selon les consignes du cours et les compétences de l’équipe.

## 7. Choix techniques et décisions à confirmer

L’équipe a choisi **Flutter** pour l’application mobile. Il reste à confirmer avec l’enseignant :

- Backend requis, ou application prototype avec données locales autorisée.
- Outils imposés pour la base de données, l’authentification et la démonstration.
- Nombre de membres, répartition des tâches et date de rendu du projet.

Ne pas mélanger plusieurs frameworks mobiles. Choisir une pile unique, écrire les versions dans le README et s’assurer que chaque membre peut lancer l’application.

## 8. Plan de réalisation

### Étape 1 — Cadrage

Valider les rôles, les quatre fonctions MVP et les exclusions avec le professeur. Écrire les scénarios d’usage et répartir le travail.

### Étape 2 — Conception

Faire les maquettes des six écrans et un diagramme simple des entités. Décrire les droits par rôle avant de développer.

### Étape 3 — Squelette mobile

Créer le projet, configurer Git, lancer l’application sur émulateur/téléphone, puis ajouter navigation et écrans vides.

### Étape 4 — Parcours principal

Implémenter connexion et accès par rôle, puis services, planning et transmissions. Avancer fonctionnalité par fonctionnalité avec une démonstration utilisable à chaque étape.

### Étape 5 — Finalisation

Corriger les parcours, ajouter des données de démonstration fictives, vérifier les accès de chaque rôle, préparer captures d’écran, présentation et procédure de lancement.

## 9. Répartition possible (équipe de 4 à 6)

- 1 personne : coordination, Git et intégration.
- 1–2 personnes : écrans et navigation mobile.
- 1 personne : authentification et rôles.
- 1 personne : données/services/plannings.
- 1 personne : transmissions, documentation et préparation de la démonstration.

À 2 ou 3 personnes, regrouper ces lots. Toute contribution doit passer par une branche et une pull request si l’équipe sait utiliser ce flux ; sinon, convenir d’une règle simple pour éviter les modifications concurrentes.

## 10. Première séance de travail

1. Confirmer la pile technique et les exigences avec l’enseignant.
2. Faire valider le MVP et décider si les rendez-vous et le dossier médical sont réellement exigés.
3. Affecter un responsable à chaque lot et fixer des jalons internes.
4. Créer les maquettes des écrans Connexion, Accueil, Planning et Transmissions.
5. Une fois la technologie confirmée, initialiser le projet directement dans ce dépôt.

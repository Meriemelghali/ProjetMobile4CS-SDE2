# HôpitalConnect — Modules et fonctionnalités

## 1. Présentation

HôpitalConnect est une application mobile interne destinée au personnel hospitalier. Elle aide les équipes à consulter les services, organiser les gardes et transmettre les informations opérationnelles utiles.

L’équipe a aussi proposé des fonctions de rendez-vous, de pharmacie et de dossier médical. Ce document les répertorie, mais les classe comme extensions : elles élargissent le projet et, pour les données médicales, demandent des règles de sécurité supplémentaires.

## 2. Utilisateurs et rôles

| Rôle | Accès prévu dans le projet |
| --- | --- |
| Administrateur | Gérer les comptes, l’hôpital, les ressources, les services et les plannings. |
| Chef de service | Consulter les ressources hospitalières, son service, son planning et les transmissions ; publier des transmissions. |
| Secrétaire | Consulter les services, les ressources hospitalières, son planning et les transmissions de son service. |
| Médecin | Consulter les ressources hospitalières, son service et ses gardes, lire et publier les transmissions autorisées. |
| Personnel soignant | Consulter les ressources hospitalières, son service et son planning, lire et publier les transmissions autorisées. |
| Pharmacien | Rôle à ajouter seulement si le module pharmacie est validé ; gérer le catalogue et les stocks. |
| Patient | Pas d’accès dans le MVP interne. À ajouter seulement si l’équipe transforme le projet en application destinée aussi aux patients. |
| Professeur | Encadrant et évaluateur du projet, pas un utilisateur métier de l’application, sauf consigne contraire de l’enseignant. |

Un compte peut recevoir plusieurs rôles par l’administrateur. Après une connexion réussie, l’utilisateur choisit le profil avec lequel ouvrir sa session ; les autorisations de l’API sont limitées à ce rôle pour la session en cours. L’inscription publique crée toujours un compte Patient uniquement.

## 3. Catalogue des modules

### Module 1 — Authentification et utilisateurs

**But :** permettre au personnel autorisé d’accéder à son espace.

Fonctionnalités prévues :

- Se connecter et se déconnecter.
- Consulter son profil : nom, adresse e-mail, rôle et service de rattachement.
- Attribuer un ou plusieurs rôles parmi Administrateur, Chef de service, Médecin, Personnel soignant, Secrétaire et Patient.
- Créer, modifier et désactiver un compte du personnel (Administrateur).
- Restreindre les écrans et actions selon le rôle.
- Réinitialiser un mot de passe dans une version avec backend.

**Priorité :** connexion de démonstration dans le prototype ; authentification réelle et permissions côté serveur après choix de la technologie backend.

### Module 2 — Gestion de l’hôpital

**But :** gérer la structure et les ressources matérielles de l’établissement.

Fonctionnalités :

- Créer et modifier les hôpitaux et rattacher les services à un hôpital.
- Gérer les chambres par service et leurs états.
- Ajouter des lits, affecter un patient lors d’une admission, puis libérer le lit à la sortie.
- Consulter les lits disponibles et le taux d’occupation par service ou hôpital.
- Gérer les salles d’opération et planifier les interventions avec contrôle des conflits de créneaux.
- Affecter du matériel aux services ou aux salles, signaler les pannes et suivre la maintenance.
- Autoriser la consultation aux médecins et au personnel soignant ; réserver les modifications à l’Administrateur.

**Priorité :** module disponible avec des données de démonstration uniquement. Ne saisissez aucune donnée réelle ou identifiable de patient.

### Module 3 — Gestion des services et des équipes

**But :** permettre au personnel de savoir dans quel service il travaille et qui compose l’équipe.

Fonctionnalités prévues :

- Consulter un service : nom, description et emplacement.
- Consulter la liste des membres d’une équipe.
- Créer ou modifier un service (Administrateur).
- Affecter ou retirer un membre d’un service (Administrateur).
- Désactiver un service qui n’est plus utilisé (Administrateur).

**Priorité :** MVP. Dans le prototype, l’Administrateur peut ajouter un service de démonstration ; les changements restent en mémoire pendant la session.

### Module 4 — Planning du personnel et gardes

**But :** aider le personnel à connaître ses horaires et aider l’administrateur à organiser les équipes.

Fonctionnalités prévues :

- Consulter les gardes par jour et par semaine.
- Afficher les heures, le service, le membre affecté et sa fonction.
- Ajouter ou modifier une garde (Administrateur).
- Vérifier que l’heure de fin est après l’heure de début.
- Signaler les jours de repos ou les gardes à venir.

**Priorité :** MVP. Dans le prototype, l’Administrateur peut créer une garde de démonstration ; les changements restent en mémoire pendant la session.

### Module 5 — Transmissions de service

**But :** faciliter le passage d’informations opérationnelles entre les équipes.

Fonctionnalités prévues :

- Consulter les transmissions du service.
- Publier une note avec un titre, un contenu, un auteur et une date.
- Marquer une information comme importante (évolution prévue).
- Afficher les consignes opérationnelles pertinentes à l’équipe.
- Ne pas saisir de nom, dossier ou donnée médicale réelle dans le prototype.

**Priorité :** MVP. Les notes du prototype sont locales à la session et ne sont pas partagées entre appareils.

### Module 6 — Rendez-vous des patients

**But :** organiser les rendez-vous entre un patient et un service ou un médecin.

Fonctionnalités possibles :

- Créer une demande de rendez-vous.
- Consulter les créneaux disponibles.
- Confirmer, modifier ou annuler un rendez-vous.
- Afficher les rendez-vous au patient et au personnel autorisé.
- Envoyer des rappels.

**Priorité :** extension à valider avec l’enseignant. Ce module implique un parcours patient, alors que l’idée retenue est une application interne au personnel.

### Module 7 — Dossier médical

**But :** permettre aux professionnels habilités de consulter et de tenir à jour le dossier médical d’un patient, et au patient de consulter le sien.

Fonctionnalités réalisées :

- Rechercher un patient (nom, e-mail), filtrer (allergie sévère, vus ce mois, dossier à créer) et ouvrir son dossier.
- Synthèse : alertes sur les constantes hors norme, prochain contrôle, dernières constantes avec mini-courbes, allergies par sévérité, pathologies chroniques, antécédents et vaccinations.
- Bandeau d’alerte permanent en cas d’allergie sévère.
- Historique chronologique des consultations, ordonnances et rendez-vous.
- Constantes vitales (tension, pouls, température, SpO₂, glycémie, poids) en graphiques avec zone normale, points hors norme et statistiques.
- Saisie d’une consultation, de constantes (statut calculé pendant la saisie) et édition du dossier.
- Carte d’urgence du patient retournable, avec QR code ne contenant que l’identifiant ; scan par un soignant pour ouvrir le dossier.
- Export PDF du dossier.

| Rôle | Droits |
| --- | --- |
| Médecin | Lecture, consultations, constantes, édition du dossier |
| Personnel soignant | Lecture et saisie des constantes |
| Patient | Lecture de son propre dossier, carte d’urgence, PDF |
| Administrateur, secrétaire, autres | Aucun accès au contenu médical |

**Priorité :** extension réalisée avec des données fictives uniquement (`npm run seed:demo`, voir [comptes de test](comptes-de-test.md)). Les droits sont vérifiés par l’API.

### Module 8 — Gestion de la pharmacie

**But :** suivre les produits et les stocks de la pharmacie hospitalière.

Fonctionnalités possibles :

- Consulter un catalogue de médicaments ou de produits.
- Ajouter ou modifier un produit et son stock.
- Enregistrer une entrée ou une sortie de stock.
- Signaler les stocks bas ou les dates de péremption proches.
- Restreindre la gestion au pharmacien et à l’administrateur autorisé.

**Priorité :** extension à valider. La pharmacie est un domaine distinct du parcours principal de coordination des équipes.

### Module 9 — Tableau de bord et notifications

**But :** donner à chaque utilisateur un aperçu rapide de ses informations utiles.

Fonctionnalités prévues ou envisagées :

- Afficher le service de rattachement et la prochaine garde.
- Montrer les dernières transmissions importantes.
- Adapter les informations affichées au rôle.
- Ajouter des notifications lors d’une nouvelle garde ou transmission (après mise en place d’un backend).

**Priorité :** tableau de bord simple dans le MVP ; notifications connectées comme évolution.

## 4. Matrice de priorité

| Module | MVP | Extension | Remarque |
| --- | :---: | :---: | --- |
| Authentification et utilisateurs | Oui, version de démonstration | Oui | L’authentification sécurisée nécessite un backend. |
| Gestion de l’hôpital et de ses ressources | Oui |  | Données de démonstration ; consultation pour le personnel autorisé et gestion par l’Administrateur. |
| Services et équipes | Oui |  | Fonctions de base pour l’organisation du personnel. |
| Planning du personnel | Oui |  | Gardes par date, service et membre. |
| Transmissions opérationnelles | Oui |  | Aucun renseignement médical identifiable. |
| Tableau de bord | Oui |  | Résumé adapté au rôle. |
| Rendez-vous des patients |  | Oui | À valider car le public cible changerait. |
| Dossier médical |  | Oui | Réalisé avec données fictives ; droits vérifiés par l’API. |
| Pharmacie et stocks |  | Oui | À valider ; rôle Pharmacien à définir. |
| Notifications |  | Oui | Nécessitent un service serveur pour les appareils. |

## 5. Périmètre recommandé pour la première démonstration

La démonstration doit montrer un parcours cohérent du personnel :

1. Choisir un rôle de démonstration et ouvrir une session.
2. Voir son tableau de bord.
3. Consulter un service et son équipe.
4. Consulter le planning et, en Administrateur, ajouter une garde.
5. Consulter et publier une transmission opérationnelle fictive.
6. Consulter les lits et équipements, puis tester une affectation et une intervention avec des données fictives.

Les rendez-vous patients, le dossier médical et la pharmacie seront ajoutés seulement après validation du premier périmètre par l’enseignant et par l’équipe.

## 6. Limites actuelles du prototype

- Les données du backend sont persistées dans MongoDB ; la disponibilité dépend de la configuration du serveur.
- Les accès aux ressources sont contrôlés par rôle par l’API ; l’interface Flutter ne remplace pas ces contrôles.
- Utilisez exclusivement des données fictives : cette application de démonstration n’est pas conçue pour héberger des informations de santé réelles.

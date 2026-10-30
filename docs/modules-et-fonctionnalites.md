# HôpitalConnect — Modules et fonctionnalités

## 1. Présentation

HôpitalConnect est une application mobile interne destinée au personnel hospitalier. Elle aide les équipes à consulter les services, organiser les gardes et transmettre les informations opérationnelles utiles.

L’équipe a aussi proposé des fonctions de rendez-vous, de pharmacie et de dossier médical. Ce document les répertorie, mais les classe comme extensions : elles élargissent le projet et, pour les données médicales, demandent des règles de sécurité supplémentaires.

## 2. Utilisateurs et rôles

| Rôle | Accès prévu dans le projet |
| --- | --- |
| Administrateur | Gérer les comptes du personnel, les rôles, les services et les plannings. |
| Médecin | Consulter son service et ses gardes, lire et publier les transmissions autorisées. Les rendez-vous et dossiers patients sont des extensions. |
| Personnel soignant | Consulter son service et son planning, lire et publier les transmissions autorisées. |
| Pharmacien | Rôle à ajouter seulement si le module pharmacie est validé ; gérer le catalogue et les stocks. |
| Patient | Pas d’accès dans le MVP interne. À ajouter seulement si l’équipe transforme le projet en application destinée aussi aux patients. |
| Professeur | Encadrant et évaluateur du projet, pas un utilisateur métier de l’application, sauf consigne contraire de l’enseignant. |

Les rôles doivent être attribués par l’administrateur dans une vraie version. Le choix de rôle sur l’écran actuel sert uniquement à la démonstration et n’est pas une authentification sécurisée.

## 3. Catalogue des modules

### Module 1 — Authentification et utilisateurs

**But :** permettre au personnel autorisé d’accéder à son espace.

Fonctionnalités prévues :

- Se connecter et se déconnecter.
- Consulter son profil : nom, adresse e-mail, rôle et service de rattachement.
- Attribuer les rôles Administrateur, Médecin et Personnel soignant.
- Créer, modifier et désactiver un compte du personnel (Administrateur).
- Restreindre les écrans et actions selon le rôle.
- Réinitialiser un mot de passe dans une version avec backend.

**Priorité :** connexion de démonstration dans le prototype ; authentification réelle et permissions côté serveur après choix de la technologie backend.

### Module 2 — Gestion de l’hôpital

**But :** présenter les informations générales utiles au personnel.

Fonctionnalités envisagées :

- Consulter le nom et les coordonnées de l’établissement.
- Consulter la liste des services et leur emplacement.
- Administrer les informations de l’établissement (Administrateur), si cette partie est exigée par le cours.

**Priorité :** informations de base et annuaire des services ; la gestion exhaustive de l’hôpital est hors MVP.

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

**But :** permettre à des professionnels autorisés de consulter les informations médicales d’un patient.

Fonctionnalités possibles si l’enseignant confirme ce besoin :

- Rechercher un patient et consulter son dossier.
- Consulter les antécédents, allergies, consultations et documents.
- Restreindre chaque dossier aux professionnels habilités.
- Tracer les accès et protéger les données.

**Priorité :** hors MVP. Ne pas utiliser de données réelles dans le prototype étudiant. Cette fonction nécessite une validation explicite de l’enseignant et une conception de sécurité adaptée.

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
| Gestion de l’hôpital | Partielle | Oui | Annuaire de services d’abord. |
| Services et équipes | Oui |  | Fonctions de base pour l’organisation du personnel. |
| Planning du personnel | Oui |  | Gardes par date, service et membre. |
| Transmissions opérationnelles | Oui |  | Aucun renseignement médical identifiable. |
| Tableau de bord | Oui |  | Résumé adapté au rôle. |
| Rendez-vous des patients |  | Oui | À valider car le public cible changerait. |
| Dossier médical |  | Oui | À valider ; données sensibles exclues du prototype. |
| Pharmacie et stocks |  | Oui | À valider ; rôle Pharmacien à définir. |
| Notifications |  | Oui | Nécessitent un service serveur pour les appareils. |

## 5. Périmètre recommandé pour la première démonstration

La démonstration doit montrer un parcours cohérent du personnel :

1. Choisir un rôle de démonstration et ouvrir une session.
2. Voir son tableau de bord.
3. Consulter un service et son équipe.
4. Consulter le planning et, en Administrateur, ajouter une garde.
5. Consulter et publier une transmission opérationnelle fictive.

Les rendez-vous patients, le dossier médical et la pharmacie seront ajoutés seulement après validation du premier périmètre par l’enseignant et par l’équipe.

## 6. Limites actuelles du prototype

- Pas de serveur ni de base de données partagée.
- Les services, gardes et transmissions ajoutés sont temporaires et disparaissent à la fermeture de la session.
- La connexion et le choix de rôle sont simulés ; ils ne protègent pas réellement les données.
- Toutes les informations affichées sont fictives.

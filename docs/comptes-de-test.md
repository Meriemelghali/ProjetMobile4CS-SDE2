# Comptes de test — démonstration du dossier médical

Ces comptes sont **fictifs** et créés par `npm run seed:demo` (dossier
`backend/`). Relancer la commande remet les données de démonstration à zéro
sans toucher aux autres comptes. Aucune donnée réelle de patient.

**Mot de passe commun : `HopitalDemo2026`**
(modifiable avec la variable d’environnement `DEMO_PASSWORD` au moment du seed)

| Rôle | E-mail | À montrer pendant la démo |
| --- | --- | --- |
| Médecin | `dr.karim.demo@demo.test` | Onglet **Dossiers** → rechercher un patient → synthèse, graphiques, nouvelle consultation, modification du dossier, export PDF, scan QR |
| Personnel soignant | `inf.sarra.demo@demo.test` | Onglet **Dossiers** → saisie de constantes avec statut en direct (pas d’édition du dossier) |
| Patiente | `patient.yasmine.demo@demo.test` | Carte « Mon dossier médical » sur l’accueil, **allergie sévère** (pénicilline), carte d’urgence avec QR |
| Patient | `patient.omar.demo@demo.test` | Hypertension et diabète : courbes de tension et de glycémie qui s’améliorent |
| Patiente | `patient.amal.demo@demo.test` | Insuffisance cardiaque : pic de poids et désaturation, allergie sévère à l’aspirine |
| Secrétaire | `sec.lina.demo@demo.test` | Aucun accès au contenu médical (contrôle des droits) |
| Administrateur | `admin.demo@demo.test` | Gestion des comptes ; aucun accès au contenu médical |

## Scénario de démonstration conseillé (5 min)

1. Lancer l’application : **splash screen animé** puis connexion.
2. Se connecter en médecin → **Dossiers** : statistiques, recherche, filtre
   « Allergie sévère ».
3. Ouvrir *Amal Jaziri* : bandeau rouge d’allergie, alertes de constantes,
   onglet **Constantes** (poids, SpO₂) avec zone normale.
4. **Ajouter → Saisir des constantes** : taper une SpO₂ à 89 % et montrer le
   statut qui passe au rouge pendant la saisie.
5. **Ajouter → Nouvelle consultation**, puis onglet **Historique**.
6. Exporter le dossier en **PDF**.
7. Se déconnecter, se connecter en patiente *Yasmine* : carte « Mon dossier
   médical », **carte d’urgence** qui se retourne pour afficher le QR code.
8. Se connecter en secrétaire : pas d’onglet Dossiers ; l’API refuse l’accès
   (403).

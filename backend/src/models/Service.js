// =============================================================================
// MODÈLE MONGOOSE : Service
// Représente un service hospitalier dans la base MongoDB.
// Tous les champs ajoutés sont OPTIONNELS (default: '') pour rétrocompatibilité :
// les collègues qui n'envoient pas ces champs ne cassent rien.
// =============================================================================

const mongoose = require('mongoose');

const serviceSchema = new mongoose.Schema(
  {
    // --- Champs existants (inchangés) ---
    name:        { type: String, required: true, trim: true, maxlength: 120, unique: true },
    description: { type: String, default: '', trim: true, maxlength: 1000 },
    location:    { type: String, default: '', trim: true, maxlength: 160 },
    active:      { type: Boolean, default: true },

    // --- Nouveaux champs optionnels (ajoutés par le module services SDE2) ---
    // Tous ont une valeur par défaut → les anciens documents existants ne sont pas cassés

    // Type de service : médecine, chirurgie, urgences, etc.
    serviceType:  { type: String, default: '', trim: true, maxlength: 60 },

    // Bâtiment où se trouve le service (ex : "Bâtiment A")
    building:     { type: String, default: '', trim: true, maxlength: 80 },

    // Étage dans le bâtiment (ex : "3e étage", "RDC")
    floor:        { type: String, default: '', trim: true, maxlength: 40 },

    // Capacité d'accueil du service (nombre de lits / places)
    capacity:     { type: Number, default: 0, min: 0 },

    // Numéro de téléphone interne du service
    phone:        { type: String, default: '', trim: true, maxlength: 30 },

    // Adresse email du service (pour les transmissions)
    email:        { type: String, default: '', trim: true, maxlength: 120 },

    // Nom du responsable / chef de service
    headName:     { type: String, default: '', trim: true, maxlength: 120 },

    // Horaires d'ouverture (ex : "Lun–Ven 08h00–18h00 / Urgences 24h/24")
    openingHours: { type: String, default: '', trim: true, maxlength: 200 },

    // Notes internes (informations opérationnelles non médicales)
    notes:        { type: String, default: '', trim: true, maxlength: 500 },
  },
  {
    // timestamps : ajoute automatiquement createdAt et updatedAt
    timestamps: true,
  }
);

module.exports = mongoose.models.Service || mongoose.model('Service', serviceSchema);

// =============================================================================
// CONTROLLER : servicePdfController
// Génère un document PDF pour un service hospitalier et le sert au client.
// Endpoint : GET /services/:id/pdf
// Accessible sans authentification pour permettre le scan QR depuis n'importe
// quel téléphone (même sans compte dans l'application).
// =============================================================================

const PDFDocument = require('pdfkit'); // Bibliothèque de génération PDF côté Node.js
const Service = require('../models/Service'); // Modèle Mongoose du service
const { HttpError } = require('../errors');   // Classe d'erreur HTTP personnalisée
const { requireId } = require('../utils/validation'); // Validation de l'id MongoDB

// =============================================================================
// Constantes de mise en page
// =============================================================================

const PAGE_MARGIN  = 50;  // Marge gauche/droite de la page en points
const PRIMARY      = '#123047'; // Bleu foncé (navy) — couleur principale
const ACCENT       = '#176B87'; // Bleu — couleur d'accentuation
const MINT         = '#36A98B'; // Vert menthe — couleur des badges actifs
const GREY         = '#687B86'; // Gris — texte secondaire
const LIGHT_BG     = '#F4F7F8'; // Fond gris très clair des sections
const INACTIVE_COL = '#8797A0'; // Gris pour les services inactifs

// =============================================================================
// Handler principal
// =============================================================================

/**
 * GET /services/:id/pdf
 * Génère un PDF A4 complet pour le service et le stream au client.
 * Pas d'authentification : accessible via QR code depuis n'importe quel appareil.
 */
async function getPdf(req, res) {
  // Valide l'id MongoDB passé dans l'URL
  const id = requireId(req.params.id, 'service id');

  // Cherche le service dans MongoDB
  const service = await Service.findById(id);
  if (!service) throw new HttpError(404, 'Service not found.');

  // Configure les headers HTTP pour indiquer que la réponse est un PDF
  res.setHeader('Content-Type', 'application/pdf');
  // inline = affiche dans le navigateur (pas de téléchargement forcé)
  res.setHeader(
    'Content-Disposition',
    `inline; filename="${encodeURIComponent(service.name)}.pdf"`
  );

  // Crée le document PDF avec PDFKit
  const doc = new PDFDocument({
    size: 'A4',          // Format A4 (595×842 points)
    margin: PAGE_MARGIN, // Marges uniformes
    info: {
      Title: service.name,
      Author: 'HôpitalConnect',
      Subject: 'Fiche service hospitalier',
    },
  });

  // Pipe le PDF directement vers la réponse HTTP (streaming)
  doc.pipe(res);

  // ---- Construction du contenu du PDF ----
  _buildHeader(doc, service);
  _buildBody(doc, service);
  _buildFooter(doc, service);

  // Finalise et envoie le PDF
  doc.end();
}

// =============================================================================
// Construction de l'en-tête coloré
// =============================================================================

/**
 * Dessine le bloc d'en-tête bleu foncé avec le nom et le type du service.
 */
function _buildHeader(doc, service) {
  const headerHeight = 110; // Hauteur du bloc d'en-tête en points

  // Rectangle de fond bleu foncé
  doc
    .rect(PAGE_MARGIN, PAGE_MARGIN, doc.page.width - PAGE_MARGIN * 2, headerHeight)
    .fill(PRIMARY);

  // Badge statut (vert si actif, gris si inactif) — aligné à droite
  const badgeColor = service.active ? MINT : INACTIVE_COL;
  const badgeText  = service.active ? 'ACTIF' : 'INACTIF';
  const badgeW = 55, badgeH = 18;
  const badgeX = doc.page.width - PAGE_MARGIN - badgeW - 10;
  const badgeY = PAGE_MARGIN + 12;

  doc
    .roundedRect(badgeX, badgeY, badgeW, badgeH, 9) // Forme pill arrondie
    .fill(badgeColor);

  doc
    .fillColor('white')
    .fontSize(7)
    .text(badgeText, badgeX, badgeY + 5, {
      width: badgeW,
      align: 'center',
    });

  // Sous-titre "FICHE SERVICE HOSPITALIER"
  doc
    .fillColor('rgba(255,255,255,0.6)')
    .fontSize(8)
    .text('FICHE SERVICE HOSPITALIER', PAGE_MARGIN + 16, PAGE_MARGIN + 16);

  // Nom du service en grand et gras
  doc
    .fillColor('white')
    .fontSize(22)
    .font('Helvetica-Bold')
    .text(service.name, PAGE_MARGIN + 16, PAGE_MARGIN + 34, {
      width: doc.page.width - PAGE_MARGIN * 2 - badgeW - 20,
    });

  // Type de service en bleu clair
  doc
    .fillColor('#B0D4E0')
    .fontSize(12)
    .font('Helvetica')
    .text(service.serviceType || 'Service hospitalier',
      PAGE_MARGIN + 16, PAGE_MARGIN + 70);

  // Repositionne le curseur sous l'en-tête
  doc.moveDown(0.5);
  doc.y = PAGE_MARGIN + headerHeight + 20;
}

// =============================================================================
// Construction du corps du PDF
// =============================================================================

/**
 * Dessine toutes les sections d'information du service.
 */
function _buildBody(doc, service) {
  // ---- Description ----
  if (service.description) {
    _sectionTitle(doc, 'Description');
    doc
      .fillColor('#2C4A5A')
      .fontSize(10)
      .font('Helvetica')
      .text(service.description, PAGE_MARGIN, doc.y, {
        width: doc.page.width - PAGE_MARGIN * 2,
        lineGap: 3, // Espacement entre les lignes
      });
    doc.moveDown(1);
  }

  // ---- Localisation ----
  const hasLocation = service.building || service.floor || service.location;
  if (hasLocation) {
    _sectionTitle(doc, 'Localisation');
    const rows = [];
    if (service.building)  rows.push(['Bâtiment',   service.building]);
    if (service.floor)     rows.push(['Étage',       service.floor]);
    if (service.location)  rows.push(['Emplacement', service.location]);
    _infoTable(doc, rows);
    doc.moveDown(1);
  }

  // ---- Contact ----
  const hasContact = service.headName || service.phone || service.email;
  if (hasContact) {
    _sectionTitle(doc, 'Contact');
    const rows = [];
    if (service.headName) rows.push(['Responsable', service.headName]);
    if (service.phone)    rows.push(['Téléphone',   service.phone]);
    if (service.email)    rows.push(['Email',        service.email]);
    _infoTable(doc, rows);
    doc.moveDown(1);
  }

  // ---- Infos pratiques ----
  const hasPractical = service.capacity > 0 || service.openingHours;
  if (hasPractical) {
    _sectionTitle(doc, 'Infos pratiques');
    const rows = [];
    if (service.capacity > 0)  rows.push(['Capacité', `${service.capacity} lits / places`]);
    if (service.openingHours)  rows.push(['Horaires', service.openingHours]);
    _infoTable(doc, rows);
    doc.moveDown(1);
  }

  // ---- Notes internes ----
  if (service.notes) {
    _sectionTitle(doc, 'Notes internes');
    // Fond jaune pâle pour les notes
    const noteY   = doc.y;
    const noteH   = 40 + (service.notes.length / 60) * 14; // Hauteur dynamique
    const noteW   = doc.page.width - PAGE_MARGIN * 2;
    doc
      .roundedRect(PAGE_MARGIN, noteY, noteW, noteH, 6)
      .fill('#FFF8E7')
      .strokeColor('#FFE082')
      .lineWidth(1)
      .roundedRect(PAGE_MARGIN, noteY, noteW, noteH, 6)
      .stroke();

    doc
      .fillColor('#5D4037')
      .fontSize(10)
      .text(service.notes, PAGE_MARGIN + 12, noteY + 12, {
        width: noteW - 24,
        lineGap: 3,
      });
    doc.moveDown(1.5);
  }
}

// =============================================================================
// Construction du pied de page
// =============================================================================

/**
 * Ajoute le pied de page avec la date et le nom de l'application.
 */
function _buildFooter(doc, service) {
  const footerY = doc.page.height - PAGE_MARGIN - 20;
  const pageW   = doc.page.width - PAGE_MARGIN * 2;

  // Ligne de séparation
  doc
    .strokeColor('#E5ECEF')
    .lineWidth(1)
    .moveTo(PAGE_MARGIN, footerY)
    .lineTo(doc.page.width - PAGE_MARGIN, footerY)
    .stroke();

  // Date de génération
  const now = new Date();
  const dateStr = now.toLocaleDateString('fr-FR', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });

  doc
    .fillColor(GREY)
    .fontSize(8)
    .font('Helvetica')
    .text(`Généré le ${dateStr}`, PAGE_MARGIN, footerY + 7)
    .text('HôpitalConnect', PAGE_MARGIN, footerY + 7, {
      width: pageW,
      align: 'right',
    });
}

// =============================================================================
// Helpers privés
// =============================================================================

/**
 * Dessine un titre de section avec une barre bleue à gauche.
 */
function _sectionTitle(doc, title) {
  const y = doc.y;
  // Barre bleue à gauche
  doc
    .rect(PAGE_MARGIN, y, 3, 14)
    .fill(ACCENT);
  // Texte du titre en majuscules
  doc
    .fillColor(PRIMARY)
    .fontSize(10)
    .font('Helvetica-Bold')
    .text(title.toUpperCase(), PAGE_MARGIN + 10, y + 1);

  doc.moveDown(0.6);
}

/**
 * Dessine un tableau de lignes clé-valeur sur fond gris clair.
 */
function _infoTable(doc, rows) {
  const tableX = PAGE_MARGIN;
  const tableW = doc.page.width - PAGE_MARGIN * 2;
  const rowH   = 20; // Hauteur de chaque ligne
  const tableH = rows.length * rowH + 8; // Hauteur totale du tableau

  // Fond gris clair
  doc
    .roundedRect(tableX, doc.y, tableW, tableH, 6)
    .fill(LIGHT_BG);

  let currentY = doc.y + 6; // Position Y de la première ligne

  rows.forEach(([label, value]) => {
    // Label en gras bleu foncé (colonne gauche, largeur fixe 100pt)
    doc
      .fillColor(PRIMARY)
      .fontSize(9)
      .font('Helvetica-Bold')
      .text(label + ' :', tableX + 10, currentY, { width: 100 });

    // Valeur en texte normal (colonne droite)
    doc
      .fillColor('#2C4A5A')
      .fontSize(9)
      .font('Helvetica')
      .text(value, tableX + 115, currentY, { width: tableW - 125 });

    currentY += rowH; // Passe à la ligne suivante
  });

  doc.y = currentY; // Met à jour la position Y du curseur
}

module.exports = { getPdf };

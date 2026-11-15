// =============================================================================
// UTILITAIRE : ServicePdf
// Génère un document PDF complet pour un service hospitalier.
// Le PDF contient : en-tête coloré, description, localisation, contact,
// infos pratiques, notes internes et un pied de page avec la date.
// Utilise le package 'pdf' pour la génération et 'printing' pour l'affichage.
// =============================================================================

import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';           // Types PDF : couleurs, unités, formats
import 'package:pdf/widgets.dart' as pw; // Widgets PDF (équivalent des widgets Flutter)
import 'package:printing/printing.dart'; // Affichage, impression et partage du PDF

import '../domain/hospital_service.dart'; // Modèle HospitalService

/// Classe statique regroupant la génération et l'affichage du PDF d'un service.
class ServicePdf {

  // --------------------------------------------------------------------------
  // Couleurs du projet converties en PdfColor (format RGB 0.0 → 1.0)
  // --------------------------------------------------------------------------

  /// Bleu foncé — couleur principale du projet (#123047)
  static const _navy = PdfColor.fromInt(0xFF123047);

  /// Bleu primaire — couleur d'accentuation (#176B87)
  static const _blue = PdfColor.fromInt(0xFF176B87);

  /// Vert menthe — couleur secondaire (#36A98B)
  static const _mint = PdfColor.fromInt(0xFF36A98B);

  /// Gris très clair — fond des sections (#F4F7F8)
  static const _bgLight = PdfColor.fromInt(0xFFF4F7F8);

  /// Gris moyen — texte secondaire (#687B86)
  static const _textGrey = PdfColor.fromInt(0xFF687B86);

  // --------------------------------------------------------------------------
  // Point d'entrée public : génère et ouvre le PDF
  // --------------------------------------------------------------------------

  /// Génère le PDF du service et ouvre la visionneuse native (impression/partage).
  /// [context] est nécessaire pour afficher la visionneuse via le package printing.
  static Future<void> openPdf(
    BuildContext context,
    HospitalService service,
  ) async {
    // Génère le document PDF en mémoire
    final pdf = await _buildDocument(service);

    // Convertit le document PDF en bytes (données binaires)
    final bytes = await pdf.save();

    // Ouvre la visionneuse PDF native (impression, partage, téléchargement)
    // layoutBuilder : définit le format de page (A4 ici)
    await Printing.layoutPdf(
      onLayout: (_) => bytes,         // Fournit les bytes du PDF
      name: '${service.name}.pdf',    // Nom du fichier PDF
    );
  }

  // --------------------------------------------------------------------------
  // Construction du document PDF
  // --------------------------------------------------------------------------

  /// Construit le document PDF complet avec toutes les sections.
  /// Retourne un objet [pw.Document] prêt à être sauvegardé en bytes.
  static Future<pw.Document> _buildDocument(HospitalService service) async {
    // Crée un nouveau document PDF vide
    final doc = pw.Document(
      title: service.name,          // Métadonnée : titre du document
      author: 'HôpitalConnect',     // Métadonnée : auteur
      subject: 'Fiche service hospitalier', // Métadonnée : sujet
    );

    // Ajoute une page au document avec le contenu du service
    doc.addPage(
      pw.MultiPage(                  // MultiPage : gère automatiquement les sauts de page
        pageFormat: PdfPageFormat.a4, // Format A4 standard (210×297mm)

        // Marges de la page
        margin: const pw.EdgeInsets.symmetric(
          horizontal: 40,  // 40 unités de marge gauche/droite
          vertical: 40,    // 40 unités de marge haut/bas
        ),

        // En-tête répété sur chaque page
        header: (context) => _buildHeader(service),

        // Pied de page répété sur chaque page
        footer: (context) => _buildFooter(context),

        // Contenu principal de la page
        build: (context) => [
          pw.SizedBox(height: 20), // Espacement après l'en-tête

          // Section Description (si renseignée)
          if (service.description.isNotEmpty)
            _buildSection('Description', service.description),

          // Section Localisation (si au moins un champ renseigné)
          if (service.building.isNotEmpty ||
              service.floor.isNotEmpty ||
              service.location.isNotEmpty)
            _buildInfoSection('Localisation', [
              if (service.building.isNotEmpty)
                _InfoLine('Bâtiment', service.building),
              if (service.floor.isNotEmpty)
                _InfoLine('Étage', service.floor),
              if (service.location.isNotEmpty)
                _InfoLine('Emplacement', service.location),
            ]),

          // Section Contact (si au moins un champ renseigné)
          if (service.headName.isNotEmpty ||
              service.phone.isNotEmpty ||
              service.email.isNotEmpty)
            _buildInfoSection('Contact', [
              if (service.headName.isNotEmpty)
                _InfoLine('Responsable', service.headName),
              if (service.phone.isNotEmpty)
                _InfoLine('Téléphone', service.phone),
              if (service.email.isNotEmpty)
                _InfoLine('Email', service.email),
            ]),

          // Section Infos pratiques (capacité et/ou horaires)
          if (service.capacity > 0 || service.openingHours.isNotEmpty)
            _buildInfoSection('Infos pratiques', [
              if (service.capacity > 0)
                _InfoLine('Capacité', '${service.capacity} lits / places'),
              if (service.openingHours.isNotEmpty)
                _InfoLine('Horaires', service.openingHours),
            ]),

          // Section Notes internes (si renseignées)
          if (service.notes.isNotEmpty)
            _buildNotesSection(service.notes),
        ],
      ),
    );

    return doc; // Retourne le document construit
  }

  // --------------------------------------------------------------------------
  // EN-TÊTE DE PAGE
  // --------------------------------------------------------------------------

  /// Construit l'en-tête coloré avec le nom, le type et le statut du service.
  static pw.Widget _buildHeader(HospitalService service) {
    return pw.Container(
      width: double.infinity,       // Prend toute la largeur de la page
      padding: const pw.EdgeInsets.all(20),

      // Fond bleu foncé (couleur navy du projet)
      decoration: const pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),

      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Ligne : titre "FICHE SERVICE" + badge statut
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Titre en petit texte blanc discret
              pw.Text(
                'FICHE SERVICE HOSPITALIER',
                style: pw.TextStyle(
                  color: PdfColor.fromInt(0x99FFFFFF), // Blanc semi-transparent
                  fontSize: 9,
                  letterSpacing: 1.5,        // Espacement des lettres
                ),
              ),

              // Badge statut (vert si actif, gris si inactif)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: service.isActive ? _mint : _textGrey,
                  borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(20)),
                ),
                child: pw.Text(
                  service.isActive ? 'ACTIF' : 'INACTIF',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 8), // Espacement

          // Nom du service en grand et gras
          pw.Text(
            service.name,
            style: pw.TextStyle(
              color: PdfColors.white,     // Blanc pur pour le nom
              fontSize: 24,              // Grande taille pour le titre principal
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 4),

          // Type de service en couleur bleue
          pw.Text(
            service.serviceType.label,   // Ex : "Cardiologie", "Urgences"
            style: const pw.TextStyle(
              color: PdfColor.fromInt(0xFFB0D4E0), // Bleu clair sur fond navy
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PIED DE PAGE
  // --------------------------------------------------------------------------

  /// Construit le pied de page avec la date de génération et le numéro de page.
  static pw.Widget _buildFooter(pw.Context context) {
    // Récupère la date et l'heure actuelles
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} à '
        '${now.hour.toString().padLeft(2, '0')}h'
        '${now.minute.toString().padLeft(2, '0')}';

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),

      // Ligne de séparation au-dessus du pied de page
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _bgLight, width: 1),
        ),
      ),

      padding: const pw.EdgeInsets.only(top: 6),

      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Date et heure de génération
          pw.Text(
            'Généré le $dateStr',
            style: const pw.TextStyle(
              color: _textGrey,
              fontSize: 8,
            ),
          ),

          // Numéro de page (ex : "Page 1 / 2")
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(
              color: _textGrey,
              fontSize: 8,
            ),
          ),

          // Nom de l'application
          pw.Text(
            'HôpitalConnect',
            style: pw.TextStyle(
              color: _blue,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SECTION TEXTE (Description)
  // --------------------------------------------------------------------------

  /// Construit une section avec un titre et un paragraphe de texte.
  static pw.Widget _buildSection(String title, String content) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16), // Espacement entre sections
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Titre de section avec fond gris clair
          _buildSectionTitle(title),
          pw.SizedBox(height: 8),

          // Contenu textuel
          pw.Text(
            content,
            style: const pw.TextStyle(
              color: PdfColor.fromInt(0xFF2C4A5A), // Bleu très foncé
              fontSize: 11,
              lineSpacing: 4,                       // Espacement entre les lignes
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SECTION INFOS (lignes clé : valeur)
  // --------------------------------------------------------------------------

  /// Construit une section avec un titre et des lignes clé-valeur.
  static pw.Widget _buildInfoSection(
      String title, List<_InfoLine> lines) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title), // Titre de la section
          pw.SizedBox(height: 8),

          // Conteneur avec fond gris clair pour les lignes d'info
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: _bgLight,          // Fond gris clair
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),

            child: pw.Column(
              children: lines.map((line) =>
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Clé (label) en gras et en bleu
                      pw.SizedBox(
                        width: 100, // Largeur fixe pour aligner les valeurs
                        child: pw.Text(
                          line.label,
                          style: pw.TextStyle(
                            color: _navy,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      // Séparateur
                      pw.Text(' : ',
                          style: const pw.TextStyle(
                              color: _textGrey, fontSize: 10)),
                      // Valeur
                      pw.Expanded(
                        child: pw.Text(
                          line.value,
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFF2C4A5A),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SECTION NOTES (fond jaune)
  // --------------------------------------------------------------------------

  /// Construit la section des notes internes avec un fond jaune.
  static pw.Widget _buildNotesSection(String notes) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Notes internes'),
          pw.SizedBox(height: 8),

          // Container jaune pâle pour les notes
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFF8E7), // Jaune très pâle
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.fromBorderSide(
                pw.BorderSide(
                  color: PdfColor.fromInt(0xFFFFE082), // Bordure jaune
                  width: 1,
                ),
              ),
            ),
            child: pw.Text(
              notes,
              style: const pw.TextStyle(
                color: PdfColor.fromInt(0xFF5D4037), // Marron foncé
                fontSize: 10,
                lineSpacing: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TITRE DE SECTION (réutilisable)
  // --------------------------------------------------------------------------

  /// Construit un titre de section avec une barre bleue à gauche.
  static pw.Widget _buildSectionTitle(String title) {
    return pw.Row(
      children: [
        // Barre colorée à gauche du titre
        pw.Container(
          width: 4, height: 16,
          decoration: const pw.BoxDecoration(
            color: _blue,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 8),
        // Texte du titre en majuscules
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            color: _navy,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Classe utilitaire privée : paire clé-valeur pour les sections d'info
// =============================================================================

/// Représente une ligne "label : valeur" dans une section d'information.
class _InfoLine {
  const _InfoLine(this.label, this.value);
  final String label; // Ex : "Bâtiment"
  final String value; // Ex : "Bâtiment A"
}

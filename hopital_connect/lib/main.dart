// =============================================================================
// POINT D'ENTRÉE — APP COMPLÈTE avec login + backend
// =============================================================================

import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  // Initialise les bindings Flutter avant tout appel async
  WidgetsFlutterBinding.ensureInitialized();

  // L'application démarre sur le splash screen animé, qui restaure la
  // session sauvegardée (token) pendant l'animation puis ouvre le tableau
  // de bord ou la page de connexion.
  runApp(const HopitalConnectApp(showSplash: true));
}

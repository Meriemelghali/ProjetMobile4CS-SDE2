// =============================================================================
// POINT D'ENTRÉE — APP COMPLÈTE avec login + backend
// =============================================================================

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/session/app_session.dart';
import 'core/session/session_manager.dart';

Future<void> main() async {
  // Initialise les bindings Flutter avant tout appel async
  WidgetsFlutterBinding.ensureInitialized();

  // Tente de restaurer une session existante (token sauvegardé)
  final restored = await SessionManager.instance.restore();

  runApp(
    HopitalConnectApp(
      // Si un token valide existe → ouvre le dashboard directement
      // Sinon → affiche la page de login
      initialSession: restored == null
          ? null
          : AppSession(token: restored.token, user: restored.user),
    ),
  );
}

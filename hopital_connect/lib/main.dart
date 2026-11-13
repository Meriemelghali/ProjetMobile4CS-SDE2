import 'package:flutter/material.dart';

import 'app.dart';
import 'core/session/app_session.dart';
import 'core/session/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final restored = await SessionManager.instance.restore();
  runApp(
    HopitalConnectApp(
      initialSession: restored == null
          ? null
          : AppSession(token: restored.token, user: restored.user),
    ),
  );
}

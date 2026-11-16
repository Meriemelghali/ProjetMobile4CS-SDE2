// =============================================================================
// SPLASH SCREEN animé
// Logo qui apparaît (échelle + fondu), croix médicale pulsée, onde ECG
// tracée progressivement. Pendant l'animation, la session sauvegardée est
// restaurée ; on bascule ensuite en fondu vers la connexion ou le tableau
// de bord.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/session/app_session.dart';
import '../../core/session/session_manager.dart';
import '../auth/presentation/login_page.dart';
import '../dashboard/presentation/dashboard_page.dart';

typedef SessionRestorer = Future<AppSession?> Function();

Future<AppSession?> restoreSavedSession() async {
  final restored = await SessionManager.instance.restore();
  return restored == null
      ? null
      : AppSession(token: restored.token, user: restored.user);
}

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.restoreSession = restoreSavedSession,
    this.minimumDuration = const Duration(milliseconds: 2200),
    this.destinationBuilder,
  });

  final SessionRestorer restoreSession;
  final Duration minimumDuration;

  /// Permet aux tests de remplacer les écrans de destination.
  final Widget Function(AppSession? session)? destinationBuilder;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    AppSession? session;
    try {
      final results = await Future.wait<Object?>([
        widget.restoreSession(),
        Future<void>.delayed(widget.minimumDuration),
      ]);
      session = results.first as AppSession?;
    } catch (_) {
      session = null;
    }
    if (!mounted) return;
    final destination =
        widget.destinationBuilder?.call(session) ??
        (session == null ? const LoginPage() : DashboardPage(session: session));
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 1.04, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Animation<double> _interval(
    double begin,
    double end, {
    Curve curve = Curves.easeOutCubic,
  }) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final logoScale = Tween(
      begin: 0.4,
      end: 1.0,
    ).animate(_interval(0, 0.45, curve: Curves.elasticOut));
    final logoFade = _interval(0, 0.25);
    final ecg = _interval(0.3, 0.85, curve: Curves.easeInOut);
    final titleFade = _interval(0.45, 0.75);
    final titleSlide = Tween(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(_interval(0.45, 0.8));
    final taglineFade = _interval(0.65, 1);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B2233), Color(0xFF123047), Color(0xFF176B87)],
          ),
        ),
        child: Stack(
          children: [
            // Halo décoratif
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) =>
                    CustomPaint(painter: _HaloPainter(progress: _pulse.value)),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: logoFade,
                    child: ScaleTransition(
                      scale: logoScale,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) => Transform.scale(
                          scale: 1 + _pulse.value * 0.04,
                          child: child,
                        ),
                        child: const _Logo(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 220,
                    height: 46,
                    child: AnimatedBuilder(
                      animation: ecg,
                      builder: (context, _) => CustomPaint(
                        painter: _EcgPainter(progress: ecg.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FadeTransition(
                    opacity: titleFade,
                    child: SlideTransition(
                      position: titleSlide,
                      child: const Text(
                        'HôpitalConnect',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: taglineFade,
                    child: const Text(
                      'La coordination au cœur des équipes',
                      style: TextStyle(color: Color(0xFFB7D3DE), fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: FadeTransition(
                opacity: taglineFade,
                child: const Column(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF36A98B),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Prototype étudiant · données fictives',
                      style: TextStyle(color: Color(0xFF7FA3B3), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 112,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(34),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF36A98B).withValues(alpha: 0.45),
          blurRadius: 40,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF176B87), Color(0xFF36A98B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 52),
      ),
    ),
  );
}

/// Tracé ECG révélé progressivement, avec un point lumineux en tête.
class _EcgPainter extends CustomPainter {
  _EcgPainter({required this.progress});

  final double progress;

  static const _points = [
    Offset(0, 0.5),
    Offset(0.22, 0.5),
    Offset(0.28, 0.42),
    Offset(0.33, 0.5),
    Offset(0.4, 0.5),
    Offset(0.44, 0.62),
    Offset(0.49, 0.05),
    Offset(0.54, 0.95),
    Offset(0.58, 0.5),
    Offset(0.66, 0.5),
    Offset(0.72, 0.36),
    Offset(0.78, 0.5),
    Offset(1, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(_points.first.dx * size.width, _points.first.dy * size.height);
    for (final point in _points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    final metric = path.computeMetrics().first;
    final visible = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      visible,
      Paint()
        ..color = const Color(0xFF36A98B).withValues(alpha: 0.35)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      visible,
      Paint()
        ..color = const Color(0xFF7FE0C2)
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final head = metric.getTangentForOffset(metric.length * progress)?.position;
    if (head != null && progress < 1) {
      canvas.drawCircle(head, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_EcgPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Cercles concentriques qui « respirent » derrière le logo.
class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 70);
    final base = math.min(size.width, size.height) * 0.22;
    for (var i = 0; i < 3; i++) {
      final radius = base + i * 46 + progress * 10;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.07 - i * 0.018),
      );
    }
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_service.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSigningIn = true);
    try {
      final session = await AuthService().login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DashboardPage(session: session),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _openRegistration() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10123047),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Connexion',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Connectez-vous à votre compte HôpitalConnect.',
                            style: TextStyle(
                              color: Color(0xFF687B86),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _FieldLabel('Adresse e-mail'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'nom@hopital.fr',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Saisissez votre adresse e-mail.';
                              }
                              if (!value.contains('@')) {
                                return 'Vérifiez le format de votre adresse e-mail.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          const _FieldLabel('Mot de passe'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _hidePassword,
                            onFieldSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              hintText: 'Votre mot de passe',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _hidePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Saisissez votre mot de passe.';
                              }
                              if (value.length < 10) {
                                return 'Le mot de passe doit contenir au moins 10 caractères.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isSigningIn ? null : _openRegistration,
                            child: const Text('Créer un compte patient'),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _isSigningIn ? null : _signIn,
                            icon: _isSigningIn
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward),
                            label: Text(
                              _isSigningIn ? 'Connexion…' : 'Se connecter',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              backgroundColor: AppColors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 7,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: AppColors.blue,
                      ),
                      Text(
                        'Accès sécurisé pour les patients et le personnel',
                        style: TextStyle(
                          color: Color(0xFF687B86),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Votre rôle et vos droits sont chargés depuis votre compte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF81919A), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFE1F2EF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: AppColors.blue,
            size: 42,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'HôpitalConnect',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'La coordination au cœur des équipes',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF687B86), fontSize: 14),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.navy,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gavel_logo.dart';
import '../../widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showPasswordForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (ok && mounted) context.go('/home');
  }

  Future<void> _loginWithPasskey(AuthProvider auth) async {
    final email = _emailController.text.trim();
    final ok = await auth.loginWithPasskey(email: email.isEmpty ? null : email);
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final showPasskeyOption = auth.passkeysSupported;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/welcome'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Center(child: GavelLogo(size: 72)),
              const SizedBox(height: 16),
              Text('Bienvenido Mánager',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                'Entra a tu liga y controla tus cláusulazos',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showPasskeyOption) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_rounded,
                                color: AppColors.primaryGreen, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Entra con Face ID, huella o el bloqueo de tu dispositivo — sin contraseña.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      PrimaryButton(
                        label: 'Continuar con Face ID',
                        icon: Icons.fingerprint,
                        isLoading: auth.isLoading,
                        onPressed: () => _loginWithPasskey(auth),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.divider)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('o conéctate con',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: AppColors.divider)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_showPasswordForm)
                        OutlinedButton(
                          onPressed: () =>
                              setState(() => _showPasswordForm = true),
                          child: const Text('Usar email y contraseña'),
                        ),
                    ],
                    if (_showPasswordForm || !showPasskeyOption) ...[
                      if (showPasskeyOption) const SizedBox(height: 4),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email_rounded,
                                    size: 20),
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Introduce un email válido'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Introduce tu contraseña'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            PrimaryButton(
                              label: 'Entrar a mi liga',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: auth.isLoading,
                              onPressed: () => _submit(auth),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        auth.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.dangerRed, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Aún no tienes cuenta?',
                      style: AppTextStyles.body(
                          fontSize: 13, color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Regístrate aquí'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

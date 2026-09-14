import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
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
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showPasskeyOption) ...[
                const SizedBox(height: 12),
                const Icon(Icons.face_retouching_natural, size: 48, color: AppColors.primaryGreen),
                const SizedBox(height: 12),
                const Text(
                  'Entra con Face ID, huella o el bloqueo de tu dispositivo — sin contraseña.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Continuar con Face ID',
                  icon: Icons.fingerprint,
                  isLoading: auth.isLoading,
                  onPressed: () => _loginWithPasskey(auth),
                ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(child: Divider(color: AppColors.divider)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    Expanded(child: Divider(color: AppColors.divider)),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_showPasswordForm)
                  OutlinedButton(
                    onPressed: () => setState(() => _showPasswordForm = true),
                    child: const Text('Usar email y contraseña'),
                  ),
              ],
              if (_showPasswordForm || !showPasskeyOption) ...[
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Introduce un email válido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Introduce tu contraseña' : null,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'INICIAR SESIÓN',
                        isLoading: auth.isLoading,
                        onPressed: () => _submit(auth),
                      ),
                    ],
                  ),
                ),
              ],
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.dangerRed),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('¿No tienes cuenta?', style: TextStyle(color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('CREAR CUENTA'),
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

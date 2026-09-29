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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _showPasswordForm = false;

  // Drives the glow behind the form: 2.5 s brighter, 2.5 s dimmer (a 5 s cycle), eased at both ends.
  // Purely decorative; disposed with the screen.
  late final AnimationController _glowController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500))
    ..repeat(reverse: true);
  late final Animation<double> _glowBreath =
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);

  @override
  void dispose() {
    _glowController.dispose();
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
              const SizedBox(height: 24),
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
              // Soft, slowly breathing light behind the form card (see `_FormGlow`).
              _FormGlow(
                animation: _glowBreath,
                child: Container(
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
                                  prefixIcon: Icon(
                                      Icons.alternate_email_rounded,
                                      size: 20),
                                ),
                                validator: (v) =>
                                    (v == null || !v.contains('@'))
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

/// A wide, blurred light behind `child` (the login form card) that breathes very slowly: its strength
/// goes from `minAlpha` to `maxAlpha` and back as `animation` runs 0..1..0, so it never disappears and
/// the change is barely noticeable. It sits under the card and never takes touches.
class _FormGlow extends StatelessWidget {
  const _FormGlow({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  static const double minAlpha = 0.05;
  static const double maxAlpha = 0.085;

  // A greenish white, in line with the Splash glow but softer.
  static final Color _tint =
      Color.lerp(AppColors.primaryGreen, Colors.white, 0.25)!;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Generous box around the card; the gradient (radius 0.5 of its shorter side) fades to nothing
        // before reaching any of its edges, so no edge or disc is ever visible.
        Positioned(
          left: -60,
          right: -60,
          top: -140,
          bottom: -140,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final alpha =
                    minAlpha + (maxAlpha - minAlpha) * animation.value;
                return DecoratedBox(
                  key: const Key('login-form-glow'),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.5,
                      colors: [
                        _tint.withValues(alpha: alpha),
                        _tint.withValues(alpha: alpha * 0.45),
                        _tint.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        child,
      ],
    );
  }
}

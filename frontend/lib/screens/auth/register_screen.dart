import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _acceptedRules = false;
  double _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // UI-only strength heuristic (length and variety).
  void _updatePasswordStrength() {
    final value = _passwordController.text;
    var score = 0;
    if (value.length >= 6) score++;
    if (value.length >= 10) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value))
      score++;
    setState(() => _passwordStrength = score / 4);
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate() || !_acceptedRules) return;
    final ok = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmController.text,
    );
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
                      icon: const Icon(Icons.arrow_back_rounded)),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.gavel_rounded,
                          color: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Crear cuenta',
                              style: AppTextStyles.headline(fontSize: 20)),
                          const SizedBox(height: 2),
                          Text(
                            'Únete a tu liga de Clausulazos',
                            style: AppTextStyles.body(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de mánager',
                        prefixIcon:
                            Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El nombre es obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon:
                            Icon(Icons.alternate_email_rounded, size: 20),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Introduce un email válido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña segura',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(4, (i) {
                        final filled = _passwordStrength * 4 > i;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                            decoration: BoxDecoration(
                              color: filled
                                  ? AppColors.primaryGreen
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      validator: (v) => (v != _passwordController.text)
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REGLAS DE CLÁUSULA ACTIVAS',
                            style: AppTextStyles.mono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary)
                                .copyWith(letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 8),
                          const _RuleLine(
                              text:
                                  'Máx. ${AppConfig.maxActiveClauses} activas por sentido (realizadas/recibidas)'),
                          const SizedBox(height: 4),
                          const _RuleLine(
                              text:
                                  '${AppConfig.clauseDurationDays} días de cooldown exactos por cláusulazo'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () =>
                          setState(() => _acceptedRules = !_acceptedRules),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _acceptedRules,
                            onChanged: (v) =>
                                setState(() => _acceptedRules = v ?? false),
                          ),
                          Expanded(
                            child: Text(
                              'Acepto el reglamento de cláusulas de la liga',
                              style: AppTextStyles.body(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(auth.errorMessage!,
                          style: const TextStyle(
                              color: AppColors.dangerRed, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Crear perfil y unirme',
                      icon: Icons.arrow_forward_rounded,
                      isLoading: auth.isLoading,
                      onPressed: _acceptedRules ? () => _submit(auth) : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¿Ya estás registrado?',
                      style: AppTextStyles.body(
                          fontSize: 13, color: AppColors.textSecondary)),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Inicia sesión'),
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

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 14, color: AppColors.primaryGreen),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: AppTextStyles.body(
                    fontSize: 12, color: AppColors.textPrimary))),
      ],
    );
  }
}

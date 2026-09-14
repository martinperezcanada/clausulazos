import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/release_time_formatter.dart';
import '../../models/passkey.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/passkeys_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/primary_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().refreshAll();
      context.read<ClauseProvider>().loadHistory();
      context.read<PasskeysProvider>().load();
    });
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/welcome');
  }

  Future<void> _openChangePassword(BuildContext context) async {
    await showDialog(context: context, builder: (_) => const _ChangePasswordDialog());
  }

  Future<void> _addPasskey(BuildContext context) async {
    final name = await showDialog<String>(context: context, builder: (_) => const _AddPasskeyDialog());
    if (name == null || !context.mounted) return; // cancelled
    final provider = context.read<PasskeysProvider>();
    final ok = await provider.registerPasskey(name: name.isEmpty ? null : name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Passkey añadida correctamente.' : (provider.errorMessage ?? 'No se ha podido añadir la passkey.'))),
    );
  }

  Future<void> _deletePasskey(BuildContext context, PasskeyInfo passkey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar passkey'),
        content: Text('¿Seguro que quieres eliminar "${passkey.displayName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<PasskeysProvider>().deletePasskey(passkey.id);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final clauseProvider = context.watch<ClauseProvider>();
    final passkeysProvider = context.watch<PasskeysProvider>();
    final user = authProvider.currentUser;
    final stats = userProvider.myStats;

    final myId = user?.id;
    final totalPerformed = myId == null ? 0 : clauseProvider.history.where((c) => c.fromUserId == myId).length;
    final totalReceived = myId == null ? 0 : clauseProvider.history.where((c) => c.toUserId == myId).length;

    DateTime? nextRelease;
    if (stats != null) {
      final candidates = [stats.performed.nextReleaseAt, stats.received.nextReleaseAt].whereType<DateTime>().toList()
        ..sort();
      if (candidates.isNotEmpty) nextRelease = candidates.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            context.read<UserProvider>().refreshAll(),
            context.read<ClauseProvider>().loadHistory(),
            context.read<PasskeysProvider>().load(),
          ]),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.surfaceElevated,
                    child: Text(
                      (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 26, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              const _SectionLabel('CLÁUSULAS'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MiniStat(label: 'Realizados', value: '$totalPerformed')),
                  const SizedBox(width: 10),
                  Expanded(child: _MiniStat(label: 'Recibidos', value: '$totalReceived')),
                ],
              ),
              const SizedBox(height: 10),
              if (stats != null)
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: 'Activos realizados',
                        value: '${stats.performed.active}/${stats.performed.limit}',
                        highlight: stats.performed.isExceeded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniStat(
                        label: 'Activos recibidos',
                        value: '${stats.received.active}/${stats.received.limit}',
                        highlight: stats.received.isExceeded,
                      ),
                    ),
                  ],
                ),
              if (nextRelease != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        'Próxima liberación: ${ReleaseTimeFormatter.dayAndTime(nextRelease)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              const _SectionLabel('CUENTA'),
              const SizedBox(height: 10),
              _ActionRow(
                icon: Icons.lock_outline_rounded,
                label: 'Cambiar contraseña',
                onTap: () => _openChangePassword(context),
              ),

              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionLabel('PASSKEYS / FACE ID'),
                  if (passkeysProvider.isSupported)
                    TextButton.icon(
                      onPressed: passkeysProvider.isRegistering ? null : () => _addPasskey(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Configurar Face ID'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (!passkeysProvider.isSupported)
                const Text(
                  'Este navegador no admite Passkeys/Face ID.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                )
              else if (passkeysProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (passkeysProvider.passkeys.isEmpty)
                const Text(
                  'Todavía no tienes ninguna passkey registrada.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                )
              else
                ...passkeysProvider.passkeys.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      leading: const Icon(Icons.fingerprint, color: AppColors.primaryGreen),
                      title: Text(p.displayName),
                      subtitle: Text(
                        p.lastUsedAt != null
                            ? 'Último uso: ${ReleaseTimeFormatter.dayAndTime(p.lastUsedAt!)}'
                            : 'Nunca usada',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                        onPressed: () => _deletePasskey(context, p),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              PrimaryButton(label: 'Cerrar sesión', onPressed: () => _logout(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.dangerRed : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final ok = await context.read<AuthProvider>().changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _error = context.read<AuthProvider>().errorMessage ?? 'No se ha podido cambiar la contraseña.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Cambiar contraseña'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
              validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.dangerRed, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: _isSubmitting ? null : _submit, child: const Text('Guardar')),
      ],
    );
  }
}

class _AddPasskeyDialog extends StatefulWidget {
  const _AddPasskeyDialog();

  @override
  State<_AddPasskeyDialog> createState() => _AddPasskeyDialogState();
}

class _AddPasskeyDialogState extends State<_AddPasskeyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Configurar Face ID'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Tu navegador te pedirá confirmar con Face ID, huella u otro bloqueo de tu dispositivo.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: 'Nombre (opcional)', hintText: 'iPhone de Martín'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

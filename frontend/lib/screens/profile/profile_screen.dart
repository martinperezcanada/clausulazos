import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/release_time_formatter.dart';
import '../../core/theme/sync_time_formatter.dart';
import '../../core/webauthn/webauthn_client.dart';
import '../../models/fantasy_sync_status.dart';
import '../../models/passkey.dart';
import '../../providers/auth_provider.dart';
import '../../providers/clause_provider.dart';
import '../../providers/fantasy_sync_provider.dart';
import '../../providers/passkeys_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/dashboard/pulsing_dot.dart';

/// Profile screen. Its data comes from `UserProvider`, `ClauseProvider` and `FantasySyncProvider`.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Whether this device/browser has a platform authenticator (Face ID, Touch ID, Android biometrics,
  // Windows Hello), via `WebAuthnClient.isPlatformAuthenticatorAvailable()`. Always false on non-Web
  // builds (stub client), so the passkeys section never offers Face ID where it can't work.
  bool _platformAuthenticatorAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _loadPasskeys();
    });
  }

  Future<void> _loadPasskeys() async {
    final passkeys = context.read<PasskeysProvider>();
    if (!passkeys.isSupported) return;
    final available =
        await const WebAuthnClient().isPlatformAuthenticatorAvailable();
    if (!mounted) return;
    setState(() => _platformAuthenticatorAvailable = available);
    await passkeys.load();
  }

  Future<void> _addPasskey() async {
    final provider = context.read<PasskeysProvider>();
    final ok = await provider.registerPasskey();
    if (!mounted) return;
    AppSnackBar.show(
      context,
      message: ok
          ? 'Passkey añadida correctamente.'
          : (provider.errorMessage ?? 'No se ha podido añadir la passkey.'),
      icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline,
      iconColor: ok ? AppColors.primaryGreen : AppColors.dangerRed,
    );
  }

  Future<void> _deletePasskey(PasskeyInfo passkey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar passkey'),
        content: Text('¿Seguro que quieres eliminar "${passkey.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<PasskeysProvider>();
    final ok = await provider.deletePasskey(passkey.id);
    if (!mounted || ok) return;
    AppSnackBar.show(
      context,
      message: provider.errorMessage ?? 'No se ha podido eliminar la passkey.',
      icon: Icons.error_outline,
      iconColor: AppColors.dangerRed,
    );
  }

  Future<void> _refresh() => Future.wait([
        context.read<UserProvider>().refreshAll(),
        context.read<ClauseProvider>().loadHistory(),
        context.read<FantasySyncProvider>().load(),
      ]);

  Future<void> _logout(BuildContext context) async {
    // Ask first: the logout only runs after an explicit confirmation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _LogoutConfirmDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/welcome');
  }

  String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second =
        parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final initials = (first + second).toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final clauseProvider = context.watch<ClauseProvider>();
    final syncProvider = context.watch<FantasySyncProvider>();
    final passkeysProvider = context.watch<PasskeysProvider>();
    final user = authProvider.currentUser;

    // Only where WebAuthn works and a platform authenticator is available, or when passkeys already
    // exist so they can still be reviewed and deleted.
    final showPasskeys = passkeysProvider.isSupported &&
        (_platformAuthenticatorAvailable ||
            passkeysProvider.passkeys.isNotEmpty);

    final myId = user?.id;
    final totalPerformed = myId == null
        ? 0
        : clauseProvider.history.where((c) => c.fromUserId == myId).length;
    final totalReceived = myId == null
        ? 0
        : clauseProvider.history.where((c) => c.toUserId == myId).length;

    final clauseHasPending = myId == null
        ? false
        : clauseProvider.history.any((c) => c.needsConfirmationFrom(myId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title:
            AppTopBar(userName: user?.name ?? '', hasPending: clauseHasPending),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeaderCard(
                  name: user?.name ?? '',
                  initials: _initialsFor(user?.name ?? '')),
              const SizedBox(height: 20),
              _DiagonalStatsCard(
                totalPerformed: totalPerformed,
                totalReceived: totalReceived,
              ),
              const SizedBox(height: 20),
              _GovernanceCard(syncStatus: syncProvider.status),
              if (showPasskeys) ...[
                const SizedBox(height: 20),
                _PasskeysCard(
                  passkeys: passkeysProvider.passkeys,
                  isLoading: passkeysProvider.isLoading,
                  isRegistering: passkeysProvider.isRegistering,
                  canAdd: _platformAuthenticatorAvailable,
                  onAdd: _addPasskey,
                  onDelete: _deletePasskey,
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _logout(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.surfaceHighest,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout_rounded,
                        size: 20, color: AppColors.dangerRed),
                    label: Text(
                      'Cerrar Sesión',
                      style: AppTextStyles.headline(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dangerRed),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'CLAUSULAZOS',
                    style: AppTextStyles.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)
                        .copyWith(letterSpacing: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.textSecondary.withOpacity(0.5)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '1.1',
                    style: AppTextStyles.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryGreen)
                        .copyWith(letterSpacing: 0.6),
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

/// User card at the top of Profile: avatar and name.
class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.name, required this.initials});

  final String name;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surfaceElevated),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryGreen.withOpacity(0.35)),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProfileAvatar(initials: initials),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.headline(
                        fontSize: 24, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 80px initials avatar with a gradient ring and glow (same initials pattern as `AppTopBar`); there is
/// no avatar upload.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Two-tone loop (green -> blue -> green) so the ring has no visible gap.
              gradient: const SweepGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.infoBlue,
                  AppColors.primaryGreen,
                ],
              ),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.45),
                    blurRadius: 18)
              ],
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.background),
              child: Text(initials,
                  style: AppTextStyles.mono(
                      fontSize: 24, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single "confrontation" card for performed vs received clauses, split by a diagonal seam positioned
/// from the `totalPerformed`/`totalReceived` counts (not a fixed 50/50).
class _DiagonalStatsCard extends StatelessWidget {
  const _DiagonalStatsCard({
    required this.totalPerformed,
    required this.totalReceived,
  });

  final int totalPerformed;
  final int totalReceived;

  @override
  Widget build(BuildContext context) {
    final total = totalPerformed + totalReceived;
    // With no clauses at all the ratio is undefined: split evenly.
    final greenFraction = total > 0 ? totalPerformed / total : 0.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 108,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surface),
            CustomPaint(painter: _DiagonalSplitPainter(greenFraction)),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryGreen),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'EJECUTADAS',
                              style: AppTextStyles.mono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)
                                  .copyWith(letterSpacing: 0.6),
                            ),
                          ],
                        ),
                        Text(
                          '$totalPerformed',
                          style: AppTextStyles.headline(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'RECIBIDAS',
                              style: AppTextStyles.mono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)
                                  .copyWith(letterSpacing: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.dangerRed),
                            ),
                          ],
                        ),
                        Text(
                          '$totalReceived',
                          style: AppTextStyles.headline(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dangerRed),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the diagonal seam: a green wedge (left, sized by `greenFraction`) and a red wedge (right)
/// sharing one slanted edge, so there is no gap between two rectangles.
class _DiagonalSplitPainter extends CustomPainter {
  const _DiagonalSplitPainter(this.greenFraction);

  final double greenFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final slant = size.height * 0.4;
    final centerX = size.width * greenFraction;
    final topX = (centerX + slant / 2).clamp(0.0, size.width);
    final bottomX = (centerX - slant / 2).clamp(0.0, size.width);

    final greenPath = Path()
      ..moveTo(0, 0)
      ..lineTo(topX, 0)
      ..lineTo(bottomX, size.height)
      ..lineTo(0, size.height)
      ..close();
    final redPath = Path()
      ..moveTo(topX, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(bottomX, size.height)
      ..close();

    canvas.drawPath(
        greenPath, Paint()..color = AppColors.primaryGreen.withOpacity(0.16));
    canvas.drawPath(
        redPath, Paint()..color = AppColors.dangerRed.withOpacity(0.16));
    canvas.drawLine(
      Offset(topX, 0),
      Offset(bottomX, size.height),
      Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _DiagonalSplitPainter oldDelegate) =>
      oldDelegate.greenFraction != greenFraction;
}

/// "Reglas & Gobernanza de Liga". The clause-limit rule uses the `AppConfig` constants and the Fantasy
/// sync row uses `FantasySyncStatus`. "Notificaciones Push" is a fixed, non-interactive switch (there's
/// no per-user preference), deliberately not a real `Switch` so it can't be mistaken for a working
/// toggle.
class _GovernanceCard extends StatelessWidget {
  const _GovernanceCard({required this.syncStatus});

  final FantasySyncStatus? syncStatus;

  @override
  Widget build(BuildContext context) {
    final synced = syncStatus?.lastSuccessfulSyncAt != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text('Reglas & Gobernanza de Liga',
                  style: AppTextStyles.headline(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _GovernanceRow(
            icon: Icons.rule_rounded,
            title: 'Límites de Clausulazo',
            subtitle:
                'Máx ${AppConfig.maxActiveClauses} activas · ${AppConfig.clauseDurationDays} días por cláusula',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(
                'Estricto',
                style: AppTextStyles.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryGreen),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _GovernanceRow(
            icon: Icons.sync_rounded,
            title: 'Sincronización LaLiga Fantasy',
            subtitle: 'Conectado vía Token API',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: PulsingDot(
                      color: synced
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                      size: 6),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    SyncTimeFormatter.describe(
                        syncStatus?.lastSuccessfulSyncAt),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.mono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: synced
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _GovernanceRow(
            icon: Icons.notifications_active_rounded,
            title: 'Notificaciones Push',
            subtitle: 'Alertar 1h antes de expirar blindaje',
            trailing: Container(
              width: 40,
              height: 22,
              padding: const EdgeInsets.all(2),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(999)),
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.background),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "PASSKEYS / FACE ID": the passkeys registered on this account (`PasskeysProvider`,
/// `/auth/passkeys`) and the action to add one through the browser's WebAuthn dialog. Same card and row
/// style as `_GovernanceCard`.
class _PasskeysCard extends StatelessWidget {
  const _PasskeysCard({
    required this.passkeys,
    required this.isLoading,
    required this.isRegistering,
    required this.canAdd,
    required this.onAdd,
    required this.onDelete,
  });

  final List<PasskeyInfo> passkeys;
  final bool isLoading;
  final bool isRegistering;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<PasskeyInfo> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint,
                  color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text('Passkeys / Face ID',
                  style: AppTextStyles.headline(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading && passkeys.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (passkeys.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Todavía no tienes ninguna passkey registrada.',
                style: AppTextStyles.body(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            for (final passkey in passkeys) ...[
              _GovernanceRow(
                icon: Icons.fingerprint,
                title: passkey.displayName,
                subtitle: passkey.lastUsedAt != null
                    ? 'Último uso: ${ReleaseTimeFormatter.dayAndTime(passkey.lastUsedAt!)}'
                    : 'Nunca usada',
                trailing: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Eliminar passkey',
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.dangerRed, size: 20),
                    onPressed: () => onDelete(passkey),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          if (canAdd)
            Semantics(
              container: true,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isRegistering ? null : onAdd,
                child: _GovernanceRow(
                  icon: Icons.add_moderator_outlined,
                  title: 'Configurar Face ID',
                  subtitle:
                      'Confirma con Face ID, huella o el bloqueo de tu dispositivo.',
                  trailing: Align(
                    alignment: Alignment.centerRight,
                    child: isRegistering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_rounded,
                            color: AppColors.primaryGreen, size: 22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Cerrar sesión" confirmation in the app's own style instead of the stock `AlertDialog`. Pops `true`
/// only when the user confirms.
class _LogoutConfirmDialog extends StatelessWidget {
  const _LogoutConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dangerRed.withOpacity(0.12),
              ),
              child: const Icon(Icons.logout_rounded,
                  size: 24, color: AppColors.dangerRed),
            ),
            const SizedBox(height: 18),
            Text(
              '¿Cerrar sesión?',
              textAlign: TextAlign.center,
              style: AppTextStyles.headline(
                  fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Estás seguro de que quieres cerrar sesión?',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.dangerRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GovernanceRow extends StatelessWidget {
  const _GovernanceRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.trailing});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.body(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(flex: 2, child: trailing),
        ],
      ),
    );
  }
}

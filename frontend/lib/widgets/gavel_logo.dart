import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// The CLAUSULAZOS logo: a judge's gavel over its sound block on a rounded tile. Shared by the splash
/// (which animates `angle`/`ring`) and the login (static), so both show the same logo. Scales
/// proportionally with `size` (designed at 128).
///
/// `angle` is the gavel's swing around the top of its handle (0 = struck, negative = raised); `ring` is
/// the impact ripple progress (0 = none).
class GavelLogo extends StatelessWidget {
  const GavelLogo({super.key, this.size = 128, this.angle = 0, this.ring = 0});

  final double size;
  final double angle;
  final double ring;

  @override
  Widget build(BuildContext context) {
    final scale = size / 128;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.14),
            blurRadius: 40 * scale,
            spreadRadius: 1 * scale,
          ),
        ],
      ),
      child: CustomPaint(painter: GavelPainter(angle: angle, ring: ring)),
    );
  }
}

/// Draws the gavel with plain rounded rectangles so it stays crisp at any size. Accents: two green
/// bands on the head and, on impact, a green ripple from the block.
class GavelPainter extends CustomPainter {
  GavelPainter({required this.angle, required this.ring});

  final double angle;
  final double ring;

  // Drawn in a 128 x 128 design space.
  static const double _pivotX = 64;
  static const double _pivotY = 18;
  static const double _blockTop = 92;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 128, size.height / 128);

    // Sound block.
    final block = RRect.fromRectAndRadius(
      const Rect.fromLTWH(28, _blockTop, 72, 12),
      const Radius.circular(5),
    );
    canvas.drawRRect(block, Paint()..color = const Color(0xFF3B4859));

    // Impact ripple.
    if (ring > 0 && ring < 1) {
      final radius = 8 + 46 * Curves.easeOut.transform(ring);
      canvas.drawCircle(
        const Offset(64, _blockTop),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.primaryGreen.withValues(alpha: 0.55 * (1 - ring)),
      );
    }

    // Gavel, swinging around the top of its handle.
    canvas.save();
    canvas.translate(_pivotX, _pivotY);
    canvas.rotate(angle);

    final handle = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-4.5, 0, 9, 54),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(handle, Paint()..color = const Color(0xFFAAB6C4));

    final headRect =
        Rect.fromCenter(center: const Offset(0, 60), width: 54, height: 28);
    final head = RRect.fromRectAndRadius(headRect, const Radius.circular(9));
    canvas.drawRRect(
      head,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4F7FA), Color(0xFFC3CEDA)],
        ).createShader(headRect),
    );

    // Two thin green bands near the ends of the head.
    canvas.save();
    canvas.clipRRect(head);
    final band = Paint()..color = AppColors.primaryGreen;
    for (final x in const [-17.0, 17.0]) {
      canvas.drawRect(
          Rect.fromCenter(center: Offset(x, 60), width: 5, height: 28), band);
    }
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GavelPainter old) =>
      old.angle != angle || old.ring != ring;
}

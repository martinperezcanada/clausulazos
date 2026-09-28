import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A free clause slot ("Slot N libre") inside the Cláusulas Ejecutadas/Recibidas cards.
class SlotStatus extends StatelessWidget {
  const SlotStatus({super.key, required this.slotNumber, required this.hint});

  final int slotNumber;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Slot $slotNumber libre',
                    style: AppTextStyles.body(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(hint,
                    style: AppTextStyles.body(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

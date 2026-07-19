import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Gros bouton d'enregistrement, pensé pour être actionné sans réflexion,
/// juste avant/pendant la prière. Pulse au rythme du niveau sonore.
class RecordButton extends StatelessWidget {
  final bool isRecording;
  final double amplitude; // 0..1
  final VoidCallback onTap;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.amplitude,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double ring = isRecording ? 12 + amplitude * 26 : 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(
            color: isRecording ? AppColors.danger : AppColors.gold,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: (isRecording ? AppColors.danger : AppColors.gold)
                  .withValues(alpha: 0.35),
              blurRadius: 24 + ring,
              spreadRadius: ring / 3,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                size: 84,
                color: isRecording ? AppColors.danger : AppColors.gold,
              ),
              const SizedBox(height: 8),
              Text(
                isRecording ? 'Arrêter' : 'Enregistrer',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 1.2,
                  color: isRecording ? AppColors.danger : AppColors.goldSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

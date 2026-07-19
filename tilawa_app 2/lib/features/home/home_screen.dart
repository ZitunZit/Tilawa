import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/record_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tilawa')),
      body: Center(
        child: switch (state.status) {
          AppStatus.processing => _Processing(state: state),
          _ => _RecordArea(state: state),
        },
      ),
    );
  }
}

class _RecordArea extends StatelessWidget {
  final AppState state;
  const _RecordArea({required this.state});

  @override
  Widget build(BuildContext context) {
    final isRec = state.status == AppStatus.recording;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<double>(
          stream: state.recorder.amplitude,
          initialData: 0,
          builder: (context, snap) => RecordButton(
            isRecording: isRec,
            amplitude: snap.data ?? 0,
            onTap: () async {
              if (isRec) {
                await state.stopAndProcess();
              } else {
                await state.startRecording();
              }
            },
          ),
        ),
        const SizedBox(height: 40),
        Text(
          isRec
              ? 'Enregistrement en cours…'
              : 'Appuyez pour enregistrer la récitation',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
        ),
        const SizedBox(height: 24),
        if (!isRec)
          TextButton.icon(
            onPressed: () => state.importAndProcess(),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Importer un fichier audio existant'),
          ),
      ],
    );
  }
}

class _Processing extends StatelessWidget {
  final AppState state;
  const _Processing({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_fix_high, size: 64, color: AppColors.gold),
          const SizedBox(height: 24),
          const Text('Nettoyage de la récitation…',
              style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: state.progress == 0 ? null : state.progress,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.gold,
          ),
          const SizedBox(height: 12),
          Text(state.progressMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

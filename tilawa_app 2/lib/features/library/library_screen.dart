import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/audio/exporter.dart';
import '../../core/models/recording.dart';
import '../../core/utils/format.dart';
import '../../theme/app_theme.dart';
import '../player/player_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.library;

    return Scaffold(
      appBar: AppBar(title: const Text('Bibliothèque')),
      body: items.isEmpty
          ? const _Empty()
          : RefreshIndicator(
              onRefresh: state.loadLibrary,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _RecordingCard(state: state, rec: items[i]),
              ),
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_outlined,
              size: 64, color: AppColors.goldDim),
          SizedBox(height: 16),
          Text('Aucune récitation pour le moment',
              style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final AppState state;
  final Recording rec;
  const _RecordingCard({required this.state, required this.rec});

  @override
  Widget build(BuildContext context) {
    final playablePath = rec.cleanedPath ?? rec.rawPath;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceHigh,
          child: Icon(Icons.play_arrow, color: AppColors.gold),
        ),
        title: Text(rec.label ?? 'Récitation',
            style: const TextStyle(color: AppColors.textPrimary)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDate(rec.createdAt),
                style: const TextStyle(color: AppColors.textMuted)),
            Text(
              rec.isCleaned
                  ? 'Nettoyé · ${formatDuration(rec.cleanedDuration ?? rec.duration)} '
                      '(brut ${formatDuration(rec.duration)})'
                  : 'Brut · ${formatDuration(rec.duration)}',
              style: const TextStyle(color: AppColors.goldSoft, fontSize: 12),
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(path: playablePath, title: rec.label),
          ),
        ),
        trailing: PopupMenuButton<String>(
          color: AppColors.surfaceHigh,
          onSelected: (v) async {
            switch (v) {
              case 'share':
                await Exporter.share(playablePath, subject: rec.label);
              case 'rename':
                await _rename(context);
              case 'delete':
                await state.remove(rec);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'share', child: Text('Partager / Exporter')),
            PopupMenuItem(value: 'rename', child: Text('Renommer')),
            PopupMenuItem(value: 'delete', child: Text('Supprimer')),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: rec.label ?? '');
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nom de la prière'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex. Isha, Fajr…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (label != null && label.isNotEmpty) {
      await state.rename(rec, label);
    }
  }
}

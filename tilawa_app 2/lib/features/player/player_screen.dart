import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/audio/exporter.dart';
import '../../core/utils/format.dart';
import '../../theme/app_theme.dart';

/// Lecteur simple pour ré-écouter un enregistrement (brut ou nettoyé).
class PlayerScreen extends StatefulWidget {
  final String path;
  final String? title;
  const PlayerScreen({super.key, required this.path, this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _player.setFilePath(widget.path);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Lecture')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.graphic_eq, size: 96, color: AppColors.gold),
            const SizedBox(height: 32),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final total = _player.duration ?? Duration.zero;
                final max = total.inMilliseconds.toDouble().clamp(1, 1e9);
                return Column(
                  children: [
                    Slider(
                      value: pos.inMilliseconds.toDouble().clamp(0, max),
                      max: max,
                      activeColor: AppColors.gold,
                      inactiveColor: AppColors.surfaceHigh,
                      onChanged: (v) =>
                          _player.seek(Duration(milliseconds: v.round())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(pos),
                            style:
                                const TextStyle(color: AppColors.textMuted)),
                        Text(formatDuration(total),
                            style:
                                const TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return IconButton.filled(
                  iconSize: 48,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.black,
                  ),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () => playing ? _player.pause() : _player.play(),
                );
              },
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () =>
                  Exporter.share(widget.path, subject: widget.title),
              icon: const Icon(Icons.share),
              label: const Text('Partager / Exporter'),
            ),
          ],
        ),
      ),
    );
  }
}

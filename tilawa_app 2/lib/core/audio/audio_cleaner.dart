import 'package:path/path.dart' as p;
import '../models/audio_clip.dart';
import '../plugins/plugin.dart';
import '../plugins/plugin_registry.dart';
import 'storage_paths.dart';
import 'wav_codec.dart';

/// Orchestrateur du nettoyage : exécute, dans l'ordre, tous les plugins de
/// traitement activés (pipeline). C'est le seul endroit qui « connaît » le
/// pipeline — l'ajout d'un plugin ne demande aucune modification ici.
class AudioCleaner {
  final PluginRegistry registry;

  AudioCleaner({PluginRegistry? registry})
      : registry = registry ?? PluginRegistry.instance;

  /// Nettoie un WAV brut et écrit le WAV nettoyé. Renvoie le chemin de sortie
  /// et la durée finale.
  Future<CleanResult> cleanFile(
    String rawWavPath, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.0, 'Chargement…');
    AudioClip clip = await WavCodec.decodeFile(rawWavPath);
    final originalDuration = clip.duration;

    final pipeline = registry.activePipeline;
    if (pipeline.isEmpty) {
      onProgress?.call(1.0, 'Aucun traitement activé.');
    }

    final allSegments = <Segment>[];
    for (var i = 0; i < pipeline.length; i++) {
      final plugin = pipeline[i];
      final base = i / pipeline.length;
      final span = 1 / pipeline.length;
      final result = await plugin.process(
        clip,
        onProgress: (pr, msg) =>
            onProgress?.call(base + pr * span, '${plugin.name} : $msg'),
      );
      clip = result.clip;
      allSegments.addAll(result.detectedSegments);
    }

    onProgress?.call(0.98, 'Enregistrement du fichier nettoyé…');
    final cleanedDir = await StoragePaths.cleanedDir();
    final name = p.basenameWithoutExtension(rawWavPath);
    final outPath = p.join(cleanedDir, '${name}_clean.wav');
    await WavCodec.encodeFile(clip, outPath);

    onProgress?.call(1.0, 'Terminé.');
    return CleanResult(
      cleanedPath: outPath,
      originalDuration: originalDuration,
      cleanedDuration: clip.duration,
      segments: allSegments,
    );
  }
}

class CleanResult {
  final String cleanedPath;
  final Duration originalDuration;
  final Duration cleanedDuration;
  final List<Segment> segments;

  const CleanResult({
    required this.cleanedPath,
    required this.originalDuration,
    required this.cleanedDuration,
    required this.segments,
  });

  /// Proportion de temps supprimé (silences + formules).
  double get reduction => originalDuration.inMilliseconds == 0
      ? 0
      : 1 - cleanedDuration.inMilliseconds / originalDuration.inMilliseconds;
}

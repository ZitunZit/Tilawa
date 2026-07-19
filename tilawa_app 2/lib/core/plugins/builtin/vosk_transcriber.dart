// SEUL fichier de l'app à dépendre de `vosk_flutter`.
//
// Il n'est compilé que s'il est explicitement importé (pour activer l'ancrage
// vocal). Le reste de l'app fonctionne sans lui ni sans Vosk.
//
// Exemple d'activation (dans votre code, une fois le modèle présent) :
//
//   import 'core/plugins/plugin_registry.dart';
//   import 'core/plugins/builtin/vosk_transcriber.dart';
//   ...
//   final modelPath = await extractVoskModelToDevice(); // à vous de fournir
//   PluginRegistry.instance.registerVosk(VoskTranscriber(modelPath));
//
// Modèle arabe : « vosk-model-ar-mgb2-0.4 » (https://alphacephei.com/vosk/models),
// à embarquer comme asset compressé puis extrait sur l'appareil (voir
// ModelLoader du package vosk_flutter), ou téléchargé au premier lancement.
//
// NB : l'API de `vosk_flutter` peut évoluer d'une version à l'autre ; ajustez
// les quelques appels ci-dessous si nécessaire (voir la doc du package).

import 'dart:convert';
import 'dart:typed_data';

import 'package:vosk_flutter/vosk_flutter.dart';

import '../../models/audio_clip.dart';
import '../plugin.dart';
import '../plugin_registry.dart';
import 'vosk_anchor_plugin.dart';

/// Bootstrap à appeler UNE fois au démarrage (voir main.dart) : extrait le
/// modèle Vosk embarqué (asset zip) et active l'ancrage vocal comme sélecteur
/// principal. Renvoie true si Vosk a été activé, false si le modèle est absent
/// (dans ce cas l'app garde le sélecteur par densité, sans planter).
Future<bool> enableVoskFromAsset({
  String assetZip = 'assets/models/vosk-ar.zip',
  double minKeep = 25.0,
}) async {
  try {
    final modelPath = await ModelLoader().loadFromAssets(assetZip);
    PluginRegistry.instance
        .registerVosk(VoskTranscriber(modelPath), minKeep: minKeep);
    return true;
  } catch (_) {
    return false; // modèle absent/incompatible -> repli densité
  }
}

class VoskTranscriber implements Transcriber {
  final String modelPath;
  VoskTranscriber(this.modelPath);

  @override
  Future<List<TranscribedWord>> transcribe(
    AudioClip clip16k, {
    ProgressCallback? onProgress,
  }) async {
    final vosk = VoskFlutterPlugin.instance();
    final model = await vosk.createModel(modelPath);
    final recognizer = await vosk.createRecognizer(
      model: model,
      sampleRate: 16000,
    );
    await recognizer.setWords(words: true);

    final bytes = _pcmBytes(clip16k.samples);
    const chunk = 8000; // ~0,25 s de PCM 16 bits
    final words = <TranscribedWord>[];
    for (var off = 0; off < bytes.length; off += chunk) {
      final end = (off + chunk) < bytes.length ? off + chunk : bytes.length;
      final accepted = await recognizer
          .acceptWaveformBytes(Uint8List.sublistView(bytes, off, end));
      if (accepted == true) {
        words.addAll(_parse(await recognizer.getResult()));
      }
      onProgress?.call(0.1 + 0.7 * off / bytes.length, 'Transcription…');
    }
    words.addAll(_parse(await recognizer.getFinalResult()));
    return words;
  }

  List<TranscribedWord> _parse(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final res = (map['result'] as List?) ?? const [];
    return res
        .map((w) => TranscribedWord(
              w['word'] as String? ?? '',
              (w['start'] as num?)?.toDouble() ?? 0,
              (w['end'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Uint8List _pcmBytes(Int16List samples) {
    final bd = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      bd.setInt16(i * 2, samples[i], Endian.little);
    }
    return bd.buffer.asUint8List();
  }
}

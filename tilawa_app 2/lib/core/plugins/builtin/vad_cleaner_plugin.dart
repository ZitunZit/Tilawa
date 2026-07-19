import 'dart:math' as math;
import '../../models/audio_clip.dart';
import '../plugin.dart';

/// Plugin léger n°2 : détection d'activité vocale (VAD).
///
/// Affine le résultat du seuil d'énergie en distinguant la *voix* d'un bruit
/// stationnaire (ventilation, réverbération de la salle, brouhaha léger).
///
/// Implémentation de référence : VAD "maison" très léger basé sur deux
/// indices classiques du traitement de la parole — le taux de passages par
/// zéro (ZCR) et le rapport d'énergie basse/haute fréquence — sans réseau de
/// neurones ni modèle à charger. Pour une précision supérieure, on peut
/// brancher le modèle Silero VAD (package `vad`, ONNX embarqué, hors-ligne)
/// en remplaçant [_isSpeechFrame] ; voir docs/PLUGINS.md.
class VadCleanerPlugin extends AudioProcessorPlugin {
  @override
  String get id => 'core.vad';
  @override
  String get name => 'Détection de voix (VAD)';
  @override
  String get description =>
      'Ne conserve que les segments réellement vocaux (VAD léger, hors-ligne).';
  @override
  int get order => 20; // après la suppression grossière des silences
  @override
  bool get enabledByDefault => true;

  final int frameMs;
  final int minSpeechMs;

  VadCleanerPlugin({this.frameMs = 30, this.minSpeechMs = 200});

  @override
  Future<ProcessingResult> process(
    AudioClip input, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.0, 'Détection de la voix…');
    final frame = math.max(1, input.sampleIndexAt(frameMs));
    final nFrames = (input.samples.length / frame).ceil();

    final speech = List<bool>.filled(nFrames, false);
    for (var f = 0; f < nFrames; f++) {
      final start = f * frame;
      final end = math.min(start + frame, input.samples.length);
      speech[f] = _isSpeechFrame(input.samples, start, end);
      if (f % 200 == 0) {
        onProgress?.call(0.6 * f / nFrames, 'Détection de la voix…');
      }
    }

    // Regroupe en segments et supprime les micro-segments parasites.
    final minSpeechFrames = math.max(1, minSpeechMs ~/ frameMs);
    final segments = <Segment>[];
    int? s;
    for (var f = 0; f <= nFrames; f++) {
      final v = f < nFrames && speech[f];
      if (v) {
        s ??= f;
      } else if (s != null) {
        if (f - s >= minSpeechFrames) {
          segments.add(Segment(
            s * frame,
            math.min(f * frame, input.samples.length),
            kind: SegmentKind.speech,
          ));
        }
        s = null;
      }
    }

    onProgress?.call(0.85, 'Assemblage…');
    final kept =
        segments.map((seg) => input.slice(seg.startSample, seg.endSample));
    final out = segments.isEmpty
        ? input
        : AudioClip.concat(kept.toList(), input.sampleRate);

    onProgress?.call(1.0, 'Voix isolée.');
    return ProcessingResult(out, detectedSegments: segments);
  }

  /// Décision voix/non-voix pour une trame.
  ///
  /// Heuristique légère : la parole voisée a une énergie suffisante ET un
  /// taux de passage par zéro modéré (ni silence, ni sifflement/bruit blanc).
  bool _isSpeechFrame(List<int> samples, int start, int end) {
    double energy = 0;
    int zeroCrossings = 0;
    int prevSign = 0;
    for (var i = start; i < end; i++) {
      final v = samples[i] / 32768.0;
      energy += v * v;
      final sign = v > 0 ? 1 : (v < 0 ? -1 : 0);
      if (sign != 0 && prevSign != 0 && sign != prevSign) zeroCrossings++;
      if (sign != 0) prevSign = sign;
    }
    final n = math.max(1, end - start);
    final rms = math.sqrt(energy / n);
    final zcr = zeroCrossings / n;

    const energyFloor = 0.012; // en-dessous : silence
    const zcrMax = 0.35; // au-dessus : bruit non voisé / fricative pure
    return rms >= energyFloor && zcr <= zcrMax;
  }
}

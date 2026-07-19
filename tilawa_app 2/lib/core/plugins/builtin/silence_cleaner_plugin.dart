import 'dart:math' as math;
import '../../models/audio_clip.dart';
import '../plugin.dart';

/// Plugin léger n°1 : suppression des silences par seuil d'énergie (RMS).
///
/// Méthode "intelligente mais légère" demandée dans le cahier des charges :
/// aucune IA, uniquement du traitement du signal. On découpe le clip en
/// petites fenêtres, on calcule l'énergie RMS de chaque fenêtre, et on
/// marque comme "silence" toute zone sous le seuil pendant assez longtemps.
///
/// Très rapide, quelques Ko de RAM, fonctionne sur n'importe quel appareil.
class SilenceCleanerPlugin extends AudioProcessorPlugin {
  @override
  String get id => 'core.silence';
  @override
  String get name => 'Suppression des silences';
  @override
  String get description =>
      'Retire les blancs entre les passages récités (détection d\'énergie RMS).';
  @override
  int get order => 10; // s'exécute en premier

  /// Fenêtre d'analyse en millisecondes.
  final int windowMs;

  /// Durée minimale d'un silence pour être supprimé (évite de hacher la voix).
  final int minSilenceMs;

  /// Marge conservée autour de la parole pour ne pas couper les attaques/fins.
  final int paddingMs;

  /// Seuil relatif au pic (0..1). En-dessous = silence.
  final double thresholdRatio;

  SilenceCleanerPlugin({
    this.windowMs = 20,
    this.minSilenceMs = 400,
    this.paddingMs = 120,
    this.thresholdRatio = 0.06,
  });

  @override
  Future<ProcessingResult> process(
    AudioClip input, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.0, 'Analyse des silences…');

    final win = math.max(1, input.sampleIndexAt(windowMs));
    final nWindows = (input.samples.length / win).ceil();

    // 1) Énergie RMS par fenêtre + pic global.
    final rms = List<double>.filled(nWindows, 0);
    double peak = 1e-9;
    for (var w = 0; w < nWindows; w++) {
      final start = w * win;
      final end = math.min(start + win, input.samples.length);
      double sum = 0;
      for (var i = start; i < end; i++) {
        final s = input.samples[i] / 32768.0;
        sum += s * s;
      }
      final r = math.sqrt(sum / math.max(1, end - start));
      rms[w] = r;
      if (r > peak) peak = r;
      if (w % 200 == 0) {
        onProgress?.call(0.4 * w / nWindows, 'Analyse des silences…');
      }
    }

    // 2) Marquage voix / silence.
    final threshold = peak * thresholdRatio;
    final isVoice = List<bool>.generate(nWindows, (w) => rms[w] >= threshold);

    // 3) Construction des segments de parole (fusion + padding).
    final minSilenceWin = math.max(1, minSilenceMs ~/ windowMs);
    final padWin = paddingMs ~/ windowMs;

    final segments = <Segment>[];
    int? voiceStart;
    int silenceRun = 0;

    void closeSegment(int endWin) {
      if (voiceStart == null) return;
      final s = math.max(0, (voiceStart! - padWin)) * win;
      final e = math.min(input.samples.length, (endWin + padWin) * win);
      segments.add(Segment(s, e, kind: SegmentKind.speech));
      voiceStart = null;
    }

    for (var w = 0; w < nWindows; w++) {
      if (isVoice[w]) {
        voiceStart ??= w;
        silenceRun = 0;
      } else if (voiceStart != null) {
        silenceRun++;
        if (silenceRun >= minSilenceWin) {
          closeSegment(w - silenceRun);
          silenceRun = 0;
        }
      }
    }
    closeSegment(nWindows - 1);

    onProgress?.call(0.8, 'Assemblage…');

    // 4) Concaténation des segments de parole (fusion des chevauchements).
    final merged = _mergeOverlaps(segments);
    final kept = merged
        .map((s) => input.slice(s.startSample, s.endSample))
        .toList(growable: false);

    final out = kept.isEmpty
        ? AudioClip(samples: input.samples, sampleRate: input.sampleRate)
        : AudioClip.concat(kept, input.sampleRate);

    onProgress?.call(1.0, 'Silences supprimés.');
    return ProcessingResult(out, detectedSegments: merged);
  }

  List<Segment> _mergeOverlaps(List<Segment> input) {
    if (input.isEmpty) return input;
    final sorted = [...input]
      ..sort((a, b) => a.startSample.compareTo(b.startSample));
    final out = <Segment>[sorted.first];
    for (final s in sorted.skip(1)) {
      final last = out.last;
      if (s.startSample <= last.endSample) {
        out[out.length - 1] = Segment(
          last.startSample,
          math.max(last.endSample, s.endSample),
          kind: SegmentKind.speech,
        );
      } else {
        out.add(s);
      }
    }
    return out;
  }
}

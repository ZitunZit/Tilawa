import 'dart:typed_data';

/// Représentation en mémoire d'un clip audio PCM mono 16 bits.
///
/// C'est l'unité d'échange entre tous les plugins de traitement :
/// un plugin reçoit un [AudioClip] et renvoie un [AudioClip] transformé.
/// Le format est volontairement simple (PCM 16 bits mono) pour rester
/// léger et 100% hors-ligne, sans dépendance à un décodeur lourd.
class AudioClip {
  /// Échantillons PCM 16 bits signés, mono.
  final Int16List samples;

  /// Fréquence d'échantillonnage (ex. 16000 pour le VAD, 44100 pour la qualité).
  final int sampleRate;

  const AudioClip({required this.samples, required this.sampleRate});

  Duration get duration => Duration(
      microseconds: (samples.length / sampleRate * 1e6).round());

  /// Index d'échantillon correspondant à un instant en millisecondes.
  int sampleIndexAt(int ms) => (ms / 1000 * sampleRate).round();

  /// Extrait un sous-clip entre deux index d'échantillons.
  AudioClip slice(int startSample, int endSample) {
    final s = startSample.clamp(0, samples.length);
    final e = endSample.clamp(s, samples.length);
    return AudioClip(
      samples: Int16List.sublistView(samples, s, e),
      sampleRate: sampleRate,
    );
  }

  /// Concatène une liste de segments (même sampleRate attendu).
  static AudioClip concat(List<AudioClip> parts, int sampleRate) {
    final total = parts.fold<int>(0, (n, p) => n + p.samples.length);
    final out = Int16List(total);
    var offset = 0;
    for (final p in parts) {
      out.setRange(offset, offset + p.samples.length, p.samples);
      offset += p.samples.length;
    }
    return AudioClip(samples: out, sampleRate: sampleRate);
  }
}

/// Un intervalle de temps repéré dans un clip (en échantillons).
class Segment {
  final int startSample;
  final int endSample;

  /// Type de segment détecté (parole, silence, formule liturgique…).
  final SegmentKind kind;

  const Segment(this.startSample, this.endSample,
      {this.kind = SegmentKind.speech});

  int get length => endSample - startSample;
}

enum SegmentKind {
  /// Récitation à conserver.
  speech,

  /// Silence / pause à supprimer.
  silence,

  /// Formule liturgique répétitive (takbir, tasmi', tasbih…) à supprimer.
  liturgicalFormula,
}

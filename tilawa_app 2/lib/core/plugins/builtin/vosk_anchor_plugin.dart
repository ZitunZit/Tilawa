import 'dart:typed_data';
import '../../models/audio_clip.dart';
import '../plugin.dart';
import 'recitation_arabic.dart';

/// Un mot reconnu avec ses instants (secondes).
class TranscribedWord {
  final String word;
  final double start;
  final double end;
  const TranscribedWord(this.word, this.start, this.end);
}

/// Interface de transcription (Dart pur) : permet au plugin d'ancrage de
/// rester découplé du moteur ASR. L'implémentation Vosk vit dans
/// `vosk_transcriber.dart` (seul fichier à dépendre de `vosk_flutter`), afin
/// que le cœur de l'app compile même sans Vosk.
abstract class Transcriber {
  Future<List<TranscribedWord>> transcribe(
    AudioClip clip16k, {
    ProgressCallback? onProgress,
  });
}

/// Sélecteur de récitation par **ancrage vocal** (hors-ligne).
///
/// Détecte les repères parlés qui délimitent la récitation :
///   - « Bismillah ar-rahman ar-rahim » → DÉBUT d'un passage à garder ;
///   - « Allahu Akbar » (takbir)        → FIN du passage (à couper) ;
///   - « As-salamu alaykum » (taslim)   → fin de prière (à couper).
///
/// Puis garde uniquement les intervalles [Bismillah → Allahu Akbar suivant].
/// Aucun pré-enregistrement de l'imam : le modèle ASR est générique.
///
/// Branché avec un [Transcriber] (ex. VoskTranscriber). Réf. de calibration :
/// `tools/clean_with_vosk.py`.
class VoskAnchorPlugin extends AudioProcessorPlugin {
  final Transcriber transcriber;
  final double minKeepSeconds;

  VoskAnchorPlugin({required this.transcriber, this.minKeepSeconds = 25.0});

  @override
  String get id => 'core.vosk_anchor';
  @override
  String get name => 'Ancrage vocal (Vosk)';
  @override
  String get description =>
      'Coupe précisément sur « Bismillah » / « Allahu Akbar » via reconnaissance '
      'vocale arabe embarquée. Optionnel : nécessite un modèle ASR.';
  @override
  int get order => 4; // sélecteur de zones, avant tout le reste
  @override
  bool get enabledByDefault => false;
  @override
  bool get isHeavy => true;

  @override
  Future<ProcessingResult> process(
    AudioClip input, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.0, 'Reconnaissance vocale…');
    final clip16k =
        input.sampleRate == 16000 ? input : _resampleTo16k(input);

    List<TranscribedWord> words;
    try {
      words = await transcriber.transcribe(clip16k, onProgress: onProgress);
    } catch (e) {
      // Dégradation propre : on ne coupe rien plutôt que couper à tort.
      onProgress?.call(1.0, 'ASR indisponible ($e) — audio inchangé.');
      return ProcessingResult(input);
    }

    onProgress?.call(0.85, 'Repérage des ancres…');
    final anchors = ArabicAnchors.find(
      words.map((w) => (ArabicAnchors.normalize(w.word), w.start)).toList(),
    );
    final total = input.duration.inMilliseconds / 1000.0;
    final intervals = ArabicAnchors.keepIntervals(
      bism: anchors.bismillah,
      takbir: anchors.takbir,
      salam: anchors.salam,
      totalSeconds: total,
      minKeep: minKeepSeconds,
    );

    if (intervals.isEmpty) {
      onProgress?.call(1.0, 'Aucune ancre exploitable — audio inchangé.');
      return ProcessingResult(input);
    }

    final sr = input.sampleRate;
    final kept = <AudioClip>[];
    final segs = <Segment>[];
    for (final iv in intervals) {
      final a = (iv.$1 * sr).round().clamp(0, input.samples.length);
      final b = (iv.$2 * sr).round().clamp(a, input.samples.length);
      kept.add(input.slice(a, b));
      segs.add(Segment(a, b, kind: SegmentKind.speech));
    }

    onProgress?.call(1.0, '${intervals.length} passage(s) gardé(s) via ancrage.');
    return ProcessingResult(AudioClip.concat(kept, sr), detectedSegments: segs);
  }

  /// Rééchantillonnage linéaire simple vers 16 kHz (suffisant pour l'ASR).
  AudioClip _resampleTo16k(AudioClip input) {
    const target = 16000;
    final ratio = target / input.sampleRate;
    final outLen = (input.samples.length * ratio).floor();
    final out = Int16List(outLen);
    for (var i = 0; i < outLen; i++) {
      final srcPos = i / ratio;
      final i0 = srcPos.floor();
      final i1 = (i0 + 1).clamp(0, input.samples.length - 1);
      final frac = srcPos - i0;
      out[i] = (input.samples[i0] * (1 - frac) + input.samples[i1] * frac)
          .round();
    }
    return AudioClip(samples: out, sampleRate: target);
  }
}

import 'dart:math' as math;
import 'dart:typed_data';
import '../../models/audio_clip.dart';
import '../plugin.dart';

/// Sélecteur de récitation par **densité de parole** (léger, hors-ligne).
///
/// Principe (validé sur enregistrements réels de Taraweeh) : la récitation est
/// une zone DENSE et CONTINUE de parole (Fatiha + sourate, avec de petites
/// pauses internes de waqf), tandis que les formules (takbir, tasmi', tasbih),
/// le dhikr et le salam final sont des bouffées COURTES et ISOLÉES entourées
/// de davantage de silence.
///
/// On calcule une densité de parole glissante : élevée = récitation à garder,
/// basse = interjections/transitions à retirer. On ne garde que les blocs
/// assez longs pour contenir Al-Fatiha (`minBlockSeconds`), ce qui écarte
/// automatiquement les formules et le taslim final.
///
/// ⚠️ Doit s'exécuter AVANT la suppression des silences : il a besoin du
/// timing d'origine (les silences) pour distinguer récitation et formules.
class RecitationBlockPlugin extends AudioProcessorPlugin {
  @override
  String get id => 'core.recitation_block';
  @override
  String get name => 'Sélection de la récitation (densité)';
  @override
  String get description =>
      'Garde les passages denses et continus (récitation) et retire les '
      'formules courtes isolées (takbir, dhikr) et le salam final.';
  @override
  int get order => 5; // sélecteur de zones : tout premier
  @override
  bool get enabledByDefault => true;

  /// Fenêtre de densité (s).
  final double densityWindow;

  /// Seuil de densité (0..1) au-dessus duquel on est en récitation.
  final double densityThreshold;

  /// Durée minimale d'un bloc gardé (doit contenir Al-Fatiha).
  final double minBlockSeconds;

  RecitationBlockPlugin({
    this.densityWindow = 8.0,
    this.densityThreshold = 0.50,
    this.minBlockSeconds = 25.0,
  });

  @override
  Future<ProcessingResult> process(
    AudioClip input, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.0, 'Analyse de la densité de parole…');
    final sr = input.sampleRate;
    final s = input.samples;
    final win = math.max(1, (0.02 * sr).round()); // 20 ms
    final n = s.length ~/ win;
    if (n < 3) return ProcessingResult(input);

    // 1) RMS par fenêtre + pic (99e centile approché).
    final rms = Float64List(n);
    for (var f = 0; f < n; f++) {
      final start = f * win;
      double sum = 0;
      for (var i = start; i < start + win; i++) {
        final v = s[i] / 32768.0;
        sum += v * v;
      }
      rms[f] = math.sqrt(sum / win);
    }
    final sorted = Float64List.fromList(rms)..sort();
    final peak = sorted[(0.99 * (n - 1)).floor()];
    final thr = peak * 0.06;

    // 2) Densité de parole glissante.
    final voiced = List<double>.generate(n, (f) => rms[f] >= thr ? 1.0 : 0.0);
    final w = math.max(1, (densityWindow / 0.02).round());
    final dens = _movingAverage(voiced, w);

    onProgress?.call(0.5, 'Repérage des blocs de récitation…');

    // 3) Blocs contigus au-dessus du seuil (fusion des trous < 2 s).
    final rec = List<bool>.generate(n, (f) => dens[f] >= densityThreshold);
    final cores = <List<int>>[];
    int? start;
    int last = -1;
    for (var f = 0; f < n; f++) {
      if (rec[f]) {
        start ??= f;
        if (last >= 0 && (f - last) * 0.02 > 2.0) {
          cores.add([start!, last]);
          start = f;
        }
        last = f;
      }
    }
    if (start != null) cores.add([start!, last]);

    // 4) Cale les frontières sur le silence local ; garde ≥ minBlock.
    int snap(int frame, double back, double fwd) {
      final lo = math.max(0, frame - (back / 0.02).round());
      final hi = math.min(n - 1, frame + (fwd / 0.02).round());
      var best = lo;
      for (var i = lo; i <= hi; i++) {
        if (rms[i] < rms[best]) best = i;
      }
      return best;
    }

    final blocks = <List<int>>[];
    for (final c in cores) {
      final a = snap(c[0], 2.5, 0.5);
      final b = snap(c[1], 0.3, 1.5);
      if ((b - a) * 0.02 >= minBlockSeconds) blocks.add([a, b]);
    }

    if (blocks.isEmpty) {
      onProgress?.call(1.0, 'Aucun bloc de récitation détecté (audio inchangé).');
      return ProcessingResult(input);
    }

    // 5) Concatène les blocs (avec une petite marge).
    final pad = (0.12 * sr).round();
    final kept = <AudioClip>[];
    final segs = <Segment>[];
    for (final b in blocks) {
      final a = math.max(0, b[0] * win - pad);
      final e = math.min(s.length, b[1] * win + pad);
      kept.add(input.slice(a, e));
      segs.add(Segment(a, e, kind: SegmentKind.speech));
    }

    onProgress?.call(1.0, '${blocks.length} passage(s) de récitation gardé(s).');
    return ProcessingResult(AudioClip.concat(kept, sr), detectedSegments: segs);
  }

  List<double> _movingAverage(List<double> a, int w) {
    final n = a.length;
    final prefix = Float64List(n + 1);
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + a[i];
    }
    final out = List<double>.filled(n, 0);
    final half = w ~/ 2;
    for (var i = 0; i < n; i++) {
      final lo = math.max(0, i - half);
      final hi = math.min(n, i + half + 1);
      out[i] = (prefix[hi] - prefix[lo]) / (hi - lo);
    }
    return out;
  }
}

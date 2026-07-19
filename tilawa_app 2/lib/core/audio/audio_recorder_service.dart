import 'dart:async';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'storage_paths.dart';

/// Service d'enregistrement micro multiplateforme basé sur le package `record`
/// (Android, iOS, Windows, macOS, Linux, web). Enregistre en WAV PCM 16 bits,
/// format ouvert et directement exploitable par le pipeline de nettoyage.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  /// Fréquence d'enregistrement. 16 kHz suffit pour la voix et allège le
  /// traitement (VAD) sur appareils modestes ; 44,1 kHz pour la qualité max.
  final int sampleRate;

  Timer? _amplitudeTimer;
  final _amplitudeController = StreamController<double>.broadcast();

  AudioRecorderService({this.sampleRate = 16000});

  /// Flux du niveau sonore (0..1) pour animer le bouton pendant la prière.
  Stream<double> get amplitude => _amplitudeController.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Démarre l'enregistrement, renvoie le chemin du fichier WAV en cours.
  Future<String> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Permission microphone refusée.');
    }
    final dir = await StoragePaths.rawDir();
    final path = p.join(dir, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
      path: path,
    );

    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 120), (_) async {
      final amp = await _recorder.getAmplitude();
      // Normalise le dBFS (~ -45..0) vers 0..1.
      final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      if (!_amplitudeController.isClosed) _amplitudeController.add(norm);
    });

    return path;
  }

  Future<bool> get isRecording => _recorder.isRecording();

  Future<void> pause() => _recorder.pause();
  Future<void> resume() => _recorder.resume();

  /// Arrête et renvoie le chemin final du WAV.
  Future<String?> stop() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    return _recorder.stop();
  }

  Future<void> dispose() async {
    _amplitudeTimer?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
  }
}

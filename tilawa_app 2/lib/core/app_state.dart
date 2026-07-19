import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'audio/audio_cleaner.dart';
import 'audio/audio_importer.dart';
import 'audio/audio_recorder_service.dart';
import 'audio/wav_codec.dart';
import 'models/recording.dart';
import 'storage/recording_repository.dart';

enum AppStatus { idle, recording, processing }

/// État central de l'application (pattern ChangeNotifier + provider).
/// Relie enregistrement, import, nettoyage et bibliothèque.
class AppState extends ChangeNotifier {
  final AudioRecorderService recorder;
  final AudioImporter importer;
  final AudioCleaner cleaner;
  final RecordingRepository repo;
  final _uuid = const Uuid();

  AppStatus status = AppStatus.idle;
  double progress = 0;
  String progressMessage = '';
  List<Recording> library = [];

  String? _currentRawPath;
  DateTime? _recordStart;

  AppState({
    required this.recorder,
    required this.importer,
    required this.cleaner,
    required this.repo,
  });

  Future<void> loadLibrary() async {
    library = await repo.all();
    notifyListeners();
  }

  // ---- Enregistrement ----
  Future<void> startRecording() async {
    _currentRawPath = await recorder.start();
    _recordStart = DateTime.now();
    status = AppStatus.recording;
    notifyListeners();
  }

  Future<void> stopAndProcess() async {
    final path = await recorder.stop() ?? _currentRawPath;
    final duration =
        DateTime.now().difference(_recordStart ?? DateTime.now());
    if (path == null) {
      status = AppStatus.idle;
      notifyListeners();
      return;
    }
    await _process(path, duration);
  }

  // ---- Import ----
  Future<void> importAndProcess() async {
    final path = await importer.pickAndImport();
    if (path == null) return;
    // Durée réelle depuis le WAV décodé.
    Duration dur;
    try {
      dur = (await WavCodec.decodeFile(path)).duration;
    } catch (_) {
      dur = Duration.zero;
    }
    await _process(path, dur);
  }

  // ---- Nettoyage + enregistrement en bibliothèque ----
  Future<void> _process(String rawPath, Duration rawDuration) async {
    status = AppStatus.processing;
    progress = 0;
    notifyListeners();

    final result = await cleaner.cleanFile(
      rawPath,
      onProgress: (pr, msg) {
        progress = pr;
        progressMessage = msg;
        notifyListeners();
      },
    );

    final rec = Recording(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      duration: rawDuration,
      rawPath: rawPath,
      cleanedPath: result.cleanedPath,
      cleanedDuration: result.cleanedDuration,
    );
    await repo.upsert(rec);
    await loadLibrary();

    status = AppStatus.idle;
    progress = 0;
    notifyListeners();
  }

  Future<void> rename(Recording r, String label) async {
    await repo.upsert(r.copyWith(label: label));
    await loadLibrary();
  }

  Future<void> remove(Recording r) async {
    await repo.delete(r.id);
    await loadLibrary();
  }
}

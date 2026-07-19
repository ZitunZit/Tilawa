import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'app.dart';
import 'core/app_state.dart';
import 'core/audio/audio_cleaner.dart';
import 'core/audio/audio_importer.dart';
import 'core/audio/audio_recorder_service.dart';
import 'core/plugins/plugin_registry.dart';
import 'core/plugins/builtin/vosk_transcriber.dart';
import 'core/storage/recording_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite via FFI sur desktop (Windows/macOS/Linux). Mobile utilise natif.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Chargement des plugins de traitement (point d'extension unique).
  // Pour ajouter un plugin communautaire :
  //   PluginRegistry.instance.registerProcessor(MonPlugin());
  PluginRegistry.instance.registerBuiltins();

  // Active l'ancrage vocal Vosk avec le modèle arabe embarqué. Si le modèle
  // est absent (build sans asset), l'app garde le sélecteur par densité.
  await enableVoskFromAsset();

  final state = AppState(
    recorder: AudioRecorderService(sampleRate: 16000),
    importer: AudioImporter(),
    cleaner: AudioCleaner(),
    repo: RecordingRepository(),
  )..loadLibrary();

  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const TilawaApp(),
    ),
  );
}

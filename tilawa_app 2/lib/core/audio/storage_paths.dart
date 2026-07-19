import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Emplacements locaux des fichiers (tout reste sur l'appareil, hors-ligne).
class StoragePaths {
  static Directory? _base;

  static Future<Directory> _baseDir() async {
    if (_base != null) return _base!;
    final docs = await getApplicationDocumentsDirectory();
    _base = Directory(p.join(docs.path, 'Tilawa'));
    await _base!.create(recursive: true);
    return _base!;
  }

  /// Dossier des enregistrements bruts (WAV).
  static Future<String> rawDir() async {
    final d = Directory(p.join((await _baseDir()).path, 'raw'));
    await d.create(recursive: true);
    return d.path;
  }

  /// Dossier des enregistrements nettoyés (WAV).
  static Future<String> cleanedDir() async {
    final d = Directory(p.join((await _baseDir()).path, 'cleaned'));
    await d.create(recursive: true);
    return d.path;
  }

  /// Dossier des exports temporaires (MP3/FLAC pour partage).
  static Future<String> exportDir() async {
    final d = Directory(p.join((await _baseDir()).path, 'exports'));
    await d.create(recursive: true);
    return d.path;
  }

  /// Chemin de la base d'index de la bibliothèque.
  static Future<String> dbPath() async =>
      p.join((await _baseDir()).path, 'library.db');
}

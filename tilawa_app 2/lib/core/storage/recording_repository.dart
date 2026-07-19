import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../audio/storage_paths.dart';
import '../models/recording.dart';

/// Bibliothèque locale : index SQLite des enregistrements (mobile + desktop).
/// Sur Windows/macOS/Linux, l'initialisation FFI est faite dans main.dart.
class RecordingRepository {
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final path = await StoragePaths.dbPath();
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE recordings(
            id TEXT PRIMARY KEY,
            label TEXT,
            created_at INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL,
            raw_path TEXT NOT NULL,
            cleaned_path TEXT,
            cleaned_duration_ms INTEGER
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> upsert(Recording r) async {
    final db = await _open();
    await db.insert(
      'recordings',
      r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Toutes les entrées, les plus récentes d'abord.
  Future<List<Recording>> all() async {
    final db = await _open();
    final rows = await db.query('recordings', orderBy: 'created_at DESC');
    return rows.map(Recording.fromMap).toList();
  }

  Future<void> delete(String id) async {
    final db = await _open();
    final rows =
        await db.query('recordings', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final r = Recording.fromMap(rows.first);
      await _tryDeleteFile(r.rawPath);
      if (r.cleanedPath != null) await _tryDeleteFile(r.cleanedPath!);
    }
    await db.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _tryDeleteFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Ignore : la suppression de l'index prime.
    }
  }
}

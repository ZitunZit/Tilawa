import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'storage_paths.dart';
import 'wav_codec.dart';
import '../models/audio_clip.dart';

/// Import d'un fichier audio existant (dictaphone, téléphone…) au cas où
/// l'imam aurait oublié de lancer l'enregistrement à temps.
///
/// v1 : import direct des WAV. Les formats compressés (MP3/M4A/OGG) sont
/// acceptés mais nécessitent un décodeur ; on documente le branchement d'un
/// plugin de décodage (voir docs/PLUGINS.md) pour rester hors-ligne et léger.
class AudioImporter {
  /// Ouvre le sélecteur de fichiers natif et copie le fichier choisi dans le
  /// dossier des enregistrements bruts. Renvoie le chemin local, ou null si
  /// l'utilisateur annule.
  Future<String?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac'],
    );
    if (result == null || result.files.single.path == null) return null;

    final srcPath = result.files.single.path!;
    final ext = p.extension(srcPath).toLowerCase();
    final rawDir = await StoragePaths.rawDir();
    final destName = 'import_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(rawDir, destName);
    await File(srcPath).copy(destPath);
    return destPath;
  }

  /// Charge un fichier importé en [AudioClip]. Ne gère nativement que le WAV ;
  /// pour un format compressé, lève une erreur explicite invitant à activer
  /// un plugin de décodage.
  Future<AudioClip> load(String path) async {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.wav') {
      return WavCodec.decodeFile(path);
    }
    throw UnsupportedError(
      'Format $ext : activez un plugin de décodage audio, ou convertissez '
      'le fichier en WAV. (Le cœur reste volontairement léger et hors-ligne.)',
    );
  }
}

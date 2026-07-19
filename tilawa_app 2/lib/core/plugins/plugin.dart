import 'dart:async';
import '../models/audio_clip.dart';

/// Contrat de base commun à tous les plugins Tilawa.
///
/// L'architecture est volontairement modulaire : le cœur de l'application
/// ne connaît que ces interfaces. La communauté peut ajouter de nouveaux
/// traitements audio ou de nouveaux exports SANS toucher au cœur, simplement
/// en enregistrant un plugin dans le [PluginRegistry].
abstract class TilawaPlugin {
  /// Identifiant unique et stable (ex. "core.silence").
  String get id;

  /// Nom lisible affiché à l'utilisateur.
  String get name;

  /// Description courte.
  String get description;
}

/// Résultat d'une étape de traitement, avec les segments détectés
/// pour permettre l'affichage et le débogage.
class ProcessingResult {
  final AudioClip clip;
  final List<Segment> detectedSegments;

  const ProcessingResult(this.clip, {this.detectedSegments = const []});
}

/// Signature d'un rapport de progression (0.0 -> 1.0) + message.
typedef ProgressCallback = void Function(double progress, String message);

/// Plugin de traitement audio : reçoit un clip, renvoie un clip transformé.
///
/// Les plugins sont chaînés dans un pipeline (voir [AudioCleaner]).
/// Chaque plugin doit rester léger : les implémentations de référence
/// utilisent de la détection d'activité vocale (VAD) et des seuils
/// d'énergie plutôt qu'un gros modèle d'IA, pour tourner sur du matériel
/// modeste et 100% hors-ligne.
abstract class AudioProcessorPlugin extends TilawaPlugin {
  /// Priorité d'exécution dans le pipeline (plus petit = plus tôt).
  int get order => 100;

  /// Le plugin est-il activé par défaut ?
  bool get enabledByDefault => true;

  /// Ce plugin nécessite-t-il des ressources lourdes (modèle IA) ?
  /// S'il renvoie true, le cœur le laisse optionnel/désactivable.
  bool get isHeavy => false;

  /// Traite un clip. [onProgress] permet de remonter l'avancement.
  Future<ProcessingResult> process(
    AudioClip input, {
    ProgressCallback? onProgress,
  });
}

/// Plugin d'export/partage : produit un fichier à partir d'un WAV nettoyé.
///
/// Exemples : export MP3, FLAC, envoi vers une intégration tierce…
abstract class ExporterPlugin extends TilawaPlugin {
  /// Extension de sortie (ex. "mp3").
  String get fileExtension;

  /// Convertit/prépare un fichier source (WAV) et renvoie le chemin de sortie.
  Future<String> export(String sourceWavPath, {ProgressCallback? onProgress});
}

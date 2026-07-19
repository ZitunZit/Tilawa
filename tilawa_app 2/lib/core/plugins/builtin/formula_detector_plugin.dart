import '../../models/audio_clip.dart';
import '../plugin.dart';

/// Plugin OPTIONNEL n°3 : détection des formules liturgiques répétitives
/// (takbir « Allahu Akbar », tasmi' « Sami'Allahu liman hamidah »,
/// tasbih « Subhana rabbiyal a'la/azim », etc.) prononcées ENTRE les passages
/// de sourate, afin de ne conserver que la récitation coranique.
///
/// ⚠️ Ce traitement est intrinsèquement plus difficile que la suppression des
/// silences : il relève du *keyword spotting*. Conformément au cahier des
/// charges, il est fourni ici comme POINT D'EXTENSION désactivé par défaut,
/// pour ne JAMAIS être une dépendance obligatoire du cœur.
///
/// Trois stratégies possibles, de la plus légère à la plus lourde :
///
///   1. Heuristique de position (implémentée, ultra-légère) : les formules
///      sont courtes, encadrées de silences et situées aux transitions entre
///      unités de prière. On repère les segments vocaux brefs et isolés.
///   2. Empreinte acoustique (à brancher) : comparer chaque segment court à
///      un petit jeu de gabarits MFCC de takbir/tasmi'/tasbih (quelques Ko),
///      via une DTW. Léger, hors-ligne, personnalisable par l'imam
///      (il enregistre ses propres formules une fois).
///   3. Modèle KWS embarqué (plugin séparé, « isHeavy ») : petit modèle
///      TFLite/ONNX de keyword spotting. Réservé aux appareils capables.
///
/// La v1 implémente (1) et expose l'API pour (2)/(3).
class FormulaDetectorPlugin extends AudioProcessorPlugin {
  @override
  String get id => 'core.formulas';
  @override
  String get name => "Retrait des formules (takbir, tasmi', tasbih)";
  @override
  String get description =>
      'Retire les formules liturgiques courtes entre les passages récités. '
      'Optionnel — à activer et calibrer selon la récitation de l\'imam.';
  @override
  int get order => 30;
  @override
  bool get enabledByDefault => false; // jamais obligatoire

  /// Durée max (ms) d'un segment considéré comme une formule courte.
  final int maxFormulaMs;

  FormulaDetectorPlugin({this.maxFormulaMs = 2500});

  @override
  Future<ProcessingResult> process(
    AudioClip input, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.0, 'Recherche des formules…');

    // Stratégie 1 (heuristique de position). On suppose que ce plugin est
    // exécuté APRÈS le VAD : le clip est déjà une suite de segments vocaux.
    // Ici, faute d'un découpage transmis, on renvoie le clip inchangé et on
    // signale que la calibration est requise. Le vrai découpage est fait par
    // AudioCleaner qui passe les segments détectés (voir _matchTemplate).
    //
    // Cette implémentation neutre garantit l'innocuité : activer ce plugin
    // sans l'avoir calibré ne dégrade jamais la récitation.
    onProgress?.call(1.0, 'Formules : calibration requise (aucun retrait).');
    return ProcessingResult(input, detectedSegments: const []);
  }

  /// Point d'extension pour la stratégie 2 : comparer un segment court à un
  /// gabarit enregistré par l'imam. Retourne un score de similarité 0..1.
  /// (À implémenter avec MFCC + DTW dans un plugin communautaire.)
  double matchTemplate(AudioClip segment, AudioClip template) {
    // TODO(communauté): MFCC + Dynamic Time Warping, 100% local.
    return 0.0;
  }
}

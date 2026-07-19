import 'plugin.dart';
import 'builtin/recitation_block_plugin.dart';
import 'builtin/silence_cleaner_plugin.dart';
import 'builtin/vad_cleaner_plugin.dart';
import 'builtin/vosk_anchor_plugin.dart';

/// Registre central des plugins. Point d'extension unique de l'application.
///
/// Pour ajouter un plugin communautaire, il suffit d'appeler
/// [registerProcessor] ou [registerExporter] au démarrage (voir main.dart),
/// sans modifier le reste du code.
class PluginRegistry {
  PluginRegistry._();
  static final PluginRegistry instance = PluginRegistry._();

  final List<AudioProcessorPlugin> _processors = [];
  final List<ExporterPlugin> _exporters = [];

  /// État activé/désactivé par id de plugin (persistable via les préférences).
  final Map<String, bool> _enabled = {};

  List<AudioProcessorPlugin> get processors =>
      List.unmodifiable(_processors..sort((a, b) => a.order.compareTo(b.order)));

  List<ExporterPlugin> get exporters => List.unmodifiable(_exporters);

  /// Charge les plugins fournis en standard. Appelé une fois au démarrage.
  ///
  /// Pipeline par défaut (100 % hors-ligne, sans modèle) :
  ///   [5]  Sélection de la récitation par densité de parole
  ///   [10] Suppression des silences longs restants (waqf préservés)
  ///   [20] VAD fin — désactivé par défaut (à activer au besoin)
  void registerBuiltins() {
    registerProcessor(RecitationBlockPlugin());
    // minSilenceMs élevé : on ne retire que les vrais blancs, on garde les
    // petites pauses naturelles (waqf) entre les versets.
    registerProcessor(SilenceCleanerPlugin(minSilenceMs: 1200));
    registerProcessor(VadCleanerPlugin());
    setEnabled('core.vad', false);
  }

  /// Active l'ancrage vocal (optionnel). Reçoit un [Transcriber] concret
  /// (ex. VoskTranscriber, défini dans `builtin/vosk_transcriber.dart`, seul
  /// fichier à dépendre de `vosk_flutter`). À appeler quand le modèle ASR est
  /// présent sur l'appareil (voir docs/PLUGINS.md et tools/).
  void registerVosk(Transcriber transcriber, {double minKeep = 25.0}) {
    registerProcessor(
      VoskAnchorPlugin(transcriber: transcriber, minKeepSeconds: minKeep),
    );
    // Devient le sélecteur de zones prioritaire ; la densité passe en repli.
    setEnabled('core.vosk_anchor', true);
    setEnabled('core.recitation_block', false);
  }

  void registerProcessor(AudioProcessorPlugin p) {
    _processors.add(p);
    _enabled.putIfAbsent(p.id, () => p.enabledByDefault);
  }

  void registerExporter(ExporterPlugin p) => _exporters.add(p);

  bool isEnabled(String id) => _enabled[id] ?? false;
  void setEnabled(String id, bool value) => _enabled[id] = value;

  /// Pipeline actif = processeurs activés, triés par ordre.
  List<AudioProcessorPlugin> get activePipeline =>
      processors.where((p) => isEnabled(p.id)).toList();
}

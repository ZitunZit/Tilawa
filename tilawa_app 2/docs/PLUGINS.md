# Écrire un plugin Tilawa

Le système de plugins est le moyen recommandé d'étendre Tilawa **sans modifier le cœur**. Deux familles existent : les traitements audio et les exports.

## 1. Un plugin de traitement audio

Implémentez `AudioProcessorPlugin` (`lib/core/plugins/plugin.dart`) :

```dart
import 'package:tilawa/core/models/audio_clip.dart';
import 'package:tilawa/core/plugins/plugin.dart';

class NoiseReducerPlugin extends AudioProcessorPlugin {
  @override
  String get id => 'community.noise_reducer';
  @override
  String get name => 'Réduction de bruit';
  @override
  String get description => 'Atténue le bruit de fond de la salle.';
  @override
  int get order => 5;                 // s'exécute avant la suppression des silences
  @override
  bool get isHeavy => false;          // léger : reste activable partout

  @override
  Future<ProcessingResult> process(
    AudioClip input, {
    ProgressCallback? onProgress,
  }) async {
    onProgress?.call(0, 'Réduction du bruit…');
    // ... transformez input.samples ...
    onProgress?.call(1, 'Terminé.');
    return ProcessingResult(input /* ou un nouveau AudioClip */);
  }
}
```

Enregistrez-le au démarrage, dans `main.dart`, **sans rien changer d'autre** :

```dart
PluginRegistry.instance.registerBuiltins();
PluginRegistry.instance.registerProcessor(NoiseReducerPlugin()); // ← une ligne
```

L'`order` détermine la position dans le pipeline (plus petit = plus tôt). Un plugin peut être activé/désactivé via `PluginRegistry.instance.setEnabled(id, bool)`.

### Brancher Silero VAD (précision supérieure, toujours hors-ligne)

Le `VadCleanerPlugin` intégré utilise un VAD « maison » léger. Pour une précision supérieure, créez un plugin qui utilise le package [`vad`](https://pub.dev/packages/vad) (modèle Silero, ONNX embarqué, aucun réseau) et donnez-lui le même `order` (20) en désactivant le VAD léger. Déclarez `isHeavy => true` si le modèle est significatif, afin que l'app le laisse optionnel sur les appareils modestes.

### Retrait des formules (takbir / dhikr) : deux sélecteurs de récitation

Le retrait des formules a été validé sur de vrais enregistrements de Taraweeh.
Constat clé : le regroupement « non supervisé » (repérer les takbir parce
qu'ils se répètent) **ne marche pas** — le takbir est mélodique et différent à
chaque fois. Deux approches fiables sont fournies à la place.

**1. `RecitationBlockPlugin` — densité de parole (défaut, léger, sans modèle).**
La récitation est une zone dense et continue de parole (Fatiha + sourate) ;
les formules/dhikr sont des bouffées courtes isolées. On garde les blocs denses
assez longs pour contenir Al-Fatiha (`minBlockSeconds`, 25 s par défaut), ce qui
écarte automatiquement takbir, dhikr et salam final. 100 % hors-ligne, tourne
partout. Doit s'exécuter **avant** la suppression des silences (il a besoin du
timing d'origine).

**2. `VoskAnchorPlugin` — ancrage vocal (optionnel, précis).**
Reconnaissance vocale arabe hors-ligne (Vosk) pour détecter « Bismillah »
(début à garder) et « Allahu Akbar » (coupe), plus le salam final. Aucun
pré-enregistrement de l'imam : le modèle est générique. Découplé du moteur via
l'interface `Transcriber` ; l'implémentation Vosk est dans
`builtin/vosk_transcriber.dart` (seul fichier dépendant de `vosk_flutter`), si
bien que l'app compile sans Vosk. Activation :

```dart
import 'core/plugins/plugin_registry.dart';
import 'core/plugins/builtin/vosk_transcriber.dart';
// ... modèle arabe extrait sur l'appareil (voir tools/README.md) :
PluginRegistry.instance.registerVosk(VoskTranscriber(modelPath));
```

**Banc d'essai :** `tools/clean_with_vosk.py` applique exactement cette logique
d'ancrage en Python sur PC (utile pour traiter en lot et régler les seuils avant
de figer le comportement de l'app).

## 2. Un plugin d'export

Implémentez `ExporterPlugin` pour ajouter un format (MP3, FLAC…) :

```dart
class Mp3ExporterPlugin extends ExporterPlugin {
  @override
  String get id => 'community.mp3';
  @override
  String get name => 'Export MP3';
  @override
  String get description => 'Convertit le WAV nettoyé en MP3 pour le partage.';
  @override
  String get fileExtension => 'mp3';

  @override
  Future<String> export(String sourceWavPath, {ProgressCallback? onProgress}) async {
    // Encodez sourceWavPath → .mp3 avec un encodeur embarqué (hors-ligne),
    // renvoyez le chemin de sortie.
    ...
  }
}
```

Puis : `PluginRegistry.instance.registerExporter(Mp3ExporterPlugin());`

## Règles d'or

- **Hors-ligne only** : aucun appel réseau dans un plugin de traitement du cœur.
- **Léger par défaut** : préférez le traitement du signal ; réservez l'IA aux plugins `isHeavy` et rendez-les optionnels.
- **Innocuité** : un plugin activé mais non configuré ne doit jamais dégrader la récitation (préférer « ne rien retirer » au doute).
- **Un `id` stable et unique** (préfixez par `community.` ou votre organisation).

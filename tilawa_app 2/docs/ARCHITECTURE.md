# Architecture

## Vue d'ensemble

Tilawa est structuré en trois couches :

1. **UI** (`lib/features`, `lib/widgets`) — écrans Enregistrer / Bibliothèque / Lecteur.
2. **Cœur** (`lib/core`) — services audio, stockage, état applicatif.
3. **Plugins** (`lib/core/plugins`) — point d'extension unique. Le cœur ne connaît que des *interfaces*, jamais les implémentations concrètes.

Tout est hors-ligne : aucune couche ne fait d'appel réseau.

## Le pipeline de traitement

Le nettoyage est une chaîne de plugins exécutés dans l'ordre. Chaque plugin reçoit un `AudioClip` (PCM 16 bits mono) et renvoie un `AudioClip` transformé.

```
WAV brut ─► WavCodec.decode ─► AudioClip
                                  │
        ┌─────────────────────────┴──────────────────────────┐
        ▼                        ▼                            ▼
 [10] SilenceCleaner ─► [20] VadCleaner ─► [30] FormulaDetector (option)
        │  RMS/seuil        │ voix vs bruit      │ takbir/tasmi'/tasbih
        └──────────────► AudioClip nettoyé ◄─────┘
                                  │
                       WavCodec.encode ─► WAV nettoyé ─► Bibliothèque
```

L'orchestrateur est `AudioCleaner.cleanFile()`. Il lit le pipeline **actif** depuis le `PluginRegistry` (plugins activés, triés par `order`), applique chaque étape et remonte la progression à l'UI.

### Pourquoi PCM 16 bits mono en interne ?

- Format le plus simple à manipuler en pur Dart, sans décodeur natif lourd.
- Suffisant pour la voix ; le VAD travaille idéalement à 16 kHz.
- Le down-mix stéréo→mono et la lecture WAV sont gérés par `WavCodec`.

### Approche « légère d'abord »

Conformément au cahier des charges, la détection privilégie le **traitement du signal** :

- `SilenceCleaner` : énergie RMS par fenêtre de 20 ms, seuil relatif au pic, fusion des segments avec marge (padding) pour ne pas couper les attaques.
- `VadCleaner` : décision voix/non-voix par trame via énergie + taux de passage par zéro (ZCR). Aucun modèle à charger.

Une IA locale (Silero VAD, keyword spotting) reste **optionnelle** et n'est jamais une dépendance du cœur. Un plugin lourd s'auto-déclare via `isHeavy => true`, ce qui permet à l'app de le laisser désactivable.

## Flux de données (état applicatif)

`AppState` (ChangeNotifier) orchestre :

```
Enregistrer ──► AudioRecorderService.start()/stop() ──► WAV brut
Importer   ──► AudioImporter.pickAndImport()        ──► WAV brut
                                                          │
                                                AudioCleaner.cleanFile()
                                                          │
                                    Recording (id, date, durées, chemins)
                                                          │
                                        RecordingRepository.upsert() (SQLite)
                                                          │
                                              Bibliothèque (liste réactive)
```

## Stockage

Tout est local sous `Documents/Tilawa/` :

- `raw/` — WAV bruts (enregistrés ou importés)
- `cleaned/` — WAV nettoyés
- `exports/` — fichiers temporaires de partage (futurs MP3/FLAC)
- `library.db` — index SQLite (métadonnées uniquement)

Sur desktop, SQLite est initialisé via FFI (`sqflite_common_ffi`) dans `main.dart`.

## Points d'extension

| Interface | Rôle | Exemple |
|---|---|---|
| `AudioProcessorPlugin` | Étape de traitement audio | débruitage, Silero VAD, keyword spotting |
| `ExporterPlugin` | Format/canal de sortie | export MP3, FLAC, intégration tierce |

Voir [`PLUGINS.md`](PLUGINS.md).

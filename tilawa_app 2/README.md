# Tilawa

**Application libre, gratuite et hors-ligne d'enregistrement et de nettoyage automatique des récitations de prière, pour les imams et les mosquées.**

Tilawa permet à un imam d'enregistrer sa récitation pendant la prière, puis de produire automatiquement un fichier audio « nettoyé » ne contenant que la récitation des sourates — sans les silences ni les formules répétitives prononcées entre les passages (*takbir* « Allahu Akbar », *tasmi'* « Sami'Allahu liman hamidah », *tasbih* « Subhana rabbiyal a'la/azim », etc.).

> Nom de travail — « Tilawa » signifie *récitation du Coran* en arabe. Modifiable à tout moment (voir `pubspec.yaml`, `lib/app.dart`, `lib/theme`).

## Principes

- **100 % hors-ligne.** Enregistrement, traitement, stockage et export local ne nécessitent aucune connexion internet.
- **Léger.** Le nettoyage repose d'abord sur des méthodes de traitement du signal peu gourmandes (détection d'énergie + détection d'activité vocale), pensées pour tourner sur d'anciens téléphones et des PC de mosquée modestes. Une IA locale plus poussée reste **optionnelle** (plugin), jamais obligatoire.
- **Multiplateforme, base de code unique.** Flutter cible Android, iOS, Windows, macOS et Linux.
- **Extensible.** Architecture à plugins : la communauté peut ajouter des traitements ou des formats d'export sans toucher au cœur.
- **Libre et pérenne.** Licence **GPLv3** (copyleft fort).

## Fonctionnalités (v0.1)

- 🔴 **Enregistrement en direct** via un gros bouton unique, pensé pour être actionné sans réflexion juste avant/pendant la prière.
- 📥 **Import** d'un fichier audio existant (si l'enregistrement a été oublié).
- 🧹 **Nettoyage automatique** : deux sélecteurs de récitation validés sur de vrais Taraweeh —
  1. **densité de parole** (défaut, léger, sans modèle) : garde les blocs denses et continus (récitation), retire takbir/dhikr/salam ;
  2. **ancrage vocal Vosk** (optionnel) : coupe précisément sur « Bismillah » / « Allahu Akbar » par reconnaissance vocale arabe hors-ligne, sans pré-enregistrement de l'imam.
  Plus suppression des silences longs et VAD. Banc d'essai PC : `tools/clean_with_vosk.py`.
- 📤 **Export / partage natif** (WhatsApp, mail, cloud, sauvegarde locale) via la feuille de partage du système.
- 📚 **Bibliothèque locale** : liste par date, durée, ré-écoute, ré-export, suppression, nom de prière optionnel.
- 🎨 **Interface noir & doré**, sobre et élégante.

## Stack technique

| Besoin | Brique open source |
|---|---|
| Base multiplateforme | [Flutter](https://flutter.dev) |
| Enregistrement micro | [`record`](https://pub.dev/packages/record) |
| Détection d'activité vocale (option Silero) | [`vad`](https://pub.dev/packages/vad) (Silero VAD, ONNX embarqué) |
| Lecture | [`just_audio`](https://pub.dev/packages/just_audio) |
| Import de fichiers | [`file_picker`](https://pub.dev/packages/file_picker) |
| Partage natif | [`share_plus`](https://pub.dev/packages/share_plus) |
| Index bibliothèque | [`sqflite`](https://pub.dev/packages/sqflite) + `sqflite_common_ffi` (desktop) |
| WAV pur Dart | `WavCodec` (interne, `lib/core/audio/wav_codec.dart`) |

Le VAD « maison » léger (énergie + taux de passage par zéro) est intégré et sans dépendance ; le modèle **Silero VAD** peut être branché pour plus de précision (voir `docs/PLUGINS.md`).

## Démarrage

```bash
# Pré-requis : Flutter 3.22+ (https://docs.flutter.dev/get-started/install)
flutter pub get

# Lancer (choisir la cible)
flutter run                 # appareil/émulateur connecté
flutter run -d windows      # ou macos / linux / chrome
flutter run -d android      # ou ios

# Tests
flutter test

# Builds de production
flutter build apk           # Android
flutter build ipa           # iOS
flutter build windows       # Windows
flutter build macos         # macOS
flutter build linux         # Linux
```

> Les dossiers de plateforme (`android/`, `ios/`, `windows/`, `macos/`, `linux/`) sont générés automatiquement par `flutter create .` à la racine du projet (voir plus bas), afin de garder ce dépôt centré sur le code partagé.

### Générer les dossiers de plateforme

Ce scaffold contient le code partagé (`lib/`, `test/`, `pubspec.yaml`). Pour obtenir un projet compilable :

```bash
cd tilawa
flutter create .            # génère android/ ios/ windows/ macos/ linux/ web/
flutter pub get
flutter run
```

`flutter create .` ne touche pas au `lib/` existant.

### Permissions

- **Micro** : `record` gère la demande. Ajouter les entrées natives requises :
  - Android : `RECORD_AUDIO` dans `android/app/src/main/AndroidManifest.xml`.
  - iOS/macOS : `NSMicrophoneUsageDescription` dans `Info.plist`.

## Structure du projet

```
lib/
  main.dart                 # bootstrap, enregistrement des plugins
  app.dart                  # navigation (Enregistrer / Bibliothèque)
  theme/app_theme.dart      # identité visuelle noir & doré
  core/
    app_state.dart          # état global (record → clean → bibliothèque)
    models/                 # Recording, AudioClip, Segment
    audio/                  # recorder, importer, cleaner, wav_codec, exporter
    storage/                # RecordingRepository (SQLite)
    plugins/                # cœur d'extensibilité
      plugin.dart           # interfaces AudioProcessorPlugin / ExporterPlugin
      plugin_registry.dart  # registre central
      builtin/              # silence, VAD, formules (optionnel)
  features/                 # home, library, player
  widgets/                  # RecordButton
docs/
  ARCHITECTURE.md
  PLUGINS.md
```

Voir [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) pour le pipeline de traitement et [`docs/PLUGINS.md`](docs/PLUGINS.md) pour écrire un plugin.

## Feuille de route

- [x] Sélecteur de récitation par densité de parole (validé sur Taraweeh réel).
- [x] Ancrage vocal Vosk (Bismillah / Allahu Akbar) + banc d'essai PC.
- [ ] Empaquetage du modèle Vosk arabe comme asset + extraction au 1er lancement.
- [ ] Réglages UI pour choisir/calibrer le sélecteur (densité vs Vosk, seuils).
- [ ] Plugin d'export MP3/FLAC (encodeur embarqué).
- [ ] Décodage des imports compressés (MP3/M4A) hors-ligne.
- [ ] Forme d'onde interactive avec segments détectés (édition manuelle des coupes).

## Contribuer

Les contributions sont bienvenues — voir [`CONTRIBUTING.md`](CONTRIBUTING.md). Le point d'entrée pour étendre l'app est le système de plugins : aucun besoin de modifier le cœur.

## Licence

[GNU GPLv3](LICENSE). Tilawa et tous ses dérivés restent libres et open source.

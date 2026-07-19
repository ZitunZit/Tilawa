# Outils — nettoyage par ancrage vocal (Vosk)

`clean_with_vosk.py` nettoie une récitation **hors-ligne** en détectant les
repères parlés (« Bismillah » = début à garder, « Allahu Akbar » = coupe,
« As-salamu alaykum » = fin de prière). Aucun pré-enregistrement de l'imam
n'est requis : le modèle Vosk est générique.

C'est le **banc d'essai de référence** de la détection par ancres : la même
logique est portée dans l'app (`lib/core/plugins/builtin/vosk_anchor_plugin.dart`).
Utilise ce script sur ton PC pour traiter en lot tes enregistrements et régler
les seuils avant de figer le comportement de l'app.

## Installation (une fois)

```bash
pip install vosk numpy scipy
# ffmpeg requis dans le PATH : https://ffmpeg.org
```

Télécharge le modèle arabe (une fois, ~1,3 Go) depuis
<https://alphacephei.com/vosk/models> → **`vosk-model-ar-mgb2-0.4`**, puis
décompresse-le, par ex. dans `tools/models/vosk-model-ar-mgb2-0.4`.

> Le téléchargement du modèle est la seule étape qui demande internet. Une fois
> le modèle en local, tout le traitement est 100 % hors-ligne.

## Utilisation

```bash
python clean_with_vosk.py \
  --input  "Taraweeh.mp3" \
  --model  "models/vosk-model-ar-mgb2-0.4" \
  --output "Taraweeh_nettoye.mp3" \
  --hybrid
```

Options :

| Option | Rôle |
|---|---|
| `--keep-fatiha-min 25` | durée minimale (s) d'un passage gardé (doit contenir Al-Fatiha) |
| `--hybrid` | combine ancres ASR **et** densité de parole (recommandé) |
| `--dump-transcript t.json` | sauvegarde la transcription horodatée (utile pour déboguer les ancres) |

## Comment ça marche

1. **Conversion** de l'audio en WAV mono 16 kHz (format attendu par Vosk).
2. **Transcription** Vosk avec horodatage mot à mot.
3. **Détection des ancres** (après normalisation de l'arabe : diacritiques
   retirés, alef/hamza unifiés) : `بسم`, `الله اكبر`, `السلام`.
4. **Intervalles à garder** : de chaque « Bismillah » au « Allahu Akbar »
   suivant. Un passage trop court pour contenir la Fatiha est ignoré.
5. **Repli densité** : si l'ASR rate des ancres (récitation très mélodique),
   on complète par la détection de blocs denses de parole.
6. **Rendu** : concaténation avec fondus de 30 ms, coupes calées sur les
   silences, export au format voulu.

## Réglage

- Si des takbir subsistent → baisse `--keep-fatiha-min` prudemment, ou vérifie
  la transcription (`--dump-transcript`) pour voir si « الله اكبر » est bien
  reconnu.
- Si de la récitation est tronquée → active `--hybrid` et/ou augmente la marge
  dans `keep_intervals`.
- La qualité dépend du modèle : `vosk-model-ar-mgb2-0.4` gère bien l'arabe
  standard des formules ; la récitation mélodique est parfois mal transcrite,
  d'où l'intérêt du mode `--hybrid`.

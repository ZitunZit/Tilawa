# Modèles (Vosk)

Ce dossier reçoit le modèle de reconnaissance vocale arabe **`vosk-ar.zip`**
embarqué dans l'app pour la détection des ancres « Bismillah » / « Allahu Akbar ».

Le fichier `vosk-ar.zip` **n'est pas versionné** dans le dépôt (≈ 1,2 Go). Il est
récupéré automatiquement à la compilation par `.github/workflows/build.yml`
(depuis <https://alphacephei.com/vosk/models> → `vosk-model-ar-mgb2-0.4`), placé
ici, puis emballé dans l'installeur final. L'utilisateur obtient donc une app
100 % hors-ligne, modèle inclus.

## Le placer manuellement (build local)

```bash
curl -L https://alphacephei.com/vosk/models/vosk-model-ar-mgb2-0.4.zip \
  -o assets/models/vosk-ar.zip
```

Sans ce fichier, l'app démarre quand même et bascule sur le sélecteur de
récitation par densité (aucun plantage) — seul l'ancrage vocal précis est
indisponible.

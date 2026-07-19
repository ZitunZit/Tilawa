# Contribuer à Tilawa

Merci de votre intérêt ! Tilawa est un outil communautaire libre (GPLv3) au service des mosquées.

## Philosophie

- **Hors-ligne d'abord** : aucune fonctionnalité du cœur ne doit dépendre d'internet.
- **Léger d'abord** : le matériel cible est modeste (vieux téléphones, PC de mosquée). Préférez le traitement du signal aux gros modèles ; l'IA lourde va dans un plugin `isHeavy` optionnel.
- **Étendre par plugin** : la plupart des ajouts (traitements, exports) ne doivent pas modifier le cœur. Voir [`docs/PLUGINS.md`](docs/PLUGINS.md).
- **Respect du contexte** : l'app sert la prière ; sobriété, fiabilité et innocuité priment sur les fonctionnalités.

## Mettre en place l'environnement

```bash
flutter --version        # 3.22+
cd tilawa
flutter create .         # génère les dossiers de plateforme
flutter pub get
flutter test
flutter run
```

## Workflow

1. Ouvrez une *issue* décrivant le besoin/bug avant un gros changement.
2. Branchez : `git checkout -b feat/ma-fonctionnalite`.
3. Respectez le style : `flutter analyze` doit passer, `dart format .` appliqué.
4. Ajoutez des tests pour toute logique de traitement (`flutter test`).
5. Ouvrez une *pull request* claire (quoi / pourquoi / captures si UI).

## Style de code

- Dart/Flutter idiomatique, `flutter_lints` respecté.
- Nommez les `id` de plugins avec un préfixe (`community.…`).
- Commentez le *pourquoi*, pas le *quoi*.

## Licence des contributions

En contribuant, vous acceptez que votre code soit distribué sous **GPLv3**, comme le reste du projet.

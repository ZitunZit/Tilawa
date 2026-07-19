# Obtenir l'app installable (compilation automatique)

Tu n'as **rien à installer sur ton ordinateur**. La compilation se fait toute
seule sur les serveurs de GitHub (gratuit). Elle télécharge le modèle vocal,
construit les apps Windows / macOS / Linux / Android avec le modèle **inclus**,
et te donne les fichiers prêts à installer.

## Étape par étape

### 1. Créer un compte GitHub (gratuit, une fois)
Va sur <https://github.com> et crée un compte.

### 2. Créer un dépôt et y mettre le projet
- Clique sur **New repository**, donne un nom (ex. `tilawa`), laisse en
  « Private » si tu veux, puis **Create**.
- Sur la page du dépôt, clique **uploading an existing file**, puis glisse tout
  le contenu du dossier `tilawa` (ce projet). Valide avec **Commit changes**.

> Astuce : l'appli **GitHub Desktop** (<https://desktop.github.com>) rend le
> dépôt/upload plus simple si tu préfères une interface.

### 3. Lancer la compilation
- Onglet **Actions** du dépôt → autorise les workflows si demandé.
- Choisis **Build Tilawa (multi-plateforme)** → bouton **Run workflow** →
  **Run workflow**.
- Attends ~15–30 min (le téléchargement du modèle de 1,2 Go prend du temps).

### 4. Récupérer les apps
- Toujours dans **Actions**, ouvre la compilation terminée (coche verte).
- En bas, section **Artifacts** : télécharge
  - `tilawa-windows` (Windows)
  - `tilawa-macos` (Mac)
  - `tilawa-linux` (Linux)
  - `tilawa-android-apk` (Android)

Chaque fichier contient l'app **avec le modèle vocal intégré**, 100 % hors-ligne.

### 5. (Option) Créer une « Release » officielle
Pour générer une page de téléchargement propre avec toutes les versions :
crée un **tag** `v0.1.0` (onglet **Releases** → **Draft a new release** →
tag `v0.1.0` → **Publish**). Le workflow se relance et attache automatiquement
tous les installeurs à la Release.

## À savoir

- **iOS (iPhone/iPad)** : Apple exige un compte développeur payant (99 $/an) et
  une signature. La compilation iOS n'est donc pas automatisée ici ; elle
  s'ajoute quand tu auras ce compte.
- **Taille** : le modèle arabe (~1,2 Go) est inclus, donc les apps sont
  volumineuses. C'est le prix du « 100 % hors-ligne, rien à rater ». Sur
  Android, l'APK s'installe en « sideload » (hors store) vu sa taille.
- **Signature** : les apps ne sont pas signées par un éditeur. Windows/macOS
  afficheront un avertissement au premier lancement (clic droit → Ouvrir sur
  Mac ; « Informations complémentaires → Exécuter » sur Windows). La signature
  officielle s'ajoute plus tard si tu publies sur les stores.
- **Mise à jour** : à chaque modification du code renvoyée sur GitHub, relance
  le workflow pour obtenir de nouvelles apps.

## Alternative sans GitHub

Si tu préfères, n'importe quel développeur peut compiler en local avec Flutter :
voir `README.md` (section Démarrage) + placer le modèle via
`assets/models/README.md`.

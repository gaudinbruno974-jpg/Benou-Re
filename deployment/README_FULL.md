# Déploiement détaillé — Bénou-Ré

Objectif
- Fournir une procédure reproductible pour créer et configurer un projet
  Firebase par loge, produire les artefacts (`google-services.json`,
  `GoogleService-Info.plist`, `lib/firebase_options.dart`) et préparer les
  builds Flutter.

Conventions
- `project-id` recommandé: `benou-re-<loge-slug>-<env>` (ex: benou-re-le-petit-prince-prod)
- `loge-slug`: remplacer les espaces par des tirets, minuscules.
- Environnements: `prod` pour production, `staging` optionnel.

Prérequis locaux
- Compte Google avec droits de création de projet
- Installer:
  - Google Cloud SDK: https://cloud.google.com/sdk
  - Node.js + npm
  - Firebase CLI: `npm install -g firebase-tools`
  - Dart/Flutter (compatible avec le projet)
  - FlutterFire CLI: `dart pub global activate flutterfire_cli`

Étapes (résumé)
1. Créer le projet GCP
2. Initialiser Firebase et activer services (Firestore, Auth, Storage)
3. Créer les apps Android et iOS dans Firebase (obtenir les config files)
4. Exécuter `flutterfire configure` pour générer `lib/firebase_options.dart`
5. Placer les fichiers de config et commiter les changements non sensibles
6. Construire et tester les builds

Étapes détaillées

1) Créer le projet GCP (via `gcloud`) — exécuter manuellement
- Exemple:

```powershell
# remplacer <PROJECT_ID> et <PROJECT_NAME>
gcloud projects create <PROJECT_ID> --name="Bénou-Re - <PROJECT_NAME>"
# Associer un billing account si nécessaire
# gcloud beta billing projects link <PROJECT_ID> --billing-account=XXXX
```

2) Activer les APIs nécessaires

```powershell
gcloud services enable firestore.googleapis.com storage.googleapis.com
```

3) Créer le projet Firebase et initialiser
- Depuis Firebase Console: créer un projet et relier au `PROJECT_ID`
- Ou via Firebase CLI (requiert auth):

```bash
firebase login
firebase projects:create <PROJECT_ID> --display-name "Bénou-Re - <PROJECT_NAME>"
```

4) Ajouter les apps (Android / iOS)
- Android: ajouter application et renseigner `Android package name` (ex:
  `com.benoure.<loge_slug>`). Télécharger `google-services.json`.
- iOS: ajouter application et renseigner `iOS bundle id` (ex:
  `com.benoure.<loge_slug>.ios`). Télécharger `GoogleService-Info.plist`.

5) Placer les fichiers
- `google-services.json` -> `android/app/`
- `GoogleService-Info.plist` -> `ios/Runner/`
- Attention: ne pas committer ces fichiers dans un dépôt public. Stocker
  également dans le Google Drive sécurisé de la loge.

6) FlutterFire configure

```bash
# depuis la racine du projet Flutter
dart pub global activate flutterfire_cli
flutterfire configure --project=<PROJECT_ID> --out=lib/firebase_options.dart
```

7) Comptes de service et automatisation
- Créer un compte de service `deployer@<PROJECT_ID>.iam.gserviceaccount.com`
- Rôles recommandés: `Firebase Admin`, `Firestore Admin`, `Storage Admin`.
- Télécharger la clé JSON pour opérations automatisées (ne pas committer).

8) Règles Firestore et sécurité
- Déployer des règles de sécurité adaptées (ex: limiter accès écriture aux
  comptes admin). Tester les règles avant mise en production.

9) Build & release
- Android: `flutter build apk` ou `flutter build appbundle`
- iOS: `flutter build ios` (nécessite macOS)

10) Documentation et Drive
- Créer un dossier dans le Drive de l'obédience / loge pour stocker:
  - `project-id`, propriétaire(s), comptes admins
  - les fichiers `google-services`
  - la clé de compte de service (stockage restreint)
  - checklist de déploiement et captures d'écran

Check-list rapide avant remise à la loge
- [ ] `google-services.json` placé
- [ ] `GoogleService-Info.plist` placé
- [ ] `lib/firebase_options.dart` généré
- [ ] Règles Firestore testées
- [ ] Comptes administrateurs créés
- [ ] Documentation Drive à jour

Annexes — commandes utiles (exemples)

- Lister projets Firebase:

```bash
firebase projects:list
```

- Créer une application Android via CLI:

```bash
# create an Android app (requires firebase CLI to support apps:create)
firebase apps:create android com.benoure.<loge_slug> --project=<PROJECT_ID>
```

Notes
- Certaines opérations (création d'app iOS, téléchargement des fichiers de
  config) sont souvent plus simples via l'interface Firebase Console.
- Bruno réalisera la création initiale; le secrétaire de chaque loge gérera
  ensuite les données quotidiennes.

Support
- Contacter Bruno pour les droits GCP/Firebase et l'exécution finale.

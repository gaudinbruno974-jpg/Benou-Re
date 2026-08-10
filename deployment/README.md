# Déploiement — Bénou-Ré (procédure)

But: documenter et automatiser la création d'un projet Firebase par loge et
les étapes nécessaires pour intégrer l'instance dans l'application Flutter.

Prérequis
- Installer `gcloud` (Google Cloud SDK) et s'authentifier: `gcloud auth login`
- Installer `firebase-tools` (Firebase CLI): `npm i -g firebase-tools`
- Installer `flutterfire` CLI: `dart pub global activate flutterfire_cli`
- Avoir un compte Google disposant des droits pour créer des projets

Checklist (ordre recommandé)
1. Créer le projet Google Cloud / Firebase (choisir un `project-id` unique).
2. Activer Firestore, Authentication (Email et Google Sign-In si besoin),
   Storage, et les APIs nécessaires.
3. Créer un compte de service pour les opérations automatisées (optionnel
   mais recommandé). Télécharger la clé JSON et la stocker en lieu sûr.
4. Configurer la partie Android: générer `google-services.json` et placer
   dans `android/app/`.
5. Configurer la partie iOS: générer `GoogleService-Info.plist` et placer
   dans `ios/Runner/`.
6. Exécuter `flutterfire configure --project=<project-id>` pour générer
   `lib/firebase_options.dart`.
7. Mettre à jour les clés et secrets dans le gestionnaire sécurisé (ne pas
   committer de clés privées dans Git).
8. Construire l'application (ex: `flutter build apk` / `flutter build ios`) et
   déployer si besoin.

Étapes détaillées (rapide)

- Création projet (gcloud)
  - `gcloud projects create <PROJECT_ID> --name="Bénou-Re-<loge>"`
  - `gcloud services enable firestore.googleapis.com storage.googleapis.com`

- Authentification
  - Dans Firebase Console > Authentication > Methodes: activer Email/Password
  - Créer les comptes administrateurs (ou provisionner via la console)

- Automatisation FlutterFire
  - `dart pub global activate flutterfire_cli`
  - `flutterfire configure --project=<PROJECT_ID>`

Bonnes pratiques
- Ne pas stocker `google-services.json` ni `GoogleService-Info.plist` dans
  un dépôt public. Utiliser un coffre (Google Drive sécurisé de l'obédience).
- Documenter `project-id` et propriétaires dans le Google Drive de la loge.

Fichiers fournis
- `deploy_template.ps1`: script PowerShell d'aide à la création de projet et
  de préparation des artifacts Android/iOS.

Contact
- Responsable technique: Bruno (exécutera la création initiale pour chaque
  loge).

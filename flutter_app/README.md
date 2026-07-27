# Bénou Ré — Application Flutter (Dart natif)

Portage natif **Flutter/Dart** de l'application de gestion de la R∴L∴ Bénou Ré
(version web React/TypeScript à la racine du dépôt). Cette app se compile en
Android/iOS natif et se développe entièrement en Dart (VSCode / Android Studio).

## Ce qui est implémenté (socle)

- **Firebase** : initialisation (`firebase_options.dart`), **Auth** email/mot de
  passe avec repli de migration des comptes pré-enregistrés (comme le web), et
  **Firestore** temps réel (collections `members`, `sessions`, `visitors`,
  `config`).
- **Écrans** :
  - Connexion (`login_screen.dart`) + accès rapides démo.
  - Parvis / tableau de bord (`parvis_screen.dart`) avec menu selon le rôle.
  - Membres : liste + création/édition/suppression (`members_screen.dart`,
    `member_edit_screen.dart`).
  - Tenues : liste + détail présents/excusés/visiteurs (`sessions_screen.dart`).
  - Visiteurs : CRUD (`visitors_screen.dart`).
  - Trésorerie : synthèse cotisations + suivi paiement (`treasury_screen.dart`).
  - Bibliothèque (Architecture/Instructions/Rituels) : écran d'attente
    (`library_screen.dart`).
- **Génération PDF** (`services/pdf_service.dart`, packages `pdf` + `printing`) :
  - **Convocation / ordre du jour** avec en-tête graphique complet (logos GLDB +
    Bénou Ré, GRANDE LOGE DE BOURBON, rites, filiations) et date égyptienne du
    R∴A∴P∴M∴M∴.
  - **Feuille de présence / émargement** (tableau membres + invités, signatures).
  - **Planche tracée** (en-tête graphique + texte officiel + signatures
    Orateur/V∴M∴/Secrétaire).
  - Boutons d'export dans le détail d'une tenue (aperçu + partage/enregistrement).
- **Émargement / signatures** (`screens/emargement_screen.dart`, package
  `signature`) : pad de signature pour chaque présent + signatures officielles de
  la planche ; enregistrées dans Firestore (`session.signatures` et champs
  `planche*`) et reprises dans les PDF.
- **Modèles Dart** : `models/member.dart`, `session.dart`, `visitor.dart`
  (avec `fromMap` / `toMap`, portés depuis `src/types.ts`).
- **État** : `state/app_state.dart` (`ChangeNotifier` + `provider`).
- **Thème** : `theme.dart` (identité sombre teal/or).

## Reste à porter (TODO)

- Intégration **Google Drive** (archivage automatique des PDF) — voir la note
  OAuth ci-dessous. Les PDF sont pour l'instant partageables/enregistrables
  manuellement via l'aperçu.
- **Éditeur** de planche tracée (saisie des travaux/notes) — la génération PDF et
  la capture des signatures sont faites, mais l'édition du texte des travaux se
  fait encore côté web.
- Écran de **statistiques** détaillé (équivalent `DashboardStats.tsx`).
- **Seed** initial Firestore (équivalent `initializeAllAccountsAndDatabase`).

## Prérequis

- **Flutter** stable (testé avec 3.44.x, Dart 3.x).
- **JDK 21** et **Android SDK** (via Android Studio ou command-line tools).

## Lancer / builder

```bash
cd flutter_app
flutter pub get
flutter run                 # sur un émulateur/appareil
flutter build apk --debug   # APK debug -> build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release # APK release (signature à configurer)
```

## Configuration Firebase (important)

`firebase_options.dart` reprend la configuration **web** existante du projet
`benou-re-loge`. L'auth email/mot de passe et Firestore fonctionnent avec ces
identifiants, mais pour un build de production propre sur appareil il est
recommandé d'enregistrer des applications natives dédiées :

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=benou-re-loge
```

Cela génère un `firebase_options.dart` par plateforme et
`android/app/google-services.json`, après avoir enregistré l'app Android
(`re.benou.benou_re`) dans la console Firebase.

## Google Drive OAuth (mobile)

Comme sur le web, le flux OAuth par popup ne fonctionne pas en natif. Pour
l'archivage Drive, utiliser `google_sign_in` (+ scope Drive) puis l'API Drive
REST, ce qui nécessite un **client OAuth Android** (package `re.benou.benou_re`
+ empreinte SHA-1) dans la Google Cloud Console. Étape à réaliser côté console
projet.

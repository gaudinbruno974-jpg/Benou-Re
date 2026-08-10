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

- Écran de **statistiques** détaillé (équivalent `DashboardStats.tsx`).
- **Seed** initial Firestore (équivalent `initializeAllAccountsAndDatabase`).

## Prérequis

- **Flutter** stable (testé avec 3.44.x, Dart 3.x).
- **JDK 21** et **Android SDK** (via Android Studio ou command-line tools).

## Lancer / builder

Le projet Flutter est à la racine du dépôt (`lib/`, `pubspec.yaml`) : toutes les
commandes ci-dessous se lancent depuis cette racine.

```bash
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

## Google Drive (archivage des PDF)

L'archivage Drive est implémenté nativement (`lib/services/drive_service.dart`) :
connexion via `google_sign_in` (scope `drive`), puis appels à l'API Drive REST
pour créer/retrouver le dossier de la tenue (`Tenue {chrono} {jj} {mm} {annee}`,
sous le dossier parent partagé) et y déposer les 3 PDF. Le bouton **« Archiver
sur Google Drive »** se trouve dans le détail d'une tenue.

Comme sur le web, le flux OAuth par popup ne fonctionne pas en natif : il faut un
**client OAuth Android** provisionné pour l'app. Config à faire une seule fois :

1. **Empreinte SHA-1** de la clé de signature (debug) :
   ```bash
   cd android
   ./gradlew signingReport        # Windows : .\gradlew signingReport
   ```
   Copiez la ligne `SHA1:` de la variante `debug` (et la `SHA-256` si demandée).
   Pour un APK release, ajoutez aussi le SHA-1 de votre keystore de release.

2. **Firebase Console** → *Project settings* → votre app Android
   (`re.benou.benou_re`) → **Add fingerprint** → collez le SHA-1.
   Cela crée automatiquement le client OAuth Android dans le projet Google Cloud.

3. **Firebase Console** → *Authentication* → *Sign-in method* → activez le
   fournisseur **Google**.

4. **Google Cloud Console** (projet `benou-re-loge`) :
   - *APIs & Services* → **activer l'API Google Drive** ;
   - *OAuth consent screen* : si l'app est en mode *Testing*, ajoutez votre
     adresse Google dans **Test users** (sinon le scope Drive est refusé).

5. Relancez : `flutter clean && flutter run`. Au 1er archivage, une fenêtre de
   connexion Google s'affiche ; ensuite les PDF sont déposés dans le dossier de
   la tenue.

> Le scope `drive` complet est utilisé (comme le web) pour écrire dans le dossier
> parent partagé existant. Pour une publication grand public, ce scope demande la
> vérification de l'app par Google ; en usage interne (utilisateurs de test) ce
> n'est pas nécessaire.

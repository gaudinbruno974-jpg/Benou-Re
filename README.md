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

Depuis la mise en place du multi-loges, **Android exige un flavor** : la loge
est choisie par l'option `--flavor`. Le web n'est pas concerné (voir plus bas).

```bash
flutter pub get
flutter run --flavor benoure                     # sur un émulateur/appareil
flutter build apk --debug --flavor benoure       # -> build/app/outputs/flutter-apk/app-benoure-debug.apk
flutter build apk --release --flavor benoure     # APK release (signature à configurer)
flutter build apk --debug --flavor petitprince   # loge pilote Le Petit Prince
flutter build web --release --dart-define=FLAVOR=benoure       # web, loge benoure
flutter build web --release --dart-define=FLAVOR=petitprince   # web, loge petitprince
```

Sans `--flavor`, la commande Android échoue avec
« You must specify a --flavor option ». Le nom du fichier produit contient
désormais le flavor (`app-benoure-debug.apk`, `app-petitprince-debug.apk`).

Sur le web, `--dart-define=FLAVOR=<flavor>` joue le même rôle que `--flavor`
sur Android (voir [Web multi-loges](#web-multi-loges) plus bas) ; omis, il
vaut `benoure` par défaut.

## Multi-loges

L'identité de chaque loge est répartie en deux endroits, selon qu'elle doit ou
non être figée dans le binaire :

| Où | Quoi | Fichier |
| --- | --- | --- |
| Flavor (compilation) | `applicationId`, nom sous l'icône, logos, `firebase_options.dart` | `android/app/build.gradle.kts`, `android/app/src/<flavor>/` |
| Firestore `config/settings` | nom, numéro, orient, lieu de réunion, dossiers Drive | document modifiable sans rebuild |

Le code ne lit jamais ces valeurs en dur : tout passe par
[`lib/config/lodge_config.dart`](lib/config/lodge_config.dart), dont les
valeurs par défaut sont celles de Bénou Ré. Une loge ne renseigne dans
Firestore que les champs qui la distinguent ; les autres gardent le repli du
flavor, ce qui laisse l'application correcte hors connexion.

Champs reconnus dans `config/settings` : `lodgeName`, `lodgeNumber`,
`lodgeOrient`, `lodgeOrientLong`, `lodgeObedience`, `lodgeMeetingPlace`,
`driveParentFolderId` et `libraryFolders` (par type de document puis par grade).

**Ajouter une loge** : créer son projet Firebase (voir [deployment/](deployment/)),
ajouter un flavor dans `android/app/build.gradle.kts`, déposer son
`google-services.json` et un `res/values/strings.xml` dans
`android/app/src/<flavor>/`, puis renseigner `config/settings` dans son
Firestore.

## Web multi-loges

Le web n'a pas d'équivalent natif du flavor Android (`appFlavor` reste
toujours nul dans un navigateur) : le flavor y est choisi au build via
`--dart-define=FLAVOR=<flavor>`, lu par `lib/firebase_options.dart` (repli sur
`benoure` si l'option est omise, pour ne rien changer aux builds existants).

Le dossier `web/` reste la source versionnée du site **benoure**. Flutter ne
fusionne pas non plus de dossiers `web/<flavor>/` au build (contrairement à
Android) : les fichiers qui diffèrent par loge (`index.html`, `manifest.json`,
favicon, icônes) sont donc dupliqués dans `web-flavors/<flavor>/` et copiés
par-dessus `web/` juste avant le build par un script dédié, qui restaure
ensuite `web/` à son état versionné (benoure) :

```bash
./deployment/build_web.ps1 -Flavor benoure          # PowerShell
./deployment/build_web.ps1 -Flavor petitprince

./deployment/build_web.sh benoure                    # bash
./deployment/build_web.sh petitprince
```

Chaque loge est déployée sur le Hosting **de son propre projet Firebase**
(cohérent avec un projet isolé par loge), sélectionné via l'alias déclaré dans
`.firebaserc` :

```bash
firebase deploy --only hosting                 # benoure (projet par défaut)
firebase deploy --only hosting -P petitprince   # petit-prince-loge
```

> **Limitation connue** : `web-flavors/petitprince/index.html` n'embarque pas
> encore de `google-signin-client_id` (pas de client OAuth Web provisionné
> pour `petit-prince-loge`). L'archivage Google Drive reste donc indisponible
> sur ce site tant que ce client n'est pas créé dans la Google Cloud Console
> du projet (même démarche que le client OAuth Android, voir
> [Google Drive](#google-drive-archivage-des-pdf) plus bas) ; Auth
> email/mot de passe et Firestore ne sont pas affectés.

**Ajouter une loge côté web** : créer `web-flavors/<flavor>/` avec ses propres
`index.html`, `manifest.json`, `favicon.png` et `icons/`, puis ajouter son
alias de projet dans `.firebaserc`.

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

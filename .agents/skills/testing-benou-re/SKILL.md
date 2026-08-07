---
name: testing-benou-re
description: How to run and end-to-end test the Bénou Ré Flutter app (Firebase Auth + Firestore prod data) locally in a browser, including how to reach the Tenue screens and how to avoid writing to production.
---

# Tester l'app Bénou Ré (Flutter web)

## Lancer l'app localement (le plus rapide)
```bash
cd <repo>            # racine du projet Flutter (lib/, pubspec.yaml)
flutter build web --release          # ~1 min ; `flutter run -d chrome` marche aussi
(cd build/web && python3 -m http.server 8088)
```
Puis ouvrir http://localhost:8088 dans Chrome (`wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz`
pour maximiser avant d'enregistrer). Après un rebuild, recharger avec **Ctrl+Shift+R** : un cache/service
worker peut servir l'ancien `main.dart.js` et faire croire qu'« une modification n'est pas effective ».

## Connexion
Écran de login email + mot de passe (Firebase Auth). Utiliser les identifiants fournis par l'utilisateur
(compte V∴M∴ / admin, nécessaire car la plupart des actions sont derrière `canEditSessions(currentUser)`).
Pas de secret d'environnement requis : les identifiants doivent être demandés à l'utilisateur.

## Attention : Firestore = données de PRODUCTION
Il n'y a pas d'environnement de staging. Tester en **lecture seule** :
- quitter les écrans par la flèche « Retour » de l'AppBar, jamais par l'icône coche / bouton ENREGISTRER ;
- les modifications de champs et de présences ne sont que locales tant qu'on n'enregistre pas ;
- dans l'Emargement, fermer le dialogue de signature via « Annuler ».

## Navigation vers les écrans « Tenue »
Parvis → carte **Tenues** → deux onglets : « Reprise des Travaux » (à venir) et « Travaux Suspendus »
(date < aujourd'hui, cf. `Session.isSuspended` dans `lib/models/session.dart`).
Depuis la carte d'une tenue : bouton **Emargement** (gauche), icône **crayon** = Modifier la tenue,
**chevron** = Détail & documents. Depuis le détail : « Présents en tenue » (`SessionPresenceScreen`),
« Emargement Présence », « Edition Planche Tracée », et les boutons PDF.

## Piège : écran devenu inatteignable par l'UI
Certaines features masquent le bouton d'accès à un écran (ex. « Présents en tenue » masqué sur une tenue
suspendue). `SessionPresenceScreen` n'a alors plus aucun appelant. Pour vérifier tout de même son contenu,
appliquer un **patch local temporaire non commité** neutralisant la condition dans
`lib/screens/sessions_screen.dart`, rebuild, tester, puis `git checkout` du fichier — et le signaler
explicitement dans le rapport comme « vérifié via chemin instrumenté ».

## Toujours faire un contrôle négatif
Les features « lecture seule » se testent en comparant une tenue **suspendue** et une tenue **à venir**
(champ où l'on tape du texte, bouton Présent/Excusé qui change de couleur, présence/absence de l'icône
Enregistrer). Sans ce contrôle, un écran simplement cassé ressemble à un écran verrouillé.

## Si « la modification n'est pas effective » chez l'utilisateur
Vérifier d'abord que ce n'est pas un problème de déploiement plutôt que de code :
```bash
curl -s https://benou-re-loge.web.app/main.dart.js | grep -c "<nouvelle chaîne UI>"
```
0 ⇒ le build hébergé est antérieur au commit. Redéploiement nécessaire :
`flutter build web --release && firebase deploy --only hosting` (projet `benou-re-loge`).
Idem pour Android : l'APK installé doit être régénéré (`flutter build apk`).

## Divers
- `flutter analyze` doit passer ; `test/widget_test.dart` peut échouer de façon préexistante — ne pas s'y fier.
- Le DOM Flutter web n'expose presque rien : se fier aux **captures d'écran** (les `<textarea>`/`<input>`
  du `flt-text-editing-host` sont toutefois utiles pour lire le contenu exact d'un champ actif).

## Devin Secrets Needed
Aucun secret stocké. Identifiants Firebase Auth (email + mot de passe d'un compte V∴M∴/admin) à demander
à l'utilisateur ; l'accès au projet Firebase `benou-re-loge` (CLI) serait nécessaire pour tester un déploiement.

// Configuration Firebase du projet "benou-re-loge".
//
// Ces valeurs proviennent de la configuration web existante (src/firebase.ts).
// Pour un build de production sur appareil, il est recommandé d'exécuter
// `flutterfire configure` afin de générer des identifiants natifs par
// plateforme (appId Android/iOS dédié + google-services.json). Voir le README.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBmjvNZNZX5ZGcR4QAC3rlrTNJiHnFBeGI',
    appId: '1:184228725535:web:397104a16f16932108a62a',
    messagingSenderId: '184228725535',
    projectId: 'benou-re-loge',
    authDomain: 'benou-re-loge.firebaseapp.com',
    storageBucket: 'benou-re-loge.firebasestorage.app',
  );
  // Android : à remplacer par un appId natif via `flutterfire configure`.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBrQaUIG2AjSRCAwjFilVnrLcuZPEum39Y',
    appId: '1:184228725535:android:e831784d7837eadc08a62a',
    messagingSenderId: '184228725535',
    projectId: 'benou-re-loge',
    storageBucket: 'benou-re-loge.firebasestorage.app',
  );
  // iOS : à remplacer par un appId natif via `flutterfire configure`.

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA6d0kMjjS9_tNURYoRKbiqrLjfqSZP2sg',
    appId: '1:184228725535:ios:c61e947d0348c80708a62a',
    messagingSenderId: '184228725535',
    projectId: 'benou-re-loge',
    storageBucket: 'benou-re-loge.firebasestorage.app',
    androidClientId: '184228725535-kptstidkro6e2rr8naau5pbjllusf4vk.apps.googleusercontent.com',
    iosClientId: '184228725535-nt27evr72vn4cuven9c45g3f740tqlep.apps.googleusercontent.com',
    iosBundleId: 're.benou.benouRe',
  );
}

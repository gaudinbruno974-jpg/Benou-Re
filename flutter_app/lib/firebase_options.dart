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
    authDomain: 'benou-re-loge.firebaseapp.com',
    projectId: 'benou-re-loge',
    storageBucket: 'benou-re-loge.firebasestorage.app',
    messagingSenderId: '184228725535',
    appId: '1:184228725535:web:397104a16f16932108a62a',
  );

  // Android : à remplacer par un appId natif via `flutterfire configure`.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmjvNZNZX5ZGcR4QAC3rlrTNJiHnFBeGI',
    projectId: 'benou-re-loge',
    storageBucket: 'benou-re-loge.firebasestorage.app',
    messagingSenderId: '184228725535',
    appId: '1:184228725535:web:397104a16f16932108a62a',
  );

  // iOS : à remplacer par un appId natif via `flutterfire configure`.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBmjvNZNZX5ZGcR4QAC3rlrTNJiHnFBeGI',
    projectId: 'benou-re-loge',
    storageBucket: 'benou-re-loge.firebasestorage.app',
    messagingSenderId: '184228725535',
    appId: '1:184228725535:web:397104a16f16932108a62a',
    iosBundleId: 're.benou.benouRe',
  );
}

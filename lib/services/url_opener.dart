// Ouverture d'une URL externe, indépendante de la plateforme.
// - Mobile (Android) : Intent.ACTION_VIEW via MethodChannel (voir MainActivity).
// - Web : window.open dans un nouvel onglet.
export 'url_opener_mobile.dart'
    if (dart.library.js_interop) 'url_opener_web.dart';

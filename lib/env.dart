// Réglages liés à l'environnement de déploiement.

/// Affiche le pavé « Comptes de test » sur l'écran de connexion.
///
/// ⚠️ Mettre à false avant tout déploiement en production.
///
/// Volontairement indépendant de `kDebugMode` : l'environnement de test est
/// déployé avec `flutter build web --release`, où `kDebugMode` vaut toujours
/// false.
const bool kShowTestAccounts = true;

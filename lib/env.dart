// Réglages liés à l'environnement de déploiement.

import 'config/flavor.dart';

/// Affiche le pavé « Comptes de test » sur l'écran de connexion.
///
/// Bénou Ré, Le Petit Prince et Le Temple d'Horus sont en production : leurs
/// comptes de démonstration sont retirés. AL-Khemia, encore en phase
/// d'essai, les conserve.
///
/// Volontairement indépendant de `kDebugMode` : l'environnement de test est
/// déployé avec `flutter build web --release`, où `kDebugMode` vaut toujours
/// false.
const bool kShowTestAccounts = currentFlavor == 'alkhemia';

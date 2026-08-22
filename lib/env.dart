// Réglages liés à l'environnement de déploiement.

import 'config/flavor.dart';

/// Affiche le pavé « Comptes de test » sur l'écran de connexion.
///
/// Bénou Ré est en production depuis un moment : ses comptes de
/// démonstration sont retirés. Le Petit Prince et Le Temple d'Horus, encore
/// en phase d'essai, les conservent.
///
/// Volontairement indépendant de `kDebugMode` : l'environnement de test est
/// déployé avec `flutter build web --release`, où `kDebugMode` vaut toujours
/// false.
const bool kShowTestAccounts = currentFlavor != 'benoure';

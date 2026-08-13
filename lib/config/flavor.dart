// Détecte la loge active depuis le mécanisme de flavor : `appFlavor` (natif,
// renseigné par `--flavor` sur Android/iOS) ou, sur le web où `appFlavor`
// reste toujours nul, `--dart-define=FLAVOR=<flavor>` (voir README). Point
// central pour tout code qui doit choisir une valeur par flavor en dehors de
// `firebase_options.dart` (ex. `LodgeConfig`).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show appFlavor;

const String _webFlavor = String.fromEnvironment('FLAVOR', defaultValue: 'benoure');

/// Constante de compilation (pas une valeur lue au runtime) : `kIsWeb`,
/// `_webFlavor` et `appFlavor` sont tous des `const`, ce qui permet de
/// continuer à écrire des widgets `const` ailleurs dans l'app (ex.
/// `BrColors` dans `theme.dart`) tout en variant par flavor.
const String currentFlavor = kIsWeb ? _webFlavor : (appFlavor ?? 'benoure');

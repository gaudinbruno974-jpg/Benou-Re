// Sélectionne la configuration Firebase du flavor actif.
//
// `appFlavor` est renseigné automatiquement par le tookit Flutter à partir de
// l'option `--flavor`, déjà obligatoire pour tout build Android (cf.
// android/app/build.gradle.kts) : aucune étape supplémentaire n'est donc
// nécessaire pour qu'une loge parle au bon projet Firebase, et il est
// impossible d'oublier de le préciser puisque le build échoue sinon.
//
// Sur le web, `appFlavor` (mécanisme natif) reste toujours nul : le flavor y
// est fourni au moment du build via `--dart-define=FLAVOR=<flavor>` (voir
// README et lib/config/flavor.dart), avec `benoure` en valeur par défaut pour
// ne rien changer aux builds web existants qui ne précisent pas cette option.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'config/flavor.dart';
import 'firebase_options_alkhemia.dart' as alkhemia;
import 'firebase_options_benoure.dart' as benoure;
import 'firebase_options_petitprince.dart' as petitprince;
import 'firebase_options_templehorus.dart' as templehorus;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (currentFlavor == 'petitprince') {
      return petitprince.DefaultFirebaseOptions.currentPlatform;
    }
    if (currentFlavor == 'templehorus') {
      return templehorus.DefaultFirebaseOptions.currentPlatform;
    }
    if (currentFlavor == 'alkhemia') {
      return alkhemia.DefaultFirebaseOptions.currentPlatform;
    }
    return benoure.DefaultFirebaseOptions.currentPlatform;
  }
}

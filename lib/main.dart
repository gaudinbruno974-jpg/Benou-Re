import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'config/flavor.dart';
import 'config/lodge_config.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/br_decor.dart';
import 'screens/grande_loge_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/parvis_screen.dart';
import 'screens/passport_verify_screen.dart';
import 'screens/presence_response_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BenouReApp());
}

class BenouReApp extends StatelessWidget {
  const BenouReApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: LodgeConfig.current.name,
        debugShowCheckedModeBanner: false,
        theme: buildBrTheme(), // ✅ Le thème est bien centralisé
        locale: const Locale('fr', 'FR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        // Le dégradé et le filigrane sont peints derrière tous les écrans.
        builder: (context, child) =>
            BrBackground(child: child ?? const SizedBox.shrink()),
        home: const _Root(),
      ),
    );
  }
}

/// Jeton de lien de réponse (`#/reponse/<jeton>`), si l'URL en porte un —
/// détecté avant la porte d'authentification puisque la page de réponse est
/// publique, accessible sans connexion (voir presence_response_screen.dart).
String? _presenceResponseToken() {
  final candidates = [Uri.base.fragment, Uri.base.path];
  for (final candidate in candidates) {
    final match = RegExp(r'reponse/([A-Za-z0-9-]+)').firstMatch(candidate);
    if (match != null) return match.group(1);
  }
  return null;
}

/// Jeton de vérification du Passeport Maçonnique (`#/passeport/<jeton>`),
/// même principe que [_presenceResponseToken] — page publique, détectée
/// avant la porte d'authentification.
String? _passportVerifyToken() {
  final candidates = [Uri.base.fragment, Uri.base.path];
  for (final candidate in candidates) {
    final match = RegExp(r'passeport/([A-Za-z0-9-]+)').firstMatch(candidate);
    if (match != null) return match.group(1);
  }
  return null;
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final token = _presenceResponseToken();
    if (token != null) {
      return PresenceResponseScreen(token: token);
    }
    final passportToken = _passportVerifyToken();
    if (passportToken != null) {
      return PassportVerifyScreen(token: passportToken);
    }

    final state = context.watch<AppState>();

    // Écran de chargement : utilise les couleurs du thème
    if (state.authLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: BrColors.gold),
              const SizedBox(height: 24),
              Text(
                'Chargement du Temple...',
                style: TextStyle(color: BrColors.muted, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }

    // Connecté à Firebase Auth mais fiche membre introuvable : on l'indique au
    // lieu de renvoyer silencieusement sur l'écran de connexion.
    if (state.currentUser == null && state.isSignedIn) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.dataError == null) ...[
                  const CircularProgressIndicator(color: BrColors.gold),
                  const SizedBox(height: 24),
                  Text(
                    'Ouverture du Temple...',
                    style: TextStyle(color: BrColors.muted, letterSpacing: 2),
                  ),
                ] else
                  Text(
                    'Accès aux données refusé :\n${state.dataError}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: BrColors.muted),
                  ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.read<AppState>().logout(),
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Utilisateur non connecté → LoginScreen
    if (state.currentUser == null) {
      return const LoginScreen();
    }

    // Grande Loge : pas de Parvis loge bleue (Tenues, Trésorerie...), qui
    // n'a pas de sens pour ce flavor — accueil dédié, voir la planche de
    // cette étape (fondation seulement).
    if (currentFlavor == 'grandeloge') {
      return const GrandeLogeHomeScreen();
    }

    // Utilisateur connecté → ParvisScreen
    return const ParvisScreen();
  }
}

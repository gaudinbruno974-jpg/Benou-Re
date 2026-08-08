import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/br_decor.dart';
import 'screens/login_screen.dart';
import 'screens/parvis_screen.dart';

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
        title: 'Bénou Ré',
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

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
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

    // Utilisateur connecté → ParvisScreen
    return const ParvisScreen();
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/parvis_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        theme: buildBrTheme(),
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
    if (state.authLoading) {
      return const Scaffold(
        backgroundColor: BrColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: BrColors.gold),
              SizedBox(height: 24),
              Text(
                'Chargement du Temple...',
                style: TextStyle(color: BrColors.muted, letterSpacing: 2),
              ),
            ],
          ),
        ),
      );
    }
    if (state.currentUser == null) {
      return const LoginScreen();
    }
    return const ParvisScreen();
  }
}

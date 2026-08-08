// Écran de connexion avec "Se souvenir de moi".
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- NOUVEAU

import '../env.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

/// Mot de passe commun aux comptes fictifs de l'environnement de test.
const String _testPassword = '030365';

/// Comptes fictifs proposés en accès rapide sur l'environnement de test.
///
/// Ces comptes doivent exister dans Firebase Auth et dans la collection
/// `members`. Le V∴M∴ en est volontairement absent : c'est un compte réel.
const List<({String label, String email, String password})> _testAccounts = [
  (label: 'Apprenti', email: 'apprentis@loge.com', password: _testPassword),
  (label: 'Compagnon', email: 'compagnons@loge.com', password: _testPassword),
  (label: 'Maître', email: 'maitres@loge.com', password: _testPassword),
  (label: 'Secrétaire', email: 'secretaire@loge.com', password: _testPassword),
  (label: 'Trésorier', email: 'tresorier@loge.com', password: _testPassword),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _rememberMe = false; // <-- NOUVEAU

  @override
  void initState() {
    super.initState();
    _loadSavedEmail(); // <-- NOUVEAU
  }

  // Charge l'email sauvegardé au démarrage
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remember_email');
    if (email != null) {
      setState(() {
        _emailCtrl.text = email;
        _rememberMe = true;
      });
    }
  }

  // Sauvegarde ou efface l'email selon l'état de la case
  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('remember_email', email);
    } else {
      await prefs.remove('remember_email');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login(String email, String password) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().auth.login(email, password);
      // On sauvegarde l'email si la connexion réussit
      await _saveEmail(email);
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          _error = 'Identifiants incorrects. Vérifiez email et mot de passe.';
        } else {
          _error = e.message ?? 'Erreur lors de la connexion.';
        }
      });
    } catch (e) {
      setState(() => _error = 'Une erreur est survenue lors de la connexion.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Connecte directement l'un des comptes fictifs, champs préremplis pour que
  /// l'on voie quel profil est utilisé.
  void _loginAsTestAccount(String email, String password) {
    _emailCtrl.text = email;
    _passwordCtrl.text = password;
    _login(email, password);
  }

  Widget _testAccountsPanel() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BrColors.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: BrColors.error.withValues(alpha: 0.5),
        width: 1.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, color: BrColors.error, size: 18),
            const SizedBox(width: 8),
            Text(
              'ENVIRONNEMENT DE TEST — ACCÈS RAPIDE',
              style: TextStyle(
                color: BrColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final account in _testAccounts)
              ActionChip(
                label: Text(account.label),
                avatar: const Icon(Icons.person_outline, size: 16),
                onPressed: _loading
                    ? null
                    : () =>
                          _loginAsTestAccount(account.email, account.password),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 92,
                    width: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          BrColors.surface.withValues(alpha: 0.9),
                          BrColors.backgroundDark.withValues(alpha: 0.9),
                        ],
                      ),
                      border: Border.all(
                        color: BrColors.gold.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: BrColors.raisedShadow,
                    ),
                    child: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: BrColors.goldBright,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'RL BÉNOU RÉ',
                    style: TextStyle(
                      color: BrColors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ordre Initiatique Ancien et Primitif de Memphis-Misraïm',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BrColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 32),
                  BrCard(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ORIENT DE SAINT-PIERRE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BrColors.goldBright,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: BrColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: BrColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: BrColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: BrColors.text),
                          decoration: const InputDecoration(
                            labelText: 'Email de connexion',
                            prefixIcon: Icon(
                              Icons.mail_outline,
                              color: BrColors.gold,
                            ),
                            hintText: 'ex: vm@loge.com',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          style: const TextStyle(color: BrColors.text),
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: BrColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ============= LA CASE À COCHER =============
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) => setState(() {
                                _rememberMe = value ?? false;
                                if (!_rememberMe) {
                                  SharedPreferences.getInstance().then(
                                    (prefs) => prefs.remove('remember_email'),
                                  );
                                }
                              }),
                              activeColor: BrColors.teal,
                              checkColor: BrColors.text,
                            ),
                            const Text(
                              'Se souvenir de moi',
                              style: TextStyle(color: BrColors.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // =============================================
                        ElevatedButton.icon(
                          onPressed: _loading
                              ? null
                              : () =>
                                    _login(_emailCtrl.text, _passwordCtrl.text),
                          icon: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: BrColors.text,
                                  ),
                                )
                              : const Icon(Icons.login, size: 18),
                          label: const Text('ENTRER SUR LE PARVIS'),
                        ),
                      ],
                    ),
                  ),
                  if (kShowTestAccounts) ...[
                    const SizedBox(height: 20),
                    _testAccountsPanel(),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    'EX CINERIBUS, AD LUCEM PERPETUAM',
                    style: TextStyle(
                      color: BrColors.muted,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

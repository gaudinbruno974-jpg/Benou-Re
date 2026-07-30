// Écran de connexion (porté depuis src/components/LoginScreen.tsx).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

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

  static const _quickAccounts = [
    ('VM (Bruno)', 'gaudin.bruno974@gmail.com'),
    ('Secrétaire (Muriel)', 'muriel.mete.mm@gmail.com'),
    ('Trésorier (Noah)', 'gaudin.noah974@gmail.com'),
    ('Maître (Philippe)', 'philippe.costille@gmail.com'),
    ('Compagnon (Aure)', 'aure.costille@gmail.com'),
    ('Apprenti (Sacha)', 'sacha.costille@gmail.com'),
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrColors.background,
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
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BrColors.background,
                      border: Border.all(
                        color: BrColors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: BrColors.gold,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'ORIENT DE SAINT-PIERRE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: BrColors.gold,
                              fontSize: 11,
                              letterSpacing: 2,
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
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _login(
                                    _emailCtrl.text,
                                    _passwordCtrl.text,
                                  ),
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
                          const Divider(height: 32, color: BrColors.divider),
                          const Text(
                            'ACCÈS RAPIDE (DÉMO / TEST)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: BrColors.gold,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final acc in _quickAccounts)
                                OutlinedButton(
                                  onPressed: _loading
                                      ? null
                                      : () => _login(acc.$2, 'password123'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: BrColors.goldBright,
                                    side: BorderSide(
                                      color: BrColors.muted.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    acc.$1,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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

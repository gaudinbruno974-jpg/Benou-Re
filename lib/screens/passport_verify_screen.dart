// Page publique de vérification d'un Passeport Maçonnique, scannée via le QR
// plein écran généré depuis member_passport_screen.dart. Accessible sans
// authentification, comme presence_response_screen.dart : voir main.dart
// pour la détection de route et firestore.rules pour la portée exacte des
// droits accordés au jeton (lecture seule, jeton non devinable, jamais
// énumérable). Le jeton n'est valable qu'une heure — voir passport_token.dart.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/passport_token.dart';
import '../state/app_state.dart';
import '../theme.dart';

class PassportVerifyScreen extends StatefulWidget {
  final String token;
  const PassportVerifyScreen({super.key, required this.token});

  @override
  State<PassportVerifyScreen> createState() => _PassportVerifyScreenState();
}

enum _LoadState { loading, notFound, expired, ready }

class _PassportVerifyScreenState extends State<PassportVerifyScreen> {
  _LoadState _state = _LoadState.loading;
  PassportToken? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final token = await appState.getPassportToken(widget.token);
    if (!mounted) return;
    if (token == null) {
      setState(() => _state = _LoadState.notFound);
      return;
    }
    setState(() {
      _token = token;
      _state = token.isExpired ? _LoadState.expired : _LoadState.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'GRANDE LOGE DE BOURBON',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Vérification du Passeport Maçonnique',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  _buildBody(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: BrColors.gold),
        );
      case _LoadState.notFound:
        return const _MessageCard(
          icon: Icons.qr_code_2,
          title: 'QR invalide',
          color: Colors.redAccent,
          message: 'Ce code de vérification est introuvable.',
        );
      case _LoadState.expired:
        return const _MessageCard(
          icon: Icons.hourglass_bottom,
          title: 'Code expiré',
          color: Colors.orange,
          message: "Ce QR n'est plus valable (durée d'une heure dépassée). "
              'Demandez au porteur de le régénérer depuis son application.',
        );
      case _LoadState.ready:
        return _buildValid(_token!);
    }
  }

  Widget _buildValid(PassportToken token) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3FBF6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF34D399), width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF34D399)),
                  SizedBox(width: 8),
                  Text(
                    'Identité vérifiée',
                    style: TextStyle(
                      color: Color(0xFF0F5132),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${civiliteTitle(token.civilite)} ${token.memberName}'.trim(),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (token.grade.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    token.grade,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'R∴L∴ ${token.lodgeName} N°${token.lodgeNumber}',
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
              Text(
                'O∴ de ${token.lodgeOrient} — ${token.lodgeObedience}',
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
              if (token.initiationDate.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "Initié le ${token.initiationDate}",
                    style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ce code est valable jusqu\'à '
          '${token.expiresAt.hour.toString().padLeft(2, '0')}:'
          '${token.expiresAt.minute.toString().padLeft(2, '0')}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.color = BrColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

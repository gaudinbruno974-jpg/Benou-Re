// Affichage plein écran du QR de vérification du Passeport Maçonnique — voir
// member_edit_screen.dart pour la génération du jeton (valable une heure) et
// passport_verify_screen.dart pour la page publique scannée.
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PassportQrFullScreen extends StatelessWidget {
  final String url;
  final String memberName;
  final DateTime expiresAt;
  const PassportQrFullScreen({
    super.key,
    required this.url,
    required this.memberName,
    required this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Vérification du Passeport'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                memberName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              QrImageView(
                data: url,
                size: 260,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                'Valable jusqu\'à '
                '${expiresAt.hour.toString().padLeft(2, '0')}:'
                '${expiresAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

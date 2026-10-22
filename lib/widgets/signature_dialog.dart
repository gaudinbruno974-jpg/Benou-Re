// Pavé de signature partagé (Émargement, Paiement des Agapes).
// Renvoie la signature en data URL base64, ou null si elle est annulée.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../theme.dart';

Future<String?> captureSignature(BuildContext context, String name) async {
  final controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BrColors.surface,
      title: Text(
        'Signature — $name',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SizedBox(
        width: 400,
        height: 220,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          // Taille imposée depuis l'extérieur (ce SizedBox), rien passé à
          // Signature lui-même : lui donner width/height déclenche un calcul
          // de taille interne au package (Center + LimitedBox) qui peut
          // désynchroniser la zone visuellement blanche de la zone
          // réellement cliquable (bandes mortes en haut/bas du pavé,
          // constaté par l'utilisateur sur Android — un premier correctif
          // passant width/height à Signature n'avait pas suffi).
          child: Signature(
            controller: controller,
            backgroundColor: Colors.white,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => controller.clear(),
          child: const Text('Effacer'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (controller.isEmpty) {
              Navigator.pop(ctx);
              return;
            }
            final bytes = await controller.toPngBytes();
            if (bytes == null) {
              if (ctx.mounted) Navigator.pop(ctx);
              return;
            }
            final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
            if (ctx.mounted) Navigator.pop(ctx, dataUrl);
          },
          child: const Text('Valider'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

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
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Signature(
            controller: controller,
            height: 220,
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

// Génération du QR de vérification du Passeport Maçonnique — un jeton valable
// une heure (voir passport_token.dart), affiché plein écran. Fonction
// partagée : seul le membre connecté peut générer SON PROPRE QR (voir
// members_screen.dart, où le bouton n'apparaît que sur sa propre ligne) — à
// la différence du PDF d'archive, réservé au bureau (voir
// member_edit_screen.dart).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../models/member.dart';
import '../models/passport_token.dart';
import '../state/app_state.dart';
import 'passport_qr_fullscreen.dart';

Future<void> showMemberPassportQr(BuildContext context, Member member) async {
  final messenger = ScaffoldMessenger.of(context);
  final state = context.read<AppState>();
  try {
    final lodge = LodgeConfig.current;
    final now = DateTime.now();
    final token = PassportToken(
      id: generatePassportToken(),
      memberId: member.id,
      memberName: member.fullName,
      civilite: member.civilite,
      grade: member.grade,
      initiationDate: member.initiationDate,
      entryDate: member.entryDate,
      lodgeName: lodge.name,
      lodgeNumber: lodge.number,
      lodgeOrient: lodge.orient,
      lodgeObedience: lodge.obedienceAcronym,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    await state.createPassportToken(token);
    if (!context.mounted) return;
    final url = '${lodge.webOrigin}/#/passeport/${token.id}';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PassportQrFullScreen(
          url: url,
          memberName: member.fullName,
          expiresAt: token.expiresAt,
        ),
        fullscreenDialog: true,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
  }
}

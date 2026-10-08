// Émargement Planche Tracée : signature des trois officiers qui
// authentifient la planche tracée (Orateur / V∴M∴ / Secrétaire), enregistrée
// dans les champs planche* de la tenue. Les présents (membres, visiteurs,
// dignitaires) signent désormais au moment du pointage, sur l'écran
// Présence — voir session_presence_screen.dart.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/signature_dialog.dart';

class _Signer {
  final String id; // clé de stockage
  final String name;
  final String role;
  final String? current; // data URL existante
  const _Signer(this.id, this.name, this.role, this.current);
}

class EmargementScreen extends StatelessWidget {
  final String sessionId;
  const EmargementScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => Session(id: sessionId),
    );
    // Signatures officielles de la planche tracée.
    final vmName = plancheVmName(
      session,
      state.members,
      lodgeVmName: state.lodgeVmName,
    );
    final orateur = state.members.firstWhere(
      (m) =>
          m.function.trim() == 'Orateur' && session.presentIds.contains(m.id),
      orElse: () => const Member(id: ''),
    );
    final secretaire = state.members.firstWhere(
      (m) =>
          m.function.trim() == 'Secrétaire' &&
          session.presentIds.contains(m.id),
      orElse: () => const Member(id: ''),
    );
    final plancheSigners = <_Signer>[
      _Signer(
        'plancheOrateurSignature',
        session.plancheOrateurName ??
            (orateur.id.isNotEmpty ? orateur.fullName : 'Orateur'),
        // Civilité inconnue quand le nom vient du champ saisi à la main
        // (pas de fiche associée à l'orateur dans ce cas).
        '${civiliteTitle(session.plancheOrateurName != null ? '' : orateur.civilite)} Orateur',
        session.plancheOrateurSignature,
      ),
      _Signer(
        'plancheVMSignature',
        vmName,
        'Le Vénérable Maître',
        session.plancheVMSignature,
      ),
      _Signer(
        'plancheSecretarySignature',
        secretaire.id.isNotEmpty ? secretaire.fullName : 'Secrétaire',
        '${civiliteTitle(secretaire.civilite)} Secrétaire',
        session.plancheSecretarySignature,
      ),
    ];

    final missing = plancheSigners
        .where((a) => (a.current ?? '').isEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Émargement Planche Tracée'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$missing signature(s) manquante(s) sur ${plancheSigners.length} signataire(s)',
                style: const TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          for (final s in plancheSigners)
            _SignerTile(signer: s, onSign: () => _sign(context, session, s)),
        ],
      ),
    );
  }

  Future<void> _sign(
    BuildContext context,
    Session session,
    _Signer signer,
  ) async {
    final state = context.read<AppState>();
    final dataUrl = await captureSignature(context, signer.name);
    if (dataUrl == null) return;

    final map = Map<String, dynamic>.from(session.toMap());
    map[signer.id] = dataUrl;
    await state.updateSession(Session.fromMap(session.id, map));
  }
}

class _SignerTile extends StatelessWidget {
  final _Signer signer;
  final VoidCallback? onSign;
  const _SignerTile({required this.signer, this.onSign});

  @override
  Widget build(BuildContext context) {
    final signed = (signer.current ?? '').isNotEmpty;
    final color = signed ? const Color(0xFF34D399) : BrColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        accent: color,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signer.role,
                    style: const TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            BrBadge(
              label: signed ? 'Signé' : 'En attente',
              color: color,
              icon: signed ? Icons.check_circle_outline : Icons.schedule,
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onSign,
              child: Text(
                signed ? 'Modifier' : 'Signer',
                style: const TextStyle(color: BrColors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

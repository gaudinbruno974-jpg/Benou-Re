// Émargement : capture des signatures (porté depuis
// src/components/SessionEmargementScreen.tsx + SignaturePad.tsx).
// Chaque présent signe ; les signatures (data URL base64) sont enregistrées
// dans session.signatures. Les signatures de la planche (Orateur / V∴M∴ /
// Secrétaire) sont enregistrées dans les champs planche* de la tenue.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final sigs = session.signatures;

    final presentMembers = state.members
        .where((m) => session.presentIds.contains(m.id))
        .toList();
    final presentVisitors = state.visitors
        .where((v) => session.visitorIds.contains(v.id))
        .toList();
    final presentDignitaries = state.dignitaries
        .where((d) => session.dignitaryIds.contains(d.id))
        .toList();

    final memberSigners = <_Signer>[
      for (final m in presentMembers)
        _Signer(
          m.id,
          m.fullName,
          m.function != 'Aucun' && m.function.isNotEmpty
              ? m.function
              : 'Membre',
          sigs[m.id],
        ),
    ];
    final visitorSigners = <_Signer>[
      for (final v in presentVisitors)
        _Signer(
          v.id,
          v.fullName,
          session.visitorRoles[v.id] ??
              (v.function.isNotEmpty ? v.function : 'Visiteur'),
          sigs[v.id],
        ),
    ];
    final dignitarySigners = <_Signer>[
      for (final d in presentDignitaries)
        _Signer(
          d.id,
          d.fullName,
          session.dignitaryRoles[d.id] ??
              (d.title.isNotEmpty ? d.title : 'Dignitaire'),
          sigs[d.id],
        ),
    ];
    final attendees = <_Signer>[
      ...memberSigners,
      ...visitorSigners,
      ...dignitarySigners,
    ];

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
        'Le Frère Orateur',
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
        'La Sœur Secrétaire',
        session.plancheSecretarySignature,
      ),
    ];

    // Tenue suspendue : seules les signatures de la planche tracée restent
    // affichées et signables.
    final isSuspended = session.isSuspended;
    final signers = isSuspended ? plancheSigners : attendees;
    final missing = signers.where((a) => (a.current ?? '').isEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emargement'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isSuspended
                    ? '$missing signature(s) manquante(s) sur ${signers.length} signataire(s) de la planche tracée'
                    : '$missing signature(s) manquante(s) sur ${signers.length} présent(s)',
                style: const TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          if (isSuspended)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Tenue suspendue : seules les signatures de la planche tracée restent disponibles.',
                style: TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          if (!isSuspended) ...[
            const _SectionTitle('MEMBRES PRÉSENTS'),
            if (memberSigners.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Aucun membre présent enregistré.',
                  style: TextStyle(color: BrColors.muted),
                ),
              ),
            for (final a in memberSigners)
              _SignerTile(
                signer: a,
                onSign: () => _sign(context, session, a, isPlanche: false),
              ),
            const SizedBox(height: 12),
            const _SectionTitle('VISITEURS PRÉSENTS'),
            if (visitorSigners.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Aucun visiteur présent enregistré.',
                  style: TextStyle(color: BrColors.muted),
                ),
              ),
            for (final a in visitorSigners)
              _SignerTile(
                signer: a,
                onSign: () => _sign(context, session, a, isPlanche: false),
              ),
            const SizedBox(height: 12),
            const _SectionTitle('DIGNITAIRES PRÉSENTS'),
            if (dignitarySigners.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Aucun dignitaire présent enregistré.',
                  style: TextStyle(color: BrColors.muted),
                ),
              ),
            for (final a in dignitarySigners)
              _SignerTile(
                signer: a,
                onSign: () => _sign(context, session, a, isPlanche: false),
              ),
            const SizedBox(height: 12),
          ],
          const _SectionTitle('SIGNATURES DE LA PLANCHE TRACÉE'),
          for (final s in plancheSigners)
            _SignerTile(
              signer: s,
              onSign: () => _sign(context, session, s, isPlanche: true),
            ),
        ],
      ),
    );
  }

  Future<void> _sign(
    BuildContext context,
    Session session,
    _Signer signer, {
    required bool isPlanche,
  }) async {
    final state = context.read<AppState>();
    final dataUrl = await captureSignature(context, signer.name);
    if (dataUrl == null) return;

    final map = Map<String, dynamic>.from(session.toMap());
    if (isPlanche) {
      map[signer.id] = dataUrl;
    } else {
      final sigs = Map<String, dynamic>.from(
        (map['signatures'] as Map?) ?? <String, dynamic>{},
      );
      sigs[signer.id] = dataUrl;
      map['signatures'] = sigs;
    }
    await state.updateSession(Session.fromMap(session.id, map));
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: BrSectionTitle(text, icon: Icons.draw_outlined),
    );
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
